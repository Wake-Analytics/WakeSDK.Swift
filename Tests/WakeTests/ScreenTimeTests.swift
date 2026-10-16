import XCTest
@testable import Wake

/// The foreground accumulator and the marks on it: what counts, what doesn't, what
/// survives a relaunch, and what erasure takes with it.
final class ScreenTimeTests: XCTestCase {

    private let t0 = Date(timeIntervalSince1970: 1000)

    private func make(store: InMemoryStore, clock: any Clock) -> ScreenTime {
        ScreenTime(clock: clock, store: store)
    }

    // MARK: The accumulator

    func testOnlyForegroundTimeCounts() {
        let clock = ManualClock(date: t0)
        let screenTime = make(store: InMemoryStore(), clock: clock)

        screenTime.resumed(now: t0)
        screenTime.backgrounded(now: t0.addingTimeInterval(60))
        // An hour in the background contributes nothing.
        screenTime.resumed(now: t0.addingTimeInterval(3660))
        screenTime.backgrounded(now: t0.addingTimeInterval(3690))

        XCTAssertEqual(screenTime.total(now: t0.addingTimeInterval(3690)), 90)
    }

    func testTheSegmentInFlightCounts() {
        let screenTime = make(store: InMemoryStore(), clock: ManualClock(date: t0))

        screenTime.resumed(now: t0)

        // Nothing has been banked yet, but the app is being looked at right now.
        XCTAssertEqual(screenTime.total(now: t0.addingTimeInterval(45)), 45)
    }

    func testResumingTwiceKeepsTheSegmentInFlight() {
        let screenTime = make(store: InMemoryStore(), clock: ManualClock(date: t0))

        screenTime.resumed(now: t0)
        screenTime.resumed(now: t0.addingTimeInterval(30))

        XCTAssertEqual(screenTime.total(now: t0.addingTimeInterval(60)), 60, "the second resume is not a restart")
    }

    func testBackgroundingWithoutForegroundDoesNothing() {
        let screenTime = make(store: InMemoryStore(), clock: ManualClock(date: t0))

        screenTime.backgrounded(now: t0.addingTimeInterval(60))

        XCTAssertEqual(screenTime.total(now: t0.addingTimeInterval(60)), 0)
    }

    func testTheTotalSurvivesARelaunch() {
        let store = InMemoryStore()
        let first = make(store: store, clock: ManualClock(date: t0))
        first.resumed(now: t0)
        first.backgrounded(now: t0.addingTimeInterval(120))

        // A new process over the same store — which is what a relaunch is.
        let second = make(store: store, clock: ManualClock(date: t0))

        XCTAssertEqual(second.total(now: t0.addingTimeInterval(500)), 120)
    }

    // MARK: Marks

    func testScreenTimeSinceAMark() {
        let screenTime = make(store: InMemoryStore(), clock: ManualClock(date: t0))

        screenTime.resumed(now: t0)
        screenTime.mark("onboarding_started", now: t0.addingTimeInterval(10))

        XCTAssertEqual(screenTime.since("onboarding_started", now: t0.addingTimeInterval(70)), 60)
    }

    func testBackgroundedTimeIsNotCountedTowardsAMark() {
        let screenTime = make(store: InMemoryStore(), clock: ManualClock(date: t0))

        screenTime.resumed(now: t0)
        screenTime.mark("onboarding_started", now: t0)
        screenTime.backgrounded(now: t0.addingTimeInterval(30))
        // A day away.
        screenTime.resumed(now: t0.addingTimeInterval(86_400))

        XCTAssertEqual(
            screenTime.since("onboarding_started", now: t0.addingTimeInterval(86_410)),
            40,
            "30s before leaving plus 10s after coming back"
        )
    }

    func testAnUnmarkedPointIsNil() {
        let screenTime = make(store: InMemoryStore(), clock: ManualClock(date: t0))
        screenTime.resumed(now: t0)

        XCTAssertNil(screenTime.since("never_marked", now: t0.addingTimeInterval(60)), "absent, never zero")
    }

