import XCTest
@testable import Wake

final class IdentityConsentTests: XCTestCase {

    private func makeCore(
        store: InMemoryStore,
        sink: CollectingSink = CollectingSink(),
        uuid: CountingUUID = CountingUUID()
    ) -> Wake.Core {
        Wake.Core(store: store, clock: ManualClock(date: Date(timeIntervalSince1970: 1_000)), sink: sink, uuid: uuid.next)
    }

    func testNothingWrittenAndNoEventsBeforeStart() {
        let store = InMemoryStore()
        let sink = CollectingSink()
        let core = makeCore(store: store, sink: sink)

        core.record(name: "used_search", params: ["query": .string("cats"), "results": .int(2)])

        XCTAssertTrue(store.isEmpty, "no disk writes before start")
        XCTAssertTrue(sink.received.isEmpty, "log no-ops before start")
    }

    func testStartCreatesInstallID() {
        let store = InMemoryStore()
        let core = makeCore(store: store)

        core.start(apiKey: "k")

        XCTAssertEqual(store.string(forKey: Keys.installID), "id-1")
    }

    func testInstallIDStableAcrossRestarts() {
        let store = InMemoryStore()
        let uuid = CountingUUID()
        let core = makeCore(store: store, uuid: uuid)

        core.start(apiKey: "k")
        core.start(apiKey: "k")

        XCTAssertEqual(store.string(forKey: Keys.installID), "id-1", "same id, uuid() consumed once")
    }

    func testDeleteDataErasesIdentityAndDeactivates() {
        let store = InMemoryStore()
        let sink = CollectingSink()
        let core = makeCore(store: store, sink: sink)

        core.start(apiKey: "k")
        core.record(name: "opened_paywall", params: [:])
        XCTAssertEqual(sink.received.count, 1)

        core.deleteData()

        XCTAssertNil(store.string(forKey: Keys.installID))
        XCTAssertNil(store.integer(forKey: Keys.sequence))
        XCTAssertEqual(store.string(forKey: Keys.pendingErasureID), "id-1", "erasure queued for the beacon")

        core.record(name: "opened_paywall", params: [:])
        XCTAssertEqual(sink.received.count, 1, "log no-ops after deleteData")
    }

    func testReStartAfterDeleteYieldsFreshID() {
        let store = InMemoryStore()
        let core = makeCore(store: store)

        core.start(apiKey: "k")
        core.deleteData()
        core.start(apiKey: "k")

        XCTAssertEqual(store.string(forKey: Keys.installID), "id-2", "fresh id after re-consent")
    }
}
