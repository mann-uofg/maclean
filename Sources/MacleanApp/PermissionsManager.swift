import AppKit

/// Handles Accessibility permissions effectively by prompting the system.
public final class PermissionsManager {
    
    /// Checks if Accessibility is granted. If not, it prompts the user securely via macOS System Settings.
    public static func checkAndPromptAccess() -> Bool {
        let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }
}
