import XCTest
@testable import MacleanCore

final class DeadlockStressTests: XCTestCase {
    
    /// Stress test the enable/disable cycle 100 times concurrently to ensure 
    /// the actor isolation and internal locks do not deadlock.
    func testRapidEnableDisableDoesNotDeadlock() async throws {
        let eventTap = EventTapManager()
        let unlock = UnlockCoordinator()
        let watchdog = WatchdogManager()
        
        let actor = BlockingSessionActor(
            eventTapManager: eventTap,
            unlockCoordinator: unlock,
            watchdogManager: watchdog
        )
        
        // Use a task group to hit the actor rapidly
        await withTaskGroup(of: Void.self) { group in
            for _ in 0..<100 {
                group.addTask {
                    do {
                        try await actor.startBlocking(timeout: 1, requireTouchID: false)
                        await actor.stopBlocking()
                    } catch {
                        // Expected to throw "already active" sometimes since we spam it natively.
                        // The test is that it does not hang and finishes 100 iterations.
                    }
                }
            }
        }
        
        // Ensure clean state
        await actor.stopBlocking()
        let finalState = await actor.isBlocking
        XCTAssertFalse(finalState, "Actor should not be blocking after test finishes.")
    }
}
