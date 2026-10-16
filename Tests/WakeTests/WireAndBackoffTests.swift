import XCTest
import Foundation
@testable import Wake

final class WireTests: XCTestCase {

    private func json(_ data: Data) -> [String: Any] {
        (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] ?? [:]
    }

    func testEventsBodyShape() throws {
        let env = makeEnvelope(id: "e1", name: "used_search", seq: 7,
                               params: ["query": .string("cats"), "results": .int(2), "on": .bool(true)])
        let data = try Wire.eventsBody(
            installID: "inst-1", sdkVersion: "0.1.0", events: [BufferedEvent(env)]
        )
        let obj = json(data)
        XCTAssertEqual(obj["install_id"] as? String, "inst-1")
        XCTAssertEqual(obj["sdk_version"] as? String, "0.1.0")
        XCTAssertEqual(Set(obj.keys), ["install_id", "sdk_version", "events"],
                       "the batch carries these three and nothing else")

        let events = obj["events"] as? [[String: Any]]
        let e = try XCTUnwrap(events?.first)
        XCTAssertEqual(e["event_id"] as? String, "e1")
        XCTAssertEqual(e["name"] as? String, "used_search")
        XCTAssertEqual(e["event_sequence"] as? Int, 7)
        XCTAssertEqual(e["is_sandbox"] as? Bool, false)
        XCTAssertNil(e["session_id"], "omitted when nil")

        let params = e["params"] as? [String: Any]
        XCTAssertEqual(params?["query"] as? String, "cats")
        XCTAssertEqual(params?["results"] as? Int, 2)          // number, not tagged
        XCTAssertEqual(params?["on"] as? Bool, true)           // real bool, not 0/1
    }

    func testEventsBodyEnvironmentFields() throws {
        // Present → serialized under snake_case keys.
        let full = Wake.Envelope(
            eventID: "e1", name: "used_search", params: [:],
            clientTS: Date(timeIntervalSince1970: 0), eventSequence: 1,
            sdkVersion: "0.1.0",
            osVersion: "18.2.0", appVersion: "3.4.1",
            platform: "ios", device: "iPhone16,2", locale: "en-US", country: "US",
            configID: "a1b2c3d4e5f6"
        )
        let e = try XCTUnwrap((json(try Wire.eventsBody(
            installID: "i", sdkVersion: "0.1.0", events: [BufferedEvent(full)]
        ))["events"] as? [[String: Any]])?.first)
        XCTAssertEqual(e["os_version"] as? String, "18.2.0")
        XCTAssertEqual(e["app_version"] as? String, "3.4.1")
        XCTAssertEqual(e["platform"] as? String, "ios")
        XCTAssertEqual(e["device"] as? String, "iPhone16,2")
        XCTAssertEqual(e["locale"] as? String, "en-US")
        XCTAssertEqual(e["country"] as? String, "US")
        XCTAssertEqual(e["config_id"] as? String, "a1b2c3d4e5f6")

        // Absent → keys omitted (server tolerates omission).
        let bare = try XCTUnwrap((json(try Wire.eventsBody(
            installID: "i", sdkVersion: "0.1.0",
            events: [BufferedEvent(makeEnvelope(id: "e2", name: "x"))]
        ))["events"] as? [[String: Any]])?.first)
        for key in ["platform", "device", "locale", "country", "config_id"] {
            XCTAssertNil(bare[key], "\(key) omitted when nil")
        }
    }

    func testErasureBodyShape() throws {
        XCTAssertEqual(json(try Wire.erasureBody(installID: "inst-9"))["install_id"] as? String, "inst-9")
    }
}

final class BackoffTests: XCTestCase {

    func testClassify() {
        XCTAssertEqual(HTTPPolicy.classify(200), .success)
        XCTAssertEqual(HTTPPolicy.classify(204), .success)
        XCTAssertEqual(HTTPPolicy.classify(429), .retry)
        XCTAssertEqual(HTTPPolicy.classify(503), .retry)
        XCTAssertEqual(HTTPPolicy.classify(408), .retry)
        XCTAssertEqual(HTTPPolicy.classify(401), .hold)
        XCTAssertEqual(HTTPPolicy.classify(403), .hold)
        XCTAssertEqual(HTTPPolicy.classify(400), .dropPermanent)
        XCTAssertEqual(HTTPPolicy.classify(413), .dropPermanent)
    }

    func testDelayMonotonicAndCapped() {
        let b = Backoff(base: 1, cap: 300)
        XCTAssertEqual(b.delay(forAttempt: 0), 0)
        XCTAssertEqual(b.delay(forAttempt: 1), 1)
        XCTAssertEqual(b.delay(forAttempt: 2), 2)
        XCTAssertEqual(b.delay(forAttempt: 3), 4)
        XCTAssertEqual(b.delay(forAttempt: 100), 300, "capped")
    }
}
