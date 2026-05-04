import Testing
@testable import LocalChatKit

struct AsyncSemaphoreTests {

    @Test func acquiresUpToLimit() async {
        let semaphore = AsyncSemaphore(limit: 3)
        await semaphore.acquire()
        await semaphore.acquire()
        await semaphore.acquire()
        await semaphore.release()
        await semaphore.release()
        await semaphore.release()
    }

    @Test func blocksWhenLimitReached() async {
        let semaphore = AsyncSemaphore(limit: 1)
        let flag = WaiterFlag()
        await semaphore.acquire()

        let waiter = Task {
            await semaphore.acquire()
            await flag.set()
            await semaphore.release()
        }

        for _ in 0..<20 { await Task.yield() }
        #expect(await !flag.isSet, "Acquire should be blocked while slot is taken")

        await semaphore.release()
        await waiter.value
        #expect(await flag.isSet, "Acquire should succeed after slot is released")
    }
}

private actor WaiterFlag {
    private(set) var isSet = false
    func set() { isSet = true }
}
