import SwiftUI
import AppKit

/// Individual tab row with favicon, title, and hover actions
struct TabRowView: View {
    let tab: PersistentTab
    var showFolderBadge: Bool = false
    
    @StateObject private var tabManager = TabManager.shared
    @State private var isHovered: Bool = false
    @State private var showingMoveMenu: Bool = false
    @State private var showingRenameSheet: Bool = false
    @State private var renameText: String = ""
    
    var body: some View {
        HStack(spacing: 10) {
            // Favicon
            FaviconView(urlString: tab.url)
                .frame(width: 16, height: 16)
            
            // Title and domain
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(tab.displayTitle)
                        .font(.system(size: 13))
                        .lineLimit(1)
                        .foregroundColor(.primary)
                    
                    if tab.hasCustomTitle {
                        Image(systemName: "pencil.circle.fill")
                            .font(.system(size: 9))
                            .foregroundColor(.secondary.opacity(0.5))
                    }
                }
                
                HStack(spacing: 4) {
                    Text(tab.domain)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                    
                    if tab.lastVisitedAt != nil {
                        Text("•")
                            .foregroundColor(.secondary.opacity(0.5))
                        
                        Text(tab.lastVisitedRelative)
                            .font(.system(size: 11))
                            .foregroundColor(.secondary.opacity(0.7))
                    }
                    
                    // Folder badge for search results
                    if showFolderBadge, let folder = tab.folder {
                        Text("•")
                            .foregroundColor(.secondary.opacity(0.5))
                        
                        HStack(spacing: 3) {
                            Image(systemName: folder.icon)
                                .font(.system(size: 8))
                            Text(folder.name)
                                .font(.system(size: 10))
                        }
                        .foregroundColor(folder.color)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(
                            Capsule()
                                .fill(folder.color.opacity(0.15))
                        )
                    }
                }
            }
            
            Spacer()
            
            // Pinned indicator
            if tab.pinned && !isHovered {
                Image(systemName: "pin.fill")
                    .font(.system(size: 10))
                    .foregroundColor(.orange)
            }
            
            // Hover actions
            if isHovered {
                hoverActions
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isHovered ? Color(NSColor.selectedContentBackgroundColor).opacity(0.3) : Color.clear)
        )
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
        .onTapGesture {
            tabManager.openTab(tab)
        }
        .contextMenu {
            contextMenuContent
        }
        .sheet(isPresented: $showingRenameSheet) {
            RenameTabSheet(tab: tab, isPresented: $showingRenameSheet)
        }
    }
    
    // MARK: - Hover Actions
    
    private var hoverActions: some View {
        HStack(spacing: 6) {
            // Open in browser
            Button(action: { tabManager.openTab(tab) }) {
                Image(systemName: "arrow.up.right.square")
                    .font(.system(size: 12))
            }
            .buttonStyle(.plain)
            .help("Open in browser")
            
            // Pin/Unpin
            Button(action: { tabManager.togglePin(tab) }) {
                Image(systemName: tab.pinned ? "pin.slash.fill" : "pin")
                    .font(.system(size: 12))
                    .foregroundColor(tab.pinned ? .orange : .secondary)
            }
            .buttonStyle(.plain)
            .help(tab.pinned ? "Unpin" : "Pin")
            
            // Archive
            Button(action: { tabManager.archiveTab(tab) }) {
                Image(systemName: "archivebox")
                    .font(.system(size: 12))
            }
            .buttonStyle(.plain)
            .help("Archive")
        }
    }
    
    // MARK: - Context Menu
    
    @ViewBuilder
    private var contextMenuContent: some View {
        Button(action: { tabManager.openTab(tab) }) {
            Label("Open in Browser", systemImage: "arrow.up.right.square")
        }
        
        Button(action: {
            if let url = URL(string: tab.url) {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(url.absoluteString, forType: .string)
            }
        }) {
            Label("Copy URL", systemImage: "doc.on.doc")
        }
        
        Divider()
        
        Button(action: { showingRenameSheet = true }) {
            Label("Rename", systemImage: "pencil")
        }
        
        Button(action: { tabManager.togglePin(tab) }) {
            Label(tab.pinned ? "Unpin" : "Pin", systemImage: tab.pinned ? "pin.slash.fill" : "pin.fill")
        }
        
        // Move to folder submenu
        if !tabManager.folders.isEmpty {
            Menu("Move to Folder") {
                Button("None (Unfiled)") {
                    tabManager.moveTab(tab, to: nil)
                }
                
                Divider()
                
                ForEach(tabManager.folders, id: \.id) { folder in
                    Button(folder.name) {
                        tabManager.moveTab(tab, to: folder)
                    }
                }
            }
        }
        
        Divider()
        
        Button(action: {
            Task {
                await tabManager.refreshMetadata(for: tab)
            }
        }) {
            Label("Refresh Metadata", systemImage: "arrow.clockwise")
        }
        
        Divider()
        
        Button(action: { tabManager.archiveTab(tab) }) {
            Label("Archive", systemImage: "archivebox")
        }
        
        Button(role: .destructive, action: { tabManager.deleteTab(tab) }) {
            Label("Delete", systemImage: "trash")
        }
    }
}

