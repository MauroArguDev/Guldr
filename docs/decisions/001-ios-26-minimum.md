# 001 — iOS 26 as the minimum deployment target

- **Status:** Accepted
- **Date:** 2026-10-01

## Context

Guldr is a new app built with Xcode 27, while iOS 27 is the current release. The minimum iOS version decides which devices can run the app, which APIs can be used without `#available` checks, and how many code paths need to be maintained and tested.

The design is built around the iOS 26 visual language (Liquid Glass, native tab bar, sheets and controls). The app also relies on APIs that matured recently: `@Observable`, SwiftData, Swift Charts, WidgetKit interactivity, and the on-device Foundation Models framework, introduced in iOS 26 and a candidate for future features.

## Decision

Set the minimum deployment target to **iOS 26.0** for every target, iPhone only.

## Alternatives considered

- **iOS 17 or 18** — reaches more devices, but every Liquid Glass API and Foundation Models call would need an `#available` branch with a fallback design, doubling UI work and test surface for a shrinking share of users. The previous project (FinTrack Pro) targeted iOS 17.6 and its design already looked dated next to the system.
- **iOS 27** — newest APIs, but it shipped only recently and would exclude a large part of active devices for no feature Guldr needs today.

## Consequences

- One design path: native components look and behave as the system does, with no compatibility fallbacks.
- No OS-version checks for current APIs. Foundation Models still needs a runtime availability check (`SystemLanguageModel.default.availability`) because it depends on Apple Intelligence hardware, not on the OS version.
- Supported devices: iPhone 11 and later, and iPhone SE (2nd generation) and later. Layouts must be verified on the SE's small screen.
- Revisit when iOS 28 ships: moving to an N-1 minimum (iOS 27) would follow the same reasoning.
