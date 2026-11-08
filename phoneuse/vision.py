"""Vision service for phoneuse: keeps OCR loaded.

Runs in .venv-vision (its own deps; `python -m phoneuse.vision`). Listens on $XDG_RUNTIME_DIR/phoneuse-vision.sock;
one JSON request per connection, one JSON reply:
  {"op": "text", "image": PATH}            -> {"lines": [{"text", "x", "y", "w", "h", "conf"}]}

Models (chosen 2026-11-06 on real iPhone screenshots):
  OCR: RapidOCR with PP-OCRv6 small (ONNX; GPU with onnxruntime-gpu, else CPU).
       Exact on iOS UI text incl. arrows, ~0.18 s per screen on an RTX 5090
       (~1.2 s on the CPU); Tesseract garbled symbols.
  On macOS: Apple's Vision framework through phoneuse-ocr (mac/ocr/main.swift; ~0.2 s a screen on Apple
       silicon), so the Mac app ships no model and the service runs in the core's own Python.
  (A GUI grounding model, GoClick-Large, used to find elements from descriptions;
  removed 2026-11-08: agents tap text by OCR and everything else by position.)
"""
import json
import os
import socket
import sys
import time

from .config import VISION_SOCKET as SOCK  # noqa: E402  (shared with the CLI)
from . import ipc  # noqa: E402
from .config import IS_WINDOWS  # noqa: E402


def log(*a):
    print(time.strftime("%H:%M:%S"), *a, file=sys.stderr, flush=True)


def mac_ocr():
    """The macOS text recognizer (mac/ocr/main.swift): PHONEUSE_OCR, the app's core/bin, or a development build in
    mac/build (`swiftc -O mac/ocr/main.swift -o mac/build/phoneuse-ocr`). None elsewhere or when it isn't built."""
    if sys.platform != "darwin":
        return None
    root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    for path in (os.environ.get("PHONEUSE_OCR"), os.path.join(root, "bin", "phoneuse-ocr"),
                 os.path.join(root, "mac", "build", "phoneuse-ocr")):
        if path and os.access(path, os.X_OK):
            return path
    return None


class MacVision:
    """OCR with Apple's Vision framework: one phoneuse-ocr process, an image path in, a JSON line out."""

    def __init__(self, helper):
        import subprocess
        self.proc = subprocess.Popen([helper], stdin=subprocess.PIPE, stdout=subprocess.PIPE, text=True, bufsize=1)
        self.ocr_device = "vision"
        log("OCR with Apple Vision:", helper)
        self.lock = threading.Lock()

    def text(self, image):
        self.proc.stdin.write(os.path.abspath(image) + "\n")
        self.proc.stdin.flush()
        reply = json.loads(self.proc.stdout.readline())
        if "error" in reply:
            raise RuntimeError(reply["error"])
        return reply

    def handle(self, req):
        with self.lock:
            if req["op"] == "text":
                return self.text(req["image"])
            if req["op"] in ("ping", "quit"):
                return {"ok": True}
            return {"error": "unknown op"}


class Vision:
    def __init__(self):
        import threading
        import onnxruntime
        if sys.platform == "win32" and hasattr(onnxruntime, "preload_dlls"):
            # Windows: CUDA and cuDNN for onnxruntime-gpu come from pip (its [cuda,cudnn]
            # extras); load them before the first session, or OCR falls back to the CPU.
            try:
                onnxruntime.preload_dlls()
            except Exception as e:
                log("CUDA libraries for OCR:", e)
        from rapidocr import RapidOCR
        import logging
        logging.getLogger("RapidOCR").setLevel(logging.WARNING)
        # No text-orientation classifier: iOS text is upright (saves ~75 ms). On an
        # NVIDIA GPU (onnxruntime-gpu) a screen takes ~0.18 s, on the CPU ~1.2 s.
        params = {"Global.use_cls": False, "Det.limit_side_len": 960,
                  "EngineConfig.onnxruntime.intra_op_num_threads": min(8, os.cpu_count() or 4)}
        if "CUDAExecutionProvider" in onnxruntime.get_available_providers():
            params["EngineConfig.onnxruntime.use_cuda"] = True
        self.ocr = RapidOCR(params=params)
        self.ocr_device = "cuda" if params.get("EngineConfig.onnxruntime.use_cuda") else "cpu"
        log("OCR on", self.ocr_device)
        self.lock = threading.Lock()

    def text(self, image):
        from PIL import Image
        W, H = Image.open(image).size
        r = self.ocr(image)
        lines = []
        for box, txt, conf in zip(r.boxes if r.boxes is not None else [], r.txts or [], r.scores or []):
            xs = [float(p[0]) for p in box]
            ys = [float(p[1]) for p in box]
            lines.append({"text": txt, "x": round(sum(xs) / 4 / W, 4), "y": round(sum(ys) / 4 / H, 4),
                          "w": round((max(xs) - min(xs)) / W, 4), "h": round((max(ys) - min(ys)) / H, 4),
                          "conf": round(float(conf), 3)})
        return {"lines": lines}

    def handle(self, req):
        with self.lock:
            if req["op"] == "text":
                return self.text(req["image"])
            if req["op"] in ("ping", "quit"):
                return {"ok": True}
            return {"error": "unknown op"}


def serve():
    if IS_WINDOWS:  # 127.0.0.1 and the per-user token (ipc.py); one service per user by its port
        v = Vision()
        ipc.serve("vision", lambda conn, rfile: _client(v, conn, rfile), log=log)
        return
    # One service at a time: two agents that both find no socket may each start one, and the
    # second would take the socket from the first, which then runs unreachable forever.
    import fcntl
    lock = open(SOCK + ".lock", "w")
    try:
        fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
    except OSError:
        log("another vision service runs; exiting")
        return
    helper = mac_ocr()
    v = MacVision(helper) if helper else Vision()
    try:
        os.unlink(SOCK)
    except FileNotFoundError:
        pass
    s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    s.bind(SOCK)
    s.listen(8)
    log("vision service on", SOCK)
    while True:
        conn, _ = s.accept()
        threading.Thread(target=_client, args=(v, conn), daemon=True).start()


def _client(v, conn, rfile=None):  # requests: {"op": "text" | "ping" | "quit", ...}
    req = {}
    with conn:
        try:
            req = json.loads((rfile or conn.makefile("rb")).readline())
            reply = v.handle(req)
        except Exception as e:
            reply = {"error": str(e)}
        try:
            data = json.dumps(reply)
        except TypeError as e:
            data = json.dumps({"error": f"bad reply: {e}"})
        conn.sendall((data + "\n").encode())
    if req.get("op") == "quit":  # the supervisor stopped: the models shouldn't stay in memory
        try:
            os.unlink(SOCK)
        except OSError:
            pass
        os._exit(0)


if __name__ == "__main__":
    serve()
