import Foundation
import SwiftData
import SwiftUI
import AppKit

/// Manages persistent tabs - CRUD operations, search, and organization
@MainActor
class TabManager: ObservableObject {
    static let shared = TabManager()
    
    // MARK: - Properties
    
    /// SwiftData model context
    var modelContext: ModelContext?
    
    /// All tabs (excluding archived)
    @Published var tabs: [PersistentTab] = []
    
    /// All folders
    @Published var folders: [TabFolder] = []
    
    /// Current search query
    @Published var searchQuery: String = ""
    
    /// Filtered tabs based on search
    var filteredTabs: [PersistentTab] {
        guard !searchQuery.isEmpty else {
            return tabs
        }
        
        let query = searchQuery.lowercased()
        return tabs.filter { tab in
            tab.title.lowercased().contains(query) ||
            tab.domain.lowercased().contains(query) ||
            (tab.tabDescription?.lowercased().contains(query) ?? false) ||
            tab.url.lowercased().contains(query)
        }
    }
    
    /// Recently active tabs (last visited within 7 days)
    var recentlyActiveTabs: [PersistentTab] {
        let sevenDaysAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        return filteredTabs
            .filter { $0.lastVisitedAt != nil && $0.lastVisitedAt! > sevenDaysAgo && !$0.pinned }
            .sorted { ($0.lastVisitedAt ?? .distantPast) > ($1.lastVisitedAt ?? .distantPast) }
    }
    
    /// Pinned tabs
    var pinnedTabs: [PersistentTab] {
        filteredTabs.filter { $0.pinned }
            .sorted { $0.createdAt < $1.createdAt }
    }
    
    /// Tabs without a folder
    var unfolderedTabs: [PersistentTab] {
        filteredTabs.filter { $0.folder == nil && !$0.pinned }
            .sorted { ($0.lastVisitedAt ?? $0.createdAt) > ($1.lastVisitedAt ?? $1.createdAt) }
    }
    
    /// Archived tabs
    var archivedTabs: [PersistentTab] {
        tabs.filter { $0.archived }
            .sorted { ($0.lastVisitedAt ?? $0.createdAt) > ($1.lastVisitedAt ?? $1.createdAt) }
    }
    
    // MARK: - Initialization
    
    private init() {}
    
    /// Configure with model context
    func configure(with context: ModelContext) {
        self.modelContext = context
        fetchData()
    }
    
    // MARK: - Data Fetching
    
    /// Fetch all tabs and folders from SwiftData
    func fetchData() {
        guard let context = modelContext else { return }
        
        // Fetch non-archived tabs
        let tabDescriptor = FetchDescriptor<PersistentTab>(
            predicate: #Predicate { !$0.archived },
            sortBy: [SortDescriptor(\.lastVisitedAt, order: .reverse)]
        )
        
        let folderDescriptor = FetchDescriptor<TabFolder>(
            sortBy: [SortDescriptor(\.orderIndex)]
        )
        
        do {
            tabs = try context.fetch(tabDescriptor)
            folders = try context.fetch(folderDescriptor)
        } catch {
            print("Failed to fetch data: \(error)")
        }
    }
    
    // MARK: - Tab CRUD Operations
    
    /// Add a new tab from URL string
    func addTab(from urlString: String, to folder: TabFolder? = nil) async -> PersistentTab? {
        guard let context = modelContext else { return nil }
        
        // Validate URL
        var cleanURL = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        if !cleanURL.hasPrefix("http://") && !cleanURL.hasPrefix("https://") {
            cleanURL = "https://" + cleanURL
        }
        
        guard URL(string: cleanURL) != nil else { return nil }
        
        // Check for duplicate
        if tabs.contains(where: { $0.url == cleanURL }) {
            return nil
        }
        
        // Fetch metadata
        let metadata = await MetadataFetcher.shared.fetch(for: cleanURL)
        
        // Create tab
        let tab = PersistentTab(
            url: cleanURL,
            domain: metadata.domain,
            title: metadata.title,
            tabDescription: metadata.description,
            folder: folder
        )
        
        // Prefetch favicon
        await FaviconManager.shared.prefetch(for: cleanURL)
        tab.faviconPath = FaviconManager.shared.getCachedPath(for: cleanURL)
        
        // Save
        context.insert(tab)
        try? context.save()
        
        fetchData()
        return tab
    }
    
    /// Delete a tab
    func deleteTab(_ tab: PersistentTab) {
        guard let context = modelContext else { return }
        context.delete(tab)
        try? context.save()
        fetchData()
    }
    
    /// Archive a tab (soft delete)
    func archiveTab(_ tab: PersistentTab) {
        tab.archived = true
        try? modelContext?.save()
        fetchData()
    }
    
    /// Restore an archived tab
    func restoreTab(_ tab: PersistentTab) {
        tab.archived = false
        try? modelContext?.save()
        fetchData()
    }
    
    /// Toggle pin status
    func togglePin(_ tab: PersistentTab) {
        tab.pinned.toggle()
        try? modelContext?.save()
        fetchData()
    }
    
