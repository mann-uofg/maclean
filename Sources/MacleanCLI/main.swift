import Foundation
import MacleanCore

let VERSION = "1.0.0"

func printUsage() {
    let usage = """
    maclean — macOS Input Blocker (\(VERSION))

    USAGE:
      maclean --time <seconds>       # Block for N seconds, then auto-unblock
      maclean --touch-id             # Block until Touch ID verified
      maclean --time 30 --touch-id   # Touch ID OR timeout, whichever comes first
      maclean --help                 # Usage instructions
      maclean --version              # Print version

    EXAMPLES:
      maclean --time 60
      maclean --touch-id
    """
    print(usage)
}

func parseArguments() -> (timeout: TimeInterval?, touchID: Bool) {
    let args = CommandLine.arguments.dropFirst()
    
    if args.contains("--help") || args.contains("-h") {
        printUsage()
        exit(0)
    }
    
    if args.contains("--version") || args.contains("-v") {
        print("maclean version \(VERSION)")
        exit(0)
    }
    
    var timeout: TimeInterval?
    var touchID = false
    
    var argsIterator = args.makeIterator()
    while let arg = argsIterator.next() {
        switch arg {
        case "--time":
            if let val = argsIterator.next(), let parsedTimeout = Double(val) {
                timeout = parsedTimeout
            } else {
                print("Error: --time requires a numeric value in seconds.")
                exit(1)
            }
        case "--touch-id":
            touchID = true
        default:
            print("Error: Unknown argument '\(arg)'")
            printUsage()
            exit(1)
        }
    }
    
    if timeout == nil && !touchID {
        print("Error: You must specify --time or --touch-id (or both).")
        printUsage()
        exit(1)
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
        
        print("Emergency Unlock: Press Left Shift + Right Shift + Escape at any time.\n")
        
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
