import SwiftUI

struct PopoverView: View {
    @EnvironmentObject var appState: MacleanAppState
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Maclean")
                .font(.title)
                .fontWeight(.bold)
            
            if appState.permissionError {
                VStack(spacing: 12) {
                    Text("Accessibility Required")
                        .font(.headline)
                        .foregroundColor(.red)
                    Text("Maclean needs Accessibility access to block input. Please grant it in System Settings -> Privacy & Security -> Accessibility, then try again.")
                        .font(.caption)
                        .multilineTextAlignment(.center)
                    
                    Button("Open System Settings") {
                        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                            NSWorkspace.shared.open(url)
                        }
                    }
                    
                    Button("I've granted access") {
                        appState.permissionError = false
                    }
                    .buttonStyle(.link)
                    .font(.caption)
                }
                .padding()
                .background(Color.red.opacity(0.1))
                .cornerRadius(8)
            }
            
            if appState.isBlocking {
                VStack(spacing: 16) {
                    Text("Cleaning Mode Active")
                        .font(.headline)
                        .foregroundColor(.green)
                    
                    if appState.timeLimit > 0 {
                        Text("\(appState.timeRemaining)s")
                            .font(.system(size: 48, weight: .black, design: .rounded))
                    } else if appState.enableTouchID {
                        Text("Waiting for Touch ID")
                            .font(.headline)
                    }
                    
                    Text("Emergency Unlock: L-Shift + R-Shift + Escape")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            } else {
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Duration: \(Int(appState.timeLimit)) seconds")
                            .font(.subheadline)
                        Slider(value: $appState.timeLimit, in: 0...300, step: 10)
                    }
                    
                    Toggle("Require Touch ID to Unlock", isOn: $appState.enableTouchID)
                    
                    Button {
                        appState.startCleaning()
                    } label: {
                        Text("Start Cleaning")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    
                    Divider()
                    
                    Button("Quit Maclean") {
                        NSApplication.shared.terminate(nil)
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(.secondary)
                    .font(.caption)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                }
            }
        }
        .padding()
        .frame(width: 320)
    }
}
