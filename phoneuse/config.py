"""phoneuse settings: defaults, overridden by ~/.config/phoneuse/config.toml.

Example config.toml:

    name = "PhoneUse"                 # AirPlay receiver name (default: "PhoneUse on <this computer>")
    screen_points = [402, 874]       # your iPhone's screen in points (iPhone 17 Pro)
    decoder = "auto"                 # GStreamer H.264 decoder; auto picks NVDEC if present
    mirror_width = 498               # mirror window width in logical pixels
    web_port = 8777                  # browser mirror: http://localhost:8777
    bluetooth = "pc"                 # "pc": this PC's Bluetooth and the bridge (root daemon, phoneuse install);
                                     # "bridge": the bridge only, everything runs as the user (the app)
"""
import os
import shutil
import socket
import subprocess
import sys
import tomllib


def computer_name():
    """This computer's name as people see it: macOS's Computer Name, the pretty hostname
    (hostnamectl) on Linux, else the short hostname."""
    if sys.platform == "darwin":
        try:
            n = subprocess.run(["scutil", "--get", "ComputerName"], capture_output=True, text=True,
                               timeout=2).stdout.strip()
            if n:
                return n
        except (OSError, subprocess.SubprocessError):
            pass
    try:
        with open("/etc/machine-info") as f:
            for line in f:
                if line.startswith("PRETTY_HOSTNAME="):
                    n = line.split("=", 1)[1].strip().strip('"')
                    if n:
                        return n
    except OSError:
        pass
    return socket.gethostname().split(".")[0]


DEFAULTS = {
    # Each computer's receiver gets its own name, so two on one network don't show up in
    # Screen Mirroring as "PhoneUse" and "PhoneUse (2)".
    "name": f"PhoneUse on {computer_name()}",
    "screen_points": [402, 874],
    "decoder": "auto",
    "mirror_width": 498,
    "web_port": 8777,
    # the app (a Flatpak) can only use the bridge; a checkout uses this PC's Bluetooth too
    "bluetooth": "bridge" if os.path.exists("/.flatpak-info") else "pc",
}

RUNTIME_DIR = os.environ.get("XDG_RUNTIME_DIR", "/tmp")
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
USER_DAEMON = CFG["bluetooth"] == "bridge"  # the app: the HID daemon runs as the user, never as root
# The app can use this PC's Bluetooth too, once bluetoothd is prepared for it (one admin password;
# see bluetooth_setup.py): this file exists while that is on.
PC_BLUETOOTH_FLAG = os.path.join(os.path.dirname(config_path()), "pc-bluetooth")
BRIDGE_ONLY = USER_DAEMON and not os.path.exists(PC_BLUETOOTH_FLAG)
# The HID daemon's command socket: the root service's, or the user's own in bridge-only mode.
HID_SOCKET = os.path.join(RUNTIME_DIR, "phoneuse-hid.sock") if USER_DAEMON else "/run/phoneuse-hid.sock"
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
