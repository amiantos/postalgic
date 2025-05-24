//
//  StaticFilesView.swift
//  Postalgic
//
//  Created by Brad Root on 4/19/25.
//

import SwiftData
import SwiftUI

struct StaticFilesView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    var blog: Blog

    @Query private var staticFiles: [StaticFile]
    
    @State private var showingAddFile = false
    @State private var showingAddFavicon = false
    @State private var showingAddSocialShareImage = false
    
    init(blog: Blog) {
        self.blog = blog
        let id = blog.persistentModelID
        let predicate = #Predicate<StaticFile> { staticFile in
            staticFile.blog?.persistentModelID == id
        }
        self._staticFiles = Query(filter: predicate, sort: \StaticFile.filename)
    }

    var body: some View {
        NavigationStack {
            List {
                // Special Files Section
                Section("Special Files") {
                    specialFileRow(
                        title: "Favicon",
                        description: "Icon that appears in browser tabs",
                        systemImage: "globe",
                        file: blog.favicon,
                        action: { showingAddFavicon = true }
                    )
                    
                    specialFileRow(
                        title: "Social Share Image",
                        description: "Image used when sharing on social media",
                        systemImage: "square.and.arrow.up",
                        file: blog.socialShareImage,
                        action: { showingAddSocialShareImage = true }
                    )
                }
                
                // Regular Files Section
                Section("Custom Files") {
                    if regularFiles.isEmpty {
                        Text("No custom files yet. Add files to include in your static site.")
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.vertical)
                    } else {
                        ForEach(regularFiles) { file in
                            StaticFileRowView(staticFile: file)
                        }
                        .onDelete(perform: deleteFiles)
                    }
                }
            }
            .navigationTitle("Static Files")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        showingAddFile = true
                    }) {
                        Image(systemName: "plus")
                    }
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showingAddFile) {
                StaticFileFormView(blog: blog).interactiveDismissDisabled()
            }
            .sheet(isPresented: $showingAddFavicon) {
                StaticFileFormView(blog: blog, specialFileType: .favicon).interactiveDismissDisabled()
            }
            .sheet(isPresented: $showingAddSocialShareImage) {
                StaticFileFormView(blog: blog, specialFileType: .socialShareImage).interactiveDismissDisabled()
            }
        }
    }
    
    private var regularFiles: [StaticFile] {
        return staticFiles.filter { !$0.isSpecialFile }
    }
    
    private func specialFileRow(title: String, description: String, systemImage: String, file: StaticFile?, action: @escaping () -> Void) -> some View {
        HStack {
            Label(title, systemImage: systemImage)
            
            Spacer()
            
            if let file = file {
                VStack(alignment: .trailing, spacing: 2) {
                    HStack(spacing: 8) {
                        Button("Replace") {
                            action()
                        }
                        .font(.caption)
                        .buttonStyle(.bordered)
                        
                        Button("Remove") {
                            deleteSpecialFile(file)
                        }
                        .font(.caption)
                        .buttonStyle(.bordered)
                        .foregroundColor(.red)
                    }
                    
                    Text(file.fileSizeString)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            } else {
                Button("Add") {
                    action()
                }
                .font(.caption)
                .buttonStyle(.bordered)
            }
        }
    }

    private func deleteFiles(at offsets: IndexSet) {
        for index in offsets {
            let fileToDelete = regularFiles[index]
            modelContext.delete(fileToDelete)
        }
        try? modelContext.save()
    }
    
    private func deleteSpecialFile(_ file: StaticFile) {
        modelContext.delete(file)
        try? modelContext.save()
    }
}

struct StaticFileRowView: View {
    let staticFile: StaticFile

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(staticFile.filename)
                    .font(.headline)

                HStack {
                    Text(staticFile.fileSizeString)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    if staticFile.isImage {
                        Text("• Image")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            
            Spacer()
            
            if staticFile.isImage {
                Image(systemName: "photo")
                    .foregroundColor(.blue)
            } else {
                Image(systemName: "doc")
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    let modelContainer = PreviewData.previewContainer
    
    return NavigationStack {
        StaticFilesView(blog: try! modelContainer.mainContext.fetch(FetchDescriptor<Blog>()).first!)
    }
    .modelContainer(modelContainer)
}