import Foundation

/// What to do with a batch after an ingest attempt.
enum Disposition: Equatable {
    case success
    case retry
    case hold
    case dropPermanent
}

enum HTTPPolicy {
    static func classify(_ status: Int) -> Disposition {
        switch status {
        case 200..<300:      return .success
        case 408, 429:       return .retry
        case 500..<600:      return .retry
        case 401, 403:       return .hold
        case 400, 413, 422:  return .dropPermanent
        default:             return (400..<500).contains(status) ? .hold : .retry
        }
    }
}

struct Backoff {
    var base: TimeInterval = 1
    var cap: TimeInterval = 300

    func delay(forAttempt attempt: Int) -> TimeInterval {
        guard attempt > 0 else { return 0 }
        return min(cap, base * pow(2, Double(attempt - 1)))
    }
}
