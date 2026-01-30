import SwiftUI
import Foundation
import ServiceManagement

class SettingsViewModel: ObservableObject {
    @AppStorage("defaultSaveDirectory") var defaultSaveDirectory: String = ""
    @AppStorage("askToSave") var askToSave: Bool = false
    @AppStorage("launchAtLogin") var launchAtLogin: Bool = false
    @AppStorage("useCustomYouTubeApp") var useCustomYouTubeApp: Bool = false
    @AppStorage("customYouTubeAppPath") var customYouTubeAppPath: String = ""
    
    @Published var message: String = ""
    @Published var showPermissionAlert: Bool = false
    @Published var lastError: String = ""
    
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
                    self.message = ""
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
        
        panel.begin { [weak self] response in
            if response == .OK {
                self?.defaultSaveDirectory = panel.url?.path ?? ""
            }
        }
    }
    
    func selectYouTubeApp() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.application]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        
        panel.begin { [weak self] response in
            if response == .OK, let url = panel.url {
                self?.customYouTubeAppPath = url.path
            }
        }
    }
}
