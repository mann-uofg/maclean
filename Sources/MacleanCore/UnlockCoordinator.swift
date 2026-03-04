import Foundation
import LocalAuthentication

/// Coordinates the timeout and Touch ID verification race to safely unblock input.
///
/// **OS-Level Design Decision (Concurrency & Cancellation)**:
/// Utilizes Swift structured concurrency `withThrowingTaskGroup` to guarantee that exactly
/// one unlock condition wins. If the timeout expires or Touch ID succeeds, the group completes
/// and implicitly cancels the losing path. This ensures we never leave a hanging `LAContext`
/// evaluation or a stray timer running in the background.
public final class UnlockCoordinator: Sendable {
    
    public init() {}
    
    /// Waits for either the timeout to expire or the user to authenticate via Touch ID.
    /// If neither condition is met, this suspends until cancelled.
    public func waitForUnlock(timeout: TimeInterval?, requireTouchID: Bool) async throws {
        if timeout == nil && !requireTouchID {
            // Infinite block until externally cancelled.
            try await Task.sleep(nanoseconds: UInt64.max)
            return
        }
        
        try await withThrowingTaskGroup(of: Void.self) { group in
            
            // 1. Timeout Path
            if let activeTimeout = timeout, activeTimeout > 0 {
                group.addTask {
                    let nanoseconds = UInt64(activeTimeout * 1_000_000_000)
                    try await Task.sleep(nanoseconds: nanoseconds)
                }
            }
            
            // 2. Authentication Path (Touch ID / Apple Watch / Password)
            if requireTouchID {
                group.addTask {
                    while true {
                        let context = LAContext()
                        var authError: NSError?
                        
                        if context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &authError) {
                            do {
                                let success = try await context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: "Unlock Maclean to restore input")
                                if success {
                                    return // Authentication succeeded! Break the group.
                                }
                            } catch {
                                // User canceled or failed authentication.
                                // We swallow the error and loop to prompt them again.
                            }
                        } else {
                            // Hardware has zero authentication capability.
                            // If there is no timeout, they MUST use the emergency chord.
                            try await Task.sleep(nanoseconds: UInt64.max)
                        }
                        
                        // Wait 1 second before re-prompting to avoid spamming the UI thread immediately
                        try await Task.sleep(nanoseconds: 1_000_000_000)
                    }
                }
            }
            
            // Wait for the first task to finish successfully
            if try await group.next() != nil {
                // First to finish wins. Cancel the rest cleanly.
                group.cancelAll()
            }
        }
    }
}
