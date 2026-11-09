"""phoneuse settings: defaults, overridden by ~/.config/phoneuse/config.toml.

Example config.toml:

    name = "PhoneUse"                 # Bluetooth device and AirPlay receiver name
    screen_points = [402, 874]       # your iPhone's screen in points (iPhone 17 Pro)
    decoder = "auto"                 # GStreamer H.264 decoder; auto picks NVDEC if present
    mirror_width = 498               # mirror window width in logical pixels
    web_port = 8777                  # browser mirror: http://localhost:8777
    bluetooth = "pc"                 # "pc": this PC's Bluetooth and the bridge (root daemon, phoneuse install);
                                     # "bridge": the bridge only, everything runs as the user (the app)
"""
import os
import shutil
import subprocess
import sys
import tempfile
import tomllib

MACOS = sys.platform == "darwin"

DEFAULTS = {
    "name": "PhoneUse",
    "screen_points": [402, 874],
    "decoder": "auto",
    "mirror_width": 498,
    "web_port": 8777,
    # the app (a Flatpak) can only use the bridge; a checkout uses this PC's Bluetooth too
    # (a Mac has only the bridge: macOS can't make the Mac a Bluetooth keyboard and mouse)
    "bluetooth": "bridge" if os.path.exists("/.flatpak-info") or MACOS else "pc",
    # UxPlay's base port (TCP and UDP n, n+1, n+2); None: its legacy fixed ports (7000, 7001, 7100;
    # 6000, 6001, 7011). macOS's own AirPlay Receiver holds 7000, so the Mac uses 7200.
    "airplay_port": 7200 if MACOS else None,
}

# macOS has no XDG_RUNTIME_DIR; its per-user temporary directory is private to the user like one
RUNTIME_DIR = os.environ.get("XDG_RUNTIME_DIR") or (tempfile.gettempdir() if MACOS else "/tmp")
if os.environ.get("FLATPAK_ID"):
    # Each `flatpak run` gets its own private runtime directory; only app/<id> is shared between
    # instances, so the service's sockets go there for agents' `phoneuse` commands to reach.
    RUNTIME_DIR = os.path.join(RUNTIME_DIR, "app", os.environ["FLATPAK_ID"])
VISION_SOCKET = os.path.join(RUNTIME_DIR, "phoneuse-vision.sock")
HUB_SOCKET = os.path.join(RUNTIME_DIR, "phoneuse-hub.sock")
FRAMES_SOCKET = os.path.join(RUNTIME_DIR, "phoneuse-frames.sock")


def config_path():
    base = os.environ.get("XDG_CONFIG_HOME", os.path.expanduser("~/.config"))
    return os.path.join(base, "phoneuse", "config.toml")


def load():
    cfg = dict(DEFAULTS)
    try:
        with open(config_path(), "rb") as f:
            cfg.update(tomllib.load(f))
    except FileNotFoundError:
        pass
    return cfg


CFG = load()
# Bridge only: the HID daemon runs as the user and never touches this PC's Bluetooth.
BRIDGE_ONLY = CFG["bluetooth"] == "bridge"
# The HID daemon's command socket: the root service's, or the user's own in bridge-only mode.
HID_SOCKET = os.path.join(RUNTIME_DIR, "phoneuse-hid.sock") if BRIDGE_ONLY else "/run/phoneuse-hid.sock"
STATE_DIR = os.path.join(os.environ.get("XDG_STATE_HOME", os.path.expanduser("~/.local/state")), "phoneuse")
NAME = CFG["name"]
SCREEN_PT = tuple(CFG["screen_points"])
PHONE_ASPECT = SCREEN_PT[0] / SCREEN_PT[1]


def decoder():
    """H.264 decoder for the mirror. Frames must leave the decoder as soon as they
    are decoded: iOS only sends a frame when the screen changes and doesn't declare
    'no reordering', so a default decoder holds each frame until the next arrives
    (measured 200 ms). nvh264dec with compliance=flexible releases them in ~1 ms;
    the software decoder releases them immediately."""
    d = CFG["decoder"]
    if d != "auto":
        return d
    if shutil.which("gst-inspect-1.0"):
        r = subprocess.run(["gst-inspect-1.0", "nvh264dec"], capture_output=True)
        if r.returncode == 0:
            return "nvh264dec max-display-delay=0 compliance=flexible"
    return "avdec_h264"
