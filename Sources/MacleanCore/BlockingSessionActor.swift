import Foundation

/// A fully isolated Swift actor that owns all mutable blocking state.
/// This acts as the single source of truth for whether the system is currently blocking input,
/// preventing data races by serializing all state transitions.
///
/// **OS-Level Design Decisions**:
/// - **Single-lock discipline**: State transitions (start, stop) are inherently serialized 
///   by Actor isolation, eliminating a whole class of data races at compile time.
/// - The `isBlocking` property is exposed as non-isolated so other components (like UI) 
///   can quickly poll the state. Wait, actor isolation in Swift 6.2 doesn't allow `nonisolated var`s 
///   that mutate, so we rely on the `isBlocking` getter which suspends to read.
public actor BlockingSessionActor {
    public private(set) var isBlocking: Bool = false
    
    private let eventTapManager: EventTapManager
    private let unlockCoordinator: UnlockCoordinator
    private let watchdogManager: WatchdogManager
    
    // Track the active wait task so we can cancel it cleanly on an emergency unlock.
    private var waitTask: Task<Void, Never>?
    
    public init(eventTapManager: EventTapManager, unlockCoordinator: UnlockCoordinator, watchdogManager: WatchdogManager) {
        self.eventTapManager = eventTapManager
        self.unlockCoordinator = unlockCoordinator
        self.watchdogManager = watchdogManager
        
        // Listen for the emergency chord bypass.
        // The event tap manager calls this closure on its own thread,
        // and we safely bridge into the actor using a Task.
        self.eventTapManager.onEmergencyUnlock = { [weak self] in
            Task { [weak self] in
                await self?.stopBlocking()
            }
        }
    }
    
    /// Starts the blocking session. Throws if a session is already active or if setup fails.
    public func startBlocking(timeout: TimeInterval? = nil, requireTouchID: Bool = false) async throws {
        guard !isBlocking else {
            throw MacleanError.blockingFailed("A blocking session is already active.")
        }
        
        isBlocking = true
        
        // OS Resource Protected: Start watchdog first. If the app crashes immediately AFTER
        // allocating the tap, the watchdog is already armed to clean it up.
        try watchdogManager.start()
        
        do {
            try eventTapManager.start()
        } catch {
            isBlocking = false
            watchdogManager.stop()
            throw error
        }
        
        // Launch the unstructured Task that strictly orchestrates the unlock conditions.
        // Keeping a reference in `waitTask` allows us to securely cancel it if needed.
        waitTask = Task {
            do {
                try await unlockCoordinator.waitForUnlock(timeout: timeout, requireTouchID: requireTouchID)
            } catch {
                // Ignore cancellation / timeout errors; they naturally result in unblocking.
            }
            
            // If the task wasn't explicitly cancelled (e.g., Touch ID succeeded or timeout passed),
            // trigger the unblock.
            self.stopBlocking()
        }
    }
    
    /// Stops the blocking session, tearing down all kernel resources.
    public func stopBlocking() {
        guard isBlocking else { return }
        
        waitTask?.cancel()
        waitTask = nil
        
        // Cleanup all OS resources.
        eventTapManager.stop()
        watchdogManager.stop()
        
        isBlocking = false
    }
}
