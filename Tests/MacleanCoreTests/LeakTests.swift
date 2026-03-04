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
        
        Task {
            let eventTap = EventTapManager()
            let unlock = UnlockCoordinator()
            let watchdog = WatchdogManager()
            
            let actor = BlockingSessionActor(
                eventTapManager: eventTap,
                unlockCoordinator: unlock,
                watchdogManager: watchdog
            )
            
            weakActor = actor
            weakEventTap = eventTap
            weakCoordinator = unlock
            weakWatchdog = watchdog
            
            do {
                try await actor.startBlocking(timeout: 1, requireTouchID: false)
                // Stop it early to test cleanup
                await actor.stopBlocking()
            } catch {
                XCTFail("Start blocking threw: \\(error)")
            }
            
            didComplete.fulfill()
        }
        
        await fulfillment(of: [didComplete], timeout: 2.0)
        
        // At this point, the Task block is done and all strong references 
        // to the core components should be released.
        // Wait a tiny bit for async deallocation if any 
        // (Task cleanup can sometimes take a microsecond)
        try? await Task.sleep(nanoseconds: 50_000_000)
        
        XCTAssertNil(weakActor, "BlockingSessionActor leaked!")
        XCTAssertNil(weakEventTap, "EventTapManager leaked!")
        XCTAssertNil(weakCoordinator, "UnlockCoordinator leaked!")
        XCTAssertNil(weakWatchdog, "WatchdogManager leaked!")
    }
}
