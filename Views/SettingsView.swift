import SwiftUI
import AppKit

struct SettingsView: View {
    @StateObject private var viewModel = SettingsViewModel()
    
    var body: some View {
        VStack(spacing: 0) {
            // Close button in top right
            HStack {
                Spacer()
                Button(action: {
                    // Post notification to close settings window
                    NotificationCenter.default.post(name: NSNotification.Name("CloseSettingsWindow"), object: nil)
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 18))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .help("Close Settings")
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 8) {
                        // App Icon
                        Group {
                            if let appIcon = NSImage(named: "AppIconDefault")
                                ?? NSImage(named: "AppIconDisplay")
                                ?? NSImage(named: "AppIcon") {
                                Image(nsImage: appIcon)
                                    .resizable()
                                    .frame(width: 64, height: 64)
                            } else {
                                // Fallback to bundle icon or SF Symbol
                                let bundleIcon = NSWorkspace.shared.icon(forFile: Bundle.main.bundlePath)
                                Image(nsImage: bundleIcon)
                                    .resizable()
                                    .frame(width: 64, height: 64)
                            }
                        }
                        
                        Text("L1nK Settings")
                            .font(.system(size: 24, weight: .semibold, design: .rounded))
                            .foregroundColor(.primary)
                        
                        // Version and Update Status
                        VStack(spacing: 6) {
                            Text("Version \(viewModel.appVersion)")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                            
                            if viewModel.hasUpdateAvailable {
                                HStack(spacing: 6) {
                                    Image(systemName: "arrow.down.circle.fill")
                                        .font(.system(size: 11))
                                        .foregroundColor(.green)
                                    Text("Update Available")
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundColor(.green)
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background {
                                    Capsule()
                                        .fill(Color.green.opacity(0.15))
                                }
                            }
                        }
                        .padding(.top, 4)
                    }
                    .padding(.top, 8)
                
                // All settings sections wrapped in rounded background
                VStack(alignment: .leading, spacing: 20) {
                    // Save Settings Section
                    SettingsSectionContent(title: "Save Location") {
                        VStack(alignment: .leading, spacing: 12) {
                            Toggle("Always ask where to save", isOn: $viewModel.askToSave)
                                .toggleStyle(.switch)
                                .font(.system(size: 13))
                            
                            if !viewModel.askToSave {
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("Default Directory")
                                            .font(.system(size: 11))
                                            .foregroundColor(.secondary)
                                        
                                        if viewModel.defaultSaveDirectory.isEmpty {
                                            Text("Desktop")
                                                .font(.system(size: 13, weight: .medium))
                                                .foregroundColor(.secondary)
                                        } else {
                                            Text(URL(fileURLWithPath: viewModel.defaultSaveDirectory).lastPathComponent)
                                                .font(.system(size: 13, weight: .medium))
                                                .lineLimit(1)
                                        }
                                    }
                                    
                                    Spacer()
                                    
                                    Button(action: { viewModel.selectDirectory() }) {
                                        Text("Change")
                                            .font(.system(size: 12, weight: .medium))
                                    }
                                    .buttonStyle(.bordered)
                                    .controlSize(.small)
                                }
                                .padding(.top, 4)
                            }
                        }
                    }
                    
                    Divider()
                        .padding(.horizontal, 16)
                    
                    // Startup Settings Section
                    SettingsSectionContent(title: "Startup") {
                        Toggle("Launch at Login", isOn: Binding(
                            get: { viewModel.launchAtLogin },
                            set: { newValue in
                                viewModel.launchAtLogin = newValue
                                viewModel.toggleLaunchAtLogin(enabled: newValue)
                            }
                        ))
                        .toggleStyle(.switch)
                        .font(.system(size: 13))
                    }
                    
                    Divider()
                        .padding(.horizontal, 16)
                    
                    // Updates Settings Section
                    SettingsSectionContent(title: "Updates") {
                        VStack(alignment: .leading, spacing: 12) {
                            Button(action: { viewModel.checkForUpdates() }) {
                                HStack {
                                    if viewModel.isCheckingForUpdates {
                                        ProgressView()
                                            .scaleEffect(0.7)
                                            .frame(width: 12, height: 12)
                                    } else {
                                        Image(systemName: "arrow.clockwise")
                                            .font(.system(size: 12))
                                    }
                                    Text("Check for Updates")
                                        .font(.system(size: 13))
                                }
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                            .disabled(viewModel.isCheckingForUpdates)
                            
                            // Update status message
                            if viewModel.updateStatus != .idle {
                                Group {
                                    switch viewModel.updateStatus {
                                    case .checking:
                                        Text("Checking for updates...")
                                            .font(.system(size: 11))
                                            .foregroundColor(.secondary)
                                    case .updateAvailable:
                                        Text("Update available!")
                                            .font(.system(size: 11))
                                            .foregroundColor(.green)
                                    case .noUpdateAvailable:
                                        HStack(spacing: 6) {
                                            Image(systemName: "checkmark.circle.fill")
                                                .font(.system(size: 11))
                                                .foregroundColor(.green)
                                            Text("You're up to date!")
                                                .font(.system(size: 11))
                                                .foregroundColor(.green)
                                        }
                                    case .error(let message):
                                        // Check if it's actually a "no update" message disguised as an error
                                        if message.lowercased().contains("up to date") || message.lowercased().contains("latest") {
                                            HStack(spacing: 6) {
                                                Image(systemName: "checkmark.circle.fill")
                                                    .font(.system(size: 11))
                                                    .foregroundColor(.green)
                                                Text("You're up to date!")
                                                    .font(.system(size: 11))
                                                    .foregroundColor(.green)
                                            }
                                        } else {
                                            Text("Error: \(message)")
                                                .font(.system(size: 11))
                                                .foregroundColor(.red)
                                        }
                                    case .idle:
                                        EmptyView()
                                    }
                                }
                                .padding(.top, 4)
                            }
                        }
                    }
                    
                    Divider()
                        .padding(.horizontal, 16)
                    
                    // YouTube Settings Section
                    SettingsSectionContent(title: "YouTube") {
                        VStack(alignment: .leading, spacing: 12) {
                            Toggle("Open YouTube in specific app", isOn: $viewModel.useCustomYouTubeApp)
                                .toggleStyle(.switch)
                                .font(.system(size: 13))
                            
                            if viewModel.useCustomYouTubeApp {
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("Application")
                                            .font(.system(size: 11))
                                            .foregroundColor(.secondary)
                                        
                                        if viewModel.customYouTubeAppPath.isEmpty {
                                            Text("No App Selected")
                                                .font(.system(size: 13, weight: .medium))
                                                .foregroundColor(.red)
                                        } else {
                                            Text(URL(fileURLWithPath: viewModel.customYouTubeAppPath).deletingPathExtension().lastPathComponent)
                                                .font(.system(size: 13, weight: .medium))
                                                .lineLimit(1)
                                        }
                                    }
                                    
                                    Spacer()
                                    
                                    Button(action: { viewModel.selectYouTubeApp() }) {
                                        Text("Choose")
                                            .font(.system(size: 12, weight: .medium))
                                    }
                                    .buttonStyle(.bordered)
                                    .controlSize(.small)
                                }
                                .padding(.top, 4)
                            }
                        }
                    }
                    
                    Divider()
                        .padding(.horizontal, 16)
                    
                    // Icons Section
                    SettingsSectionContent(title: "File Icons") {
                        VStack(alignment: .leading, spacing: 12) {
                            Toggle("Use generic icons (App Store compliant)", isOn: $viewModel.useGenericIcons)
                                .toggleStyle(.switch)
                                .font(.system(size: 13))
                            
                            Text("When enabled, uses SF Symbols instead of branded logos. Required for App Store distribution.")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    
                    Divider()
                        .padding(.horizontal, 16)
                    
                    // Pro Section
                    SettingsSectionContent(title: "Pro") {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Status")
                                        .font(.system(size: 11))
                                        .foregroundColor(.secondary)
                                    
                                    if ProManager.shared.isPro {
                                        HStack(spacing: 6) {
                                            Image(systemName: "checkmark.circle.fill")
                                                .font(.system(size: 12))
                                                .foregroundColor(.green)
                                            Text("Pro Active")
                                                .font(.system(size: 13, weight: .medium))
                                                .foregroundColor(.green)
                                        }
                                    } else {
                                        Text("Free")
                                            .font(.system(size: 13, weight: .medium))
                                            .foregroundColor(.secondary)
                                    }
                                }
                                
                                Spacer()
                                
                                if !ProManager.shared.isPro {
                                    Button(action: {
                                        ProManager.shared.upgradeToPro()
                                    }) {
                                        HStack(spacing: 6) {
                                            Image(systemName: "star.fill")
                                                .font(.system(size: 11))
                                            Text("Upgrade")
                                                .font(.system(size: 12, weight: .medium))
                                        }
                                    }
                                    .buttonStyle(.bordered)
                                    .controlSize(.small)
                                } else {
                                    Button(action: {
                                        ProManager.shared.downgradeFromPro()
                                    }) {
                                        Text("Reset (Dev)")
                                            .font(.system(size: 12, weight: .medium))
                                    }
                                    .buttonStyle(.bordered)
                                    .controlSize(.small)
                                }
                            }
                        }
                    }
                    
