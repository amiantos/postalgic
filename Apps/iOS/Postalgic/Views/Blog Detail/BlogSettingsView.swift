//
//  BlogSettingsView.swift
//  Postalgic
//
//  Created by Brad Root on 4/29/25.
//

import SwiftData
import SwiftUI

struct BlogSettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    var blog: Blog
    var onDelete: (() -> Void)? = nil
    
    @State private var showingEditBlogView = false
    @State private var showingCategoryManagement = false
    @State private var showingTagManagement = false
    @State private var showingSidebarManagement = false
    @State private var showingPublishSettingsView = false
    @State private var showingTemplateCustomizationView = false
    @State private var showingDeleteAlert = false
    @State private var deleteConfirmationText = ""
    
    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button(action: { showingEditBlogView = true }) {
                        HStack {
                            Label("Blog Metadata", systemImage: "person")
                            Spacer()
                            Image(systemName: "chevron.right").foregroundColor(.secondary)
                        }
                    }
                    
                    Button(action: { showingSidebarManagement = true }) {
                        HStack {
                            Label("Sidebar Management", systemImage: "sidebar.right")
                            Spacer()
                            Image(systemName: "chevron.right").foregroundColor(.secondary)
                        }
                    }
                } header: {
                    Text("General")
                }
                
                Section {
                    Button(action: { showingCategoryManagement = true }) {
                        HStack {
                            Label("Categories", systemImage: "folder")
                            Spacer()
                            Image(systemName: "chevron.right").foregroundColor(.secondary)
                        }
                    }
                    
                    Button(action: { showingTagManagement = true }) {
                        HStack {
                            Label("Tags", systemImage: "tag")
                            Spacer()
                            Image(systemName: "chevron.right").foregroundColor(.secondary)
                        }
                    }
                } header: {
                    Text("Content Organization")
                }
                
                Section {
                    Button(action: { showingTemplateCustomizationView = true }) {
                        HStack {
                            Label("Templates", systemImage: "richtext.page")
                            Spacer()
                            Image(systemName: "chevron.right").foregroundColor(.secondary)
                        }
                    }
                    
                    Button(action: { showingPublishSettingsView = true }) {
                        HStack {
                            Label("Publishing Settings", systemImage: "paperplane")
                            Spacer()
                            Image(systemName: "chevron.right").foregroundColor(.secondary)
                        }
                    }
                    
                    Button {
                        if let url = URL(string: blog.url) {
                            UIApplication.shared.open(url)
                        }
                    } label: {
                        HStack {
                            Label("Visit Blog", systemImage: "safari")
                            Spacer()
                            Image(systemName: "arrow.up.right").foregroundColor(.secondary)
                        }
                    }
                } header: {
                    Text("Publishing")
                }
                
                Section {
                    Button(action: { showingDeleteAlert = true }) {
                        Label("Delete Blog", systemImage: "trash")
                            .foregroundStyle(.red)
                    }
                } footer: {
                    Text("Deleting a blog will permanently remove all of its posts and associated data.")
                }
            }
            .foregroundColor(.primary)
            .navigationTitle("Blog Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .sheet(isPresented: $showingEditBlogView) {
            BlogFormView(blog: blog).interactiveDismissDisabled()
        }
        .sheet(isPresented: $showingCategoryManagement) {
            CategoryManagementView(blog: blog)
        }
        .sheet(isPresented: $showingTagManagement) {
            TagManagementView(blog: blog)
        }
        .sheet(isPresented: $showingPublishSettingsView) {
            PublishSettingsView(blog: blog)
        }
        .sheet(isPresented: $showingTemplateCustomizationView) {
            TemplateCustomizationView(blog: blog).interactiveDismissDisabled()
        }
        .sheet(isPresented: $showingSidebarManagement) {
            SidebarManagementView(blog: blog)
        }
        .alert("Delete Blog", isPresented: $showingDeleteAlert) {
            TextField("Type 'delete' to confirm", text: $deleteConfirmationText)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)

            Button("Cancel", role: .cancel) {
                deleteConfirmationText = ""
            }

            Button("Delete", role: .destructive) {
                if deleteConfirmationText.lowercased() == "delete" {
                    deleteBlog()
                }
                deleteConfirmationText = ""
            }
            .disabled(deleteConfirmationText.lowercased() != "delete")
        } message: {
            Text(
                "This will permanently delete the blog '\(blog.name)' and all its posts.\n\nTo confirm, type 'delete' in the field below."
            )
        }
    }
    
    private func deleteBlog() {
        modelContext.delete(blog)
        try? modelContext.save()
        dismiss()
        
        // Call the onDelete callback to dismiss the parent view
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            onDelete?()
        }
    }
}

#Preview {
    let modelContainer = PreviewData.previewContainer

    return BlogSettingsView(
        blog: try! modelContainer.mainContext.fetch(FetchDescriptor<Blog>())
            .first!,
        onDelete: {}
    )
    .modelContainer(modelContainer)
}
