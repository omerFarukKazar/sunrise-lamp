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

## Supported lamps

| Brand | Status |
|-------|--------|
| Yeelight (Wi-Fi colour bulbs, LAN Control on) | Supported |

Other brands can be added by implementing `LampClientProtocol` in `Sources/SunriseCore/Lamp`.

## Requirements

- iOS 17 or later
- Xcode 16 or later (Swift 6)
- A Yeelight bulb on the same Wi-Fi with **LAN Control** enabled in the Yeelight app

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
