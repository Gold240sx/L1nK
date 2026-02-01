import SwiftUI

/// Sheet/inline view for adding new tabs with folder selection
struct AddTabView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var tabManager = TabManager.shared
    
    @Binding var isPresented: Bool
    
    @State private var urlInput: String = ""
    @State private var selectedFolder: TabFolder?
    @State private var isLoading: Bool = false
    @State private var errorMessage: String?
    
    var body: some View {
        VStack(spacing: 20) {
            // Header
            HStack {
                Text("Add Tab")
                    .font(.headline)
                
                Spacer()
                
                Button(action: { isPresented = false }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            
            // URL input
            VStack(alignment: .leading, spacing: 6) {
                Text("URL")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                TextField("https://example.com", text: $urlInput)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit {
                        addTab()
                    }
            }
            
            // Folder selection
            if !tabManager.folders.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Folder (optional)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Picker("Folder", selection: $selectedFolder) {
                        Text("None").tag(nil as TabFolder?)
                        
                        ForEach(tabManager.folders, id: \.id) { folder in
                            HStack {
                                Circle()
                                    .fill(folder.color)
                                    .frame(width: 8, height: 8)
                                Text(folder.name)
                            }
                            .tag(folder as TabFolder?)
                        }
                    }
                    .pickerStyle(.menu)
                }
            }
            
            // Error message
            if let error = errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
            }
            
            // Actions
            HStack(spacing: 12) {
                Button("Cancel") {
                    isPresented = false
                }
                .buttonStyle(.bordered)
                
                Button("Add Tab") {
                    addTab()
                }
                .buttonStyle(.borderedProminent)
                .disabled(urlInput.isEmpty || isLoading)
            }
            
            if isLoading {
                HStack(spacing: 8) {
                    ProgressView()
                        .scaleEffect(0.7)
                    Text("Fetching metadata...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(24)
        .frame(width: 320)
    }
    
    private func addTab() {
        guard !urlInput.isEmpty else { return }
        
        isLoading = true
        errorMessage = nil
        
        Task {
            let tab = await tabManager.addTab(from: urlInput, to: selectedFolder)
            
            isLoading = false
            
            if tab != nil {
                urlInput = ""
                selectedFolder = nil
                isPresented = false
            } else {
                errorMessage = "Invalid URL or duplicate tab"
            }
        }
    }
}

// MARK: - Preview

#Preview {
    AddTabView(isPresented: .constant(true))
}
