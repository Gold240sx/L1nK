import SwiftUI
import UniformTypeIdentifiers
import LinkPresentation
import ServiceManagement

struct ContentView: View {
    @AppStorage("defaultSaveDirectory") private var defaultSaveDirectory: String = ""
    @AppStorage("askToSave") private var askToSave: Bool = false
    @AppStorage("launchAtLogin") private var launchAtLogin: Bool = false
    @AppStorage("useCustomYouTubeApp") private var useCustomYouTubeApp: Bool = false
    @AppStorage("customYouTubeAppPath") private var customYouTubeAppPath: String = ""
    
    @State private var message: String = "Use the Menu Bar icon to interact."
    @State private var isProcessing = false
    
    @State private var showPermissionAlert = false
    @State private var lastError = ""

    var body: some View {
        VStack(spacing: 20) {
            Image(nsImage: NSImage(named: "AppIcon") ?? NSImage(systemSymbolName: "link.circle.fill", accessibilityDescription: nil)!)
                .resizable()
                .frame(width: 60, height: 60)
                .foregroundColor(.blue)
            
            Text("L1nK Settings")
                .font(.headline)
            
            Divider()
            
            // Save Settings
            VStack(alignment: .leading, spacing: 10) {
                Toggle("Always ask where to save", isOn: $askToSave)
                    .toggleStyle(.switch)
                
                if !askToSave {
                    HStack {
                        Text("Default:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        if defaultSaveDirectory.isEmpty {
                            Text("Desktop (Default)")
                                .font(.caption)
                                .italic()
                        } else {
                            Text(URL(fileURLWithPath: defaultSaveDirectory).lastPathComponent)
                                .font(.caption)
                                .fontWeight(.medium)
                                .truncationMode(.middle)
                        }
                        
                        Spacer()
                        
                        Button("Change...") {
                            selectDirectory()
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                }
            }
            .padding()
            .background(Color.secondary.opacity(0.1))
            .cornerRadius(8)
            
            // Startup Settings
            VStack(alignment: .leading) {
                Toggle("Launch at Login", isOn: Binding(
                    get: { launchAtLogin },
                    set: { newValue in
                        launchAtLogin = newValue
                        toggleLaunchAtLogin(enabled: newValue)
                    }
                ))
                .toggleStyle(.switch)
            }
            .padding()
            .background(Color.secondary.opacity(0.1))
            .cornerRadius(8)
            
            // YouTube Settings
            VStack(alignment: .leading, spacing: 10) {
                Toggle("Open YouTube in specific app", isOn: $useCustomYouTubeApp)
                    .toggleStyle(.switch)
                
                if useCustomYouTubeApp {
                    HStack {
                        if customYouTubeAppPath.isEmpty {
                            Text("No App Selected")
                                .font(.caption)
                                .italic()
                                .foregroundColor(.red)
                        } else {
                            // Show app icon/name? Just name for now
                            Text(URL(fileURLWithPath: customYouTubeAppPath).deletingPathExtension().lastPathComponent)
                                .font(.caption)
                                .fontWeight(.medium)
                        }
                        
                        Spacer()
                        
                        Button("Choose App...") {
                            selectYouTubeApp()
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                }
            }
            .padding()
            .background(Color.secondary.opacity(0.1))
            .cornerRadius(8)

            Divider()

            Button(action: {
                createFromClipboard()
            }) {
                HStack {
                    if isProcessing {
                        ProgressView()
                            .controlSize(.small)
                    }
                    Text("Create L1nk from Clipboard")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(isProcessing)
            
            Text(message)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Divider()
            
            Button("Quit L1nk") {
                NSApplication.shared.terminate(nil)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .foregroundColor(.secondary)
        }
        .padding()
        .frame(width: 320)
        .alert(isPresented: $showPermissionAlert) {
            Alert(
                title: Text("Permission Error"),
                message: Text("L1nK failed to save the file.\n\n\(lastError)\n\nPlease insure L1nK has access to your files in System Settings > Privacy & Security > Files and Folders."),
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
    
    func createFromClipboard() {
        guard let clipboardString = NSPasteboard.general.string(forType: .string) else {
            message = "Clipboard is empty!"
            return
        }
        
        let trimmed = clipboardString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: trimmed), url.scheme != nil else {
            message = "Clipboard does not contain a valid URL."
            return
        }
        
        isProcessing = true
        message = "Fetching info..."
        
        // Fetch Title if YouTube
        fetchTitle(for: url) { title in
            DispatchQueue.main.async {
                self.finalizeCreation(url: url, title: title)
            }
        }
    }
    
    func finalizeCreation(url: URL, title: String?) {
        let filename: String
        
        let isYouTube = self.isYouTube(url: url)
        let isGitHub = self.isGitHub(url: url)
        let isAppStore = self.isAppStore(url: url)
        let isVimeo = self.isVimeo(url: url)
        
        if isYouTube, let title = title {
            // Sanitize filename
            let safeTitle = title.components(separatedBy: .init(charactersIn: "/\\:?%*|\"<>")).joined()
            filename = "YT-\(safeTitle).l1nk"
        } else if isVimeo, let title = title {
             // Sanitize filename for Vimeo
            let safeTitle = title.components(separatedBy: .init(charactersIn: "/\\:?%*|\"<>")).joined()
            filename = "Vimeo-\(safeTitle).l1nk"
        } else if isGitHub {
            // Extract project name from URL: github.com/owner/repo -> repo
            let components = url.pathComponents
            if components.count >= 3 {
                // components[0] is "/", [1] is owner, [2] is repo
                filename = components[2] + ".l1nk"
            } else if components.count >= 2 {
                 filename = components[1] + ".l1nk"
            } else {
                filename = "GitHub.l1nk"
            }
        } else if isAppStore {
            // Extract app name: apps.apple.com/region/app/name/id123
            // Usually the name is the component before the last one (id)
            let name = url.deletingLastPathComponent().lastPathComponent
            if !name.isEmpty && name != "app" {
                 filename = name + ".l1nk"
            } else {
                filename = "AppStore.l1nk"
            }
        } else {
            filename = (url.host ?? "link") + ".l1nk"
        }
        
        let content = url.absoluteString
        
        let iconType: IconType
        if isYouTube { iconType = .youtube }
        else if isGitHub { iconType = .github }
        else if isAppStore { iconType = .appstore }
        else if isVimeo { iconType = .vimeo }
        else { iconType = .none }
        
        if askToSave {
            // Ensure app is active before showing dialog
            NSApp.activate(ignoringOtherApps: true)
            saveWithDialog(filename: filename, content: content, iconType: iconType)
        } else {
            saveToDefault(filename: filename, content: content, iconType: iconType)
        }
    }
    
    enum IconType {
        case none, youtube, github, appstore, vimeo
    }
    
    func isYouTube(url: URL) -> Bool {
        return url.host?.contains("youtube.com") == true || url.host?.contains("youtu.be") == true
    }
    
    func isVimeo(url: URL) -> Bool {
        return url.host?.contains("vimeo.com") == true
    }
    
    func isGitHub(url: URL) -> Bool {
        return url.host?.contains("github.com") == true
    }
    
    func isAppStore(url: URL) -> Bool {
        return url.host?.contains("apps.apple.com") == true
    }
    
    func saveWithDialog(filename: String, content: String, iconType: IconType) {
        let savePanel = NSSavePanel()
        savePanel.nameFieldStringValue = filename
        savePanel.allowedContentTypes = [UTType(exportedAs: "com.yourcompany.l1nk")]
        savePanel.canCreateDirectories = true
        
        // If we have a default directory, verify it exists before setting it
        if !defaultSaveDirectory.isEmpty {
            let defaultUrl = URL(fileURLWithPath: defaultSaveDirectory)
            // Check if directory exists
            var isDir: ObjCBool = false
            if FileManager.default.fileExists(atPath: defaultSaveDirectory, isDirectory: &isDir), isDir.boolValue {
                savePanel.directoryURL = defaultUrl
            }
        }
        
        savePanel.begin { response in
            self.isProcessing = false
            if response == .OK, let targetURL = savePanel.url {
                do {
                    try content.write(to: targetURL, atomically: true, encoding: .utf8)
                    applyIcon(type: iconType, to: targetURL)
                    message = "Saved!"
                    // Close popover?
                } catch {
                    lastError = error.localizedDescription
                    showPermissionAlert = true
                    message = "Error: \(error.localizedDescription)"
                }
            } else {
                message = "Cancelled."
            }
        }
    }
    
    func saveToDefault(filename: String, content: String, iconType: IconType) {
        defer { isProcessing = false }
        
        let savePath: String
        if !defaultSaveDirectory.isEmpty {
            savePath = defaultSaveDirectory
        } else {
            savePath = FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first!.path
        }
        
        let fileURL = URL(fileURLWithPath: savePath).appendingPathComponent(filename)
        // Avoid overwrite logic could be here, but simple overwrite for now or unique?
        // Let's make unique to be safe
        let uniqueURL = generateUniqueURL(for: fileURL)
        
        do {
            try content.write(to: uniqueURL, atomically: true, encoding: .utf8)
            applyIcon(type: iconType, to: uniqueURL)
            message = "Saved to: \(uniqueURL.lastPathComponent)"
        } catch {
            lastError = error.localizedDescription
            showPermissionAlert = true
            message = "Error: \(error.localizedDescription)"
        }
    }
    
    func applyIcon(type: IconType, to url: URL) {
        var iconName: String?
        switch type {
        case .youtube: iconName = "YouTubeIcon"
        case .github: iconName = "GitHubIcon"
        case .appstore: iconName = "AppStoreIcon"
        case .vimeo: iconName = "VimeoIcon"
        case .none: return
        }
        
        if let name = iconName, let iconImage = NSImage(named: name) {
            NSWorkspace.shared.setIcon(iconImage, forFile: url.path)
        }
    }
    
    private func generateUniqueURL(for url: URL) -> URL {
        var newURL = url
        var counter = 1
        let ext = newURL.pathExtension
        let base = newURL.deletingPathExtension().path
        
        while FileManager.default.fileExists(atPath: newURL.path) {
            newURL = URL(fileURLWithPath: "\(base) \(counter).\(ext)")
            counter += 1
        }
        return newURL
    }
    
    func fetchTitle(for url: URL, completion: @escaping (String?) -> Void) {
        // Only try fetching for YouTube or similar if previously logic restricted it. 
        // Or honestly, just fetch for ALL links? The user specifically asked for YouTube.
        // Let's stick to the user request or be broad?
        // LPMetadataProvider is good for everything. Let's use it generally if it's a valid URL.
        guard url.host?.contains("youtube.com") == true || url.host?.contains("youtu.be") == true else {
            completion(nil)
            return
        }
        
        let provider = LPMetadataProvider()
        provider.startFetchingMetadata(for: url) { metadata, error in
            if let title = metadata?.title {
                // Remove " - YouTube" if present, common suffix
                var cleanTitle = title.replacingOccurrences(of: " - YouTube", with: "")
                completion(cleanTitle)
            } else {
                print("LPMetadataProvider failed: \(String(describing: error))")
                // Fallback to manual scraping if needed, or just return nil
                self.scrapeTitle(for: url, completion: completion)
            }
        }
    }
    
    func scrapeTitle(for url: URL, completion: @escaping (String?) -> Void) {
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.114 Safari/537.36", forHTTPHeaderField: "User-Agent")
        
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            guard let data = data, let html = String(data: data, encoding: .utf8) else {
                completion(nil)
                return
            }
            
            if let regex = try? NSRegularExpression(pattern: "<title>(.*?)</title>", options: .caseInsensitive),
               let match = regex.firstMatch(in: html, options: [], range: NSRange(location: 0, length: html.count)) {
                
                if let range = Range(match.range(at: 1), in: html) {
                    var title = String(html[range])
                    title = title.replacingOccurrences(of: "&#x22;", with: "\"")
                        .replacingOccurrences(of: "&quot;", with: "\"")
                        .replacingOccurrences(of: "&amp;", with: "&")
                        .replacingOccurrences(of: " - YouTube", with: "")
                    completion(title)
                    return
                }
            }
            completion(nil)
        }
        task.resume()
    }
}

