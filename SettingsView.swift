import SwiftUI
import ServiceManagement

struct SettingsView: View {
    @AppStorage("defaultSaveDirectory") private var defaultSaveDirectory: String = ""
    @AppStorage("askToSave") private var askToSave: Bool = false
    @AppStorage("launchAtLogin") private var launchAtLogin: Bool = false
    @AppStorage("useCustomYouTubeApp") private var useCustomYouTubeApp: Bool = false
    @AppStorage("customYouTubeAppPath") private var customYouTubeAppPath: String = ""
    
    @State private var message: String = ""
    @State private var showPermissionAlert = false
    @State private var lastError = ""

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
                            Toggle("Always ask where to save", isOn: $askToSave)
                                .toggleStyle(.switch)
                                .font(.system(size: 13))
                            
                            if !askToSave {
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("Default Directory")
                                            .font(.system(size: 11))
                                            .foregroundColor(.secondary)
                                        
                                        if defaultSaveDirectory.isEmpty {
                                            Text("Desktop")
                                                .font(.system(size: 13, weight: .medium))
                                                .foregroundColor(.secondary)
                                        } else {
                                            Text(URL(fileURLWithPath: defaultSaveDirectory).lastPathComponent)
                                                .font(.system(size: 13, weight: .medium))
                                                .lineLimit(1)
                                        }
                                    }
                                    
                                    Spacer()
                                    
                                    Button(action: selectDirectory) {
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
                            get: { launchAtLogin },
                            set: { newValue in
                                launchAtLogin = newValue
                                toggleLaunchAtLogin(enabled: newValue)
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
                            Toggle("Open YouTube in specific app", isOn: $useCustomYouTubeApp)
                                .toggleStyle(.switch)
                                .font(.system(size: 13))
                            
                            if useCustomYouTubeApp {
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("Application")
                                            .font(.system(size: 11))
                                            .foregroundColor(.secondary)
                                        
                                        if customYouTubeAppPath.isEmpty {
                                            Text("No App Selected")
                                                .font(.system(size: 13, weight: .medium))
                                                .foregroundColor(.red)
                                        } else {
                                            Text(URL(fileURLWithPath: customYouTubeAppPath).deletingPathExtension().lastPathComponent)
                                                .font(.system(size: 13, weight: .medium))
                                                .lineLimit(1)
                                        }
                                    }
                                    
                                    Spacer()
                                    
                                    Button(action: selectYouTubeApp) {
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
                
                    if !message.isEmpty {
                        Text(message)
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
        .alert(isPresented: $showPermissionAlert) {
            Alert(
                title: Text("Permission Error"),
                message: Text("L1nK failed to save the file.\n\n\(lastError)\n\nPlease ensure L1nK has access to your files in System Settings > Privacy & Security > Files and Folders."),
                primaryButton: .default(Text("Open Settings"), action: {
                    if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_FilesAndFolders") {
                        NSWorkspace.shared.open(url)
                    }
                }),
                secondaryButton: .cancel()
            )
        }
    }
    
    func toggleLaunchAtLogin(enabled: Bool) {
        if #available(macOS 13.0, *) {
            do {
                if enabled {
                    try SMAppService.mainApp.register()
                } else {
                    try SMAppService.mainApp.unregister()
                }
                message = enabled ? "Launch at login enabled" : "Launch at login disabled"
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    message = ""
                }
            } catch {
                print("Failed to toggle login item: \(error)")
                message = "Failed to update login setting."
            }
        } else {
            message = "Launch at login requires macOS 13+"
        }
    }
    
    func selectDirectory() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true
        
        panel.begin { response in
            if response == .OK {
                defaultSaveDirectory = panel.url?.path ?? ""
            }
        }
    }
    
    func selectYouTubeApp() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.application]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        
        panel.begin { response in
            if response == .OK, let url = panel.url {
                customYouTubeAppPath = url.path
            }
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
