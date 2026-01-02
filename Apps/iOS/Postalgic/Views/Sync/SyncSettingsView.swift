//
//  SyncSettingsView.swift
//  Postalgic
//
//  Created by Claude on 12/14/25.
//

import SwiftUI
import SwiftData

struct SyncSettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    var blog: Blog

    @State private var syncEnabled: Bool
    @State private var showingDisableConfirmation = false

    // Sync Down state
    @State private var isCheckingChanges = false
    @State private var isSyncing = false
    @State private var syncCheckResult: SyncCheckResult?
    @State private var syncProgress: IncrementalSyncProgress?
    @State private var syncResult: IncrementalSyncResult?
    @State private var syncError: String?

    // Force re-sync state
    @State private var showingForceResyncConfirmation = false
    @State private var isForceResyncing = false
    @State private var forceResyncProgress: String?
    @State private var forceResyncError: String?

    init(blog: Blog) {
        self.blog = blog
        _syncEnabled = State(initialValue: blog.syncEnabled)
    }

    var body: some View {
        NavigationStack {
            Form {
                if blog.syncEnabled {
                    // Sync is enabled - show toggle to disable and status
                    Section {
                        Toggle("Enable Sync", isOn: $syncEnabled)
                            .onChange(of: syncEnabled) { oldValue, newValue in
                                if !newValue {
                                    showingDisableConfirmation = true
                                }
                            }
                    } header: {
                        Text("Sync Status")
                    } footer: {
                        if let lastSynced = blog.lastSyncedAt {
                            Text("Last synced: \(lastSynced.formatted(date: .abbreviated, time: .shortened))")
                        } else {
                            Text("Sync data will be generated when you publish your blog.")
                        }
                    }

                    // Sync Down section
                    Section {
                        if isCheckingChanges {
                            HStack {
                                ProgressView()
                                    .padding(.trailing, 8)
                                Text("Checking for changes...")
                            }
                        } else if isSyncing {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    ProgressView()
                                        .padding(.trailing, 8)
                                    Text(syncProgress?.step ?? "Syncing...")
                                }
                                if let progress = syncProgress {
                                    ProgressView(value: progress.progress)
                                }
                            }
                        } else if let result = syncResult {
                            HStack {
                                Image(systemName: result.success ? "checkmark.circle.fill" : "xmark.circle.fill")
                                    .foregroundColor(result.success ? .green : .red)
                                Text(result.message)
                            }
                        } else if let checkResult = syncCheckResult {
                            if checkResult.hasChanges {
                                VStack(alignment: .leading, spacing: 8) {
                                    HStack {
                                        Image(systemName: "arrow.down.circle.fill")
                                            .foregroundColor(.blue)
                                        Text("Changes available")
                                    }
                                    Text(checkResult.changeSummary)
                                        .font(.caption)
                                        .foregroundColor(.secondary)

                                    Button {
                                        Task { await pullChanges() }
                                    } label: {
                                        HStack {
                                            Spacer()
                                            Label("Pull Changes", systemImage: "arrow.down.circle")
                                            Spacer()
                                        }
                                    }
                                    .buttonStyle(.borderedProminent)
                                }
                            } else {
                                HStack {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.green)
                                    Text("Up to date")
                                }
                            }
                        } else {
                            Button {
                                Task { await checkForChanges() }
                            } label: {
                                HStack {
                                    Spacer()
                                    Label("Check for Changes", systemImage: "arrow.triangle.2.circlepath")
                                    Spacer()
                                }
                            }
                        }

                        if let error = syncError {
                            Text(error)
                                .foregroundColor(.red)
                                .font(.caption)
                        }
                    } header: {
                        Text("Sync Down")
                    } footer: {
                        Text("Pull changes from your published site to update this device.")
                    }

                    // Force Re-sync section
                    Section {
                        if isForceResyncing {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    ProgressView()
                                        .padding(.trailing, 8)
                                    Text(forceResyncProgress ?? "Re-syncing...")
                                }
                            }
                        } else {
                            Button(role: .destructive) {
                                showingForceResyncConfirmation = true
                            } label: {
                                HStack {
                                    Spacer()
                                    Label("Force Re-sync (Reset)", systemImage: "arrow.counterclockwise.circle")
                                    Spacer()
                                }
                            }
                        }

                        if let error = forceResyncError {
                            Text(error)
                                .foregroundColor(.red)
                                .font(.caption)
                        }
                    } header: {
                        Text("Recovery")
                    } footer: {
                        Text("Erases all posts, categories, and tags from this device and re-imports everything from the remote site. Publishing settings are preserved.")
                    }
                } else {
                    // Sync is not enabled - show setup form
                    Section {
                        Button {
                            enableSync()
                        } label: {
                            HStack {
                                Spacer()
                                Text("Enable Sync")
                                Spacer()
                            }
                        }
                    } header: {
                        Text("Setup Sync")
                    } footer: {
                        Text("When enabled, sync data will be generated alongside your published site, allowing you to import your blog on other devices. Draft posts stay local to each device and are not synced.")
                    }
                }
            }
            .navigationTitle("Sync Settings")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
            .alert("Disable Sync", isPresented: $showingDisableConfirmation) {
                Button("Cancel", role: .cancel) {
                    syncEnabled = true
                }
                Button("Disable", role: .destructive) {
                    disableSync()
                }
            } message: {
                Text("This will stop generating sync data when you publish.")
            }
            .alert("Force Re-sync", isPresented: $showingForceResyncConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Reset & Re-sync", role: .destructive) {
                    Task { await forceResync() }
                }
            } message: {
                Text("This will delete ALL posts, categories, tags, and sidebar content from this device and re-import everything from the remote site. Your publishing settings (AWS, SFTP, Git) will be preserved. This cannot be undone.")
            }
        }
    }

    private func enableSync() {
        blog.syncEnabled = true
        try? modelContext.save()
        syncEnabled = true
    }

    private func disableSync() {
        blog.syncEnabled = false
        try? modelContext.save()
        syncEnabled = false
    }

    private func checkForChanges() async {
        isCheckingChanges = true
        syncError = nil
        syncCheckResult = nil
        syncResult = nil

        do {
            let result = try await SyncChecker.checkForChanges(blog: blog)
            await MainActor.run {
                syncCheckResult = result
                isCheckingChanges = false
            }
        } catch {
            await MainActor.run {
                syncError = error.localizedDescription
                isCheckingChanges = false
            }
        }
    }

    private func pullChanges() async {
        isSyncing = true
        syncError = nil

        do {
            let result = try await IncrementalSync.pullChanges(
                blog: blog,
                modelContext: modelContext
            ) { progress in
                Task { @MainActor in
                    syncProgress = progress
                }
            }

            await MainActor.run {
                syncResult = result
                syncCheckResult = nil
                isSyncing = false
            }
        } catch {
            await MainActor.run {
                syncError = error.localizedDescription
                isSyncing = false
            }
        }
    }

    /// Force re-sync: Delete all content and re-import from remote, keeping publishing settings
    private func forceResync() async {
        isForceResyncing = true
        forceResyncError = nil
        forceResyncProgress = "Preparing..."

        do {
            // Step 1: Delete all existing content
            await MainActor.run {
                forceResyncProgress = "Deleting local content..."
            }

            // Delete posts
            for post in blog.posts {
                modelContext.delete(post)
            }

            // Delete categories
            for category in blog.categories {
                modelContext.delete(category)
            }

            // Delete tags
            for tag in blog.tags {
                modelContext.delete(tag)
            }

            // Delete sidebar objects
            for sidebar in blog.sidebarObjects {
                modelContext.delete(sidebar)
            }

            // Delete static files
            for file in blog.staticFiles {
                modelContext.delete(file)
            }

            // Delete custom theme if exists
            if let theme = blog.customTheme {
                modelContext.delete(theme)
                blog.customTheme = nil
            }

            // Clear local sync hashes
            blog.localSyncHashes = [:]
            blog.lastSyncedVersion = nil

            try modelContext.save()

            // Step 2: Fetch manifest and re-import all content
            await MainActor.run {
                forceResyncProgress = "Fetching remote data..."
            }

            let baseURL = SyncImporter.normalizeURL(blog.url)

            // Fetch manifest
            let manifest = try await SyncImporter.fetchManifest(from: baseURL)

            // Step 3: Download and import blog settings (but preserve publishing config)
            await MainActor.run {
                forceResyncProgress = "Importing blog settings..."
            }

            let blogData = try await SyncImporter.downloadFile(from: "\(baseURL)/sync/blog.json")
            let decoder = JSONDecoder()
            let syncBlog = try decoder.decode(SyncDataGenerator.SyncBlog.self, from: blogData)

            // Update blog metadata (but NOT publishing settings)
            blog.name = syncBlog.name
            blog.tagline = syncBlog.tagline
            blog.authorName = syncBlog.authorName
            blog.authorUrl = syncBlog.authorUrl
            blog.authorEmail = syncBlog.authorEmail
            blog.accentColor = syncBlog.colors.accent
            blog.backgroundColor = syncBlog.colors.background
            blog.textColor = syncBlog.colors.text
            blog.postsPerPage = syncBlog.postsPerPage
            blog.timeZoneIdentifier = syncBlog.timeZoneIdentifier
            blog.selectedTheme = syncBlog.theme

            var fileHashes: [String: String] = [:]
            fileHashes["blog.json"] = blogData.sha256Hash()

            // Step 4: Import categories
            await MainActor.run {
                forceResyncProgress = "Importing categories..."
            }

            let categoriesIndexData = try await SyncImporter.downloadFile(from: "\(baseURL)/sync/categories/index.json")
            let categoryIds = try decoder.decode([String].self, from: categoriesIndexData)
            fileHashes["categories/index.json"] = categoriesIndexData.sha256Hash()

            for categoryId in categoryIds {
                let categoryData = try await SyncImporter.downloadFile(from: "\(baseURL)/sync/categories/\(categoryId).json")
                let syncCategory = try decoder.decode(SyncDataGenerator.SyncCategory.self, from: categoryData)

                let category = Category(name: syncCategory.name, blog: blog)
                category.categoryDescription = syncCategory.description
                category.stub = syncCategory.stub
                category.syncId = syncCategory.id
                modelContext.insert(category)

                fileHashes["categories/\(categoryId).json"] = categoryData.sha256Hash()
            }

            // Step 5: Import tags
            await MainActor.run {
                forceResyncProgress = "Importing tags..."
            }

            let tagsIndexData = try await SyncImporter.downloadFile(from: "\(baseURL)/sync/tags/index.json")
            let tagIds = try decoder.decode([String].self, from: tagsIndexData)
            fileHashes["tags/index.json"] = tagsIndexData.sha256Hash()

            for tagId in tagIds {
                let tagData = try await SyncImporter.downloadFile(from: "\(baseURL)/sync/tags/\(tagId).json")
                let syncTag = try decoder.decode(SyncDataGenerator.SyncTag.self, from: tagData)

                let tag = Tag(name: syncTag.name, blog: blog)
                tag.stub = syncTag.stub
                tag.syncId = syncTag.id
                modelContext.insert(tag)

                fileHashes["tags/\(tagId).json"] = tagData.sha256Hash()
            }

            // Step 6: Import embed images (before posts since posts reference them)
            await MainActor.run {
                forceResyncProgress = "Importing embed images..."
            }

            if let embedImagesFiles = manifest.files.filter({ $0.key.hasPrefix("embed-images/") && !$0.key.hasSuffix("index.json") }).keys.sorted() as? [String], !embedImagesFiles.isEmpty {
                for filePath in embedImagesFiles {
                    let imageData = try await SyncImporter.downloadFile(from: "\(baseURL)/sync/\(filePath)")
                    let filename = (filePath as NSString).lastPathComponent

                    // Save to embed images directory
                    let embedImagesDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                        .appendingPathComponent("embed-images")
                    try FileManager.default.createDirectory(at: embedImagesDir, withIntermediateDirectories: true)
                    let fileURL = embedImagesDir.appendingPathComponent(filename)
                    try imageData.write(to: fileURL)

                    fileHashes[filePath] = imageData.sha256Hash()
                }
            }

            // Step 7: Import posts
            await MainActor.run {
                forceResyncProgress = "Importing posts..."
            }

            let postsIndexData = try await SyncImporter.downloadFile(from: "\(baseURL)/sync/posts/index.json")
            let postIds = try decoder.decode([String].self, from: postsIndexData)
            fileHashes["posts/index.json"] = postsIndexData.sha256Hash()

            // Build lookup maps for categories and tags
            let categoryMap = Dictionary(uniqueKeysWithValues: blog.categories.compactMap { cat -> (String, Category)? in
                guard let syncId = cat.syncId else { return nil }
                return (syncId, cat)
            })
            let tagMap = Dictionary(uniqueKeysWithValues: blog.tags.compactMap { tag -> (String, Tag)? in
                guard let syncId = tag.syncId else { return nil }
                return (syncId, tag)
            })

            for postId in postIds {
                let postData = try await SyncImporter.downloadFile(from: "\(baseURL)/sync/posts/\(postId).json")
                let syncPost = try decoder.decode(SyncDataGenerator.SyncPost.self, from: postData)

                let post = Post(title: syncPost.title, content: syncPost.content, blog: blog)
                post.stub = syncPost.stub
                post.isDraft = false
                post.syncId = syncPost.id

                // Parse date
                let dateFormatter = ISO8601DateFormatter()
                dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                if let date = dateFormatter.date(from: syncPost.createdAt) {
                    post.createdAt = date
                } else {
                    dateFormatter.formatOptions = [.withInternetDateTime]
                    if let date = dateFormatter.date(from: syncPost.createdAt) {
                        post.createdAt = date
                    }
                }

                // Link category
                if let catId = syncPost.categoryId, let category = categoryMap[catId] {
                    post.category = category
                }

                // Link tags
                if let tagIds = syncPost.tagIds {
                    for tagId in tagIds {
                        if let tag = tagMap[tagId] {
                            post.tags.append(tag)
                        }
                    }
                }

                modelContext.insert(post)
                fileHashes["posts/\(postId).json"] = postData.sha256Hash()
            }

            // Step 8: Import sidebar objects
            await MainActor.run {
                forceResyncProgress = "Importing sidebar..."
            }

            let sidebarIndexData = try await SyncImporter.downloadFile(from: "\(baseURL)/sync/sidebar/index.json")
            let sidebarIds = try decoder.decode([String].self, from: sidebarIndexData)
            fileHashes["sidebar/index.json"] = sidebarIndexData.sha256Hash()

            for sidebarId in sidebarIds {
                let sidebarData = try await SyncImporter.downloadFile(from: "\(baseURL)/sync/sidebar/\(sidebarId).json")
                let syncSidebar = try decoder.decode(SyncDataGenerator.SyncSidebarObject.self, from: sidebarData)

                let sidebar = SidebarObject(type: SidebarObjectType(rawValue: syncSidebar.type) ?? .text, blog: blog)
                sidebar.title = syncSidebar.title
                sidebar.content = syncSidebar.content
                sidebar.links = syncSidebar.links?.map { link in
                    SidebarLink(title: link.title, url: link.url)
                } ?? []
                sidebar.order = syncSidebar.order
                sidebar.syncId = syncSidebar.id
                modelContext.insert(sidebar)

                fileHashes["sidebar/\(sidebarId).json"] = sidebarData.sha256Hash()
            }

            // Step 9: Update sync state
            blog.localSyncHashes = fileHashes
            blog.lastSyncedVersion = manifest.contentVersion
            blog.lastSyncedAt = Date()

            try modelContext.save()

            await MainActor.run {
                forceResyncProgress = nil
                isForceResyncing = false
                syncResult = IncrementalSyncResult(success: true, message: "Re-sync complete!", updated: true)
                syncCheckResult = nil
            }
        } catch {
            await MainActor.run {
                forceResyncError = error.localizedDescription
                isForceResyncing = false
                forceResyncProgress = nil
            }
        }
    }
}

#Preview {
    let modelContainer = PreviewData.previewContainer

    return SyncSettingsView(
        blog: try! modelContainer.mainContext.fetch(FetchDescriptor<Blog>()).first!
    )
    .modelContainer(modelContainer)
}
