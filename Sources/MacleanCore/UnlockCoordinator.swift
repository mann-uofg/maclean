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
            if let t = timeout, t > 0 {
                group.addTask {
                    let nanoseconds = UInt64(t * 1_000_000_000)
                    try await Task.sleep(nanoseconds: nanoseconds)
                }
            }
            
            // 2. Touch ID Path
            if requireTouchID {
                group.addTask {
                    let context = LAContext()
                    var authError: NSError?
                    
                    // Touch ID Deadlock Guard: LAContext evaluation is purely asynchronous 
                    // and non-blocking here.
                    guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &authError) else {
                        // If Touch ID is unavailable, we just hang this task so the timeout can win.
                        // If there is no timeout, we must throw to abort the block.
                        if timeout == nil {
                            throw MacleanError.touchIDNotAvailable
                        } else {
                            try await Task.sleep(nanoseconds: UInt64.max)
                            return
                        }
                    }
                    
                    do {
                        let success = try await context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: "Unlock Maclean to restore input")
                        if !success {
                            // Should theoretically throw, but if it returns false, hang this path.
                            try await Task.sleep(nanoseconds: UInt64.max)
                        }
                    } catch {
                        if timeout == nil {
                            // If user cancels and there's no timeout, they are permanently locked out unless they use chord.
                            // Throw to force an abort.
                            throw error
                        } else {
                            // Just wait for timeout.
                            try await Task.sleep(nanoseconds: UInt64.max)
                        }
                    }
                }
            }
            
            // Wait for the first task to finish successfully
            if let _ = try await group.next() {
                // First to finish wins. Cancel the rest cleanly.
                group.cancelAll()
            }
        }
    }
}