    /// Set custom title for a tab
    func renameTab(_ tab: PersistentTab, to newTitle: String) {
        if newTitle.isEmpty {
            tab.customTitle = nil  // Clear custom title, revert to fetched
        } else {
            tab.customTitle = newTitle
        }
        try? modelContext?.save()
        fetchData()
    }
    
    /// Open tab in browser and update last visited
    func openTab(_ tab: PersistentTab) {
        guard let url = tab.urlObject else { return }
        
        tab.markVisited()
        try? modelContext?.save()
        
        NSWorkspace.shared.open(url)
        fetchData()
    }
    
    /// Move tab to folder
    func moveTab(_ tab: PersistentTab, to folder: TabFolder?) {
        tab.folder = folder
        try? modelContext?.save()
        fetchData()
    }
    
    /// Update tab metadata (re-fetch from URL)
    func refreshMetadata(for tab: PersistentTab) async {
        let metadata = await MetadataFetcher.shared.fetch(for: tab.url)
        
        tab.title = metadata.title
        tab.tabDescription = metadata.description
        
        await FaviconManager.shared.prefetch(for: tab.url)
        tab.faviconPath = FaviconManager.shared.getCachedPath(for: tab.url)
        
        try? modelContext?.save()
        fetchData()
    }
    
    // MARK: - Folder CRUD Operations
    
    /// Create a new folder
    func createFolder(name: String, color: Color? = nil, icon: String? = nil) -> TabFolder? {
        guard let context = modelContext else { return nil }
        
        let nextIndex = (folders.map { $0.orderIndex }.max() ?? -1) + 1
        
        let folder = TabFolder(
            name: name,
            colorHex: color?.toHex(),
            iconName: icon,
            orderIndex: nextIndex
        )
        
        context.insert(folder)
        try? context.save()
        
        fetchData()
        return folder
    }
    
    /// Rename a folder
    func renameFolder(_ folder: TabFolder, to name: String) {
        folder.name = name
        try? modelContext?.save()
        fetchData()
    }
    
    /// Delete a folder (tabs are moved to unfiled)
    func deleteFolder(_ folder: TabFolder) {
        guard let context = modelContext else { return }
        
        // Move all tabs out of folder first
        if let tabs = folder.tabs {
            for tab in tabs {
                tab.folder = nil
            }
        }
        
        context.delete(folder)
        try? context.save()
        fetchData()
    }
    
    /// Reorder folders
    func reorderFolders(from source: IndexSet, to destination: Int) {
        var reorderedFolders = folders
        reorderedFolders.move(fromOffsets: source, toOffset: destination)
        
        for (index, folder) in reorderedFolders.enumerated() {
            folder.orderIndex = index
        }
        
        try? modelContext?.save()
        fetchData()
    }
    
    /// Update folder color
    func setFolderColor(_ folder: TabFolder, color: Color) {
        folder.setColor(color)
        try? modelContext?.save()
        fetchData()
    }
    
    func setFolderIcon(_ folder: TabFolder, icon: String) {
        folder.setIcon(icon)
        try? modelContext?.save()
        fetchData()
    }
    
    // MARK: - Bulk Operations
    
    /// Delete all archived tabs permanently
    func clearArchive() {
        guard let context = modelContext else { return }
        
        let descriptor = FetchDescriptor<PersistentTab>(
            predicate: #Predicate { $0.archived }
        )
        
        do {
            let archivedTabs = try context.fetch(descriptor)
            for tab in archivedTabs {
                context.delete(tab)
            }
            try context.save()
            fetchData()
        } catch {
            print("Failed to clear archive: \(error)")
        }
    }
    
    /// Get tabs for a specific folder
    func tabs(in folder: TabFolder) -> [PersistentTab] {
        filteredTabs
            .filter { $0.folder?.id == folder.id }
            .sorted { ($0.lastVisitedAt ?? $0.createdAt) > ($1.lastVisitedAt ?? $1.createdAt) }
    }
    
    // MARK: - Backup & Restore
    
    /// Export all tabs and folders to JSON
    func exportToJSON() -> Data? {
        guard let context = modelContext else { return nil }
        
        // Fetch all tabs (including archived)
        let allTabsDescriptor = FetchDescriptor<PersistentTab>()
        let allFoldersDescriptor = FetchDescriptor<TabFolder>()
        
        do {
            let allTabs = try context.fetch(allTabsDescriptor)
            let allFolders = try context.fetch(allFoldersDescriptor)
            
            // Create export data
            let exportFolders = allFolders.map { folder in
                TabFolderExport(
                    id: folder.id,
                    name: folder.name,
                    colorHex: folder.colorHex,
                    orderIndex: folder.orderIndex,
                    createdAt: folder.createdAt
                )
            }
            
            let exportTabs = allTabs.map { tab in
                TabExport(
                    id: tab.id,
                    url: tab.url,
                    domain: tab.domain,
                    title: tab.title,
                    customTitle: tab.customTitle,
                    tabDescription: tab.tabDescription,
                    folderId: tab.folder?.id,
                    createdAt: tab.createdAt,
                    lastVisitedAt: tab.lastVisitedAt,
                    pinned: tab.pinned,
                    archived: tab.archived
                )
            }
            
            let backup = TabBackup(
                version: 1,
                exportDate: Date(),
                folders: exportFolders,
                tabs: exportTabs
            )
            
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            
            return try encoder.encode(backup)
        } catch {
            print("Failed to export: \(error)")
            return nil
        }
    }
    
