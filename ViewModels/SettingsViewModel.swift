import SwiftUI
import Foundation
import ServiceManagement
import Sparkle

class SettingsViewModel: ObservableObject {
    @AppStorage("defaultSaveDirectory") var defaultSaveDirectory: String = ""
    @AppStorage("askToSave") var askToSave: Bool = false
    @AppStorage("launchAtLogin") var launchAtLogin: Bool = false
    @AppStorage("useCustomYouTubeApp") var useCustomYouTubeApp: Bool = false
    @AppStorage("customYouTubeAppPath") var customYouTubeAppPath: String = ""
    @AppStorage("useGenericIcons") var useGenericIcons: Bool = false
    
    @Published var message: String = ""
    @Published var showPermissionAlert: Bool = false
    @Published var lastError: String = ""
    
    @Published var updateStatus: UpdateStatus = .idle
    @Published var isCheckingForUpdates: Bool = false
    @Published var hasUpdateAvailable: Bool = false
    
    var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
    }
    
    enum UpdateStatus: Equatable {
        case idle
        case checking
        case updateAvailable
        case noUpdateAvailable
        case error(String)
        
        static func == (lhs: UpdateStatus, rhs: UpdateStatus) -> Bool {
            switch (lhs, rhs) {
            case (.idle, .idle), (.checking, .checking), (.updateAvailable, .updateAvailable), (.noUpdateAvailable, .noUpdateAvailable):
                return true
            case (.error(let lhsError), .error(let rhsError)):
                return lhsError == rhsError
            default:
                return false
            }
        }
    }
    
    func setUpdateAvailable(_ available: Bool) {
        hasUpdateAvailable = available
    }
    
    func checkForUpdates() {
        guard !isCheckingForUpdates else { return }
        
        // Check if Sparkle can check for updates (not already in progress)
        let updater = SparkleManager.shared.updaterController.updater
        guard updater.canCheckForUpdates else {
            // Already checking or session in progress
            return
        }
        
        isCheckingForUpdates = true
        updateStatus = .checking
        
        SparkleManager.shared.checkForUpdates()
        
        // Timeout after 30 seconds if no response
        DispatchQueue.main.asyncAfter(deadline: .now() + 30.0) { [weak self] in
            guard let self = self, self.updateStatus == .checking else { return }
            self.isCheckingForUpdates = false
            self.updateStatus = .error("Check timed out")
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                if case .error = self.updateStatus {
                    self.updateStatus = .idle
                }
            }
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
