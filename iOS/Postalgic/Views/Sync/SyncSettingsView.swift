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
        forceResyncProgress = "Deleting local content..."

        do {
            // Step 1: Delete all existing content
            for post in blog.posts {
                modelContext.delete(post)
            }
            for category in blog.categories {
                modelContext.delete(category)
            }
            for tag in blog.tags {
                modelContext.delete(tag)
            }
            for sidebar in blog.sidebarObjects {
                modelContext.delete(sidebar)
            }
            for file in blog.staticFiles {
                modelContext.delete(file)
            }

            // Step 2: Clear local sync hashes so everything appears as "new"
            blog.localSyncHashes = [:]
            blog.lastSyncedVersion = nil

            try modelContext.save()

            // Step 3: Use the existing IncrementalSync to pull all content
            await MainActor.run {
                forceResyncProgress = "Re-importing from remote..."
            }

            let result = try await IncrementalSync.pullChanges(
                blog: blog,
                modelContext: modelContext
            ) { progress in
                Task { @MainActor in
                    forceResyncProgress = progress.step
                }
            }

            await MainActor.run {
                forceResyncProgress = nil
                isForceResyncing = false
                syncResult = result
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
