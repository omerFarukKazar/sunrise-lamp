# Sunrise Lamp

An iPhone app that turns a smart bulb into a sunrise alarm. Before your wake-up time the lamp starts at a deep red glow and slowly moves through orange to the white you chose (3000 to 6500 K). A sunset action does the reverse before sleep and turns the light off.

## How it works

- In the app you pick the sunrise length (15 to 60 minutes) and the light it ends on. While you edit, the bulb previews the end light.
- The wake time and days live in a Shortcuts automation, set to start that many minutes before you want to be up. It calls the app's **Gün doğumunu başlat** action.
- The app sends the whole sunrise to the bulb in one command. The bulb plays it on its own, so the phone does not need to stay awake.
- If you change the length later, the app reminds you to move the automation so your wake time stays the same.
- A Light tab works the bulb as a plain smart light: brightness, tone, colour, scenes.
- Shortcuts and Siri actions: **Gün doğumunu başlat**, **Gün batımını başlat**, **Işığı aç**, **Işığı kapat**.

## Set up the morning alarm

1. Open the app once on the same Wi-Fi as the bulb and allow Local Network access.
2. Pick the sunrise length and end light.
3. In Shortcuts: Automation › New Automation › Time of Day, set your wake time minus the sunrise length and the days, choose **Run Immediately**.
4. Add the **Gün doğumunu başlat** action. Optionally add **Play Music** after it. Back in the app, tap **Kurdum**.

## Supported lamp

The app is built for one lamp: a **Yeelight** Wi-Fi colour bulb with **LAN Control** turned on in the Yeelight app. Other brands are not supported, and there are no plans to add them. If you have a different lamp, see [Using a different lamp](#using-a-different-lamp).

## How it is built

- **SwiftUI app, no dependencies.** Only Apple frameworks: SwiftUI, Observation, App Intents and Network.
- **Local network only.** The phone finds the bulb with Yeelight's discovery search (UDP multicast on port 1982), then sends JSON commands over TCP port 55443. No cloud, no account, no server.
- **The bulb plays the sunrise itself.** Yeelight bulbs accept a *colour flow*: a list of steps (colour or colour temperature, brightness, duration) that the bulb runs on its own. The app sends the whole sunrise as one `set_scene` `cf` command:
  1. Deep red at 1 %
  2. Orange, then amber
  3. 2200 K, then up to 3200 K
  4. The chosen white (3000 to 6500 K) at 100 %

  Each phase takes a fifth of the sunrise length. After the last step the bulb stays on. The sunset is the same idea in reverse, and the bulb turns off at the end.
- **Shortcuts is the alarm clock.** iOS does not let an app run code at a set time in the background. A Shortcuts *Time of Day* automation does, and it calls the app's App Intent. The intent only has to send one command, so it finishes in a second. The phone can stay locked and asleep for the rest.
- **The app does not read the bulb.** It only sends commands, so it does not see changes made from the Yeelight app or a wall switch.
- **Code layout**
  - `Sources/SunriseCore`: a Swift package with the lamp protocol, the flows and the view model. It has tests and runs `swift test` on the Mac.
  - `iOS/SunriseLampPhone`: the SwiftUI screens and the App Intents.

## Using a different lamp

This repository will stay Yeelight only, but the idea carries over to any lamp that can **run a timed colour transition by itself**. This matters: Shortcuts gives the app only a few seconds, so the phone cannot step the colours for 30 minutes. Before you start, check that your lamp (or its hub) can play a scene or transition with a duration, locally or through its API. Philips Hue, for example, supports transition times on its bridge.

To adapt it, open the repository in an AI coding assistant (Claude Code, Cursor, or similar) and give it this prompt, with your lamp's details filled in:

```text
This repository is an iOS sunrise alarm app for Yeelight bulbs. Read README.md
and the code under Sources/SunriseCore and iOS/SunriseLampPhone first.

I want the same app for my lamp instead: <brand and model>.
It is controlled through: <local API / hub / cloud API, with a link to its docs>.

1. Before changing anything, tell me whether my lamp can play a timed
   transition (colour or colour temperature and brightness over minutes) on its
   own, without the phone sending steps. If it cannot, stop and explain the
   options.
2. Write a new client that conforms to LampClientProtocol in
   Sources/SunriseCore/Lamp. Map each LampCommand case to my lamp's API:
   sunrise and sunset as the lamp's own timed transition, plus temperature,
   colour, power on and power off. Keep the sunrise colours and timings from
   LampCommand.sunriseFlow.
3. Add whatever my lamp needs to connect (hub pairing, an API key, a bridge IP)
   and store it with SettingsStore. Never commit keys.
4. Replace YeelightClient() in SunriseLampPhoneApp.swift and LampIntents.swift
   with the new client, and update the "Yeelight" text in the UI.
5. Add tests for the new command mapping next to the existing ones, and make
   sure swift test passes.
```

## Requirements

- iOS 17 or later
- Xcode 16 or later (Swift 6)
- A Yeelight colour bulb on the same Wi-Fi, with **LAN Control** enabled in the Yeelight app

## Build

1. Open `iOS/SunriseLampPhone.xcodeproj` in Xcode.
2. Under Signing & Capabilities, choose your own team (and change the bundle identifier if Xcode asks).
3. Run it on your iPhone.

The shared logic lives in the `SunriseCore` Swift package at the repository root. Its tests run on the Mac:

```bash
swift test
```

## License

MIT
