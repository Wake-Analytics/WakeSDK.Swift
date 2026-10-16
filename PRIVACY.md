# Wake SDK — privacy

The SDK ships a privacy manifest at [`Sources/Wake/PrivacyInfo.xcprivacy`](Sources/Wake/PrivacyInfo.xcprivacy), bundled into the `Wake` target as a resource. Xcode folds it into your app's aggregated **Privacy Report** automatically at archive time — you don't copy anything.

What you **do** copy by hand is the App Store Connect **nutrition label** (App Privacy → *Data Types*). That form is per-app, so the answers below are only Wake's contribution: the final label is the **union** of your own app's collection and every SDK's. If your app already collects one of these types for another reason, the stricter answer wins (e.g. if *your* code links Purchases to a signed-in account, that type becomes linked for the app even though Wake's own use isn't).

## What Wake collects

Three App Store Connect data types — plus coarse **environment context** that maps to
none of them (see the dedicated section below). For **every** collected type the answers
are the same:

- **Used to track you?** → **No.** Wake is first-party analytics: no IDFA, no ATT prompt, no data shared with brokers or joined to other companies' data. (`NSPrivacyTracking = false`.)
- **Linked to the user's identity?** → **No.** The only identifier is a random per-install UUID (`install_id`) the SDK mints itself and stores in the app's own `UserDefaults`; it's reset by `Wake.deleteData()`. There is no login, name, email, or device-level id.

### Paste-ready answers

| App Store Connect data type | Collect? | Linked to identity? | Used for tracking? | Purpose(s) |
|---|---|---|---|---|
| **Identifiers → User ID** | Yes | No | No | Analytics, App Functionality |
| **Usage Data → Product Interaction** | Yes | No | No | Analytics |
| **Purchases → Purchase History** | Yes | No | No | Analytics |

**Why each:**

- **User ID** — the `install_id` rides every event. It's an SDK-assigned account-level id, so it's *User ID*, not *Device ID* (which App Store Connect reserves for device-level identifiers like the IDFV/IDFA — Wake reads neither). "App Functionality" is listed alongside Analytics because the id also backs idempotency and the erasure beacon.
- **Product Interaction** — automatic events (`$first_launch`, `$session_start`/`$session_end`) plus your declared custom events.
- **Purchase History** — the fields of a Purchase Product property: `product_id`, `product_name`, `price`, `currency`, `period`, `product_type`, `is_trial`, and `transaction_id` when a transaction is passed. Only present if one of your events carries that property; if none does, you may drop this row.

## Environment context (adds no label row)

Every event also carries coarse context about the environment it was recorded in:
**platform** (`ios`/`macos`), **device model** (`iPhone16,2`), **OS version**, **app version**, **locale** (`en-US`), and **region/country** (`US`). None of these maps to an App Store Connect data type, so **none adds a row to your label** — the reasoning, so it's a defended position and not an oversight:

- **Device model** is a *model class* (`iPhone16,2`) shared by millions of units — it identifies a hardware model, not a specific device, so it is **not** *Device ID* (which App Store Connect reserves for device-level identifiers like the IDFV/IDFA — Wake reads neither). It's read from `hw.machine`, which is **not** a required-reason API (the `sysctl` required-reason category covers reading `kern.boottime`, not the hardware model).
- **Platform, OS version, app version** have no corresponding data type — they're build/runtime facts, not personal data.
- **Locale and region/country** come from `Locale.current` — the user's **Settings preference**, not a location measurement. Wake deliberately derives `country` from the locale region rather than from IP geolocation, so it is **not** *Location* data (which describes where the device physically is). It is therefore not declared as Coarse Location.

Data types Wake does **not** collect (so it adds nothing to these on your label): Contact Info, Health & Fitness, Financial Info (beyond the purchase fields above), **Location** (see the region note above — locale/country are device *settings*, not location measurements), Sensitive Info, Contacts, User Content, Browsing/Search History, Diagnostics (crash/performance), and any advertising data.

## Required-reason API

The manifest declares one:

| API category | Reason | Why |
|---|---|---|
| `NSPrivacyAccessedAPICategoryUserDefaults` | **`CA92.1`** | The SDK reads/writes only its own state (install id, event sequence, session, upload bookkeeping) under the `app.realwake.` key prefix — i.e. access to info from the same app running the SDK. |

No boot-time (`systemUptime`/`mach_absolute_time`), file-timestamp, or disk-space required-reason APIs are used, so none are declared.
