//
//  RemoteTagManagementView.swift
//  Postalgic
//
//  Created by Claude on 2/18/26.
//

import SwiftUI

struct RemoteTagManagementView: View {
    let server: RemoteServer
    let blogId: String

    @State private var tags: [RemoteTag] = []
    @State private var isLoading = true
    @State private var errorMessage: String?

    // Add/Edit
    @State private var showingAddAlert = false
    @State private var showingEditAlert = false
    @State private var editingTag: RemoteTag?
    @State private var tagName = ""

    // Delete
    @State private var showingDeleteConfirmation = false
    @State private var deletingTag: RemoteTag?

    var body: some View {
        List {
            if isLoading {
                HStack {
                    ProgressView()
                        .padding(.trailing, 8)
                    Text("Loading tags...")
                        .foregroundStyle(.secondary)
                }
            } else if tags.isEmpty {
                ContentUnavailableView {
                    Label("No Tags", systemImage: "tag")
                } description: {
                    Text("Tags help readers discover related posts.")
                }
            } else {
                ForEach(tags.sorted { $0.name < $1.name }) { tag in
                    HStack {
                        Text(tag.name)
                            .font(.headline)
                        Spacer()
                        if let count = tag.postCount {
                            Text("\(count) posts")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        editingTag = tag
                        tagName = tag.name
                        showingEditAlert = true
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button(role: .destructive) {
                            deletingTag = tag
                            showingDeleteConfirmation = true
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
            }
        }
        .navigationTitle("Tags")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    tagName = ""
                    showingAddAlert = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .refreshable {
            await loadTags()
        }
        .alert("New Tag", isPresented: $showingAddAlert) {
            TextField("Tag name", text: $tagName)
            Button("Cancel", role: .cancel) {}
            Button("Create") { createTag() }
        }
        .alert("Edit Tag", isPresented: $showingEditAlert) {
            TextField("Tag name", text: $tagName)
            Button("Cancel", role: .cancel) {}
            Button("Save") { updateTag() }
        }
        .alert("Delete Tag", isPresented: $showingDeleteConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) { deleteTag() }
        } message: {
            Text("Are you sure? This tag will be removed from all posts.")
        }
        .onAppear {
            if isLoading {
                Task { await loadTags() }
            }
        }
    }

    private func loadTags() async {
        let client = PostalgicAPIClient(server: server)
        do {
            let fetched = try await client.fetchTags(blogId: blogId)
            await MainActor.run {
                tags = fetched
                isLoading = false
                errorMessage = nil
            }
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
                isLoading = false
            }
        }
    }

    private func createTag() {
        let name = tagName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }

        let client = PostalgicAPIClient(server: server)
        Task {
            do {
                let created = try await client.createTag(blogId: blogId, name: name)
                await MainActor.run {
                    tags.append(created)
                }
            } catch {
                await MainActor.run { errorMessage = error.localizedDescription }
            }
        }
    }

    private func updateTag() {
        guard let editing = editingTag else { return }
        let name = tagName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }

        let client = PostalgicAPIClient(server: server)
        Task {
            do {
                let updated = try await client.updateTag(blogId: blogId, tagId: editing.id, name: name)
                await MainActor.run {
                    if let index = tags.firstIndex(where: { $0.id == editing.id }) {
                        tags[index] = updated
                    }
                }
            } catch {
                await MainActor.run { errorMessage = error.localizedDescription }
            }
        }
    }

    private func deleteTag() {
        guard let deleting = deletingTag else { return }

        let client = PostalgicAPIClient(server: server)
        Task {
            do {
                try await client.deleteTag(blogId: blogId, tagId: deleting.id)
                await MainActor.run {
                    tags.removeAll { $0.id == deleting.id }
                }
            } catch {
                await MainActor.run { errorMessage = error.localizedDescription }
            }
        }
    }
}
