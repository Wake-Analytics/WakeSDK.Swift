import Foundation

struct HTTPResponse: Sendable {
    let status: Int
    let body: Data
}

protocol HTTPClient: Sendable {
    func send(method: String, url: URL, headers: [String: String], body: Data?) async throws -> HTTPResponse
}

final class URLSessionHTTPClient: HTTPClient {
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func send(method: String, url: URL, headers: [String: String], body: Data?) async throws -> HTTPResponse {
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.httpBody = body
        for (key, value) in headers {
            request.setValue(value, forHTTPHeaderField: key)
        }
        let (data, response) = try await session.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        return HTTPResponse(status: status, body: data)
    }
}