// MARK: - Compact Item View (Favicon only)

/// Compact grid item showing only favicon with tooltip
struct TabCompactItemView: View {
    let tab: PersistentTab
    
    @StateObject private var tabManager = TabManager.shared
    @State private var isHovered: Bool = false
    @State private var showingRenameSheet: Bool = false
    
    var body: some View {
        ZStack(alignment: .topTrailing) {
            FaviconView(urlString: tab.url)
                .frame(width: 28, height: 28)
            
            if tab.pinned {
                Circle()
                    .fill(Color.orange)
                    .frame(width: 6, height: 6)
                    .offset(x: 2, y: -2)
            }
        }
        .frame(width: 40, height: 40)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isHovered ? Color(NSColor.selectedContentBackgroundColor).opacity(0.4) : Color(NSColor.controlBackgroundColor).opacity(0.3))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color(NSColor.separatorColor).opacity(isHovered ? 0.6 : 0.2), lineWidth: 0.5)
        )
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.1)) {
                isHovered = hovering
            }
        }
        .onTapGesture {
            tabManager.openTab(tab)
        }
        .help("\(tab.displayTitle)\n\(tab.url)")
        .contextMenu {
            Button(action: { tabManager.openTab(tab) }) {
                Label("Open in Browser", systemImage: "arrow.up.right.square")
            }
            
            Button(action: {
                if let url = URL(string: tab.url) {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(url.absoluteString, forType: .string)
                }
            }) {
                Label("Copy URL", systemImage: "doc.on.doc")
            }
            
            Divider()
            
            Button(action: { showingRenameSheet = true }) {
                Label("Rename", systemImage: "pencil")
            }
            
            Button(action: { tabManager.togglePin(tab) }) {
                Label(tab.pinned ? "Unpin" : "Pin", systemImage: tab.pinned ? "pin.slash.fill" : "pin.fill")
            }
            
            Divider()
            
            Button(action: { tabManager.archiveTab(tab) }) {
                Label("Archive", systemImage: "archivebox")
            }
            
            Button(role: .destructive, action: { tabManager.deleteTab(tab) }) {
                Label("Delete", systemImage: "trash")
            }
        }
        .sheet(isPresented: $showingRenameSheet) {
            RenameTabSheet(tab: tab, isPresented: $showingRenameSheet)
        }
    }
}

// MARK: - Grid Item View

/// Grid item view for displaying tabs in grid mode
struct TabGridItemView: View {
    let tab: PersistentTab
    
    @StateObject private var tabManager = TabManager.shared
    @State private var isHovered: Bool = false
    @State private var showingRenameSheet: Bool = false
    
