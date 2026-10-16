# Changelog

Notable changes to the Wake SDK. Versions follow [Semantic Versioning](https://semver.org), except that until `1.0` a minor bump may contain breaking changes.

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
