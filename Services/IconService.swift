import Foundation
import AppKit

class IconService {
    static let shared = IconService()
    
    private init() {}
    
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
}