    var body: some View {
        VStack(spacing: 8) {
            // Favicon (larger in grid)
            ZStack(alignment: .topTrailing) {
                FaviconView(urlString: tab.url)
                    .frame(width: 32, height: 32)
                
                if tab.pinned {
                    Image(systemName: "pin.fill")
                        .font(.system(size: 8))
                        .foregroundColor(.orange)
                        .padding(4)
                        .background(Circle().fill(Color(NSColor.controlBackgroundColor)))
                        .offset(x: 6, y: -6)
                }
            }
            
            // Title
            HStack(spacing: 2) {
                Text(tab.displayTitle)
                    .font(.system(size: 11, weight: .medium))
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.primary)
                
                if tab.hasCustomTitle {
                    Image(systemName: "pencil.circle.fill")
                        .font(.system(size: 8))
                        .foregroundColor(.secondary.opacity(0.5))
                }
            }
            
            // Domain
            Text(tab.domain)
                .font(.system(size: 10))
                .foregroundColor(.secondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .padding(.horizontal, 8)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(isHovered ? Color(NSColor.selectedContentBackgroundColor).opacity(0.3) : Color(NSColor.controlBackgroundColor).opacity(0.5))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color(NSColor.separatorColor).opacity(isHovered ? 0.5 : 0.2), lineWidth: 0.5)
        )
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
        .onTapGesture {
            tabManager.openTab(tab)
        }
        .contextMenu {
            Button(action: { tabManager.openTab(tab) }) {
                Label("Open in Browser", systemImage: "arrow.up.right.square")
            }
            
            Button(action: {
                if let url = URL(string: tab.url) {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(url.absoluteString, forType: .string)
                }
            }) {
                Label("Copy URL", systemImage: "doc.on.doc")
            }
            
            Divider()
            
            Button(action: { showingRenameSheet = true }) {
                Label("Rename", systemImage: "pencil")
            }
            
            Button(action: { tabManager.togglePin(tab) }) {
                Label(tab.pinned ? "Unpin" : "Pin", systemImage: tab.pinned ? "pin.slash.fill" : "pin.fill")
            }
            
            Divider()
            
            Button(action: { tabManager.archiveTab(tab) }) {
                Label("Archive", systemImage: "archivebox")
            }
            
            Button(role: .destructive, action: { tabManager.deleteTab(tab) }) {
                Label("Delete", systemImage: "trash")
            }
        }
        .sheet(isPresented: $showingRenameSheet) {
            RenameTabSheet(tab: tab, isPresented: $showingRenameSheet)
        }
    }
}

// MARK: - Rename Tab Sheet

/// Sheet for renaming a tab
struct RenameTabSheet: View {
    let tab: PersistentTab
    @Binding var isPresented: Bool
    
    @StateObject private var tabManager = TabManager.shared
    @State private var customTitle: String = ""
    
    var body: some View {
        VStack(spacing: 20) {
            // Header
            HStack {
                Text("Rename Tab")
                    .font(.headline)
                
                Spacer()
                
                Button(action: { isPresented = false }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            
            // Current info
            HStack(spacing: 10) {
                FaviconView(urlString: tab.url)
                    .frame(width: 20, height: 20)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(tab.title)
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                    
                    Text(tab.domain)
                        .font(.system(size: 10))
                        .foregroundColor(.secondary.opacity(0.7))
                }
                
                Spacer()
            }
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(NSColor.controlBackgroundColor))
            )
            
            // Custom title input
            VStack(alignment: .leading, spacing: 6) {
                Text("Custom Title")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                TextField("Enter custom title...", text: $customTitle)
                    .textFieldStyle(.roundedBorder)
                
                Text("Leave empty to use the original title")
                    .font(.caption)
                    .foregroundColor(.secondary.opacity(0.7))
            }
            
            // Actions
            HStack(spacing: 12) {
                if tab.hasCustomTitle {
                    Button("Reset to Original") {
                        tabManager.renameTab(tab, to: "")
                        isPresented = false
                    }
                    .buttonStyle(.bordered)
                }
                
                Spacer()
                
                Button("Cancel") {
                    isPresented = false
                }
                .buttonStyle(.bordered)
                
                Button("Save") {
                    tabManager.renameTab(tab, to: customTitle)
                    isPresented = false
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(24)
        .frame(width: 340)
        .onAppear {
            customTitle = tab.customTitle ?? ""
        }
    }
}