    func testMarkingAgainRestartsTheClock() {
        let screenTime = make(store: InMemoryStore(), clock: ManualClock(date: t0))

        screenTime.resumed(now: t0)
        screenTime.mark("onboarding_started", now: t0)
        screenTime.mark("onboarding_started", now: t0.addingTimeInterval(100))

        XCTAssertEqual(screenTime.since("onboarding_started", now: t0.addingTimeInterval(160)), 60, "the last mark wins")
    }

    func testOneMarkServesEveryMilestoneAfterIt() {
        let screenTime = make(store: InMemoryStore(), clock: ManualClock(date: t0))

        screenTime.resumed(now: t0)
        screenTime.mark("onboarding_started", now: t0)

        // Logging an event doesn't consume the mark: a second one measures from
        // the same place, and reads longer.
        XCTAssertEqual(screenTime.since("onboarding_started", now: t0.addingTimeInterval(30)), 30)
        XCTAssertEqual(screenTime.since("onboarding_started", now: t0.addingTimeInterval(90)), 90)
    }

    func testMarksAreIndependent() {
        let screenTime = make(store: InMemoryStore(), clock: ManualClock(date: t0))

        screenTime.resumed(now: t0)
        screenTime.mark("a", now: t0)
        screenTime.mark("b", now: t0.addingTimeInterval(50))

        XCTAssertEqual(screenTime.since("a", now: t0.addingTimeInterval(80)), 80)
        XCTAssertEqual(screenTime.since("b", now: t0.addingTimeInterval(80)), 30)
    }

    func testMarksSurviveARelaunch() {
        let store = InMemoryStore()
        let first = make(store: store, clock: ManualClock(date: t0))
        first.resumed(now: t0)
        first.mark("onboarding_started", now: t0)
        first.backgrounded(now: t0.addingTimeInterval(60))

        let second = make(store: store, clock: ManualClock(date: t0))
        second.resumed(now: t0.addingTimeInterval(86_400))

        XCTAssertEqual(second.since("onboarding_started", now: t0.addingTimeInterval(86_430)), 90)
    }

    func testResetClearsTheTotalAndTheMarks() {
        let screenTime = make(store: InMemoryStore(), clock: ManualClock(date: t0))
        screenTime.resumed(now: t0)
        screenTime.mark("onboarding_started", now: t0)
        screenTime.backgrounded(now: t0.addingTimeInterval(60))

        screenTime.reset()

        XCTAssertEqual(screenTime.total(now: t0.addingTimeInterval(60)), 0)
        XCTAssertNil(screenTime.since("onboarding_started", now: t0.addingTimeInterval(60)))
    }

    // MARK: Through Core

    func testMarkBeforeStartNoOps() {
        let store = InMemoryStore()
        let clock = ManualClock(date: t0)
        let screenTime = make(store: store, clock: clock)
        let core = Wake.Core(store: store, clock: clock, sink: CollectingSink(), screenTime: screenTime)

        core.mark("onboarding_started")

        XCTAssertNil(core.screenTimeSince("onboarding_started"), "no consent → no marks")
    }

    func testCoreResolvesTheInstallBuiltin() {
        let store = InMemoryStore()
        let clock = MutableClock(t0)
        let screenTime = make(store: store, clock: clock)
        let core = Wake.Core(store: store, clock: clock, sink: CollectingSink(), screenTime: screenTime)
        core.start(apiKey: "k")

        clock.date = t0.addingTimeInterval(120)

        XCTAssertEqual(core.screenTimeSince(ScreenTime.Builtin.install), 120, "nothing to mark")
    }

    func testDeleteDataClearsScreenTime() {
        let store = InMemoryStore()
        let clock = ManualClock(date: t0)
        let screenTime = make(store: store, clock: clock)
        let core = Wake.Core(store: store, clock: clock, sink: CollectingSink(), screenTime: screenTime)
        core.start(apiKey: "k")
        core.mark("onboarding_started")

        core.deleteData()

        XCTAssertEqual(screenTime.total(now: clock.now()), 0)
        XCTAssertNil(screenTime.since("onboarding_started", now: clock.now()))
    }
}
