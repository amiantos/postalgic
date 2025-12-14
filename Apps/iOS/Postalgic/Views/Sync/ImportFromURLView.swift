//
//  ImportFromURLView.swift
//  Postalgic
//
//  Created by Claude on 12/14/25.
//

import SwiftUI
import SwiftData

struct ImportFromURLView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var urlString: String = ""
    @State private var password: String = ""
    @State private var isLoading = false
    @State private var isImporting = false
    @State private var error: String?
    @State private var manifest: SyncImporter.SyncManifest?
    @State private var importProgress: SyncImporter.ImportProgress?
    @State private var showPasswordField = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Site URL", text: $urlString)
                        .textContentType(.URL)
                        .keyboardType(.URL)
                        .autocapitalization(.none)
                        .autocorrectionDisabled()
                        .disabled(isImporting)

                    if showPasswordField {
                        SecureField("Sync Password", text: $password)
                            .disabled(isImporting)
                    }
                } header: {
                    Text("Sync URL")
                } footer: {
                    if showPasswordField {
                        Text("This blog has drafts that require a password to import.")
                    } else {
                        Text("Enter the URL of a published Postalgic site to import.")
                    }
                }

                if let manifest = manifest {
                    Section("Blog Info") {
                        LabeledContent("Name", value: manifest.blogName)
                        LabeledContent("Source", value: manifest.appSource.capitalized)
                        LabeledContent("Files", value: "\(manifest.files.count)")
                        if manifest.hasDrafts {
                            LabeledContent("Has Drafts", value: "Yes (encrypted)")
                        }
                    }
                }

                if let progress = importProgress {
                    Section("Import Progress") {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(progress.currentStep)
                                .font(.subheadline)
                                .foregroundColor(.secondary)

                            ProgressView(value: progress.progressFraction)
                                .progressViewStyle(.linear)

                            Text("\(progress.filesDownloaded) / \(progress.totalFiles) files")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 4)
                    }
                }

                if let error = error {
                    Section {
                        Text(error)
                            .foregroundColor(.red)
                            .font(.subheadline)
                    }
                }

                Section {
                    if manifest == nil {
                        Button(action: checkURL) {
                            if isLoading {
                                HStack {
                                    ProgressView()
                                        .progressViewStyle(.circular)
                                        .scaleEffect(0.8)
                                    Text("Checking...")
                                }
                            } else {
                                Text("Check URL")
                            }
                        }
                        .disabled(urlString.isEmpty || isLoading)
                    } else {
                        Button(action: startImport) {
                            if isImporting {
                                HStack {
                                    ProgressView()
                                        .progressViewStyle(.circular)
                                        .scaleEffect(0.8)
                                    Text("Importing...")
                                }
                            } else {
                                Text("Import Blog")
                            }
                        }
                        .disabled(isImporting || (showPasswordField && password.isEmpty))
                    }
                }
            }
            .navigationTitle("Import from URL")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .disabled(isImporting)
                }
            }
            .interactiveDismissDisabled(isImporting)
        }
    }

    private func checkURL() {
        guard !urlString.isEmpty else { return }

        isLoading = true
        error = nil
        manifest = nil
        showPasswordField = false

        Task {
            do {
                let fetchedManifest = try await SyncImporter.fetchManifest(from: urlString)
                await MainActor.run {
                    manifest = fetchedManifest
                    showPasswordField = fetchedManifest.hasDrafts
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.error = error.localizedDescription
                    isLoading = false
                }
            }
        }
    }

    private func startImport() {
        guard manifest != nil else { return }

        isImporting = true
        error = nil
        importProgress = SyncImporter.ImportProgress(
            currentStep: "Starting import...",
            filesDownloaded: 0,
            totalFiles: manifest!.files.count,
            isComplete: false
        )

        Task {
            do {
                let blog = try await SyncImporter.importBlog(
                    from: urlString,
                    password: showPasswordField ? password : nil,
                    modelContext: modelContext
                ) { progress in
                    Task { @MainActor in
                        importProgress = progress
                    }
                }

                await MainActor.run {
                    isImporting = false
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    self.error = error.localizedDescription
                    isImporting = false
                    importProgress = nil
                }
            }
        }
    }
}

#Preview {
    ImportFromURLView()
        .modelContainer(PreviewData.previewContainer)
}
