import XCTest
@testable import MacleanCore

final class LeakTests: XCTestCase {
    
    /// Verifies zero memory leaks across a full block/unblock cycle.
    func testZeroLeakLifecycle() async throws {
        weak var weakActor: BlockingSessionActor?
        weak var weakEventTap: EventTapManager?
        weak var weakCoordinator: UnlockCoordinator?
        weak var weakWatchdog: WatchdogManager?
        
        let didComplete = expectation(description: "Cycle completed")
        
        // Use a separate actor or function to encapsulate the strong references
        // so that they genuinely go out of scope before we test the weak refs.
        await runLifecycleTask(
            actorRef: &weakActor, 
            eventTapRef: &weakEventTap, 
            coordinatorRef: &weakCoordinator, 
            watchdogRef: &weakWatchdog
        )
        
        didComplete.fulfill()
        await fulfillment(of: [didComplete], timeout: 2.0)
        
        // Wait a tiny bit for async deallocation if any
        try? await Task.sleep(nanoseconds: 50_000_000)
        
        XCTAssertNil(weakActor, "BlockingSessionActor leaked!")
        XCTAssertNil(weakEventTap, "EventTapManager leaked!")
        XCTAssertNil(weakCoordinator, "UnlockCoordinator leaked!")
        XCTAssertNil(weakWatchdog, "WatchdogManager leaked!")
    }
    
    @MainActor
    private func runLifecycleTask(
        actorRef: inout weak BlockingSessionActor?,
        eventTapRef: inout weak EventTapManager?,
        coordinatorRef: inout weak UnlockCoordinator?,
        watchdogRef: inout weak WatchdogManager?
    ) async {
        let eventTap = EventTapManager()
        let unlock = UnlockCoordinator()
        let watchdog = WatchdogManager()
        
        let actor = BlockingSessionActor(
            eventTapManager: eventTap,
            unlockCoordinator: unlock,
            watchdogManager: watchdog
        )
        
        actorRef = actor
        eventTapRef = eventTap
        coordinatorRef = unlock
        watchdogRef = watchdog
        
        do {
            try await actor.startBlocking(timeout: 1, requireTouchID: false)
            await actor.stopBlocking()
        } catch {
            XCTFail("Start blocking threw: \(error)")
        }
        
        // All strong references (eventTap, unlock, watchdog, actor) normally out of scope here
    }
}
