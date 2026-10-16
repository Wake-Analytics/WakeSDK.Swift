import XCTest
import Foundation
@testable import Wake

final class TransportTests: XCTestCase {


    private func makeTransport(
        http: MockHTTPClient,
        buffer: InMemoryEventBuffer,
        coalesceInterval: TimeInterval,
        batchThreshold: Int
    ) async -> Transport {
        let uploader = Uploader(
            buffer: buffer, http: http, store: InMemoryStore(),
            baseURL: URL(string: "https://x.test")!
        )
        await uploader.configure(apiKey: "k", installID: "i")
        return Transport(
            buffer: buffer, uploader: uploader,
            coalesceInterval: coalesceInterval, batchThreshold: batchThreshold
        )
    }

    private func eventRequests(_ http: MockHTTPClient) -> Int {
        http.requests(matching: "v1/events").count
    }

    func testBurstBecomesOneRequest() async throws {
        let http = MockHTTPClient(status: 200)
        let buffer = InMemoryEventBuffer()
        let transport = await makeTransport(
            http: http, buffer: buffer, coalesceInterval: 0.2, batchThreshold: 20
        )

        for i in 1...5 { transport.receive(makeEnvelope(id: "e\(i)", seq: i)) }
        XCTAssertEqual(eventRequests(http), 0, "nothing leaves inside the coalescing window")

        try await Task.sleep(nanoseconds: 600_000_000)
        XCTAssertEqual(eventRequests(http), 1, "the burst is one POST, not five")
        XCTAssertEqual(buffer.count, 0, "and it carried every event")
    }

    func testFullBatchDoesNotWaitForTheWindow() async throws {
        let http = MockHTTPClient(status: 200)
        let buffer = InMemoryEventBuffer()
        let transport = await makeTransport(
            http: http, buffer: buffer, coalesceInterval: 60, batchThreshold: 3
        )

        for i in 1...3 { transport.receive(makeEnvelope(id: "e\(i)", seq: i)) }

        try await Task.sleep(nanoseconds: 400_000_000)
        XCTAssertEqual(eventRequests(http), 1, "the threshold flushes ahead of the window")
        XCTAssertEqual(buffer.count, 0)
    }

    func testExplicitFlushSendsImmediately() async throws {
        let http = MockHTTPClient(status: 200)
        let buffer = InMemoryEventBuffer()
        let transport = await makeTransport(
            http: http, buffer: buffer, coalesceInterval: 60, batchThreshold: 20
        )

        transport.receive(makeEnvelope(id: "e1"))
        transport.flush()

        try await Task.sleep(nanoseconds: 400_000_000)
        XCTAssertEqual(eventRequests(http), 1, "backgrounding does not wait out the window")
        XCTAssertEqual(buffer.count, 0)
    }

    func testWindowReopensForLaterEvents() async throws {
        let http = MockHTTPClient(status: 200)
        let buffer = InMemoryEventBuffer()
        let transport = await makeTransport(
            http: http, buffer: buffer, coalesceInterval: 0.2, batchThreshold: 20
        )

        transport.receive(makeEnvelope(id: "e1"))
        try await Task.sleep(nanoseconds: 600_000_000)
        transport.receive(makeEnvelope(id: "e2", seq: 2))
        try await Task.sleep(nanoseconds: 600_000_000)

        XCTAssertEqual(eventRequests(http), 2, "a second burst opens a new window")
        XCTAssertEqual(buffer.count, 0)
    }

    func testStartUploadsOnlyEvents() async throws {
        // The release-day herd, settled for good: there is no second endpoint to
        // call on start. An SDK added to an app with thousands of existing installs
        // does nothing on launch but flush whatever is already buffered.
        let http = MockHTTPClient(status: 200)
        let buffer = InMemoryEventBuffer()
        let uploader = Uploader(
            buffer: buffer, http: http, store: InMemoryStore(),
            baseURL: URL(string: "https://x.test")!
        )
        let transport = Transport(buffer: buffer, uploader: uploader)

        transport.start(apiKey: "k", installID: "i")
        try await Task.sleep(nanoseconds: 400_000_000)

        XCTAssertTrue(
            http.requests(matching: "v1/declarations").isEmpty,
            "the declarations endpoint is retired"
        )
    }
}
