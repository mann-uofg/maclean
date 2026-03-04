import XCTest
@testable import MacleanCore

final class SignalHandlingTests: XCTestCase {
    
    func testResourceDisposalOnSignal() async throws {
        // We simulate the effect of a SIGTERM by calling stopBlocking()
        // and verifying that OS-level kernel resources (CFMachPort) are aggressively cleared.
        let eventTap = EventTapManager()
        let unlock = UnlockCoordinator()
        let watchdog = WatchdogManager()
        
        let actor = BlockingSessionActor(
            eventTapManager: eventTap,
            unlockCoordinator: unlock,
            watchdogManager: watchdog
        )
        
        try await actor.startBlocking(timeout: 1, requireTouchID: false)
        
        let isBlocking = await actor.isBlocking
        XCTAssertTrue(isBlocking)
        
        // Assert resource is held
        XCTAssertNotNil(eventTap.tapPort, "Mach port should be allocated")
        
        await actor.stopBlocking()
        
        let isBlockingAfter = await actor.isBlocking
        XCTAssertFalse(isBlockingAfter)
        
        // Assert resource is released
        XCTAssertNil(eventTap.tapPort, "Mach port must be cleared on stop.")
    }
}
