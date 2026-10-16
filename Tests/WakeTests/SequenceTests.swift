import XCTest
@testable import Wake

final class SequenceTests: XCTestCase {

    private func makeCore(store: InMemoryStore, sink: CollectingSink) -> Wake.Core {
        Wake.Core(store: store, clock: ManualClock(date: Date(timeIntervalSince1970: 0)), sink: sink, uuid: CountingUUID().next)
    }

    func testSequenceMonotonic() {
        let store = InMemoryStore()
        let sink = CollectingSink()
        let core = makeCore(store: store, sink: sink)
        core.start(apiKey: "k")

        core.record(name: "opened_paywall", params: [:])
        core.record(name: "opened_paywall", params: [:])
        core.record(name: "opened_paywall", params: [:])

        XCTAssertEqual(sink.received.map(\.eventSequence), [1, 2, 3])
    }

    func testSequencePersistsAcrossRelaunch() {
        let store = InMemoryStore()

        let sink1 = CollectingSink()
        let core1 = makeCore(store: store, sink: sink1)
        core1.start(apiKey: "k")
        core1.record(name: "opened_paywall", params: [:])
        XCTAssertEqual(sink1.received.map(\.eventSequence), [1])

        // New Core, same store — simulates a relaunch.
        let sink2 = CollectingSink()
        let core2 = makeCore(store: store, sink: sink2)
        core2.start(apiKey: "k")
        core2.record(name: "opened_paywall", params: [:])

        XCTAssertEqual(sink2.received.map(\.eventSequence), [2], "sequence continues across launches")
        XCTAssertEqual(store.string(forKey: Keys.installID), "id-1", "install id persisted too")
    }

    func testSequenceResetsAfterDeleteData() {
        let store = InMemoryStore()
        let sink = CollectingSink()
        let core = makeCore(store: store, sink: sink)

        core.start(apiKey: "k")
        core.record(name: "opened_paywall", params: [:])
        core.deleteData()
        core.start(apiKey: "k")
        core.record(name: "opened_paywall", params: [:])

        XCTAssertEqual(sink.received.map(\.eventSequence), [1, 1], "fresh subject restarts the sequence")
    }
}
