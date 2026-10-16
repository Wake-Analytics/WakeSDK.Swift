import XCTest
@testable import Wake

/// Verifies Core drives the transport lifecycle. The real network path is covered
/// by UploaderTests; here we use a synchronous spy so the wiring is deterministic.
final class CoreLifecycleTests: XCTestCase {

    private func makeCore(store: InMemoryStore, spy: SpyLifecycle, sink: CollectingSink) -> Wake.Core {
        Wake.Core(
            store: store,
            clock: ManualClock(date: Date(timeIntervalSince1970: 0)),
            sink: sink,
            lifecycle: spy,
            uuid: CountingUUID().next
        )
    }

    func testStartNotifiesLifecycle() {
        let spy = SpyLifecycle()
        let core = makeCore(store: InMemoryStore(), spy: spy, sink: CollectingSink())

        core.start(apiKey: "abc")

        XCTAssertEqual(spy.started.count, 1)
        XCTAssertEqual(spy.started.first?.apiKey, "abc")
        XCTAssertEqual(spy.started.first?.installID, "id-1")
    }

    func testDeleteDataRequestsErasure() {
        let spy = SpyLifecycle()
        let core = makeCore(store: InMemoryStore(), spy: spy, sink: CollectingSink())

        core.start(apiKey: "abc")
        core.deleteData()

        XCTAssertEqual(spy.erasures, ["id-1"], "the erased install id is handed to transport")
    }

    func testDeleteDataWithoutStartDoesNotRequestErasure() {
        let spy = SpyLifecycle()
        let core = makeCore(store: InMemoryStore(), spy: spy, sink: CollectingSink())

        core.deleteData()

        XCTAssertTrue(spy.erasures.isEmpty, "nothing to erase before start")
    }

    func testRecordStillReachesSinkWithLifecyclePresent() {
        let sink = CollectingSink()
        let core = makeCore(store: InMemoryStore(), spy: SpyLifecycle(), sink: sink)

        core.start(apiKey: "abc")
        core.record(name: "opened_paywall", params: [:])

        XCTAssertEqual(sink.received.count, 1)
    }
}
