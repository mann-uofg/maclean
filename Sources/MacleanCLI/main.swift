import Foundation
import MacleanCore

let VERSION = "1.0.0"

func printUsage() {
    let usage = """
    maclean — macOS Input Blocker (\(VERSION))

    USAGE:
      maclean                 # Block indefinitely until Touch ID is verified (default)
      maclean <seconds>       # Block for exactly N seconds WITH Touch ID
      maclean <seconds> touch # (Redundant) Block for N seconds WITH Touch ID

    OPTIONS:
      -h, --help              # Print this help message
      -v, --version           # Print version

    EXAMPLES:
      maclean                 (blocks until Touch ID)
      maclean 30              (blocks for 30 seconds OR until Touch ID)
      maclean 120             (blocks for 2 minutes OR until Touch ID)

    HOW TO STOP:
      - Wait for the timer to end
      - Use Touch ID (if enabled)
      - Press Ctrl+C in this terminal
      - Press Control + Option + Command + Escape simultaneously
    """
    print(usage)
}

func parseArguments() -> (timeout: TimeInterval?, touchID: Bool) {
    let args = CommandLine.arguments.dropFirst()
    
    if args.contains("--help") || args.contains("-h") || args.contains("help") {
        printUsage()
        exit(0)
    }
    
    if args.contains("--version") || args.contains("-v") || args.contains("version") {
        print("maclean version \(VERSION)")
        exit(0)
    }
    
    if args.isEmpty {
        // Default to Touch ID indefinitely
        return (nil, true)
    }
    
    var timeout: TimeInterval?
    var touchID = true // Universally enabled by default per user request
    
    for arg in args {
        if arg.lowercased() == "touch" || arg == "--touch-id" {
            touchID = true
        } else if let parsedTimeout = Double(arg) {
            timeout = parsedTimeout
        } else {
            print("Error: Unknown argument '\\(arg)'\\n")
            printUsage()
            exit(1)
        }
    }
    
    return (timeout, touchID)
}

let (timeout, touchID) = parseArguments()

// Setup Signal Handling for graceful exit
// OS Resource Protected: We catch SIGINT and SIGTERM to guarantee that the kernel
// resources (the event tap Mach port) are released before the process dies.
let signalQueue = DispatchQueue(label: "com.maclean.signals", qos: .userInitiated)
let sigtermSource = DispatchSource.makeSignalSource(signal: SIGTERM, queue: signalQueue)
let sigintSource = DispatchSource.makeSignalSource(signal: SIGINT, queue: signalQueue)

// Ignore default signal behavior so our handlers run
signal(SIGTERM, SIG_IGN)
signal(SIGINT, SIG_IGN)

// Core setup
let eventTapManager = EventTapManager()
let unlockCoordinator = UnlockCoordinator()
let watchdogManager = WatchdogManager()

let actor = BlockingSessionActor(
    eventTapManager: eventTapManager,
    unlockCoordinator: unlockCoordinator,
    watchdogManager: watchdogManager
)

sigtermSource.setEventHandler {
    Task {
        await actor.stopBlocking()
        print("\nReceived SIGTERM. Exiting safely.")
        exit(0)
    }
}
sigtermSource.resume()

sigintSource.setEventHandler {
    Task {
        await actor.stopBlocking()
        print("\nReceived SIGINT. Exiting safely.")
        exit(0)
    }
}
sigintSource.resume()

// Start the session securely
Task {
    do {
        try await actor.startBlocking(timeout: timeout, requireTouchID: touchID)
        
        let start = Date()
        let chars = ["⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏"]
        var spinnerIndex = 0
        
        print("Emergency Unlock: Press Control + Option + Command + Escape.\n")
        
        // Polling loop to draw the interactive UI element
        while await actor.isBlocking {
            let elapsed = Date().timeIntervalSince(start)
            var timeStr = ""
            if let activeTimeout = timeout {
                let remaining = max(0, Int(activeTimeout - elapsed))
                timeStr = " [\(remaining)s remaining]"
            } else if touchID {
                timeStr = " [Waiting for Touch ID]"
            }
            
            // Move cursor to start of line, clear it, then render
            print("\r\u{1B}[K\(chars[spinnerIndex % chars.count]) Cleaning mode active.\(timeStr)", terminator: "")
            fflush(stdout)
            spinnerIndex += 1
            
            try await Task.sleep(nanoseconds: 100_000_000)
        }
        
        print("\n\u{2728} Maclean session ended cleanly. Input restored.")
        exit(0)
    } catch {
        print("\nError: \(error.localizedDescription)")
        exit(1)
    }
}

// Ensure the main thread stays alive so CLI doesn't exit instantly
RunLoop.main.run()
