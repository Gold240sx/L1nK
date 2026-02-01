import SwiftUI

/// Folder header row with expand/collapse, tab count, and color indicator
struct FolderRowView: View {
    let folder: TabFolder
    let isExpanded: Bool
    let toggleExpand: () -> Void
    
    @StateObject private var tabManager = TabManager.shared
    @State private var isHovered: Bool = false
    @State private var isEditing: Bool = false
    @State private var editedName: String = ""
    @State private var showingColorPicker: Bool = false
    @State private var showingIconPicker: Bool = false
    
    var body: some View {
        HStack(spacing: 8) {
            // Expand/collapse chevron
            Button(action: toggleExpand) {
                Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.secondary)
                    .frame(width: 12)
            }
            .buttonStyle(.plain)
            
            // Folder icon with color
            Image(systemName: folder.icon)
                .font(.system(size: 12))
                .foregroundColor(folder.color)
                .frame(width: 16)
            
            // Folder name (editable)
            if isEditing {
                TextField("Folder name", text: $editedName, onCommit: {
                    if !editedName.isEmpty {
                        tabManager.renameFolder(folder, to: editedName)
                    }
                    isEditing = false
                })
                .textFieldStyle(.plain)
                .font(.system(size: 13, weight: .medium))
            } else {
                Text(folder.name)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.primary)
            }
            
            // Tab count
            Text("\(folder.tabCount)")
                .font(.system(size: 11))
                .foregroundColor(.secondary)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(
                    Capsule()
                        .fill(Color.secondary.opacity(0.15))
                )
            
            Spacer()
            
            // Hover actions
            if isHovered && !isEditing {
                hoverActions
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isHovered ? Color(NSColor.selectedContentBackgroundColor).opacity(0.2) : Color.clear)
        )
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
        .onTapGesture {
            toggleExpand()
        }
        .contextMenu {
            contextMenuContent
        }
        .popover(isPresented: $showingColorPicker) {
            colorPickerView
        }
        .popover(isPresented: $showingIconPicker) {
            iconPickerView
        }
    }
    
    // MARK: - Hover Actions
    
    private var hoverActions: some View {
        HStack(spacing: 6) {
            // Edit name
            Button(action: {
                editedName = folder.name
                isEditing = true
            }) {
                Image(systemName: "pencil")
                    .font(.system(size: 11))
            }
            .buttonStyle(.plain)
            .help("Rename")
            
            // Change icon
            Button(action: { showingIconPicker = true }) {
                Image(systemName: "square.grid.2x2")
                    .font(.system(size: 11))
            }
            .buttonStyle(.plain)
            .help("Change icon")
            
            // Change color
            Button(action: { showingColorPicker = true }) {
                Image(systemName: "paintpalette")
                    .font(.system(size: 11))
            }
            .buttonStyle(.plain)
            .help("Change color")
        }
    }
    
    // MARK: - Context Menu
    
    @ViewBuilder
    private var contextMenuContent: some View {
        Button(action: {
            editedName = folder.name
            isEditing = true
        }) {
            Label("Rename", systemImage: "pencil")
        }
        
        Button(action: { showingIconPicker = true }) {
            Label("Change Icon", systemImage: "square.grid.2x2")
        }
        
        Button(action: { showingColorPicker = true }) {
            Label("Change Color", systemImage: "paintpalette")
        }
        
        Divider()
        
        Button(role: .destructive, action: {
            tabManager.deleteFolder(folder)
        }) {
            Label("Delete Folder", systemImage: "trash")
        }
    }
    
    // MARK: - Color Picker
    
    private var colorPickerView: some View {
        VStack(spacing: 12) {
            Text("Folder Color")
                .font(.headline)
            
            LazyVGrid(columns: Array(repeating: GridItem(.fixed(32)), count: 5), spacing: 12) {
                ForEach(TabFolder.availableColors, id: \.self) { color in
                    Circle()
                        .fill(color)
                        .frame(width: 28, height: 28)
                        .overlay(
                            Circle()
                                .stroke(Color.primary.opacity(folder.color == color ? 0.5 : 0), lineWidth: 2)
                        )
                        .onTapGesture {
                            tabManager.setFolderColor(folder, color: color)
                            showingColorPicker = false
                        }
                }
            }
        }
        .padding(16)
    }
    
    // MARK: - Icon Picker
    
    private var iconPickerView: some View {
        VStack(spacing: 12) {
            Text("Folder Icon")
                .font(.headline)
            
            LazyVGrid(columns: Array(repeating: GridItem(.fixed(36)), count: 5), spacing: 10) {
                ForEach(TabFolder.availableIcons, id: \.self) { iconName in
                    ZStack {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(folder.icon == iconName ? folder.color.opacity(0.2) : Color.clear)
                            .frame(width: 32, height: 32)
                        
                        Image(systemName: iconName)
                            .font(.system(size: 14))
                            .foregroundColor(folder.icon == iconName ? folder.color : .secondary)
                    }
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(folder.icon == iconName ? folder.color : Color.clear, lineWidth: 1.5)
                    )
                    .onTapGesture {
                        tabManager.setFolderIcon(folder, icon: iconName)
                        showingIconPicker = false
                    }
                }
            }
        }
        .padding(16)
        .frame(width: 220)
    }
}

// MARK: - Preview

#Preview {
    VStack {
        FolderRowView(
            folder: TabFolder(name: "Work", colorHex: "#007AFF"),
            isExpanded: true,
            toggleExpand: {}
        )
        
        FolderRowView(
            folder: TabFolder(name: "Personal", colorHex: "#34C759"),
            isExpanded: false,
            toggleExpand: {}
        )
    }
    .frame(width: 300)
    .padding()
}
