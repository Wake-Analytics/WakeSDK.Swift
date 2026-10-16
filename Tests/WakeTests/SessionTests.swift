import XCTest
@testable import Wake

/// Unit tests for the session state machine. It takes explicit `now` values, so the
/// timeout and foreground-time logic are fully deterministic without real time.
final class SessionTests: XCTestCase {

    private let t0 = Date(timeIntervalSince1970: 1000)

    private func makeManager(store: InMemoryStore = InMemoryStore(), timeout: TimeInterval = 1800) -> SessionManager {
        SessionManager(clock: ManualClock(date: Date(timeIntervalSince1970: 0)),
                       store: store, uuid: CountingUUID().next, timeout: timeout)
    }

    func testFreshActivationBeginsSession() {
        let sm = makeManager()
        let emits = sm.activated(now: t0)
        XCTAssertEqual(emits.map(\.name), ["$session_start"])
        XCTAssertNotNil(sm.currentSessionID)
        XCTAssertEqual(emits.first?.sessionID, sm.currentSessionID)
    }

    func testResumeWithinTimeout() {
        let sm = makeManager()
        _ = sm.activated(now: t0)
        let id = sm.currentSessionID
        sm.backgrounded(now: t0.addingTimeInterval(60))

        let emits = sm.activated(now: t0.addingTimeInterval(120))   // 60s later, < 1800
        XCTAssertTrue(emits.isEmpty, "resume, no new session events")
        XCTAssertEqual(sm.currentSessionID, id, "same session")
    }

    func testNewSessionAfterTimeout() {
        let sm = makeManager()
        _ = sm.activated(now: t0)
        let old = sm.currentSessionID
        sm.backgrounded(now: t0.addingTimeInterval(60))

        let emits = sm.activated(now: t0.addingTimeInterval(60 + 2000))  // > 1800 since background
        XCTAssertEqual(emits.map(\.name), ["$session_end", "$session_start"])
        XCTAssertEqual(emits.first?.sessionID, old, "end is stamped with the OLD session")
        XCTAssertNotEqual(sm.currentSessionID, old)
        XCTAssertEqual(emits.last?.sessionID, sm.currentSessionID)
    }

    func testForegroundTimeExcludesBackgroundedGaps() {
        let sm = makeManager()
        _ = sm.activated(now: t0)                              // foreground @0
        sm.backgrounded(now: t0.addingTimeInterval(60))        // accrue 60
        _ = sm.activated(now: t0.addingTimeInterval(100))      // resume (40s backgrounded, uncounted)
        sm.backgrounded(now: t0.addingTimeInterval(130))       // accrue +30 = 90

        let emits = sm.activated(now: t0.addingTimeInterval(130 + 2000))  // close old
        let end = emits.first { $0.name == "$session_end" }
        XCTAssertEqual(end?.params["duration_seconds"], .int(90),
                       "duration is foreground time (90s), not the 130s wall span")
    }

    func testResetClearsSession() {
        let store = InMemoryStore()
        let sm = makeManager(store: store)
        _ = sm.activated(now: t0)
        XCTAssertNotNil(sm.currentSessionID)
        sm.reset()
        XCTAssertNil(sm.currentSessionID)
    }
}
