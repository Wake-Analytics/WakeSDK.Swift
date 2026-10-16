import XCTest
@testable import Wake

final class LoggingCoreTests: XCTestCase {

    private let fixedDate = Date(timeIntervalSince1970: 1_000)

    private func makeCore(sink: CollectingSink, store: InMemoryStore = InMemoryStore()) -> Wake.Core {
        Wake.Core(store: store, clock: ManualClock(date: fixedDate), sink: sink, uuid: CountingUUID().next)
    }

    func testValidEventFlowsToSink() {
        let sink = CollectingSink()
        let core = makeCore(sink: sink)
        core.start(apiKey: "k")

        core.record(name: "used_search", params: ["query": .string("cats"), "results": .int(2)])

        XCTAssertEqual(sink.received.count, 1)
        let e = sink.received[0]
        XCTAssertEqual(e.name, "used_search")
        XCTAssertEqual(e.params, ["query": .string("cats"), "results": .int(2)])
        XCTAssertEqual(e.eventID, "id-2") // id-1 was the install id
        XCTAssertEqual(e.eventSequence, 1)
        XCTAssertEqual(e.clientTS, fixedDate)
        XCTAssertEqual(e.sdkVersion, Wake.sdkVersion)
        XCTAssertNil(e.sessionID) // deferred
        XCTAssertNil(e.configID)
    }

    func testConfigurationIdRidesOnTheEvent() {
        let sink = CollectingSink()
        let core = makeCore(sink: sink)
        core.start(apiKey: "k")

        core.record(name: "used_search", params: [:], configID: "a1b2c3d4e5f6")

        XCTAssertEqual(sink.received.first?.configID, "a1b2c3d4e5f6")
        XCTAssertEqual(BufferedEvent(sink.received[0]).configID, "a1b2c3d4e5f6")
    }

    // Runtime payload validation is gone: a param of the wrong type is now a
    // compile error in the generated file, and there is no declaration table at
    // runtime to check an event name against. The core records what it is given.
    func testAnyEventIsRecorded() {
        let sink = CollectingSink()
        let core = makeCore(sink: sink)
        core.start(apiKey: "k")

        core.record(name: "mystery", params: ["whatever": .string("x")])

        XCTAssertEqual(sink.received.count, 1)
        XCTAssertEqual(sink.received[0].name, "mystery")
    }
}
