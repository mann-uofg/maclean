import SwiftUI
import AppKit
import MacleanCore

@MainActor
public final class MacleanAppState: ObservableObject {
    @Published public var timeLimit: Double = 30
    @Published public var enableTouchID: Bool = true
    @Published public var isBlocking: Bool = false
    @Published public var timeRemaining: Int = 0
    @Published public var permissionError: Bool = false
    
    // Core Engine Integration
    private let eventTapManager = EventTapManager()
    private let unlockCoordinator = UnlockCoordinator()
    private let watchdogManager = WatchdogManager()
    private lazy var blockingActor = BlockingSessionActor(
        eventTapManager: eventTapManager,
        unlockCoordinator: unlockCoordinator,
        watchdogManager: watchdogManager
    )
    
    // UI Elements
    private let overlayManager = OverlayWindowManager()
    
    // Polling task for UI updates
    private var pollingTask: Task<Void, Never>?
    
    public init() {}
    
    public func startCleaning() {
        guard !isBlocking else { return }
        
        // Setup permissions check first
        let hasAccess = PermissionsManager.checkAndPromptAccess()
        guard hasAccess else {
            permissionError = true
            return
        }
        
        permissionError = false
        
        Task {
            do {
                try await blockingActor.startBlocking(timeout: timeLimit, requireTouchID: enableTouchID)
                self.isBlocking = true
                self.timeRemaining = Int(timeLimit)
                self.overlayManager.showOverlays()
                self.startPolling()
            } catch {
                if let err = error as? MacleanError, err == .accessibilityPermissionDenied {
                    self.permissionError = true
                }
                print("Failed to start blocking: \(error.localizedDescription)")
            }
        }
    }
    
    public func stopCleaning() {
        Task {
            await blockingActor.stopBlocking()
            self.isBlocking = false
            self.overlayManager.hideOverlays()
            self.pollingTask?.cancel()
            self.pollingTask = nil
        }
    }
    
    private func startPolling() {
        pollingTask = Task {
            let start = Date()
            while await blockingActor.isBlocking {
                let elapsed = Date().timeIntervalSince(start)
                let remaining = max(0, Int(self.timeLimit - elapsed))
                
                // Only trigger publishes if the second actually ticked
                if self.timeRemaining != remaining {
                    self.timeRemaining = remaining
                }
                
                try? await Task.sleep(nanoseconds: 100_000_000)
            }
            
            // If the loop exits and we're still 'isBlocking' locally, it means 
            // the actor stopped (e.g., Touch ID passed, timeout passed, or emergency chord).
            if self.isBlocking {
                self.stopCleaning()
            }
        }
    }
}
