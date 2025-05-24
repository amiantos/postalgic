//
//  StaticFileFormView.swift
//  Postalgic
//
//  Created by Brad Root on 4/19/25.
//

import SwiftUI
import SwiftData
import PhotosUI
import UniformTypeIdentifiers

struct StaticFileFormView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    var blog: Blog
    var specialFileType: SpecialFileType?
    
    @State private var filename = ""
    @State private var selectedFileData: Data?
    @State private var selectedFileName: String?
    @State private var mimeType = ""
    @State private var showingPhotoPicker = false
    @State private var showingFilePicker = false
    @State private var showingErrorAlert = false
    @State private var errorMessage = ""
    @State private var photoPickerItem: PhotosPickerItem?
    
    private var isSpecialFile: Bool {
        specialFileType != nil
    }
    
    private var displayTitle: String {
        if let specialType = specialFileType {
            return "Add \(specialType.displayName)"
        }
        return "Add File"
    }
    
    private var canSave: Bool {
        guard selectedFileData != nil else { return false }
        
        if isSpecialFile {
            return true
        } else {
            return !filename.isEmpty && blog.isStaticFileNameUnique(filename)
        }
    }
    
    init(blog: Blog, specialFileType: SpecialFileType? = nil) {
        self.blog = blog
        self.specialFileType = specialFileType
        
        if let specialType = specialFileType {
            _filename = State(initialValue: specialType.rawValue)
        }
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section("File Selection") {
                    if selectedFileData != nil {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text("File selected: \(selectedFileName ?? "Unknown")")
                            Spacer()
                        }
                    } else {
                        Text("No file selected")
                            .foregroundColor(.secondary)
                    }
                    
                    Button("Choose from Photos") {
                        showingPhotoPicker = true
                    }
                    .disabled(selectedFileData != nil)
                    
                    Button("Choose from Files") {
                        showingFilePicker = true
                    }
                    .disabled(selectedFileData != nil)
                    
                    if selectedFileData != nil {
                        Button("Clear Selection") {
                            clearSelection()
                        }
                        .foregroundColor(.red)
                    }
                }
                
                if !isSpecialFile {
                    Section(header: Text("Filename"), footer: Text("Include the file extension. Use '/' to create subdirectories (e.g., 'images/logo.png').")) {
                        TextField("Enter filename", text: $filename)
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                        
                        if !filename.isEmpty && !blog.isStaticFileNameUnique(filename) {
                            Text("This filename already exists")
                                .foregroundColor(.red)
                                .font(.caption)
                        }
                    }
                } else {
                    Section("Filename") {
                        Text(filename)
                            .foregroundColor(.secondary)
                    }
                }
                
                if let data = selectedFileData {
                    Section("File Info") {
                        HStack {
                            Text("Size")
                            Spacer()
                            Text(ByteCountFormatter.string(fromByteCount: Int64(data.count), countStyle: .file))
                                .foregroundColor(.secondary)
                        }
                        
                        HStack {
                            Text("Type")
                            Spacer()
                            Text(mimeType.isEmpty ? "Unknown" : mimeType)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .navigationTitle(displayTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveFile()
                    }
                    .disabled(!canSave)
                }
            }
            .photosPicker(isPresented: $showingPhotoPicker, selection: $photoPickerItem, matching: .images)
            .fileImporter(isPresented: $showingFilePicker, allowedContentTypes: [.item], allowsMultipleSelection: false) { result in
                handleFileImport(result)
            }
            .onChange(of: photoPickerItem) { _, newItem in
                handlePhotoSelection(newItem)
            }
            .alert("Error", isPresented: $showingErrorAlert) {
                Button("OK") { }
            } message: {
                Text(errorMessage)
            }
        }
    }
    
    private func clearSelection() {
        selectedFileData = nil
        selectedFileName = nil
        mimeType = ""
        photoPickerItem = nil
    }
    
    private func handlePhotoSelection(_ item: PhotosPickerItem?) {
        guard let item = item else { return }
        
        Task {
            do {
                if let data = try await item.loadTransferable(type: Data.self) {
                    await MainActor.run {
                        selectedFileData = data
                        selectedFileName = "photo.\(item.supportedContentTypes.first?.preferredFilenameExtension ?? "jpg")"
                        mimeType = item.supportedContentTypes.first?.preferredMIMEType ?? "image/jpeg"
                    }
                }
            } catch {
                await MainActor.run {
                    errorMessage = "Failed to load photo: \(error.localizedDescription)"
                    showingErrorAlert = true
                }
            }
        }
    }
    
    private func handleFileImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            
            do {
                let data = try Data(contentsOf: url)
                selectedFileData = data
                selectedFileName = url.lastPathComponent
                
                // Determine MIME type
                if let contentType = UTType(filenameExtension: url.pathExtension) {
                    mimeType = contentType.preferredMIMEType ?? "application/octet-stream"
                } else {
                    mimeType = "application/octet-stream"
                }
            } catch {
                errorMessage = "Failed to load file: \(error.localizedDescription)"
                showingErrorAlert = true
            }
            
        case .failure(let error):
            errorMessage = "Failed to select file: \(error.localizedDescription)"
            showingErrorAlert = true
        }
    }
    
    private func saveFile() {
        guard let data = selectedFileData else { return }
        
        // If this is a special file, check if we need to replace an existing one
        if let specialType = specialFileType {
            // Remove existing special file of this type
            if let existingFile = blog.staticFiles.first(where: { $0.isSpecialFile && $0.fileType == specialType }) {
                modelContext.delete(existingFile)
            }
        }
        
        let staticFile = StaticFile(
            blog: blog,
            filename: filename,
            data: data,
            mimeType: mimeType,
            isSpecialFile: isSpecialFile,
            specialFileType: specialFileType
        )
        
        modelContext.insert(staticFile)
        blog.staticFiles.append(staticFile)
        
        do {
            try modelContext.save()
            dismiss()
        } catch {
            errorMessage = "Failed to save file: \(error.localizedDescription)"
            showingErrorAlert = true
        }
    }
}

#Preview {
    let modelContainer = PreviewData.previewContainer
    
    return NavigationStack {
        StaticFileFormView(blog: try! modelContainer.mainContext.fetch(FetchDescriptor<Blog>()).first!)
    }
    .modelContainer(modelContainer)
}