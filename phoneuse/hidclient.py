"""Client for the HID service's command socket (hid_daemon.py on Linux,
windows/hid.py on Windows; both speak the same line protocol)."""
import threading

from . import ipc


class Hid:
    """One connection to the HID service. Thread-safe: commands are serialized. When the
    service restarts, the next command reconnects and is sent again once, so long-lived
    clients (the mirror window, the browser mirror) keep working."""

    def __init__(self, timeout=None):
        self.timeout = timeout
        self.lock = threading.Lock()
        self._connect()

    def _connect(self):
        self.sock = ipc.connect("hid", timeout=5.0)
        self.sock.settimeout(self.timeout)
        self.f = self.sock.makefile("rb")

    def _send(self, line):
        self.sock.sendall((line + "\n").encode())
        reply = self.f.readline().decode(errors="replace").strip()
        if not reply:  # the service closed the connection
            raise ConnectionResetError("the HID service closed the connection")
        return reply

    def cmd(self, line):
        with self.lock:
            try:
                reply = self._send(line)
            except OSError:
                self.close()
                self._connect()  # the service restarted: a new connection, then once more
                reply = self._send(line)
        if not reply.startswith("ok"):
            raise RuntimeError(reply)
        return reply

    def close(self):
        try:
            self.sock.close()
        except OSError:
            pass
