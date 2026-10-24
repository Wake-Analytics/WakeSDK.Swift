# Changelog

Notable changes to the Wake SDK. Versions follow [Semantic Versioning](https://semver.org), except that until `1.0` a minor bump may contain breaking changes.

## 0.9.0 — 2026-10-24

- **Screen time counts from events.** A screen-time property's From is now an event — any you designed, or App install (`$first_launch`) and Session start (`$session_start`) — and counts from the latest time it was logged. `Wake.mark(_:)` and `Wake.StartingPoint` are gone: the events you already log are the starting lines. Regenerate `WakeEvents.swift` in Wake and remove your `Wake.mark` calls.
- **A feature's properties can travel with its later events.** A value passed on one event — a paywall's source, say — is attached to the feature's events that follow, so a purchase knows where its paywall was opened from without passing it again. The latest passing event wins, and values survive a relaunch. Comes with the regenerated file; call sites don't change.
- **Generated events are grouped by feature.** `Wake.log(.paywall.opened(source:))` instead of one flat list; type `Wake.log(.` to see your features. Comes with the regenerated file.
- **Event times are sent to the millisecond.** They used to be rounded to the second, which blurred the time between events logged close together. No code changes.

## 0.8.1 — 2026-10-16

- **The README's examples show the new key format.** New API keys start with `wake_`. Keys issued earlier keep working. No code changes.

## 0.8.0 — 2026-10-16

The first release as Wake.

- **Add the package from its new home:** `https://github.com/Wake-Analytics/WakeSDK.Swift.git`. The product and module are `Wake`, so `import Wake`.
- **Events are logged with `Wake.log(_:)`.** Each event is a value the generated file declares on `Wake.Event`: `Wake.log(.openedPaywall(source: "settings"))`, or `Wake.log(.openedLibrary)` for an event without properties. Starting points are marked the same way: `Wake.mark(.onboardingStarted)`. Regenerate `WakeEvents.swift` in Wake to get the new declarations.
- **Everything else moves from `SM` to `Wake`:** `Wake.start(apiKey:)`, `Wake.deleteData()`, `Wake.logLevel`, `Wake.productParamIDs` and the `Wake.debug…` identity tools.
- **Screen time is measured when the event is logged.**
- **Events upload to `ingest.realwake.app`.** The override is now `WAKE_INGEST_URL`, and the identity tools' compilation condition is `WAKE_IDENTITY_TOOLS`.
- **The SDK's stored state moves to `app.realwake.` keys**, and its unified-log subsystem to `app.realwake`. An app that updates starts with a new install id, and events not yet uploaded by the earlier version are discarded.
