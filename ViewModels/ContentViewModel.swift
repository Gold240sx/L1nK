import SwiftUI
import Foundation
import UniformTypeIdentifiers

class ContentViewModel: ObservableObject {
    @AppStorage("defaultSaveDirectory") var defaultSaveDirectory: String = ""
    @AppStorage("askToSave") var askToSave: Bool = false
    
    @Published var message: String = ""
    @Published var isProcessing: Bool = false
    @Published var showPermissionAlert: Bool = false
    @Published var lastError: String = ""
    
    private let linkService = LinkService.shared
    private let iconService = IconService.shared
    
    func createFromClipboard() {
        guard let clipboardString = NSPasteboard.general.string(forType: .string) else {
            withAnimation {
                message = "Clipboard is empty!"
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                withAnimation {
                    self.message = ""
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
                    self.message = ""
                }
            }
            return
        }
        
        isProcessing = true
        withAnimation {
            message = "Fetching info..."
        }
        
        // Fetch Title if YouTube/Vimeo
        linkService.fetchTitle(for: url) { [weak self] title in
            DispatchQueue.main.async {
                self?.finalizeCreation(url: url, title: title)
            }
        }
    }
    
    private func finalizeCreation(url: URL, title: String?) {
        let filename = linkService.generateFilename(for: url, title: title)
        let iconType = linkService.detectIconType(for: url)
        let content = url.absoluteString
        
        if askToSave {
            NSApp.activate(ignoringOtherApps: true)
            saveWithDialog(filename: filename, content: content, iconType: iconType)
        } else {
            saveToDefault(filename: filename, content: content, iconType: iconType)
        }
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
        
        savePanel.begin { [weak self] response in
            guard let self = self else { return }
            self.isProcessing = false
            
            // Reactivate the app and popover after save panel closes
            DispatchQueue.main.async {
                NSApp.activate(ignoringOtherApps: true)
                NotificationCenter.default.post(name: NSNotification.Name("ReactivatePopover"), object: nil)
            }
            
            if response == .OK, let targetURL = savePanel.url {
                do {
                    try content.write(to: targetURL, atomically: true, encoding: .utf8)
                    iconService.applyIcon(type: iconType, to: targetURL)
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
        let uniqueURL = linkService.generateUniqueURL(for: fileURL)
        
        do {
            try content.write(to: uniqueURL, atomically: true, encoding: .utf8)
            iconService.applyIcon(type: iconType, to: uniqueURL)
            withAnimation {
                message = "✓ Saved to: \(uniqueURL.lastPathComponent)"
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                withAnimation {
                    self.message = ""
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
}
