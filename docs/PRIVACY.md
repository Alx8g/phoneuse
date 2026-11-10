# Phone Use privacy policy

Phone Use lets your own computer see and use your iPhone, so that you, and AI agents you choose, can operate it. This
page covers the Phone Use iPhone app and the Phone Use apps for Mac and Linux. Last updated November 10, 2026.

## The short version

Phone Use has no accounts, analytics, advertising or tracking. The iPhone app talks to the computer you paired it
with, on your own network. The only thing that leaves your devices for a server run by Phone Use's developer is a
set of push notification tokens: they let your computer send you notifications through the Phone Use push relay
(below). The relay can't read what the notifications say beyond fixed wording, and it never learns your name, your
computer's name or what an agent is doing.

## What the iPhone app sends, and where

The iPhone app sends everything below to **your own computer**, the one you paired by scanning its code, over your
local network:

- **Your settings and answers.** Settings such as Keep Awake, whether agents need your OK, and your Allow or Deny
  answers.
- **Notification and Live Activity tokens.** These let your computer send you notifications and keep the Live
  Activity up to date through Apple's push notification service. Apple handles these pushes under its own privacy
  policy.
- **A bridge Wi-Fi password, if you type one.** When you move the bridge to another network, the password goes to
  your computer encrypted with the key from your pairing, and your computer passes it to the bridge.

## The push relay

Notifications and the Live Activity reach your iPhone through Apple's push notification service. A computer needs
an Apple key to use that service, so most computers send them through the Phone Use push relay, a small service the
developer runs on Cloudflare Workers.

- **What the iPhone app registers with the relay:** an identifier derived from your pairing key, your device's push
  token, its Live Activity push tokens, the current Live Activity's id, whether it is a production or development
  build, and the app's bundle id. No names and no account.
- **What the relay keeps:** one record per registration with those tokens, the time it was last updated, and a key
  derived from your pairing. It expires after 30 days without a refresh, and Unpair in the app deletes it.
- **What goes through it:** your computer sends the kind of notification (an agent asking to use your iPhone, an
  update to the Live Activity, and the like) with its details sealed with a key derived from your pairing, which the
  relay can't read. The relay fills fixed wording, such as "An agent asks to use your iPhone", and passes it to Apple.
  Your iPhone opens the sealed details itself.
- **Logs:** one line per notification with the first characters of the registration identifier, the kind, and
  Apple's answer. Cloudflare's standard request logs and rate limiting see IP addresses.

The push tokens are used only to deliver these notifications. They aren't linked to your identity, shared with
anyone except Apple for delivery, or used for tracking or advertising. A computer set up with its own Apple key sends
notifications straight to Apple instead, and then the relay isn't used for that iPhone.

Nothing else is sent to the developer or to any other server.

## Permissions the iPhone app asks for

- **Camera:** only to scan the pairing code your computer shows. The app keeps no pictures.
- **Local network:** to find and talk to your computer.
- **Notifications:** so you can allow or stop agents while your screen is mirroring.

## The computer apps

Phone Use on your computer receives your iPhone's screen through Screen Mirroring and sends taps and keystrokes to it
through Bluetooth, either directly or through the Phone Use Bridge. Your screen's picture stays on your computer.
Text recognition (reading the screen for agents) runs on your computer.

If you connect an AI agent, such as Claude Code, it can see your iPhone's screen and use it, within the controls you
set (for example, Ask every time). What the agent does with that information is governed by its provider's terms
and privacy policy, not by Phone Use.

## Children

Phone Use isn't directed at children, and it collects no information from anyone.

## Changes and contact

If this policy changes, the new version will be posted on this page. Questions: open an issue at
https://github.com/lxe/phoneuse/issues.
