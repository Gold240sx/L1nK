import SwiftUI

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
                        
                        Text("L1nK Settings")
                            .font(.system(size: 24, weight: .semibold, design: .rounded))
                            .foregroundColor(.primary)
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
