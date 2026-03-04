import Foundation

/// Crash-safe watchdog unblocking input if the main process hangs or dies.
///
/// **OS-Level Design Decision (Watchdog Architecture)**:
/// The macOS kernel fundamentally guarantees that if a process dies (cleanly or via crash), its Mach ports
/// (including `CGEventTap` allocations) are released and the tap is removed. The true lockout danger
/// is the app **hanging** while the event tap is active, causing the app to just eat events infinitely without
/// ever unblocking. 
///
/// Therefore, the watchdog is a separate lightweight `/bin/sh` subprocess that expects a heartbeat 
/// from the main app. If the heartbeat stops (due to a hang), the watchdog sends a `SIGKILL` to the 
/// main app, forcing the kernel to instantly reap the tap and restore input.
public final class WatchdogManager: @unchecked Sendable {
    private var watchdogProcess: Process?
    private var heartbeatTimer: DispatchSourceTimer?
    private let queue = DispatchQueue(label: "com.maclean.watchdog", qos: .utility)
    
    private var heartbeatFileURL: URL
    
    public init() {
        let tempDir = FileManager.default.temporaryDirectory
        heartbeatFileURL = tempDir.appendingPathComponent("maclean_heartbeat_\(ProcessInfo.processInfo.processIdentifier)")
    }
    
    /// Starts the watchdog subprocess and heartbeat timer.
    public func start() throws {
        stop() // Ensure clean state
        
        // Initial heartbeat
        try sendHeartbeat()
        
        // Start heartbeat timer every 1 second
        heartbeatTimer = DispatchSource.makeTimerSource(queue: queue)
        heartbeatTimer?.schedule(deadline: .now(), repeating: 1.0)
        heartbeatTimer?.setEventHandler { [weak self] in
            guard let self = self else { return }
            try? self.sendHeartbeat()
        }
        heartbeatTimer?.resume()
        
        // OS Resource Protected: The watchdog script uses `defer` logic (via `trap` or loop exit)
        // to ensure it doesn't leave zombie processes.
        let pid = ProcessInfo.processInfo.processIdentifier
        let path = heartbeatFileURL.path
        
        let script = """
        while true; do
            if [ ! -f "\(path)" ]; then
                exit 0
            fi
            
            LAST_MOD=$(stat -f "%m" "\(path)")
            CURRENT_TIME=$(date +%s)
            DIFF=$((CURRENT_TIME - LAST_MOD))
            
            if [ "$DIFF" -gt 4 ]; then
                # Heartbeat lost. Force kill to trigger kernel tap cleanup.
                kill -9 \(pid)
                rm -f "\(path)"
                exit 0
            fi
            sleep 1
        done
        """
        
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/sh")
        process.arguments = ["-c", script]
        
        try process.run()
        watchdogProcess = process
    }
    
    /// Stops the watchdog and cleans up resources.
    public func stop() {
        heartbeatTimer?.cancel()
        heartbeatTimer = nil
        
        // Remove the heartbeat file, which tells the script to exit gracefully
        try? FileManager.default.removeItem(at: heartbeatFileURL)
        
        watchdogProcess?.terminate()
        watchdogProcess = nil
    }
    
    private func sendHeartbeat() throws {
        let data = Data(String(Date().timeIntervalSince1970).utf8)
        try data.write(to: heartbeatFileURL, options: .atomic)
    }
    
    deinit {
        stop()
    }
}
