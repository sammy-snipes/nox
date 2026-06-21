# Nox

![Nyx, goddess of night — 10th century, Paris Psalter](nox.jpg)

Cold Turkey for iPhone. Block apps and websites with OS-level enforcement — on-device, no account, no subscription, no server.

## How It Works

nox is a single iOS app built on Apple's **Screen Time API** (Family Controls).

1. Grant nox Screen Time access (one tap, system prompt).
2. **Choose apps** through Apple's private picker (opaque tokens — nox never learns what you picked) and **type domains** to block (e.g. `reddit.com`).
3. Hit **turn on**. nox shields those apps and filters those domains system-wide.
4. To **turn off**, you start a countdown and wait out a delay you set (default 5 min). Leave the screen and the wait resets to full. Sit through it and confirm, and nox turns off.

No backend, no login, no network. Everything lives in `UserDefaults` and a `ManagedSettingsStore` on the device.

### The turn-off delay

There's no paragraph to type and no password. Turning nox off is just *time*:

- The countdown is anchored to a stored timestamp, so **closing the app doesn't dodge the wait** — reopen and it's still ticking.
- **Backing out resets it** to the full delay. You have to actually sit there.
- You **can't shorten the delay while nox is on** — change it only when off.

### Enforcement, honestly

This is **friction-grade**, not a cage. You hold the keys to your own phone, so a determined you can revoke Screen Time access in Settings or delete the app. nox's job is to make "stay blocked" the easy path and "turn off" annoying enough that the impulse passes.

> For genuinely non-bypassable enforcement you'd need to **supervise** the device (Apple Configurator) and run MDM — a different tool with a USB + wipe cost that can't ship on the App Store. nox trades that away for "no setup, works on any iPhone."

## Design

Black and white. Monospace. Terminal aesthetic. Dead minimal — the UI should look like what it's doing: removing features from your phone.

- Colors: `#000000` background, `#FFFFFF` text. No grays, no accents, no gradients.
- Font: System monospace (`SF Mono` / `Menlo`). Everything.
- No icons, no illustrations, no rounded corners, no shadows.
- Buttons are plain text with borders. Inputs are underlined text fields.
- Animations: none. Transitions: none. The app feels like a terminal.

```
┌──────────────────────────┐
│  nox                  >  │
│                          │
│  blocked apps            │
│  ─────────────────────   │
│  apps                 4  │
│  categories           1  │
│  + choose apps           │
│                          │
│  blocked domains         │
│  ─────────────────────   │
│  reddit.com          [x] │
│  tiktok.com          [x] │
│  + add domain            │
│                          │
│  ──────────────────────  │
│  [       turn off      ] │
└──────────────────────────┘
```

## Architecture

One on-device app. No server, no database, no enrollment.

| Piece | Framework | Role |
|-------|-----------|------|
| `BlockController` | FamilyControls + ManagedSettings | Authorization, apps + domains, on/off, the turn-off delay |
| `AuthView` | SwiftUI | One-tap Screen Time authorization |
| `BlocklistView` | FamilyControls | Pick apps, type domains, turn on/off |
| `AddDomainView` | SwiftUI | Type a domain to block |
| `UnblockView` | SwiftUI | The turn-off delay countdown |
| `SettingsView` | SwiftUI | Status + delay presets |
| `Theme` | SwiftUI | The black/white monospace terminal look |

```
ios/Nox/
├── NoxApp.swift            # entry point, owns BlockController
├── ContentView.swift       # routes: not-authorized → AuthView, else → BlocklistView
├── BlockController.swift    # FamilyControls auth + ManagedSettings (the core)
├── Theme.swift             # terminal aesthetic
├── Nox.entitlements        # com.apple.developer.family-controls
└── Views/
    ├── AuthView.swift
    ├── BlocklistView.swift
    ├── AddDomainView.swift
    ├── UnblockView.swift
    └── SettingsView.swift
```

## Build

Requires Xcode 16+, an iOS 16+ device, and `xcodegen` (`brew install xcodegen`).

```sh
make gen     # regenerate Nox.xcodeproj from project.yml
make open    # open in Xcode
```

The **Family Controls** capability needs the `com.apple.developer.family-controls` entitlement (in `Nox.entitlements`). For development on your own device a personal team works; App Store distribution requires requesting the Family Controls distribution entitlement from Apple.

## Roadmap

Done:
- [x] Screen Time authorization
- [x] App/category selection via FamilyActivityPicker
- [x] Domain blocking (typed list → web content filter)
- [x] Turn on / turn off
- [x] Turn-off delay (set a wait, sit through it)

Maybe later:
- [ ] Custom shield screen (ShieldConfiguration extension)
- [ ] Nuclear mode (no turn-off until a chosen date)
- [ ] Accountability partner (someone else holds the turn-off)
```
