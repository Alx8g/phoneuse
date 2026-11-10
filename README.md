<img src="packaging/icons/hicolor/256x256/apps/co.lxe.PhoneUse.png" width="128" alt="Phone Use icon: a sleepy cloud hugging a phone">

# Phone Use

**[phoneuse.tech](https://phoneuse.tech)** · **[Download](https://github.com/lxe/phoneuse/releases/latest)**

Let your AI agent, or you, use your iPhone from your computer. Your iPhone's screen
shows up in a window, and Claude Code, Codex and other agents can tap and type on it,
with your permission. No jailbreak and no cable.

Phone Use is alpha software. Please [report what breaks](https://github.com/lxe/phoneuse/issues).

## Install

1. Download Phone Use for your computer from the
   [latest release](https://github.com/lxe/phoneuse/releases/latest):
   - **Linux:** `PhoneUse-<version>-x86_64.flatpak`, then
     `flatpak install --user ./PhoneUse-<version>-x86_64.flatpak`
   - **Mac** (macOS 15 or later): `PhoneUse-<version>-mac.dmg`. Drag Phone Use to Applications.
     The Mac app needs [the bridge](#the-bridge).
   - **Windows:** from source for now, see [docs/WINDOWS.md](docs/WINDOWS.md).
2. Install the Phone Use iPhone app. It isn't in the App Store yet; build it from
   [`ios/`](ios/README.md) with Xcode.
3. Open Phone Use on your computer. It walks you through the rest: connecting the
   keyboard and mouse, pairing the iPhone app, and starting Screen Mirroring.

Your iPhone and your computer need to be on the same Wi-Fi.

## Use it

- **Yourself:** click Open iPhone. Click to tap, drag to swipe, scroll with your mouse
  wheel, and type on your keyboard.
- **With an agent:** click Connect Claude Code in the app. Phone Use can ask you on your
  iPhone before an agent takes control, and you can take over at any time.

## The bridge

The bridge is a small board that joins your Wi-Fi and acts as your iPhone's keyboard
and mouse, so your computer's Bluetooth stays free. Buy a
[LilyGO T-Display](https://lilygo.cc/products/t-display) and flash it from the Linux
app (Bridge › Flash LilyGO T-Display). [docs/BRIDGE.md](docs/BRIDGE.md) has the other
ways to flash it and how it works.

## More

- [Running from source](docs/SOURCE.md) and [Windows](docs/WINDOWS.md)
- [How it works](ARCHITECTURE.md)
- [The iPhone app and its API](docs/COMPANION.md)
- [The website](site/README.md) · [Privacy policy](docs/PRIVACY.md)

## License

MIT
