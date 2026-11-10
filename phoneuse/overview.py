"""The control window's first line: the one thing left to do, or the iPhone when nothing is.

Every shell (the GTK window, the Mac app) shows the same step, so the order of checks lives
here, and the shells read it from GET /api/app. A step is
  {"step": id, "title", "detail", "action": id or None, "icon": id, "good": bool, "quiet": bool}
where `detail` is plain text (a shell may bold `bold` inside it), `action` names what the
button does (start, setup_bridge, pair_app, open_ports, retry, open_phone), `icon` is one of phone,
keyboard, offline, bluetooth, `steps` (when present) is a numbered list to show under the title,
where "{mirroring}" stands for the Screen Mirroring icon inline and `bold` is bolded too, `good` marks a healthy state and `quiet` a button that is a
fallback rather than the step itself.
"""


def _step(step, title, detail="", action=None, icon="phone", good=False, quiet=False, bold=None, steps=None):
    return {"step": step, "title": title, "detail": detail, "action": action, "icon": icon,
            "good": good, "quiet": quiet, "bold": bold, "steps": steps}


def stopped():
    """For a shell that finds no services running (the API can't say this itself)."""
    return _step("stopped", "Phone Use is stopped", "Start it to see and use your iPhone here.", "start")


def hero(s, name):
    """s: {"picture", "bridge", "firewall", "confirmed", "paired"} as /api/app gathers them."""
    pic, b = s.get("picture"), s.get("bridge") or {}
    st, saved = b.get("status") or {}, b.get("saved")
    if not pic:
        return _step("starting", "Starting…")
    if not saved:
        return _step("setup_bridge", "Set up the bridge", "The bridge is a small puck that taps and types on your "
                     "iPhone over Bluetooth, and connects to this PC over Wi-Fi. Keep it plugged in near your iPhone.", "setup_bridge", icon="keyboard")
    if not s.get("paired"):
        return _step("pair_app", "Pair the iPhone app", "Install and pair the Phone Use app. It's where you allow "
                     "and stop agents.", "pair_app")
    if not pic.get("live"):
        fw = bool(s.get("firewall")) and not s.get("confirmed")
        return _step("start_mirroring", "Start Screen Mirroring",
                     f"If {name} isn't listed, open the ports." if fw else "",
                     "open_ports" if fw else None, quiet=True, bold=name,
                     steps=["On the iPhone, swipe down from the top-right corner.",
                            "Tap {mirroring} Screen Mirroring.", f"Choose {name}."])
    if st.get("error"):
        return _step("bridge_offline", "The bridge is offline", "Check that it has power and is on the same "
                     "Wi-Fi as this PC.", "retry", icon="offline")
    if not st.get("connected"):
        return _step("connect_bridge", "Connect the bridge to the iPhone", "On the iPhone, open Settings › "
                     "Bluetooth and tap PhoneUse Bridge. If it won't connect, forget it there and tap it again.", icon="bluetooth")
    if pic.get("paused"):
        return _step("taken_over", "You're in control", "You took over from the agent.", "open_phone", good=True)
    if pic.get("stale"):
        return _step("stale", "The picture is old", "The iPhone's screen is off, or mirroring stalled.",
                     "open_phone")
    if pic.get("lag"):
        return _step("lag", f"The picture is {pic['lag']} s behind", "A screen recording on the iPhone slows "
                     "mirroring.", "open_phone", good=True)
    return _step("mirroring", st.get("phone") or "iPhone", "Mirroring to this PC", "open_phone", good=True)
