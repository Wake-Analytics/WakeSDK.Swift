import Foundation

/// The lifecycle side of transport, called by `Core` on start and erase.
protocol TransportLifecycle: AnyObject, Sendable {
    func start(apiKey: String, installID: String)
    func requestErasure(installID: String)
    func flush()
}

/// Production transport: buffers events and drives the `Uploader`.
///
/// Logging is bursty — a screen can emit half a dozen events in the same frame —
/// so a flush per event would be a POST per event. Appends instead open a short
/// coalescing window: the burst lands in one request, and a busy app still tops
/// out at one request per window. `batchThreshold` cuts the window short when
/// enough events are already waiting, so a sustained stream keeps up rather than
/// piling into ever-larger batches.
final class Transport: EventSink, TransportLifecycle, @unchecked Sendable {
    private let buffer: EventBuffer
    let uploader: Uploader
    private let flushInterval: TimeInterval
    private let coalesceInterval: TimeInterval
    private let batchThreshold: Int
    private let lock = NSLock()
    private var pump: Task<Void, Never>?
    private var coalescing: Task<Void, Never>?
    private var bufferedSinceFlush = 0
    private let writes = DispatchQueue(label: "app.realwake.buffer", qos: .utility)

    init(
        buffer: EventBuffer,
        uploader: Uploader,
        flushInterval: TimeInterval = 30,
        coalesceInterval: TimeInterval = 1.5,
        batchThreshold: Int = 20
    ) {
        self.buffer = buffer
        self.uploader = uploader
        self.flushInterval = flushInterval
        self.coalesceInterval = coalesceInterval
        self.batchThreshold = batchThreshold
    }

    func receive(_ envelope: Wake.Envelope) {
        let event = BufferedEvent(envelope)
        writes.async { [self] in
            buffer.append(event)
            lock.lock()
            bufferedSinceFlush += 1
            let full = bufferedSinceFlush >= batchThreshold
            lock.unlock()
            if full { flushNow() } else { openCoalescingWindow() }
        }
    }

    func start(apiKey: String, installID: String) {
        Task {
            await uploader.configure(apiKey: apiKey, installID: installID)
            await uploader.flush()
            await uploader.drainErasure()
        }
        startPump()
    }

    func requestErasure(installID: String) {
        Task { [buffer, uploader, writes] in
            await uploader.deactivate()
            writes.sync { buffer.removeAll() }
            await uploader.drainErasure()
        }
    }

    func flush() {
        flushNow()
    }

    /// Flushes after `coalesceInterval`, unless a window is already open — a
    /// trailing window rather than a debounce, so a continuous stream of events
    /// still uploads on time instead of deferring forever.
    private func openCoalescingWindow() {
        lock.lock(); defer { lock.unlock() }
        guard coalescing == nil else { return }
        let interval = coalesceInterval
        coalescing = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
            guard !Task.isCancelled else { return }
            self?.flushNow()
        }
    }

    private func flushNow() {
        lock.lock()
        bufferedSinceFlush = 0
        coalescing?.cancel()
        coalescing = nil
        lock.unlock()
        // Hop through `writes` so any append already in flight is on the buffer
        // before the uploader reads it.
        writes.async { [uploader] in
            Task { await uploader.flush() }
        }
    }

    private func startPump() {
        lock.lock(); defer { lock.unlock() }
        guard pump == nil else { return }
        let interval = flushInterval
        pump = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
                self?.flushNow()
            }
        }
    }
}
