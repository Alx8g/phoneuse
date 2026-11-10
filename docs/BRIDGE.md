# The Bluetooth bridge

The bridge is an ESP32 board (a LilyGO TTGO T-Display) that the iPhone pairs with
as its Bluetooth keyboard and mouse, in place of this PC. Phone Use reaches it over
Wi-Fi, so the board can sit next to the phone on a battery or any USB charger, and
the PC's own Bluetooth radio is out of the path.

```
phoneuse (PC) ── HID daemon ──UDP over Wi-Fi──▶ bridge (ESP32) ──Bluetooth──▶ iPhone
```

## Setting one up

Everything happens from the browser mirror's settings (Settings › Bluetooth bridge)
or `phoneuse bridge setup` in a terminal. No USB cable is needed.

| Step | What happens |
|---|---|
| Find | A new bridge advertises over BLE; the PC finds it with its own Bluetooth. A set-up bridge waits for setup again after you hold its lower button for 3 s. |
| Code | The PC and the bridge exchange X25519 keys. Both show the same 6-digit code; a different code means something else answered. |
| Network | The bridge scans and lists the Wi-Fi networks it sees (2.4 GHz only). |
| Password | Sent to the bridge encrypted (AES-GCM, key from the exchange). The bridge saves the network only once it has joined. |
| Pair | On the iPhone: Settings › Bluetooth › Phone Use Bridge. |

The PC saves the bridge's id and control key in `~/.config/phoneuse/bridge.json`
before the bridge joins, and finds it again by id if its address changes.

## Using a bridge from another computer

A bridge with firmware 0.3 or later can be used by up to four computers, each with
its own control key, so a second computer doesn't need to set the bridge up again or
flash it. Any computer on the bridge's network sees it: Settings › Bluetooth bridge
lists it with its iPhone and network, and `phoneuse bridge find` prints it.

To use it, click Use… (or run `phoneuse bridge use`). The computer and the bridge
exchange X25519 keys over the network, as in setup, and the bridge's screen shows the
computer's name and a 6-digit code. If the computer shows the same code, press either
of the bridge's buttons. The bridge then trusts that computer's key. If nobody presses
a button within 90 seconds, the request lapses. The bridge takes one request at a time,
so a second computer has to wait until the first request is answered or lapses.

When a fifth computer is allowed, the bridge drops the computer it allowed first.
Forget Bridge on one computer removes only that computer. The bridge resets (no Wi-Fi,
no iPhone pairing) only when the last computer forgets it.

Updating a 0.2 bridge to 0.3 over USB with `phoneuse bridge flash` keeps its network,
its key and its iPhone pairing: the flash leaves the settings partition alone, and the
old key becomes the first computer's.

## The control link

UDP port 47700. Every packet is signed (HMAC-SHA256 with the sending computer's
control key, truncated to 8 bytes), so nobody else on the network can type on the
phone. Only FIND and ADOPT go unsigned, and their answers carry no secrets.
The bridge answers each report at once: sent, skipped (its Bluetooth queue is busy,
so the sender keeps the motion), or no phone. `bridge/main/link.c` has the packet
format.

While a bridge is in use, the HID daemon sends every report there and drops its own
Bluetooth link to the phone, so the phone never sees two keyboards. The switch
"Send input through bridge" in the settings turns this off.

## Firmware

The firmware lives in `bridge/` (ESP-IDF v6.1). With the board on USB:

```bash
phoneuse bridge flash    # build and flash
phoneuse bridge log 10   # restart it and print 10 s of its log
phoneuse bridge status   # address, phone, round trip
```

The bridge presents the same HID descriptor as the PC daemon (`hid_daemon.py`
REPORT_MAP), byte for byte: keyboard, mouse, absolute pointer, and the consumer
keys (Eject, Siri, Home, Search).

The bridge's screen shows its network, the connected phone, the report rate and
the Wi-Fi signal and power. An icon at the right of the phone's name shows what
the PC is sending, for 0.6 s after it arrives: a cursor for pointer moves, a
finger for taps and presses, a keyboard for keys. The screen sends a row to the
panel only when its text changes, and on battery the backlight dims to 15% after
two minutes without input (the button, input or a new state brings it back).
`tools/mkicons.py` renders the icons from Symbols Nerd Font into `main/icons.h`.

## Measured (2026-11-07)

| | PC Bluetooth | Bridge |
|---|---|---|
| Reports per second | 114 to 215 | 38 |
| Round trip per report | under 1 ms (local socket) | 15 ms median, 29 ms p90 |

The bridge is slower today because each report waits for its answer over Wi-Fi,
and the ESP32 shares one radio between Wi-Fi and Bluetooth (its Wi-Fi signal was
−80 dBm during the test).
