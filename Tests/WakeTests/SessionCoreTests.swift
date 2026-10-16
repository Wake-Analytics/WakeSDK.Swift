import XCTest
@testable import Wake

/// Integration: Core wiring the session manager + app lifecycle into the record path.
final class SessionCoreTests: XCTestCase {

    private let t0 = Date(timeIntervalSince1970: 1000)

    private func makeCore(
        clock: Clock,
        store: InMemoryStore,
        sink: EventSink,
        appLifecycle: (any AppLifecycleObserver)? = nil,
        lifecycle: TransportLifecycle? = nil
    ) -> Wake.Core {
        let sessions = SessionManager(clock: clock, store: store, uuid: { UUID().uuidString })
        return Wake.Core(
            store: store, clock: clock, sink: sink, lifecycle: lifecycle,
            sessions: sessions, appLifecycle: appLifecycle, uuid: CountingUUID().next
        )
    }

    func testStartEmitsSessionStartThenFirstLaunch() {
        let sink = CollectingSink()
        let core = makeCore(clock: ManualClock(date: t0), store: InMemoryStore(), sink: sink)

        core.start(apiKey: "k")

        XCTAssertEqual(sink.received.map(\.name), ["$session_start", "$first_launch"])
        let sid = sink.received.first?.sessionID
        XCTAssertNotNil(sid)
        XCTAssertEqual(sink.received.last?.sessionID, sid, "first_launch is in the same session")
        // Envelope fields populated (this is a DEBUG test build → sandbox).
        XCTAssertTrue(sink.received.first?.isSandbox == true)
        XCTAssertNotNil(sink.received.first?.osVersion)
    }

    func testFirstLaunchOnlyOncePerInstall() {
        let store = InMemoryStore()
        makeCore(clock: ManualClock(date: t0), store: store, sink: CollectingSink())
            .start(apiKey: "k")

        // Simulate a later relaunch (new Core, same store, past the session timeout).
        let sink2 = CollectingSink()
        makeCore(clock: ManualClock(date: t0.addingTimeInterval(10_000)), store: store, sink: sink2)
            .start(apiKey: "k")

        let names = sink2.received.map(\.name)
        XCTAssertFalse(names.contains("$first_launch"), "not a fresh install")
        XCTAssertTrue(names.contains("$session_end"), "prior session timed out")
        XCTAssertTrue(names.contains("$session_start"), "new session began")
    }

    func testEventsAreStampedWithCurrentSession() {
        let sink = CollectingSink()
        let core = makeCore(clock: ManualClock(date: t0), store: InMemoryStore(), sink: sink)
        core.start(apiKey: "k")
        let sid = sink.received.first?.sessionID

        core.record(name: "opened_paywall", params: [:])

        let last = sink.received.last
        XCTAssertEqual(last?.name, "opened_paywall")
        XCTAssertEqual(last?.sessionID, sid)
    }

    func testBackgroundTriggersFlush() {
        let spy = SpyLifecycle()
        let observer = ManualLifecycleObserver()
        let core = makeCore(clock: ManualClock(date: t0), store: InMemoryStore(),
                            sink: CollectingSink(), appLifecycle: observer, lifecycle: spy)
        core.start(apiKey: "k")

        observer.fireBackground()

        XCTAssertEqual(spy.flushes, 1)
    }

    func testForegroundAfterTimeoutStartsNewSession() {
        let clock = MutableClock(t0)
        let observer = ManualLifecycleObserver()
        let sink = CollectingSink()
        let core = makeCore(clock: clock, store: InMemoryStore(), sink: sink, appLifecycle: observer)
        core.start(apiKey: "k")

        observer.fireBackground()
        clock.date = t0.addingTimeInterval(2000)   // past the timeout
        observer.fireForeground()

        let starts = sink.received.filter { $0.name == "$session_start" }.count
        XCTAssertEqual(starts, 2, "a second session began after the timeout")
        XCTAssertTrue(sink.received.contains { $0.name == "$session_end" })
    }
}
