import XCTest
@testable import MacleanCore

final class LeakTests: XCTestCase {
    
    /// Verifies zero memory leaks across a full block/unblock cycle.
    func testZeroLeakLifecycle() async throws {
        weak var weakActor: BlockingSessionActor?
        weak var weakEventTap: EventTapManager?
        weak var weakCoordinator: UnlockCoordinator?
        weak var weakWatchdog: WatchdogManager?
        
        do {
            // Scope limit: all strongly retained objects are born and die inside this block
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
                await actor.stopBlocking()
            } catch {
                XCTFail("Start blocking threw: \(error)")
            }
            
            // At the end of this block, `actor`, `eventTap`, `unlock`, and `watchdog` should be deallocated natively natively.
        }
        
        // Wait a tiny bit for the internal background tasks inside `BlockingSessionActor` to finish evaluating cancellation and release `self`.
        try? await Task.sleep(nanoseconds: 50_000_000)
        
        XCTAssertNil(weakActor, "BlockingSessionActor leaked!")
        XCTAssertNil(weakEventTap, "EventTapManager leaked!")
        XCTAssertNil(weakCoordinator, "UnlockCoordinator leaked!")
        XCTAssertNil(weakWatchdog, "WatchdogManager leaked!")
    }
}
