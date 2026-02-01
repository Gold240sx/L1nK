import SwiftUI
import SwiftData
import AppKit
import UniformTypeIdentifiers

/// View mode for displaying tabs
enum TabViewMode: String, CaseIterable {
    case list = "list.bullet"
    case grid = "square.grid.2x2"
    case compact = "circle.grid.3x3"
}

/// Main container view for Persistent Tabs feature
struct PersistentTabsView: View {
    @StateObject private var tabManager = TabManager.shared
    @State private var isAddingTab: Bool = false
    @State private var newTabURL: String = ""
    @State private var showingArchive: Bool = false
    @State private var expandedFolders: Set<UUID> = []
    @State private var showingNewFolderSheet: Bool = false
    @State private var newFolderName: String = ""
    @State private var selectedFolderColor: Color = .blue
    @State private var selectedFolderIcon: String = "folder.fill"
    @State private var viewMode: TabViewMode = .list
    @State private var showingBackupMenu: Bool = false
    @State private var showingImportResult: Bool = false
    @State private var importResult: ImportResult?
    
    var body: some View {
        VStack(spacing: 0) {
            // Search bar / URL input
            searchBar
                .padding(.horizontal, 12)
                .padding(.top, 12)
                .padding(.bottom, 8)
            
            // Tab list
            ScrollView {
                switch viewMode {
                case .list:
                    listContent
                case .grid:
                    gridContent
                case .compact:
                    compactGridContent
                }
            }
            
            // Bottom bar
            bottomBar
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
        }
        .frame(minWidth: 300, minHeight: 400)
        .sheet(isPresented: $showingNewFolderSheet) {
            newFolderSheet
        }
        .sheet(isPresented: $showingArchive) {
            archiveSheet
        }
    }
    
    // MARK: - Search Bar
    
    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
                .font(.system(size: 13))
            
            TextField("Search or paste URL...", text: $tabManager.searchQuery)
                .textFieldStyle(.plain)
                .font(.system(size: 13))
                .onSubmit {
                    handleSearchSubmit()
                }
            
