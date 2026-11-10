<img src="packaging/icons/hicolor/256x256/apps/co.lxe.PhoneUse.png" width="128" alt="Phone Use icon: a sleepy cloud hugging a phone">

# Phone Use

**[phoneuse.tech](https://phoneuse.tech)** · **[Download](https://github.com/lxe/phoneuse/releases/latest)**

Phone Use lets an AI agent, or you, see and operate a real iPhone from your computer.
The iPhone mirrors its screen to the computer over AirPlay, and the computer taps and
types on it as a Bluetooth mouse and keyboard. Claude Code, Codex and other agents use
it from the command line or over MCP, and the Phone Use iPhone app is where you allow
and stop them.

No jailbreak, no developer account, no cable: Phone Use relies on Screen Mirroring and
AssistiveTouch, which every iPhone has.

> [!NOTE]
> Phone Use is alpha software. Expect rough edges, and please
> [report what breaks](https://github.com/lxe/phoneuse/issues).

## Download

Get the files from the **[latest release](https://github.com/lxe/phoneuse/releases/latest)**.

| | |
|---|---|
| **Linux** | `PhoneUse-<version>-x86_64.flatpak` |
| **macOS** 15 or later | `PhoneUse-<version>-mac.dmg`, signed and notarized; uses the bridge for input |
| **Windows** | from source for now: [docs/WINDOWS.md](docs/WINDOWS.md) |
| **iPhone app** | not in the App Store yet; build it from [`ios/`](ios/README.md) with Xcode |
| **Bridge firmware** | `phoneuse-bridge-<version>.bin` |

**Linux:**

```sh
flatpak install --user ./PhoneUse-<version>-x86_64.flatpak
flatpak run co.lxe.PhoneUse
```

**macOS:** open the DMG, drag Phone Use to Applications and open it. It lives in the
menu bar.

The app walks you through the rest: connect the keyboard and mouse (this computer's
Bluetooth or the bridge), pair the iPhone app, and start Screen Mirroring to
"Phone Use on <your computer>". Your iPhone and computer need to be on the same Wi-Fi.

## Agents

In the Phone Use app, click **Connect Claude Code**. It adds the MCP server and the
Phone Use skill, and puts a `phoneuse` command on your path. Other MCP clients can run
the server themselves (`flatpak run --command=phoneuse-mcp co.lxe.PhoneUse` on Linux).

Every action is also a command: `phoneuse open Settings`, `phoneuse text`,
`phoneuse tap-on "Wi-Fi"`, `phoneuse done`. Run `phoneuse --help` for the rest.

## The bridge

The bridge is a small board that the iPhone pairs with as its keyboard and mouse. It
joins your Wi-Fi, so it can sit anywhere in the room with the phone while your
computer's Bluetooth stays free. The Mac app needs one.

Use a [LilyGO T-Display](https://lilygo.cc/products/t-display): the original ESP32
version, not the T-Display S3. Nothing needs soldering. To flash it, plug it in over
USB and open Bridge › Flash LilyGO T-Display in the Linux app, or use
[esptool](https://github.com/espressif/esptool) with the release's firmware:

```sh
pip install esptool
esptool --chip esp32 write-flash 0x0 phoneuse-bridge-<version>.bin
```

Then click Set Up Bridge in Phone Use, check that the bridge's screen shows the same
code, and pick a 2.4 GHz Wi-Fi network. On the iPhone, open Settings › Bluetooth and
tap **Phone Use Bridge**.

## More

- [docs/SOURCE.md](docs/SOURCE.md): running Phone Use from a checkout on Linux, using the mirror, and configuration.
- [docs/WINDOWS.md](docs/WINDOWS.md): Phone Use on Windows.
- [ARCHITECTURE.md](ARCHITECTURE.md): how the parts fit together, and which iOS behaviours Phone Use depends on.
- [docs/BRIDGE.md](docs/BRIDGE.md), [docs/COMPANION.md](docs/COMPANION.md), [docs/RECIPES.md](docs/RECIPES.md): the bridge, the iPhone app and its API, and which gestures work.
- [mac/README.md](mac/README.md), [ios/README.md](ios/README.md): building the Mac and iPhone apps.
- [site/](site/README.md): the phoneuse.tech website.
- [docs/PRIVACY.md](docs/PRIVACY.md): the privacy policy.

## License

MIT