                    Divider()
                        .padding(.horizontal, 16)
                    
                    // Reset Welcome Section
                    SettingsSectionContent(title: "Welcome") {
                        Button(action: {
                            UserDefaults.standard.set(false, forKey: "hasSeenWelcome")
                            NotificationCenter.default.post(name: NSNotification.Name("ShowWelcomeWindow"), object: nil)
                        }) {
                            HStack(spacing: 8) {
                                Image(systemName: "arrow.counterclockwise")
                                    .font(.system(size: 12))
                                Text("Show Welcome Screen Again")
                                    .font(.system(size: 13))
                            }
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                }
                .padding(20)
                .background {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color(nsColor: .controlBackgroundColor).opacity(0.1))
                        .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
                }
                
                    if !viewModel.message.isEmpty {
                        Text(viewModel.message)
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                            .padding(.horizontal)
                            .multilineTextAlignment(.center)
                    }
                }
                .padding(20)
            }
            .frame(maxHeight: .infinity)
        }
        .frame(width: 400, height: 550)
        .background(Color.clear)
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("UpdateAvailable"))) { _ in
            viewModel.setUpdateAvailable(true)
            viewModel.updateStatus = .updateAvailable
            viewModel.isCheckingForUpdates = false
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("NoUpdateAvailable"))) { _ in
            viewModel.updateStatus = .noUpdateAvailable
            viewModel.isCheckingForUpdates = false
            // Clear after 3 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                if viewModel.updateStatus == .noUpdateAvailable {
                    viewModel.updateStatus = .idle
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("UpdateCheckError"))) { notification in
            let errorMessage = notification.userInfo?["error"] as? String ?? "Unknown error"
            viewModel.updateStatus = .error(errorMessage)
            viewModel.isCheckingForUpdates = false
            // Clear after 5 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                if case .error = viewModel.updateStatus {
                    viewModel.updateStatus = .idle
                }
            }
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

struct SettingsSectionContent<Content: View>: View {
    let title: String
    let content: Content
    
    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title.uppercased())
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.secondary)
                .kerning(0.5)
            
            content
        }
    }
}


struct GlassBackground: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = .hudWindow
        view.blendingMode = .behindWindow
        view.state = .active
        view.wantsLayer = true
        view.layer?.cornerRadius = 12
        return view
    }
    
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        // No updates needed
    }
}
