import Foundation
import CoreGraphics
import os

/// Manages the CGEventTap lifecycle on a dedicated thread.
///
/// **Memory Efficiency & OS-Level Safety**:
/// - Uses a dedicated background thread with its own `CFRunLoop` to prevent main thread stalls from bypassing the block.
/// - The `isBlocking` state is protected by `os_unfair_lock`, which handles priority inversion (unlike `NSLock`).
/// - The C-callback (`eventTapCallback`) allocates zero objects on the hot path.
/// - All kernel resources (`CFMachPort`, `CFRunLoopSource`) are cleaned up meticulously to prevent zombie taps.
public final class EventTapManager: @unchecked Sendable {
    
    /// The dedicated background thread that runs the CFRunLoop for the event tap.
    private var tapThread: Thread?
    
    /// The actual tap port to the window server.
    private(set) var tapPort: CFMachPort?
    
    /// The run loop source attached to our tap thread.
    private var runLoopSource: CFRunLoopSource?
    
    /// The run loop of the dedicated tap thread.
    private var tapRunLoop: CFRunLoop?
    
    /// Lock for atomic read/write of `isBlocking`
    private var stateLock = os_unfair_lock()
    private var _isBlocking: Bool = false
    
    /// Whether the tap should silently drop events.
    public var isBlocking: Bool {
        get {
            os_unfair_lock_lock(&stateLock)
            let value = _isBlocking
            os_unfair_lock_unlock(&stateLock)
            return value
        }
        set {
            os_unfair_lock_lock(&stateLock)
            _isBlocking = newValue
            os_unfair_lock_unlock(&stateLock)
        }
    }
    
    /// Called when the emergency key chord is detected (e.g., left shift + right shift + escape).
    /// This closure is called asynchronously on another thread, so no locks are held.
    public var onEmergencyUnlock: (@Sendable () -> Void)?
    
    /// State for the emergency key chord (accessed only on the tap thread, no lock needed)
    private var leftShiftDown = false
    private var rightShiftDown = false
    private var escapeDown = false
    
    public init() {}
    
    /// Starts the event tap and its dedicated run loop thread.
    public func start() throws {
        guard tapPort == nil else { return } // Already started
        
        let types: [CGEventType] = [
            .keyDown, .keyUp, .flagsChanged,
            .leftMouseDown, .leftMouseUp, .rightMouseDown, .rightMouseUp,
            .mouseMoved, .leftMouseDragged, .rightMouseDragged, .scrollWheel
        ]
        let mask = types.reduce(CGEventMask(0)) { $0 | (1 << $1.rawValue) }
        
        let selfUnretained = Unmanaged.passUnretained(self).toOpaque()
        
        // OS Resource Protected: CGEventTapCreate registers a Mach port with the window server.
        guard let port = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: eventTapCallback,
            userInfo: selfUnretained
        ) else {
            throw MacleanError.eventTapCreationFailed
        }
        
        self.tapPort = port
        self.runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, port, 0)
        
        // Start the dedicated thread to host the run loop
        let thread = Thread { [weak self] in
            guard let self = self else { return }
            self.tapRunLoop = CFRunLoopGetCurrent()
            CFRunLoopAddSource(self.tapRunLoop, self.runLoopSource, .commonModes)
            CGEvent.tapEnable(tap: self.tapPort!, enable: true)
            CFRunLoopRun() // Blocks until CFRunLoopStop is called
        }
        
        // High priority to prevent UI lag on normal events when not blocking
        thread.qualityOfService = .userInteractive 
        thread.name = "com.maclean.EventTapThread"
        self.tapThread = thread
        
        self.isBlocking = true
        thread.start()
        
        // Wait briefly for the runloop to start (simple synchronization)
        var attempts = 0
        while tapRunLoop == nil && attempts < 100 {
            Thread.sleep(forTimeInterval: 0.001)
            attempts += 1
        }
    }
    
    /// Stops the event tap, releases kernel resources, and stops the dedicated thread cleanly.
    public func stop() {
        self.isBlocking = false
        
        if let port = tapPort {
            // OS Resource Protected: Release the Mach port allocation in the kernel
            CGEvent.tapEnable(tap: port, enable: false)
            CFMachPortInvalidate(port)
        }
        
        if let runLoop = tapRunLoop, let source = runLoopSource {
            CFRunLoopRemoveSource(runLoop, source, .commonModes)
            CFRunLoopStop(runLoop)
        }
        
        self.tapPort = nil
        self.runLoopSource = nil
        self.tapRunLoop = nil
        self.tapThread = nil
        
        self.leftShiftDown = false
        self.rightShiftDown = false
        self.escapeDown = false
    }
    
    /// Fast-path C callback invoked by the system for every tapped event.
    /// Memory efficient: no allocations. Lock-free (uses os_unfair_lock).
    fileprivate func handleEvent(_ proxy: CGEventTapProxy, type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            // Re-enable tap if system disabled it unexpectedly while we are supposed to be blocking
            if let port = tapPort, isBlocking {
                CGEvent.tapEnable(tap: port, enable: true)
            }
            return Unmanaged.passUnretained(event)
        }
        
        if !isBlocking {
            return Unmanaged.passUnretained(event)
        }
        
        // Keyboard tracking for emergency chord: Left Shift + Right Shift + Escape
        if type == .flagsChanged {
            let flags = event.flags
            leftShiftDown = flags.contains(.maskShift) && event.getIntegerValueField(.keyboardEventKeycode) == 56
            rightShiftDown = flags.contains(.maskShift) && event.getIntegerValueField(.keyboardEventKeycode) == 60
            
            // If the user doesn't hit shift, flags.contains will be false
            if !flags.contains(.maskShift) {
                leftShiftDown = false
                rightShiftDown = false
            }
        } else if type == .keyDown || type == .keyUp {
            let keycode = event.getIntegerValueField(.keyboardEventKeycode)
            if keycode == 53 { // Escape
                escapeDown = (type == .keyDown)
            }
        }
        
        // Check chord
        if leftShiftDown && rightShiftDown && escapeDown {
            // Trigger emergency unlock. Do not block this thread.
            if let callback = onEmergencyUnlock {
                Task {
                    callback()
                }
            }
            return Unmanaged.passUnretained(event)
        }
        
        // Block all other events by returning nil
        return nil
    }
}

/// The C-function callback for the CGEventTap.
private func eventTapCallback(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent, refcon: UnsafeMutableRawPointer?) -> Unmanaged<CGEvent>? {
    guard let refcon = refcon else { return Unmanaged.passUnretained(event) }
    let manager = Unmanaged<EventTapManager>.fromOpaque(refcon).takeUnretainedValue()
    return manager.handleEvent(proxy, type: type, event: event)
}
