import AppKit

/// Memory-efficient manager for full-screen overlay windows.
/// 
/// **Memory Efficiency Insight**: 
/// - Uses a single bare-bones `NSWindow` per screen.
/// - Uses a simple `NSTextField` instead of a complex SwiftUI view hierarchy.
/// - Drops references (`windows.removeAll()`) on hide to instantly free the allocation.
@MainActor
public final class OverlayWindowManager {
    private var windows: [NSWindow] = []
    
    public init() {}
    
    public func showOverlays() {
        guard windows.isEmpty else { return }
        
        for screen in NSScreen.screens {
            let window = NSWindow(
                contentRect: screen.frame,
                styleMask: [.borderless],
                backing: .buffered,
                defer: false
            )
            
            window.isOpaque = false
            window.backgroundColor = NSColor.black.withAlphaComponent(0.65)
            // ScreenSaver level allows it to cover the menu bar, Dock, and other apps seamlessly
            window.level = .screenSaver
            window.ignoresMouseEvents = false // Block all stray clicks
            window.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
            
            let contentView = NSView(frame: screen.frame)
            
            let label = NSTextField(labelWithString: "Maclean Active — Input Blocked")
            label.textColor = .white
            label.font = .systemFont(ofSize: 42, weight: .heavy)
            label.alignment = .center
            
            let sublabel = NSTextField(labelWithString: "Emergency Unlock: Left Shift + Right Shift + Escape")
            sublabel.textColor = NSColor.white.withAlphaComponent(0.7)
            sublabel.font = .systemFont(ofSize: 18, weight: .medium)
            sublabel.alignment = .center
            
            label.translatesAutoresizingMaskIntoConstraints = false
            sublabel.translatesAutoresizingMaskIntoConstraints = false
            contentView.addSubview(label)
            contentView.addSubview(sublabel)
            
            NSLayoutConstraint.activate([
                label.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
                label.centerYAnchor.constraint(equalTo: contentView.centerYAnchor, constant: -20),
                sublabel.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
                sublabel.topAnchor.constraint(equalTo: label.bottomAnchor, constant: 16)
            ])
            
            window.contentView = contentView
            window.makeKeyAndOrderFront(nil)
            windows.append(window)
        }
    }
    
    public func hideOverlays() {
        for window in windows {
            window.orderOut(nil)
        }
        windows.removeAll()
    }
}
