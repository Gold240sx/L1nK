import SwiftUI
import UniformTypeIdentifiers
import LinkPresentation

struct ContentView: View {
    @AppStorage("defaultSaveDirectory") private var defaultSaveDirectory: String = ""
    @AppStorage("askToSave") private var askToSave: Bool = false
    
    @State private var message: String = ""
    @State private var isProcessing = false
    @State private var showPermissionAlert = false
    @State private var lastError = ""

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
                Button(action: createFromClipboard) {
                    HStack(spacing: 10) {
                        if isProcessing {
                            ProgressView()
                                .controlSize(.small)
                                .progressViewStyle(.circular)
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: "link.badge.plus")
                                .font(.system(size: 14, weight: .semibold))
                        }
                        
                        Text(isProcessing ? "Creating..." : "Create from Clipboard")
                            .font(.system(size: 15, weight: .semibold))
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .background {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(
                                LinearGradient(
                                    colors: isProcessing ? [.gray.opacity(0.3), .gray.opacity(0.2)] : [.blue, .purple],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .shadow(color: isProcessing ? .clear : .blue.opacity(0.3), radius: 8, x: 0, y: 4)
                    }
                    .foregroundColor(.white)
                }
                .buttonStyle(.plain)
                .disabled(isProcessing)
                .padding(.horizontal, 32)
                
                // Status message
                if !message.isEmpty {
                    Text(message)
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
    
    func createFromClipboard() {
        guard let clipboardString = NSPasteboard.general.string(forType: .string) else {
            withAnimation {
                message = "Clipboard is empty!"
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                withAnimation {
                    message = ""
                }
            }
            return
        }
        
        let trimmed = clipboardString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: trimmed), url.scheme != nil else {
            withAnimation {
                message = "Clipboard does not contain a valid URL."
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                withAnimation {
                    message = ""
                }
            }
            return
        }
        
        isProcessing = true
        withAnimation {
            message = "Fetching info..."
        }
        
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
            let safeTitle = title.components(separatedBy: .init(charactersIn: "/\\:?%*|\"<>")).joined()
            filename = "YT-\(safeTitle).l1nk"
        } else if isVimeo, let title = title {
            let safeTitle = title.components(separatedBy: .init(charactersIn: "/\\:?%*|\"<>")).joined()
            filename = "Vimeo-\(safeTitle).l1nk"
        } else if isGitHub {
            let components = url.pathComponents
            if components.count >= 3 {
                filename = components[2] + ".l1nk"
            } else if components.count >= 2 {
                filename = components[1] + ".l1nk"
            } else {
                filename = "GitHub.l1nk"
            }
        } else if isAppStore {
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
        
        if !defaultSaveDirectory.isEmpty {
            let defaultUrl = URL(fileURLWithPath: defaultSaveDirectory)
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
                    withAnimation {
                        self.message = "✓ Saved!"
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        withAnimation {
                            self.message = ""
                        }
                    }
                } catch {
                    self.lastError = error.localizedDescription
                    self.showPermissionAlert = true
                    withAnimation {
                        self.message = "Error: \(error.localizedDescription)"
                    }
                }
            } else {
                self.isProcessing = false
                withAnimation {
                    self.message = "Cancelled."
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                    withAnimation {
                        self.message = ""
                    }
                }
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
        let uniqueURL = generateUniqueURL(for: fileURL)
        
        do {
            try content.write(to: uniqueURL, atomically: true, encoding: .utf8)
            applyIcon(type: iconType, to: uniqueURL)
            withAnimation {
                message = "✓ Saved to: \(uniqueURL.lastPathComponent)"
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                withAnimation {
                    message = ""
                }
            }
        } catch {
            lastError = error.localizedDescription
            showPermissionAlert = true
            withAnimation {
                message = "Error: \(error.localizedDescription)"
            }
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
        guard url.host?.contains("youtube.com") == true || url.host?.contains("youtu.be") == true else {
            completion(nil)
            return
        }
        
        let provider = LPMetadataProvider()
        provider.startFetchingMetadata(for: url) { metadata, error in
            if let title = metadata?.title {
                let cleanTitle = title.replacingOccurrences(of: " - YouTube", with: "")
                completion(cleanTitle)
            } else {
                print("LPMetadataProvider failed: \(String(describing: error))")
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
                    let title = String(html[range])
                        .replacingOccurrences(of: "&#x22;", with: "\"")
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
