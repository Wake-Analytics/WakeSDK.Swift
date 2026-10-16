import XCTest
import Foundation
@testable import Wake

final class EventBufferTests: XCTestCase {

    private func tempURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("smtest-\(UUID().uuidString)")
            .appendingPathComponent("events.json")
    }

    func testAppendPeekRemove() {
        let buffer = FileEventBuffer(fileURL: tempURL())
        buffer.append(makeBufferedEvent(id: "a", seq: 1))
        buffer.append(makeBufferedEvent(id: "b", seq: 2))
        buffer.append(makeBufferedEvent(id: "c", seq: 3))

        XCTAssertEqual(buffer.count, 3)
        XCTAssertEqual(buffer.peek(limit: 2).map(\.eventID), ["a", "b"], "FIFO, limited")

        buffer.remove(ids: ["a", "c"])
        XCTAssertEqual(buffer.peek(limit: 10).map(\.eventID), ["b"])
    }

    func testPersistsAcrossInstances() {
        let url = tempURL()
        let first = FileEventBuffer(fileURL: url)
        first.append(makeBufferedEvent(id: "x", name: "used_search", seq: 1))

        // New instance, same file — simulates a relaunch.
        let second = FileEventBuffer(fileURL: url)
        let events = second.peek(limit: 10)
        XCTAssertEqual(events.map(\.eventID), ["x"])
        XCTAssertEqual(events.first?.name, "used_search")
    }

    func testRoundTripPreservesParamTypes() {
        let url = tempURL()
        let env = makeEnvelope(id: "p", params: [
            "s": .string("hi"), "i": .int(3), "d": .double(1.5), "b": .bool(true),
            "arr": .intArray([1, 2, 3]),
        ])
        FileEventBuffer(fileURL: url).append(BufferedEvent(env))

        let reloaded = FileEventBuffer(fileURL: url).peek(limit: 1).first
        XCTAssertEqual(reloaded?.params, [
            "s": .string("hi"), "i": .int(3), "d": .double(1.5), "b": .bool(true),
            "arr": .intArray([1, 2, 3]),
        ], "tagged disk form decodes types unambiguously")
    }
}
