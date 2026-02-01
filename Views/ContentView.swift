import SwiftUI
import AppKit

struct ContentView: View {
    @StateObject private var viewModel = ContentViewModel()
    @StateObject private var proManager = ProManager.shared
    @State private var selectedTab: ContentTab = .main

    enum ContentTab {
        case main
        case pro
    }

    var body: some View {
        VStack(spacing: 0) {
            // Tab selector
            HStack(spacing: 0) {
                TabButton(
                    title: "Main",
                    icon: "link",
                    isSelected: selectedTab == .main,
                    action: { selectedTab = .main }
                )
                
                TabButton(
                    title: "Pro",
                    icon: "star.fill",
                    isSelected: selectedTab == .pro,
                    action: { selectedTab = .pro }
                )
            }
            .padding(.horizontal, 8)
            .padding(.top, 8)
            
            // Content based on selected tab
            if selectedTab == .main {
                mainContentView
            } else {
                ProFeaturesView()
            }
        }
    }
    
    private var mainContentView: some View {
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
                    
                    Group {
                        if let appIcon = NSImage(named: "AppIconDefault")
                            ?? NSImage(named: "AppIconDisplay")
                            ?? NSImage(named: "AppIcon") {
                            Image(nsImage: appIcon)
                                .resizable()
                                .frame(width: 64, height: 64)
                        } else {
                            let bundleIcon = NSWorkspace.shared.icon(forFile: Bundle.main.bundlePath)
                            Image(nsImage: bundleIcon)
                                .resizable()
                                .frame(width: 64, height: 64)
                        }
                    }
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
                
                // Status message and Show in Finder button
                if !viewModel.message.isEmpty || viewModel.showFinderButton {
                    VStack(spacing: 10) {
                        if !viewModel.message.isEmpty {
                            Text(viewModel.message)
                                .font(.system(size: 12))
                                .foregroundColor(viewModel.message.contains("✓") ? .green : .secondary)
                                .multilineTextAlignment(.center)
                        }
                        
                        if viewModel.showFinderButton {
                            Button(action: { viewModel.showInFinder() }) {
                                HStack(spacing: 6) {
                                    Image(systemName: "folder")
                                        .font(.system(size: 11))
                                    Text("Show in Finder")
                                        .font(.system(size: 12, weight: .medium))
                                }
                                .foregroundColor(.blue)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(
                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(Color.blue.opacity(0.1))
                                )
                            }
                            .buttonStyle(.plain)
                            .transition(.opacity.combined(with: .move(edge: .top)))
                        }
                    }
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

struct TabButton: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .medium))
                Text(title)
                    .font(.system(size: 13, weight: .medium))
            }
            .frame(maxWidth: .infinity)
            .frame(height: 32)
            .background {
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? Color.blue.opacity(0.15) : Color.clear)
            }
            .foregroundColor(isSelected ? .blue : .secondary)
        }
        .buttonStyle(.plain)
    }
}
