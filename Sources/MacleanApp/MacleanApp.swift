import SwiftUI
import AppKit

@main
struct MacleanApp: App {
    @StateObject private var appState = MacleanAppState()

    init() {
        // Run as an accessory app (menu bar only, no Dock icon)
        // This is necessary because SwiftUI Apps don't automatically hide from the Dock
        // unless LSUIElement is set in an Info.plist, but doing it programmatically
        // allows us to remain fully contained within Swift Package Manager.
        NSApplication.shared.setActivationPolicy(.accessory)
    }

    var body: some Scene {
        MenuBarExtra("Maclean", systemImage: appState.isBlocking ? "keyboard.fill" : "keyboard") {
            PopoverView()
                .environmentObject(appState)
        }
        .menuBarExtraStyle(.window) // Enables arbitrary SwiftUI views rather than strict menus
    }
}
