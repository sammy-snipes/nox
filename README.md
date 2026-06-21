# Nox

![Nyx, goddess of night — 10th century, Paris Psalter](nox.jpg)

Cold Turkey for iPhone. Block apps and websites with OS-level enforcement — on-device, no account, no subscription, no server.

## How It Works

nox is a single iOS app built on Apple's **Screen Time API** (Family Controls).

1. You grant nox Screen Time access (one tap, system prompt).
2. You pick the apps, categories, and websites to block — through Apple's private picker, so nox never learns what you chose (the selection is opaque tokens, stored only on your device).
3. You hit `activate`. nox applies a **ManagedSettings shield**: the OS blanks those apps and sites system-wide.
4. To unblock, you go through friction — type-to-unblock for the MVP. Cave, and the shield lifts. Don't, and it holds.

No backend. No login. No network calls. Everything lives in `UserDefaults` and a `ManagedSettingsStore` on the device.

### Enforcement, honestly

This is **friction-grade** enforcement, not a cage. Because you hold the keys to your own phone, a determined you can revoke Screen Time access in Settings or delete the app. nox's job is to make the easy path "stay blocked" and the unblock path annoying enough that the impulse passes. The type-to-unblock ordeal is the actual product; the shield is the commodity.

> For genuinely non-bypassable enforcement you'd need to **supervise** the device (Apple Configurator) and run MDM — that's a different tool with a USB + wipe cost, and it can't ship on the App Store. nox deliberately trades that away for "no setup, no server, works on any iPhone."

## Design

Black and white. Monospace. Typewriter aesthetic. Dead minimal — the UI should look like what it's doing: removing features from your phone.

- Colors: `#000000` background, `#FFFFFF` text. No grays, no accents, no gradients.
- Font: System monospace (`SF Mono` / `Menlo`). Everything.
- No icons, no illustrations, no rounded corners, no shadows.
- Buttons are plain text with borders. Inputs are underlined text fields.
- Animations: none. Transitions: none. The app feels like a terminal.
- The type-to-unblock screen is punishing — small monospace text, no paste, character counter, typos reset to zero.

```
┌──────────────────────────┐
│                          │
│  nox                     │
│                          │
│  blocked                 │
│  ─────────────────────   │
│  apps                 4  │
│  categories           1  │
│  websites             3  │
│                          │
│  + choose what to block  │
│                          │
│                          │
│  [      activate     ]   │
│                          │
└──────────────────────────┘
```

## Architecture

One on-device app. No server, no database, no enrollment.

| Piece | Framework | Role |
|-------|-----------|------|
| `BlockController` | FamilyControls + ManagedSettings | Authorization, selection persistence, applying/lifting the shield |
| `AuthView` | SwiftUI | One-tap Screen Time authorization |
| `BlocklistView` | FamilyControls | `FamilyActivityPicker` to choose apps/sites, activate/unblock |
| `UnblockView` | SwiftUI / UIKit | Type-to-unblock friction (no-paste field, typo-resets) |
| `SettingsView` | SwiftUI | Status, counts |
| `Theme` | SwiftUI | The black/white monospace terminal look |

```
ios/Nox/
├── NoxApp.swift            # entry point, owns BlockController
├── ContentView.swift       # routes: not-authorized → AuthView, else → BlocklistView
├── BlockController.swift    # FamilyControls auth + ManagedSettings shield (the core)
├── Theme.swift             # terminal aesthetic
├── Nox.entitlements        # com.apple.developer.family-controls
└── Views/
    ├── AuthView.swift
    ├── BlocklistView.swift
    ├── UnblockView.swift
    └── SettingsView.swift
```

## Build

Requires Xcode 16+, an iOS 16+ device, and `xcodegen` (`brew install xcodegen`).

```sh
make gen     # regenerate Nox.xcodeproj from project.yml
make open    # open in Xcode
```

The **Family Controls** capability needs the `com.apple.developer.family-controls` entitlement (already in `Nox.entitlements`). For development on your own device a personal team works; App Store distribution requires requesting the Family Controls distribution entitlement from Apple.

## Roadmap

Phase 1 (MVP):
- [x] Screen Time authorization
- [x] App/category/website selection via FamilyActivityPicker
- [x] ManagedSettings shield (activate / unblock)
- [x] Type-to-unblock friction

Phase 2 (later):
- [ ] Schedules (DeviceActivity — block on a recurring window)
- [ ] Timed blocks (block until time X)
- [ ] Custom shield screen (DeviceActivity / ShieldConfiguration extension)
- [ ] Nuclear mode (no unblock until a chosen date)
- [ ] Accountability partner (someone else holds the unblock)
```
