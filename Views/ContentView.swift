import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = ContentViewModel()

    var body: some View {
        VStack(spacing: 0) {
            // Main content area
            VStack(spacing: 28) {
                Spacer()
                
                // Icon with gradient
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [.blue.opacity(0.2), .purple.opacity(0.2)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 100, height: 100)
                        .blur(radius: 20)
                    
                    Image(nsImage: NSImage(named: "AppIcon") ?? NSImage(systemSymbolName: "link.circle.fill", accessibilityDescription: nil)!)
                        .resizable()
                        .frame(width: 64, height: 64)
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.blue, .purple],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
                
                // Title
                VStack(spacing: 6) {
                    Text("L1nK")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.blue, .purple],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                    
                    Text("Create link files from your clipboard")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                }
                
                // Create button
                Button(action: { viewModel.createFromClipboard() }) {
                    HStack(spacing: 10) {
                        if viewModel.isProcessing {
                            ProgressView()
                                .controlSize(.small)
                                .progressViewStyle(.circular)
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: "link.badge.plus")
                                .font(.system(size: 14, weight: .semibold))
                        }
                        
                        Text(viewModel.isProcessing ? "Creating..." : "Create from Clipboard")
                            .font(.system(size: 15, weight: .semibold))
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .background {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(
                                LinearGradient(
                                    colors: viewModel.isProcessing ? [.gray.opacity(0.3), .gray.opacity(0.2)] : [.blue, .purple],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .shadow(color: viewModel.isProcessing ? .clear : .blue.opacity(0.3), radius: 8, x: 0, y: 4)
                    }
                    .foregroundColor(.white)
                }
                .buttonStyle(.plain)
                .disabled(viewModel.isProcessing)
                .padding(.horizontal, 32)
                
                // Status message
                if !viewModel.message.isEmpty {
                    Text(viewModel.message)
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                        .transition(.opacity.combined(with: .scale(scale: 0.95)))
                }
                
                Spacer()
            }
            .frame(width: 360, height: 420)
            
            // Bottom bar with buttons
            HStack(spacing: 0) {
                Button(action: {
                    // Show settings window
                    NotificationCenter.default.post(name: NSNotification.Name("ShowSettings"), object: nil)
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "gearshape.fill")
                            .font(.system(size: 12))
                        Text("Settings")
                            .font(.system(size: 13, weight: .medium))
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 40)
                    .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                
                Divider()
                    .frame(height: 20)
                
                Button(action: {
                    NSApplication.shared.terminate(nil)
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 12))
                        Text("Quit")
                            .font(.system(size: 13, weight: .medium))
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 40)
                    .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .background(Color(nsColor: .separatorColor).opacity(0.1))
        }
        .alert(isPresented: $viewModel.showPermissionAlert) {
            Alert(
                title: Text("Permission Error"),
                message: Text("L1nK failed to save the file.\n\n\(viewModel.lastError)\n\nPlease ensure L1nK has access to your files in System Settings > Privacy & Security > Files and Folders."),
                primaryButton: .default(Text("Open Settings"), action: {
                    if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_FilesAndFolders") {
                        NSWorkspace.shared.open(url)
                    }
                }),
                secondaryButton: .cancel()
            )
        }
    }
}
