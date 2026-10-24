# Wake

Goal-oriented analytics for iOS and macOS. You design your app's events in Wake, and the SDK records them as your users reach them.

Alpha. iOS 16+, macOS 13+, Swift 5.9+.

## Install

Add the package in Xcode:
**File → Add Package Dependencies → Search**: https://github.com/Wake-Analytics/WakeSDK.Swift.git

Or add to `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/Wake-Analytics/WakeSDK.Swift.git", .upToNextMinor(from: "0.9.0")),
]
```

Until `1.0`, a minor version may contain breaking changes, so the range stops at the next minor.

## 1. Start

```swift
import Wake

@main
struct MyApp: App {
    init() {
        Wake.start(apiKey: "wake_…")
    }
}
```

The package alone is enough: from here on, sessions and launches are reported. Before you call it, the SDK writes nothing to disk and every log call is a no-op. If you gate analytics behind a consent prompt, call `start` once the user agrees.

## 2. Design your events in Wake

Events live in Wake, not in your code. You give each one a name, a plain-language description of when it happens, and any properties it carries.

## 3. Add the generated file

Wake generates `WakeEvents.swift` for your app, with each event's description as its doc comment, and a prompt to hand your coding agent alongside it. Drop the file into your app and don't edit it: change the events in Wake and regenerate.

Events are grouped by the feature they belong to in Wake:

```swift
public extension Wake.Event {

    static var export: ExportEvents { ExportEvents() }

    struct ExportEvents {

        /// The export finishes writing and the share sheet is presented.
        ///
        /// - Parameters:
        ///   - pageCount: Pages in the exported PDF
        public func finished(pageCount: Int?) -> Wake.Event { … }
    }

    static var library: LibraryEvents { LibraryEvents() }

    struct LibraryEvents {

        /// The library is opened from the tab bar.
        public var opened: Wake.Event { … }
    }
}
```

## 4. Log

```swift
Wake.log(.search.used(query: text, results: hits.count))
Wake.log(.paywall.opened(source: "settings"))
Wake.log(.library.opened)
```

Type `Wake.log(.` and autocomplete lists your features, then each feature's events. Events are buffered on disk and uploaded in batches — they survive being killed offline, and nothing is sent twice.

## What you get without writing anything

- **`$first_launch`** — once per install. On a real App Store install it carries the account's original download date, so a user who had your app before you added the SDK reads as returning rather than new.
- **`$session_start` / `$session_end`** — a session ends after 10 minutes of inactivity. Its duration counts foreground time only, so an app left open in the background doesn't inflate it.
- **Context on every event** — platform, device model, OS and app version, locale, region. No IDFA, no device identifier; the only id is a random per-install UUID the SDK mints itself.

## Purchases

A purchase isn't an event of its own. It is a **property** you add to an event you
compose yourself — "subscribed", "bought credits", "took the annual plan" — so the
purchase and the app state around it arrive together, under a name you chose.

Add a **Purchase Product** property to the event in Wake, and the generated event
takes the whole product at the call site:

```swift
Wake.log(.paywall.subscribed(product: product, transaction: transaction, paywallSource: "onboarding"))
```

The SDK reads the product's own fields off it: `product_id`, `product_name`, `price`,
`currency`, the normalized subscription `period` and `product_type`. The price is the
one in the **buyer's own storefront currency** at that moment, which can't be looked
up afterwards; there is no product catalog to sync and nothing to reconcile later.

**The transaction says it was a purchase.** A product can be shown or chosen without
anyone paying for it, so the same property fits "viewed paywall" as well as
"subscribed". Pass the transaction when the event marks a completed purchase, and
`nil` when it doesn't:

- With a transaction, the event sends `transaction_id`, and Wake counts it as a
  purchase: buyers, revenue and products on the app's Home. Without one, the event
  still records which product it was about, but is never counted as a sale.
- The event's id is derived from the transaction, so logging the same purchase twice
  (once from the buy flow, once from a `Transaction.updates` replay at next launch)
  collapses to one instance.
- `is_trial` says whether an introductory offer applied, which only the transaction
  knows.
- The transaction's environment decides whether the purchase was a sandbox one,
  rather than the flavour your build was compiled as.

### What you may not restate

Anything in `Wake.productParamIDs` — `product_id`, `product_name`, `price`, `currency`,
`period`, `product_type`, `is_trial`, `transaction_id` — comes from the product and its
transaction. A property of your own
under one of those names is refused in Wake, and dropped and logged at `.error` if
it reaches the SDK anyway.

**Renewals are yours to decide.** The SDK never filters them. A renewal is a distinct
transaction, so dedup can't collapse it and it will land as another occurrence of the
event. Unless you want them in your data, gate your `Transaction.updates` listener
on `originalID == id`, and still `finish()` every transaction.

## Screen time since

Some events are only interesting with a duration attached: how long did someone
actually spend in the app between starting onboarding and saving their first
document? Add a **screen time since** property to the event in Wake and pick what it
counts from.

**Foreground time only.** Time with the app in the background doesn't count, which is
the whole reason the SDK has to measure it — nothing in the event stream says when
someone stopped looking.

It counts from an event — **From** — to the event that carries it — **To**: "Opened paywall → Subscribed" is the foreground time between the two.

- **From is any event you designed**, or one of the two the SDK logs itself: **App install** (`$first_launch`, every second the app has ever been in front) and **Session start** (`$session_start`, the current session's foreground time).
- **It counts from the latest From.** Logging the From event again moves the starting line, so the time is always since the most recent one on that install.
- **Logging To doesn't use From up.** A second To measures from the same From and reads longer.
- **No From yet means the property is absent** on that event — not zero.
- **The property fills itself**, measured when To is logged, so adding one doesn't change the event's arguments and your existing calls keep compiling.

## Deleting a user's data

```swift
Wake.deleteData()
```

Stops collection, erases the local subject, and asks the server to erase what it holds. Calling `start` again afterwards begins a brand-new subject.

## Privacy

The SDK ships a privacy manifest that Xcode folds into your app's Privacy Report automatically — you don't copy anything. What you do fill in by hand is the App Store Connect nutrition label; [`PRIVACY.md`](PRIVACY.md) has the paste-ready answers and the reasoning behind each.

## Testing your integration

The SDK reports integration problems out of the box — a rejected API key, a batch the server refused — under the `app.realwake` subsystem in Xcode's console and Console.app. It stays quiet when the integration is correct, so there's nothing to turn off in production.

Wrong event names and wrong param types can't reach runtime: the generated file is the only way to log, so both are compile errors.

If events aren't arriving and nothing has been reported, turn the level up before `start` to see activation and every upload:

```swift
Wake.logLevel = .debug   // .error is the default; .off silences everything
Wake.start(apiKey: "wake_…")
```

Debug and TestFlight builds are flagged **sandbox**, so your own test runs can be told apart from real users in Wake.

In `DEBUG` builds you also get identity tools, so one build can produce many distinct subjects without reinstalling:

```swift
Wake.debugCurrentInstallID       // the id to search for in Wake
Wake.debugResetIdentity()        // next start() = a brand-new subject
Wake.debugSetInstallID(id)       // keep feeding an existing subject
```

Call `Wake.start(…)` again after either mutation.

## Alpha limits

- No automatic `Transaction.updates` capture — log purchases at the call site.
- Uploads don't yet continue in the background after the app is suspended; they resume on next launch.
