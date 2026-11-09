# Phone Use for macOS

A SwiftUI shell around the same core as the Linux app (docs/MAC.md): a menu bar item and one window with the
Phone, Agents and Bridge tabs. The app keeps no phone state of its own; it reads `GET /api/app` from the core
and changes settings through the browser mirror's local API, like `phoneuse/app.py`.

## Develop

```sh
brew install gstreamer pygobject3 libplist openssl@3 cmake pkgconf xcodegen
python3.15 -m venv --system-site-packages .venv          # in the repository root
.venv/bin/pip install aiohttp numpy pillow bleak cryptography qrcode
git clone https://github.com/FDH2/UxPlay ~/code/UxPlay && cmake -S ~/code/UxPlay -B ~/code/UxPlay/build \
  -DCMAKE_BUILD_TYPE=Release -DNO_X11_DEPS=ON && make -C ~/code/UxPlay/build -j8
cd mac && xcodegen generate && xcodebuild -scheme PhoneUse -derivedDataPath build build
open "build/Build/Products/Debug/Phone Use.app"
```

The development build runs the core from this checkout (`PhoneUseRepo` in Info.plist, or `PHONEUSE_REPO`) with
its `.venv`, and UxPlay from `PHONEUSE_UXPLAY`, `~/code/UxPlay/build/uxplay` or Homebrew. If `phoneuse serve`
already runs in a terminal, the app uses it and leaves it running when it quits. The core's log is in
`~/Library/Logs/Phone Use/core.log`.

`PHONEUSE_SNAPSHOT=DIR` (debug builds) writes each tab to `DIR/<tab>.png` and quits, for design reviews
without Screen Recording permission.