    /// Save backup to a file and return the URL
    func saveBackup() -> URL? {
        guard let jsonData = exportToJSON() else { return nil }
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd_HHmmss"
        let timestamp = dateFormatter.string(from: Date())
        
        let fileName = "L1nK_Backup_\(timestamp).json"
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        
        do {
            try jsonData.write(to: tempURL)
            return tempURL
        } catch {
            print("Failed to save backup: \(error)")
            return nil
        }
    }
    
    /// Import tabs and folders from JSON data
    func importFromJSON(_ data: Data, mergeWithExisting: Bool = true) -> ImportResult {
        guard let context = modelContext else {
            return ImportResult(success: false, tabsImported: 0, foldersImported: 0, error: "No database context")
        }
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        do {
            let backup = try decoder.decode(TabBackup.self, from: data)
            
            var foldersImported = 0
            var tabsImported = 0
            var folderMapping: [UUID: TabFolder] = [:]
            
            // If not merging, clear existing data
            if !mergeWithExisting {
                let existingTabs = try context.fetch(FetchDescriptor<PersistentTab>())
                let existingFolders = try context.fetch(FetchDescriptor<TabFolder>())
                
                for tab in existingTabs {
                    context.delete(tab)
                }
                for folder in existingFolders {
                    context.delete(folder)
                }
            }
            
            // Import folders first
            for folderExport in backup.folders {
                // Check if folder already exists (by ID or name)
                let existingFolders = try context.fetch(FetchDescriptor<TabFolder>())
                let existing = existingFolders.first { $0.id == folderExport.id || $0.name == folderExport.name }
                
                if let existing = existing {
                    folderMapping[folderExport.id] = existing
                } else {
                    let folder = TabFolder(
                        id: folderExport.id,
                        name: folderExport.name,
                        colorHex: folderExport.colorHex,
                        orderIndex: folderExport.orderIndex,
                        createdAt: folderExport.createdAt
                    )
                    context.insert(folder)
                    folderMapping[folderExport.id] = folder
                    foldersImported += 1
                }
            }
            
            // Import tabs
            for tabExport in backup.tabs {
                // Check if tab already exists (by URL)
                let existingTabs = try context.fetch(FetchDescriptor<PersistentTab>())
                let existing = existingTabs.first { $0.url == tabExport.url }
                
                if existing == nil {
                    let folder = tabExport.folderId.flatMap { folderMapping[$0] }
                    
                    let tab = PersistentTab(
                        id: tabExport.id,
                        url: tabExport.url,
                        domain: tabExport.domain,
                        title: tabExport.title,
                        customTitle: tabExport.customTitle,
                        tabDescription: tabExport.tabDescription,
                        folder: folder,
                        createdAt: tabExport.createdAt,
                        lastVisitedAt: tabExport.lastVisitedAt,
                        pinned: tabExport.pinned,
                        archived: tabExport.archived
                    )
                    context.insert(tab)
                    tabsImported += 1
                }
            }
            
            try context.save()
            fetchData()
            
            return ImportResult(
                success: true,
                tabsImported: tabsImported,
                foldersImported: foldersImported,
                error: nil
            )
        } catch {
            print("Failed to import: \(error)")
            return ImportResult(success: false, tabsImported: 0, foldersImported: 0, error: error.localizedDescription)
        }
    }
    
    /// Import from a file URL
    func importFromFile(_ url: URL) -> ImportResult {
        do {
            let data = try Data(contentsOf: url)
            return importFromJSON(data)
        } catch {
            return ImportResult(success: false, tabsImported: 0, foldersImported: 0, error: error.localizedDescription)
        }
    }
}

// MARK: - Backup Data Structures

/// Complete backup container
struct TabBackup: Codable {
    let version: Int
    let exportDate: Date
    let folders: [TabFolderExport]
    let tabs: [TabExport]
}

/// Folder export structure
struct TabFolderExport: Codable {
    let id: UUID
    let name: String
    let colorHex: String?
    let orderIndex: Int
    let createdAt: Date
}

/// Tab export structure
struct TabExport: Codable {
    let id: UUID
    let url: String
    let domain: String
    let title: String
    let customTitle: String?
    let tabDescription: String?
    let folderId: UUID?
    let createdAt: Date
    let lastVisitedAt: Date?
    let pinned: Bool
    let archived: Bool
}

/// Result of an import operation
struct ImportResult {
    let success: Bool
    let tabsImported: Int
    let foldersImported: Int
    let error: String?
}