            if !tabManager.searchQuery.isEmpty {
                Button(action: { tabManager.searchQuery = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                        .font(.system(size: 12))
                }
                .buttonStyle(.plain)
            }
            
            if isURLInput {
                Button(action: { addTabFromSearch() }) {
                    Image(systemName: "plus.circle.fill")
                        .foregroundColor(.accentColor)
                        .font(.system(size: 14))
                }
                .buttonStyle(.plain)
            }
            
            Divider()
                .frame(height: 16)
            
            // View mode toggle
            HStack(spacing: 4) {
                ForEach(TabViewMode.allCases, id: \.self) { mode in
                    Button(action: { viewMode = mode }) {
                        Image(systemName: mode.rawValue)
                            .font(.system(size: 11))
                            .foregroundColor(viewMode == mode ? .accentColor : .secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(NSColor.controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color(NSColor.separatorColor).opacity(0.5), lineWidth: 0.5)
        )
    }
    
    // MARK: - List View Content
    
    private var listContent: some View {
        LazyVStack(spacing: 0) {
            // When searching, show flat list of results
            if !tabManager.searchQuery.isEmpty {
                if tabManager.filteredTabs.isEmpty {
                    noResultsView
                } else {
                    sectionHeader("Search Results", icon: "magnifyingglass")
                    
                    ForEach(tabManager.filteredTabs, id: \.id) { tab in
                        TabRowView(tab: tab, showFolderBadge: true)
                            .id("search-\(tab.id)")
                    }
                }
            } else {
                // Normal organized view when not searching
                
                // Recently Active section
                if !tabManager.recentlyActiveTabs.isEmpty {
                    sectionHeader("Recently Active", icon: "clock.arrow.circlepath")
                    
                    ForEach(Array(tabManager.recentlyActiveTabs.prefix(5)), id: \.id) { tab in
                        TabRowView(tab: tab)
                            .id("recent-\(tab.id)")
                    }
                    
                    Divider()
                        .padding(.vertical, 8)
                        .padding(.horizontal, 12)
                }
                
                // Pinned section
                if !tabManager.pinnedTabs.isEmpty {
                    sectionHeader("Pinned", icon: "pin.fill")
                    
                    ForEach(tabManager.pinnedTabs, id: \.id) { tab in
                        TabRowView(tab: tab)
                            .id("pinned-\(tab.id)")
                    }
                    
                    Divider()
                        .padding(.vertical, 8)
                        .padding(.horizontal, 12)
                }
                
                // Folders section
                if !tabManager.folders.isEmpty {
                    sectionHeader("Folders", icon: "folder.fill", action: {
                        showingNewFolderSheet = true
                    }, actionIcon: "plus")
                    
                    ForEach(tabManager.folders, id: \.id) { folder in
                        FolderRowView(
                            folder: folder,
                            isExpanded: expandedFolders.contains(folder.id),
                            toggleExpand: {
                                if expandedFolders.contains(folder.id) {
                                    expandedFolders.remove(folder.id)
                                } else {
                                    expandedFolders.insert(folder.id)
                                }
                            }
                        )
                        .id("folder-\(folder.id)")
                        
                        if expandedFolders.contains(folder.id) {
                            ForEach(tabManager.tabs(in: folder), id: \.id) { tab in
                                TabRowView(tab: tab)
                                    .padding(.leading, 24)
                                    .id("folder-\(folder.id)-tab-\(tab.id)")
                            }
                        }
                    }
                    
                    Divider()
                        .padding(.vertical, 8)
                        .padding(.horizontal, 12)
                }
                
                // Unfiled tabs
                if !tabManager.unfolderedTabs.isEmpty {
                    sectionHeader("All Tabs", icon: "square.stack.fill")
                    
                    ForEach(tabManager.unfolderedTabs, id: \.id) { tab in
                        TabRowView(tab: tab)
                            .id("unfiled-\(tab.id)")
                    }
                }
                
                // Empty state
                if tabManager.tabs.isEmpty {
                    emptyState
                }
            }
        }
        .padding(.vertical, 8)
    }
    
    // MARK: - Grid View Content
    
    private var gridContent: some View {
        LazyVGrid(
            columns: [
                GridItem(.flexible(), spacing: 12),
                GridItem(.flexible(), spacing: 12)
            ],
            spacing: 12
        ) {
            ForEach(tabManager.filteredTabs, id: \.id) { tab in
                TabGridItemView(tab: tab)
                    .id("grid-\(tab.id)")
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
    }
    
    // MARK: - Compact Grid View Content (6 columns, favicon only)
    
    private var compactGridContent: some View {
        LazyVGrid(
            columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 6),
            spacing: 8
        ) {
            ForEach(tabManager.filteredTabs, id: \.id) { tab in
                TabCompactItemView(tab: tab)
                    .id("compact-\(tab.id)")
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
    }
    
    private var isURLInput: Bool {
        let query = tabManager.searchQuery.lowercased()
        return query.hasPrefix("http://") ||
        query.hasPrefix("https://") ||
        query.contains(".") && query.count > 4
    }
    
    private func handleSearchSubmit() {
        if isURLInput {
            addTabFromSearch()
        }
    }
    
    private func addTabFromSearch() {
        Task {
            let url = tabManager.searchQuery
            tabManager.searchQuery = ""
            _ = await tabManager.addTab(from: url)
        }
    }
    
    // MARK: - Section Header
    
    private func sectionHeader(_ title: String, icon: String, action: (() -> Void)? = nil, actionIcon: String? = nil) -> some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.secondary)
                .font(.system(size: 11))
            
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.secondary)
                .textCase(.uppercase)
            
            Spacer()
            
            if let action = action, let actionIcon = actionIcon {
                Button(action: action) {
                    Image(systemName: actionIcon)
                        .foregroundColor(.secondary)
                        .font(.system(size: 11))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }
    
    // MARK: - Empty State
    
    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "rectangle.stack.badge.plus")
                .font(.system(size: 48))
                .foregroundColor(.secondary.opacity(0.5))
            
            VStack(spacing: 4) {
                Text("No Saved Tabs")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Text("Paste a URL above to save your first tab")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }
    
    private var noResultsView: some View {
        VStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 32))
                .foregroundColor(.secondary.opacity(0.5))
            
            Text("No tabs match \"\(tabManager.searchQuery)\"")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
    
    // MARK: - Bottom Bar
    
    private var bottomBar: some View {
        HStack(spacing: 12) {
            Button(action: { showingNewFolderSheet = true }) {
                HStack(spacing: 4) {
                    Image(systemName: "folder.badge.plus")
                        .font(.system(size: 11))
                    Text("New")
                        .font(.system(size: 11))
                }
                .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
            .help("New Folder")
            
            Spacer()
            
            // Backup menu
            Menu {
                Button(action: exportBackup) {
                    Label("Export Backup...", systemImage: "square.and.arrow.up")
                }
                
                Button(action: importBackup) {
                    Label("Import Backup...", systemImage: "square.and.arrow.down")
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "externaldrive")
                        .font(.system(size: 11))
                    Text("\(tabManager.tabs.count)")
                        .font(.system(size: 11))
                }
                .foregroundColor(.secondary.opacity(0.7))
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
            .help("Backup & Restore")
            
            Spacer()
            
            Button(action: { showingArchive = true }) {
                HStack(spacing: 4) {
                    Image(systemName: "archivebox")
                        .font(.system(size: 11))
                    Text("Archive")
                        .font(.system(size: 11))
                }
                .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
            .help("View Archive")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(NSColor.controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color(NSColor.separatorColor).opacity(0.5), lineWidth: 0.5)
        )
        .alert("Import Complete", isPresented: $showingImportResult) {
            Button("OK", role: .cancel) { }
        } message: {
            if let result = importResult {
                if result.success {
                    Text("Imported \(result.tabsImported) tabs and \(result.foldersImported) folders.")
                } else {
                    Text("Import failed: \(result.error ?? "Unknown error")")
                }
            }
        }
    }
    
    // MARK: - Backup Functions
    
    private func exportBackup() {
        guard let backupURL = tabManager.saveBackup() else {
            return
        }
        
        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [.json]
        savePanel.nameFieldStringValue = backupURL.lastPathComponent
        savePanel.title = "Export Tabs Backup"
        savePanel.message = "Choose where to save your tabs backup"
        
        savePanel.begin { response in
            if response == .OK, let destinationURL = savePanel.url {
                do {
                    // Remove existing file if present
                    if FileManager.default.fileExists(atPath: destinationURL.path) {
                        try FileManager.default.removeItem(at: destinationURL)
                    }
                    try FileManager.default.copyItem(at: backupURL, to: destinationURL)
                } catch {
                    print("Failed to save backup: \(error)")
                }
            }
            
            // Clean up temp file
            try? FileManager.default.removeItem(at: backupURL)
        }
    }
    
    private func importBackup() {
        let openPanel = NSOpenPanel()
        openPanel.allowedContentTypes = [.json]
        openPanel.allowsMultipleSelection = false
        openPanel.title = "Import Tabs Backup"
        openPanel.message = "Select a L1nK backup file"
        
        openPanel.begin { response in
            if response == .OK, let fileURL = openPanel.url {
                let result = tabManager.importFromFile(fileURL)
                importResult = result
                showingImportResult = true
            }
        }
    }
    
    // MARK: - New Folder Sheet
    
    private var newFolderSheet: some View {
        VStack(spacing: 20) {
            Text("New Folder")
                .font(.headline)
            
            // Preview
            HStack(spacing: 8) {
                Image(systemName: selectedFolderIcon)
                    .font(.system(size: 16))
                    .foregroundColor(selectedFolderColor)
                Text(newFolderName.isEmpty ? "Folder Name" : newFolderName)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(newFolderName.isEmpty ? .secondary : .primary)
            }
            .padding(.vertical, 8)
            
            TextField("Folder name", text: $newFolderName)
                .textFieldStyle(.roundedBorder)
            
            // Color picker
            VStack(alignment: .leading, spacing: 8) {
                Text("Color")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                HStack(spacing: 10) {
                    ForEach(TabFolder.availableColors, id: \.self) { color in
                        Circle()
                            .fill(color)
                            .frame(width: 22, height: 22)
                            .overlay(
                                Circle()
                                    .stroke(Color.primary.opacity(selectedFolderColor == color ? 0.5 : 0), lineWidth: 2)
                            )
                            .onTapGesture {
                                selectedFolderColor = color
                            }
                    }
                }
            }
            
            // Icon picker
            VStack(alignment: .leading, spacing: 8) {
                Text("Icon")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                LazyVGrid(columns: Array(repeating: GridItem(.fixed(32)), count: 8), spacing: 8) {
                    ForEach(TabFolder.availableIcons, id: \.self) { iconName in
                        ZStack {
                            RoundedRectangle(cornerRadius: 5)
                                .fill(selectedFolderIcon == iconName ? selectedFolderColor.opacity(0.2) : Color.clear)
                                .frame(width: 28, height: 28)
                            
                            Image(systemName: iconName)
                                .font(.system(size: 12))
                                .foregroundColor(selectedFolderIcon == iconName ? selectedFolderColor : .secondary)
                        }
                        .overlay(
                            RoundedRectangle(cornerRadius: 5)
                                .stroke(selectedFolderIcon == iconName ? selectedFolderColor : Color.clear, lineWidth: 1)
                        )
                        .onTapGesture {
                            selectedFolderIcon = iconName
                        }
                    }
                }
            }
            
            HStack(spacing: 12) {
                Button("Cancel") {
                    resetNewFolderForm()
                    showingNewFolderSheet = false
                }
                .buttonStyle(.bordered)
                
                Button("Create") {
                    if !newFolderName.isEmpty {
                        _ = tabManager.createFolder(name: newFolderName, color: selectedFolderColor, icon: selectedFolderIcon)
                    }
                    resetNewFolderForm()
                    showingNewFolderSheet = false
                }
                .buttonStyle(.borderedProminent)
                .disabled(newFolderName.isEmpty)
            }
        }
        .padding(24)
        .frame(width: 320)
    }
    
    private func resetNewFolderForm() {
        newFolderName = ""
        selectedFolderColor = .blue
        selectedFolderIcon = "folder.fill"
    }
    
    // MARK: - Archive Sheet
    
    private var archiveSheet: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Archived Tabs")
                    .font(.headline)
                
                Spacer()
                
                if !tabManager.archivedTabs.isEmpty {
                    Button("Clear All") {
                        tabManager.clearArchive()
                    }
                    .foregroundColor(.red)
                }
                
                Button(action: { showingArchive = false }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding()
            
            Divider()
            
            if tabManager.archivedTabs.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "archivebox")
                        .font(.system(size: 32))
                        .foregroundColor(.secondary.opacity(0.5))
                    
                    Text("No archived tabs")
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(tabManager.archivedTabs, id: \.id) { tab in
                            HStack {
                                FaviconView(urlString: tab.url)
                                    .frame(width: 16, height: 16)
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(tab.displayTitle)
                                        .font(.system(size: 13))
                                        .lineLimit(1)
                                    
                                    Text(tab.domain)
                                        .font(.system(size: 11))
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                                
                                Button(action: { tabManager.restoreTab(tab) }) {
                                    Image(systemName: "arrow.uturn.backward")
                                }
                                .buttonStyle(.plain)
                                .help("Restore")
                                
                                Button(action: { tabManager.deleteTab(tab) }) {
                                    Image(systemName: "trash")
                                        .foregroundColor(.red)
                                }
                                .buttonStyle(.plain)
                                .help("Delete permanently")
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .id("archived-\(tab.id)")
                        }
                    }
                }
            }
        }
        .frame(width: 350, height: 300)
    }
}

