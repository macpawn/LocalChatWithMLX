import Testing
@testable import LocalChatKit

struct AsyncSemaphoreTests {

    @Test func acquiresUpToLimit() async throws {
        let semaphore = AsyncSemaphore(limit: 3)
        try await semaphore.acquire()
        try await semaphore.acquire()
        try await semaphore.acquire()
        await semaphore.release()
        await semaphore.release()
        await semaphore.release()
    }

    @Test func blocksWhenLimitReached() async throws {
        let semaphore = AsyncSemaphore(limit: 1)
        let flag = WaiterFlag()
        try await semaphore.acquire()

        let waiter = Task {
            try await semaphore.acquire()
            await flag.set()
            await semaphore.release()
        }

        for _ in 0..<20 { await Task.yield() }
        #expect(await !flag.isSet, "Acquire should be blocked while slot is taken")

        await semaphore.release()
        try await waiter.value
        #expect(await flag.isSet, "Acquire should succeed after slot is released")
    }

    @Test func cancelledWaiterDoesNotAcquireReleasedSlot() async throws {
        let semaphore = AsyncSemaphore(limit: 1)
        let flag = WaiterFlag()
        try await semaphore.acquire()

        let waiter = Task {
            try await semaphore.acquire()
            await flag.set()
            await semaphore.release()
        }

        for _ in 0..<20 { await Task.yield() }
        waiter.cancel()
        await semaphore.release()
        for _ in 0..<20 { await Task.yield() }

        #expect(await !flag.isSet, "Cancelled waiter should not resume after a later release")
        switch await waiter.result {
        case .success:
            Issue.record("Cancelled waiter should fail with CancellationError")
        case .failure(let error):
            #expect(error is CancellationError)
        }
    }
}

private actor WaiterFlag {
    private(set) var isSet = false
    func set() { isSet = true }
}
