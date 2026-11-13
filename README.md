# Sunrise Lamp

An iPhone app that turns a smart bulb into a sunrise alarm. Before your wake-up time the lamp starts at a deep red glow and slowly moves through orange and warm white to 6500 K daylight. A sunset action does the reverse before sleep and turns the light off.

## How it works

- You pick a wake-up time and a sunrise length (15 to 60 minutes); the app shows when the sunrise has to start.
- A Shortcuts automation runs at that time and calls the app's **Gün doğumunu başlat** action.
- The app sends the whole sunrise to the bulb in one command. The bulb plays it on its own, so the phone does not need to stay awake.
- Shortcuts and Siri actions: **Gün doğumunu başlat**, **Gün batımını başlat**, **Işığı aç**, **Işığı kapat**.

## Set up the morning alarm

1. Open the app once on the same Wi-Fi as the bulb and allow Local Network access.
2. Pick the wake time and sunrise length; note the automation time the app shows.
3. In Shortcuts: Automation › New Automation › Time of Day, set that time and the days, choose **Run Immediately**.
4. Add the **Gün doğumunu başlat** action. Optionally add **Play Music** after it.

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
