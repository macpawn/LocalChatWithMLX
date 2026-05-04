import Foundation

actor AsyncSemaphore {
    private let limit: Int
    private var available: Int
    private var waiters: [Waiter] = []

    private struct Waiter {
        let id: UUID
        let continuation: CheckedContinuation<Void, Error>
    }

    init(limit: Int) {
        precondition(limit > 0, "AsyncSemaphore limit must be positive")
        self.limit = limit
        available = limit
    }

    func acquire() async throws {
        try Task.checkCancellation()
        if available > 0 {
            available -= 1
            return
        }
        let waiterId = UUID()
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                waiters.append(Waiter(id: waiterId, continuation: continuation))
            }
        } onCancel: {
            Task { await self.cancelWaiter(id: waiterId) }
        }
        try Task.checkCancellation()
    }

    func release() {
        if let waiter = waiters.first {
            waiters.removeFirst()
            waiter.continuation.resume()
        } else {
            assert(available < limit, "AsyncSemaphore over-released")
            available += 1
        }
    }

    private func cancelWaiter(id: UUID) {
        guard let idx = waiters.firstIndex(where: { $0.id == id }) else { return }
        let waiter = waiters.remove(at: idx)
        waiter.continuation.resume(throwing: CancellationError())
    }
}
