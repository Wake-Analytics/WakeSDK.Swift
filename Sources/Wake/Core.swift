import Foundation

extension Wake {

    /// The runtime logging core: identity, consent state, and the record path.
    final class Core: @unchecked Sendable {

        static let shared: Core = {
            let store = UserDefaultsStore()
            let clock = SystemClock()
            let buffer = FileEventBuffer.makeDefault()
            let uploader = Uploader(buffer: buffer, http: URLSessionHTTPClient(), store: store)
            let transport = Transport(buffer: buffer, uploader: uploader)
            let sessions = SessionManager(clock: clock, store: store, uuid: { UUID().uuidString })
            return Core(
                store: store, clock: clock, sink: transport, lifecycle: transport,
                sessions: sessions, screenTime: ScreenTime(clock: clock, store: store),
                appLifecycle: SystemLifecycleObserver(),
                appOrigin: SystemAppOrigin()
            )
        }()

        private let lock = NSLock()
        private let store: KeyValueStore
        private let clock: Clock
        private let sink: EventSink
        private let lifecycle: TransportLifecycle?
        private let sessions: SessionManager?
        private let screenTime: ScreenTime?
        private let appLifecycle: (any AppLifecycleObserver)?
        private let appOrigin: (any AppOriginSource)?
        private let uuid: () -> String

        private enum State {
            case inactive
            case active(Active)
        }

        private struct Active {
            let apiKey: String
            let installID: String
        }

        private var state: State = .inactive

        init(
            store: KeyValueStore = UserDefaultsStore(),
            clock: Clock = SystemClock(),
            sink: EventSink = NoopSink(),
            lifecycle: TransportLifecycle? = nil,
            sessions: SessionManager? = nil,
            screenTime: ScreenTime? = nil,
            appLifecycle: (any AppLifecycleObserver)? = nil,
            appOrigin: (any AppOriginSource)? = nil,
            uuid: @escaping () -> String = { UUID().uuidString }
        ) {
            self.store = store
            self.clock = clock
            self.sink = sink
            self.lifecycle = lifecycle
            self.sessions = sessions
            self.screenTime = screenTime
            self.appLifecycle = appLifecycle
            self.appOrigin = appOrigin
            self.uuid = uuid
        }

        // MARK: Lifecycle

        /// Activates collection. Idempotent: re-starting keeps the install id.
        func start(apiKey: String) {
            let (installID, isNewInstall): (String, Bool) = {
                lock.lock()
                defer { lock.unlock() }
                let (id, isNew) = ensureInstallID()
                state = .active(Active(apiKey: apiKey, installID: id))
                return (id, isNew)
            }()

            Diag.debug("started · install_id \(installID)")
            lifecycle?.start(apiKey: apiKey, installID: installID)

            screenTime?.resumed(now: clock.now())

            if let sessions {
                startAppLifecycle()
                for emit in sessions.activated(now: clock.now()) {
                    record(name: emit.name, params: emit.params, sessionIDOverride: emit.sessionID)
                }
                if isNewInstall {
                    recordFirstLaunch()
                }
            }
        }

        private func recordFirstLaunch() {
            guard let appOrigin else {
                record(name: AutoEvent.firstLaunch, params: [:])
                return
            }
            Task { [weak self] in
                let date = await appOrigin.originalDownloadDate()
                var params: [String: ParamValue] = [:]
                if let date {
                    params[AutoEvent.originalDownloadTS] = .string(ISO8601DateFormatter().string(from: date))
                }
                self?.record(name: AutoEvent.firstLaunch, params: params)
            }
        }

        /// Stops collection, erases the local subject, and queues the server
        /// erasure beacon.
        func deleteData() {
            let erasedID: String? = {
                lock.lock()
                defer { lock.unlock() }
                let id = store.string(forKey: Keys.installID)
                if let id { store.set(id, forKey: Keys.pendingErasureID) }
                store.set(nil, forKey: Keys.installID)
                store.setInteger(nil, forKey: Keys.sequence)
                state = .inactive
                return id
            }()
            sessions?.reset()
            screenTime?.reset()
            if let erasedID { lifecycle?.requestErasure(installID: erasedID) }
        }

#if DEBUG || WAKE_IDENTITY_TOOLS
        // MARK: Identity control (manual testing seam)

        var debugCurrentInstallID: String? {
            lock.lock(); defer { lock.unlock() }
            return store.string(forKey: Keys.installID)
        }

