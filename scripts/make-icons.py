#!/usr/bin/env python3
"""Make every app icon from the one master drawing, packaging/icons/app/phone-use-icon.svg
(1024 x 1024, full bleed). Run it after changing the master; it needs rsvg-convert and magick.

  iOS:    ios/App/Assets.xcassets/AppIcon.appiconset/icon-1024.png
          the square itself, no transparency: iOS draws the rounded mask.
  macOS:  mac/PhoneUse/Assets.xcassets/AppIcon.appiconset/icon-<size>.png (16 to 1024 at 1x and 2x)
          Apple's macOS shape: an 824 x 824 rounded square inside the 1024 canvas, with a soft shadow.
  Linux:  packaging/flatpak/co.lxe.PhoneUse.svg (the app icon) and phoneuse/web/favicon.svg
          a rounded square with GNOME's margin (8 of every 128).
"""
import json
import os
import re
import subprocess
import tempfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
MASTER = os.path.join(ROOT, "packaging", "icons", "app", "phone-use-icon.svg")


def art():
    """The master's drawing (everything inside <svg>), its ids made unique per use."""
    s = open(MASTER).read()
    s = re.sub(r"<!--.*?-->", "", s, flags=re.S)
    return re.search(r"<svg[^>]*>(.*)</svg>", s, re.S).group(1).strip()


def framed(x, size, radius, shadow=False):
    """The drawing scaled into a rounded square at (x, x), size wide, on a 1024 canvas."""
    k = size / 1024
    shadow_def = shadow_use = ""
    if shadow:
        shadow_def = ('<filter id="shadow" x="-10%" y="-10%" width="120%" height="125%">'
                      '<feDropShadow dx="0" dy="10" stdDeviation="14" flood-color="#000" flood-opacity=".3"/></filter>')
        shadow_use = f'<rect x="{x}" y="{x}" width="{size}" height="{size}" rx="{radius}" filter="url(#shadow)"/>'
    return (f'<svg xmlns="http://www.w3.org/2000/svg" width="1024" height="1024" viewBox="0 0 1024 1024">'
            f'<defs><clipPath id="shape"><rect x="{x}" y="{x}" width="{size}" height="{size}" rx="{radius}"/>'
            f'</clipPath>{shadow_def}</defs>{shadow_use}'
            f'<g clip-path="url(#shape)"><g transform="translate({x} {x}) scale({k})">{art()}</g></g></svg>\n')


def png(svg_text, size, path, opaque=False):
    with tempfile.NamedTemporaryFile("w", suffix=".svg", delete=False) as f:
        f.write(svg_text)
    try:
        subprocess.run(["rsvg-convert", "-w", str(size), "-h", str(size), f.name, "-o", path], check=True)
        if opaque:  # App Store icons must have no alpha channel
            subprocess.run(["magick", path, "-background", "white", "-alpha", "remove", "-alpha", "off", path],
                           check=True)
    finally:
        os.unlink(f.name)


def main():
    square = open(MASTER).read()

    ios = os.path.join(ROOT, "ios", "App", "Assets.xcassets", "AppIcon.appiconset")
    png(square, 1024, os.path.join(ios, "icon-1024.png"), opaque=True)

    mac_svg = framed(100, 824, 185, shadow=True)
    mac = os.path.join(ROOT, "mac", "PhoneUse", "Assets.xcassets", "AppIcon.appiconset")
    os.makedirs(mac, exist_ok=True)
    images = []
    for pt in (16, 32, 128, 256, 512):
        for scale in (1, 2):
            px = pt * scale
            name = f"icon-{px}.png"
            if not os.path.exists(os.path.join(mac, name)):
                png(mac_svg, px, os.path.join(mac, name))
            images.append({"filename": name, "idiom": "mac", "scale": f"{scale}x", "size": f"{pt}x{pt}"})
    with open(os.path.join(mac, "Contents.json"), "w") as f:
        json.dump({"images": images, "info": {"author": "xcode", "version": 1}}, f, indent=2)
    with open(os.path.join(os.path.dirname(mac), "Contents.json"), "w") as f:
        json.dump({"info": {"author": "xcode", "version": 1}}, f, indent=2)

    linux = framed(64, 896, 200)
    for path in (os.path.join(ROOT, "packaging", "flatpak", "co.lxe.PhoneUse.svg"),
                 os.path.join(ROOT, "phoneuse", "web", "favicon.svg")):
        with open(path, "w") as f:
            f.write(linux)
    print("icons written")


if __name__ == "__main__":
    main()
