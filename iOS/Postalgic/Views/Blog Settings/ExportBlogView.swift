//
//  ExportBlogView.swift
//  Postalgic
//
//  Created by Claude on 12/9/25.
//

import SwiftData
import SwiftUI

struct ExportBlogView: View {
    @Bindable var blog: Blog

    @State private var includeCredentials = false
    @State private var isExporting = false
    @State private var exportedZipURL: URL?
    @State private var errorMessage: String?
    @State private var statusMessage: String = "Ready to export"
    @State private var showingShareSheet = false

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 30) {
                    // Header Section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Export \(blog.name)")
                            .font(.largeTitle)
                            .fontWeight(.bold)

                        Text("Export your blog data to a portable ZIP file. This export can be imported into the self-hosted version of Postalgic to create an exact copy of your blog.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    // Options Section
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Export Options")
                            .font(.title2)
                            .fontWeight(.bold)

                        Toggle(isOn: $includeCredentials) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Include Publishing Credentials")
                                    .font(.headline)
                                Text("AWS keys, SFTP passwords, Git tokens")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .toggleStyle(SwitchToggleStyle(tint: Color("PBlue")))
                        .padding()
                        .background(Color(.systemGray6))
                        .clipShape(RoundedRectangle(cornerRadius: 12))

                        if includeCredentials {
                            HStack(spacing: 12) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundStyle(.orange)
                                    .font(.title3)

                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Security Warning")
                                        .font(.headline)
                                        .foregroundStyle(.primary)

                                    Text("The exported ZIP file will contain your publishing credentials in plain text. Only share this file with trusted parties and delete it after import.")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                            }
                            .padding(16)
                            .background(.orange.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                    }

                    // What's Included Section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("What's Included")
                            .font(.title2)
                            .fontWeight(.bold)

                        VStack(alignment: .leading, spacing: 8) {
                            exportItem(icon: "doc.text", title: "All Posts", description: "\(blog.posts.count) posts including drafts")
                            exportItem(icon: "folder", title: "Categories", description: "\(blog.categories.count) categories")
                            exportItem(icon: "tag", title: "Tags", description: "\(blog.tags.count) tags")
                            exportItem(icon: "sidebar.right", title: "Sidebar Content", description: "\(blog.sidebarObjects.count) sidebar items")
                            exportItem(icon: "doc.on.doc", title: "Static Files", description: "\(blog.staticFiles.count) files")
                            exportItem(icon: "paintpalette", title: "Appearance", description: "Colors and theme settings")

                            if includeCredentials {
                                exportItem(icon: "key", title: "Credentials", description: "Publishing configuration")
                            }
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }

                    // Error Message
                    if let errorMessage = errorMessage {
                        HStack(spacing: 12) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.red)
                                .font(.title3)

                            VStack(alignment: .leading, spacing: 4) {
                                Text("Error")
                                    .font(.headline)
                                    .foregroundStyle(.primary)

                                Text(errorMessage)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                        }
                        .padding(16)
                        .background(.red.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }

                    // Export Progress Section
                    if isExporting {
                        VStack(spacing: 16) {
                            ProgressView()
                                .scaleEffect(1.2)

                            VStack(spacing: 8) {
                                Text("Exporting...")
                                    .font(.headline)
                                    .foregroundStyle(.primary)

                                Text(statusMessage)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                    .multilineTextAlignment(.center)
                            }
                        }
                        .padding(24)
                        .frame(maxWidth: .infinity)
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                    } else {
                        // Action Buttons
                        VStack(spacing: 12) {
                            if exportedZipURL != nil {
                                Button(action: {
                                    showingShareSheet = true
                                }) {
                                    Label("Share Export ZIP", systemImage: "square.and.arrow.up")
                                        .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(.borderedProminent)
                                .controlSize(.large)
                                .tint(Color("PBlue"))

                                Button(action: {
                                    exportedZipURL = nil
                                    errorMessage = nil
                                }) {
                                    Label("Create New Export", systemImage: "arrow.counterclockwise")
                                        .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.large)
                            } else {
                                Button(action: {
                                    exportBlog()
                                }) {
                                    Label("Export Blog", systemImage: "square.and.arrow.up")
                                        .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(.borderedProminent)
                                .controlSize(.large)
                                .tint(Color("PBlue"))
                            }
                        }
                    }
                }
                .padding()
            }
            .sheet(isPresented: $showingShareSheet) {
                if let zipURL = exportedZipURL {
                    ShareSheet(items: [zipURL])
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
        }
    }

    // MARK: - Helper Views

    private func exportItem(icon: String, title: String, description: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(Color("PBlue"))
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(Color("PGreen"))
        }
    }

    // MARK: - Export Logic

    private func exportBlog() {
        isExporting = true
        errorMessage = nil
        statusMessage = "Preparing export..."

        Task {
            do {
                let zipURL = try await BlogExportService.exportBlog(
                    blog,
                    includeCredentials: includeCredentials,
                    modelContext: modelContext
                ) { status in
                    DispatchQueue.main.async {
                        self.statusMessage = status
                    }
                }

                DispatchQueue.main.async {
                    self.exportedZipURL = zipURL
                    self.isExporting = false
                    self.statusMessage = "Export complete!"
                }
            } catch {
                DispatchQueue.main.async {
                    self.errorMessage = error.localizedDescription
                    self.isExporting = false
                    self.statusMessage = "Export failed"
                }
            }
        }
    }
}

#Preview {
    ExportBlogView(blog: PreviewData.blog)
        .modelContainer(PreviewData.previewContainer)
}