        func debugResetIdentity() {
            lock.lock()
            store.set(nil, forKey: Keys.installID)
            store.setInteger(nil, forKey: Keys.sequence)
            state = .inactive
            lock.unlock()
            sessions?.reset()
        }

        func debugSetInstallID(_ id: String) {
            lock.lock()
            store.set(id, forKey: Keys.installID)
            store.setInteger(nil, forKey: Keys.sequence)
            state = .inactive
            lock.unlock()
            sessions?.reset()
        }
#endif // DEBUG || WAKE_IDENTITY_TOOLS

        // MARK: App lifecycle → sessions + background flush

        private func startAppLifecycle() {
            guard let appLifecycle else { return }
            appLifecycle.onForeground = { [weak self] in self?.handleForeground() }
            appLifecycle.onBackground = { [weak self] in self?.handleBackground() }
            appLifecycle.start()
        }

        private func handleForeground() {
            screenTime?.resumed(now: clock.now())
            for emit in sessions?.activated(now: clock.now()) ?? [] {
                record(name: emit.name, params: emit.params, sessionIDOverride: emit.sessionID)
            }
        }

        private func handleBackground() {
            screenTime?.backgrounded(now: clock.now())
            sessions?.backgrounded(now: clock.now())
            lifecycle?.flush()
        }

        // MARK: Screen time

        /// Put a starting point at this moment. A no-op before `start`, like every
        /// other entry point: nothing is written until there is consent.
        func mark(_ id: String) {
            lock.lock()
            let started = { if case .active = state { return true } else { return false } }()
            lock.unlock()
            guard started else {
                Diag.debug("`\(id)` not marked — Wake.start(apiKey:) hasn't been called")
                return
            }
            screenTime?.mark(id, now: clock.now())
        }

        /// Foreground seconds since that starting point, or nil when it was never
        /// marked — which is what leaves the property off the instance entirely.
        ///
        /// The two built-ins need no mark: `install` is the accumulator itself, and
        /// `session` is the open session's own foreground time.
        func screenTimeSince(_ id: String) -> TimeInterval? {
            lock.lock()
            let started = { if case .active = state { return true } else { return false } }()
            lock.unlock()
            guard started, let screenTime else { return nil }

            let now = clock.now()
            switch id {
            case ScreenTime.Builtin.install: return screenTime.total(now: now)
            case ScreenTime.Builtin.session: return sessions?.foregroundSeconds(now: now)
            default: return screenTime.since(id, now: now)
            }
        }

        // MARK: Record

        /// Records one event. A `transaction` makes the event's id deterministic —
        /// the same purchase logged twice collapses at ingest — and makes the
        /// transaction's own environment, not the build's, decide `isSandbox`.
        func record(
            name: String,
            params: [String: ParamValue],
            sessionIDOverride: String? = nil,
            transaction: TransactionIdentity? = nil,
            configID: String? = nil
        ) {
            let envelope: Envelope? = {
                lock.lock()
                defer { lock.unlock() }

                guard case .active(let active) = state else { return nil }

                return Envelope(
                    eventID: transaction.map {
                        Hashing.deterministicUUID("\(active.apiKey):\(name):\($0.id)")
                    } ?? uuid(),
                    name: name,
                    params: params,
                    clientTS: clock.now(),
                    eventSequence: nextSequence(),
                    sdkVersion: Wake.sdkVersion,
                    sessionID: sessionIDOverride ?? sessions?.currentSessionID,
                    isSandbox: transaction?.isSandbox ?? Environment.isSandbox,
                    osVersion: Environment.osVersion,
                    appVersion: Environment.appVersion,
                    platform: Environment.platform,
                    device: Environment.device,
                    locale: Environment.locale,
                    country: Environment.country,
                    configID: configID
                )
            }()

            guard let envelope else {
                Diag.debug("`\(name)` not recorded — Wake.start(apiKey:) hasn't been called")
                return
            }
            sink.receive(envelope)
        }

        // MARK: Helpers (lock held)

        private func ensureInstallID() -> (id: String, isNew: Bool) {
            if let existing = store.string(forKey: Keys.installID) {
                return (existing, false)
            }
            let fresh = uuid()
            store.set(fresh, forKey: Keys.installID)
            return (fresh, true)
        }

        private func nextSequence() -> Int {
            let next = (store.integer(forKey: Keys.sequence) ?? 0) + 1
            store.setInteger(next, forKey: Keys.sequence)
            return next
        }
    }
}
