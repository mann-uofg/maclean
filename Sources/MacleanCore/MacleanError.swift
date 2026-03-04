import Foundation

/// Structured recovery errors for the MacleanCore module.
public enum MacleanError: Error, LocalizedError, Equatable {
    /// The user denied Accessibility permissions.
    case accessibilityPermissionDenied
    /// Failed to create the underlying CGEventTap (likely permissions or kernel issue).
    case eventTapCreationFailed
    /// Touch ID is unavailable on this device.
    case touchIDNotAvailable
    /// The unlock timeout expired.
    case unlockTimeoutExpired
    /// Used when a generic system error occurs.
    case systemError(String)
    /// Used when a logic error that prevents blocking from starting correctly occurs.
    case blockingFailed(String)

    public var errorDescription: String? {
        switch self {
        case .accessibilityPermissionDenied:
            return "Accessibility permission denied. Grant 'maclean' access in System Settings -> Privacy & Security -> Accessibility."
        case .eventTapCreationFailed:
            return "Failed to create CGEventTap. Ensure Accessibility permissions are granted and no other application is conflicting."
        case .touchIDNotAvailable:
            return "Touch ID is not available, not enrolled, or not configured on this Mac."
        case .unlockTimeoutExpired:
            return "The unlock timeout expired."
        case .systemError(let message):
            return "System error: \(message)"
        case .blockingFailed(let reason):
            return "Blocking failed to start: \(reason)"
        }
    }
}
