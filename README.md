# Sunrise Lamp

A macOS menu bar app that turns a smart bulb into a sunrise alarm. Before your wake-up time the lamp starts at a deep red glow and slowly moves through orange and warm white to daylight.

## How it works

- You pick a wake-up time, a sunrise length (15 to 60 minutes) and the days.
- The app schedules a repeating Mac wake with `pmset` at the sunrise start, so it works while the Mac sleeps (not while it is shut down).
- At that time it sends the whole sunrise to the bulb in one command; the bulb plays it on its own.
- Everything lives in the app: no scripts, no launch agents. It registers itself as a login item.

## Supported lamps

| Brand | Status |
|-------|--------|
| Yeelight (Wi-Fi colour bulbs, LAN Control on) | Supported |

Other brands can be added by implementing `LampClientProtocol` in `Sources/SunriseCore/Lamp`.

## Requirements

- macOS 14 or later
- Xcode 16 or later (Swift 6)
- A Yeelight bulb on the same Wi-Fi with **LAN Control** enabled in the Yeelight app

## Build

```bash
swift test
./build.sh
```

`build.sh` builds `Sunrise Lamp.app`, signs it with your "Apple Development" certificate and installs it to `/Applications`. Signing with a stable certificate keeps macOS's Local Network permission across rebuilds.

## Permissions

- **Local Network**: to find and control the bulb.
- **Administrator password**: only when you save, to set the Mac wake time with `pmset repeat`. The app never stores it; macOS asks for it in its own dialog.

## License

MIT
