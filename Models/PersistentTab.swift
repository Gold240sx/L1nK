import Foundation
import SwiftData

/// A persistent tab - like a browser tab you don't want to close
@Model
final class PersistentTab {
    var id: UUID = UUID()
    var url: String = ""
    var domain: String = ""
    var title: String = ""
    var customTitle: String?  // User-defined custom title
    var tabDescription: String?
    var faviconPath: String?
    
    var folder: TabFolder?
    
    var createdAt: Date = Date()
    var lastVisitedAt: Date?
    var pinned: Bool = false
    var archived: Bool = false
    
    init(
        id: UUID = UUID(),
        url: String,
        domain: String? = nil,
        title: String? = nil,
        customTitle: String? = nil,
        tabDescription: String? = nil,
        faviconPath: String? = nil,
        folder: TabFolder? = nil,
        createdAt: Date = Date(),
        lastVisitedAt: Date? = nil,
        pinned: Bool = false,
        archived: Bool = false
    ) {
        self.id = id
        self.url = url
        self.domain = domain ?? URL(string: url)?.host ?? url
        self.title = title ?? URL(string: url)?.host ?? url
        self.customTitle = customTitle
        self.tabDescription = tabDescription
        self.faviconPath = faviconPath
        self.folder = folder
        self.createdAt = createdAt
        self.lastVisitedAt = lastVisitedAt
        self.pinned = pinned
        self.archived = archived
    }
    
    /// Display title - returns custom title if set, otherwise fetched title
    var displayTitle: String {
        if let custom = customTitle, !custom.isEmpty {
            return custom
        }
        return title
    }
    
    /// Whether a custom title is set
    var hasCustomTitle: Bool {
        customTitle != nil && !customTitle!.isEmpty
    }
    
    /// URL object for convenience
    var urlObject: URL? {
        URL(string: url)
    }
    
    /// Relative time since last visited
    var lastVisitedRelative: String {
        guard let lastVisited = lastVisitedAt else {
            return "Never opened"
        }
        
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: lastVisited, relativeTo: Date())
    }
    
    /// Mark as visited and update timestamp
    func markVisited() {
        lastVisitedAt = Date()
    }
}
