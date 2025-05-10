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
    @State private var showingAccentColorCustomization = false
    @State private var showingDeleteAlert = false
    @State private var deleteConfirmationText = ""
    @State private var showingStubMigrationAlert = false
    @State private var showingStubMigrationSuccessAlert = false
    @State private var migratedStubCounts: (posts: Int, categories: Int, tags: Int) = (0, 0, 0)
    
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

                    Button(action: { showingTemplateCustomizationView = true }) {
                        HStack {
                            Label("Templates", systemImage: "richtext.page")
                            Spacer()
                            Image(systemName: "chevron.right").foregroundColor(.secondary)
                        }
                    }

                    Button(action: { showingAccentColorCustomization = true }) {
                        HStack {
                            Label("Customize Accent Color", systemImage: "paintpalette")
                            Spacer()
                            Image(systemName: "chevron.right").foregroundColor(.secondary)
                        }
                    }
                } header: {
                    Text("General")
                }

                Section {
                    Button(action: { showingStubMigrationAlert = true }) {
                        HStack {
                            Label("Regenerate URL Stubs", systemImage: "link.badge.plus")
                            Spacer()
                        }
                    }
                } header: {
                    Text("Maintenance")
                } footer: {
                    Text("If some posts are not getting proper URL stubs when generating your site, use this option to regenerate all URL stubs.")
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
            .navigationTitle("Appearance")
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
        .sheet(isPresented: $showingAccentColorCustomization) {
            AccentColorCustomizationView(blog: blog)
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
        .alert("Regenerate URL Stubs", isPresented: $showingStubMigrationAlert) {
            Button("Cancel", role: .cancel) {}

            Button("Regenerate") {
                migrateStubs()
            }
        } message: {
            Text("This will regenerate URL-friendly stubs for all posts and create stubs for any categories or tags that don't have them. This is useful if you're having issues with posts not having proper URLs when generating your site.")
        }
        .alert("Stubs Generated", isPresented: $showingStubMigrationSuccessAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            let total = migratedStubCounts.posts + migratedStubCounts.categories + migratedStubCounts.tags

            if total > 0 {
                return Text("Successfully processed \(total) URL stubs:\n• Regenerated \(migratedStubCounts.posts) post stubs\n• Generated \(migratedStubCounts.categories) missing category stubs\n• Generated \(migratedStubCounts.tags) missing tag stubs")
            } else {
                return Text("No content found requiring URL stubs.")
            }
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
    
    /// Generates stubs for all posts, categories, and tags that don't have them already
    private func migrateStubs() {
        var postsUpdated = 0
        var categoriesUpdated = 0
        var tagsUpdated = 0

        // Force regenerate stubs for all posts (not just the ones without stubs)
        for post in blog.posts {
            // Force regeneration of stub regardless of current status
            post.regenerateStub()
            postsUpdated += 1
        }

        // Generate stubs for categories
        for category in blog.categories {
            if category.stub == nil || category.stub!.isEmpty {
                let generatedStub = Utils.generateStub(from: category.name)
                category.stub = blog.uniqueCategoryStub(generatedStub)
                categoriesUpdated += 1
            }
        }

        // Generate stubs for tags
        for tag in blog.tags {
            if tag.stub == nil || tag.stub!.isEmpty {
                let generatedStub = Utils.generateStub(from: tag.name)
                tag.stub = blog.uniqueTagStub(generatedStub)
                tagsUpdated += 1
            }
        }

        // Save changes
        try? modelContext.save()

        // Update counts for display in success alert
        migratedStubCounts = (postsUpdated, categoriesUpdated, tagsUpdated)
        showingStubMigrationSuccessAlert = true
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
