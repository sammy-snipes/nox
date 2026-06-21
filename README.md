# nox

![Nyx, goddess of night — 10th century, Paris Psalter](nox.jpg)

block apps and websites on your phone. stare at a timer to unblock them. on-device — no account, no server, no subscription.

one iOS app on Apple's Screen Time API (FamilyControls + ManagedSettings). pick apps, type domains, hit turn on, and they're shielded. turning off makes you sit through a delay you set — long enough for the urge to pass.

it's friction, not a cage: you hold your own keys, so nox just makes "stay blocked" the easy path.

## build

xcode 16+, an iOS 16+ device, and xcodegen (`brew install xcodegen`).

```sh
make gen      # regenerate the xcode project from project.yml
make device   # build + install on a connected phone
make site     # preview the landing page locally
```

family controls provisions on your own device with a personal team; app store distribution needs apple's separate distribution entitlement.

[nox.church](https://nox.church) · see LICENSE
