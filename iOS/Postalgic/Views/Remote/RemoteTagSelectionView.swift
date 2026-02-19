//
//  RemoteTagSelectionView.swift
//  Postalgic
//
//  Created by Claude on 2/18/26.
//

import SwiftUI

struct RemoteTagSelectionView: View {
    @Environment(\.dismiss) private var dismiss

    let server: RemoteServer
    let blogId: String
    @Binding var selectedTagIds: [String]
    @Binding var selectedTagNames: [String]

    @State private var tags: [RemoteTag] = []
    @State private var isLoading = true
    @State private var errorMessage: String?

    @State private var tagInput = ""
    @State private var showingSuggestions = false
    @State private var isCreating = false

    private var filteredTags: [RemoteTag] {
        if tagInput.isEmpty {
            return tags.sorted { $0.name < $1.name }
        } else {
            let lowercased = tagInput.lowercased()
            return tags.filter { $0.name.lowercased().contains(lowercased) }
                .sorted { $0.name < $1.name }
        }
    }

    var body: some View {
        VStack {
            // Tag input
            HStack {
                TextField("Add tags...", text: $tagInput)
                    .autocorrectionDisabled()
                    .padding(.horizontal)
                    .padding(.vertical, 10)
                    .background(.background.secondary)
                    .foregroundStyle(.primary)
                    .cornerRadius(8)
                    .padding(.trailing, 8)
                    .onSubmit {
                        addTag()
                    }
                    .onChange(of: tagInput) { _, newValue in
                        let lowercased = newValue.lowercased()
                        if lowercased != newValue {
                            tagInput = lowercased
                        }
                        showingSuggestions = !newValue.isEmpty
                    }

                Button(action: addTag) {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                }
                .disabled(tagInput.isEmpty || isCreating)
            }
            .padding(.horizontal)
            .padding(.top)

            // Selected tags
            if !selectedTagIds.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack {
                        ForEach(Array(zip(selectedTagIds, selectedTagNames)), id: \.0) { tagId, tagName in
                            HStack(spacing: 5) {
                                Text(tagName).foregroundStyle(.primary)
                                Button {
                                    removeTag(id: tagId)
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.caption)
                                }
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(.background.secondary)
                            .cornerRadius(8)
                        }
                    }
                    .padding(.vertical, 5)
                    .padding(.horizontal)
                }
                .frame(height: 40)
            }

            // Tag list
            List {
                if isLoading {
                    HStack {
                        ProgressView()
                            .padding(.trailing, 8)
                        Text("Loading tags...")
                            .foregroundStyle(.secondary)
                    }
                } else if let errorMessage {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                } else {
                    if showingSuggestions && !filteredTags.isEmpty {
                        Section("Suggestions") {
                            ForEach(filteredTags) { tag in
                                tagRow(tag)
                            }
                        }
                    }

                    Section("All Tags") {
                        if tags.isEmpty {
                            Text("No tags yet. Type above to create one.")
                                .foregroundColor(.secondary)
                                .frame(maxWidth: .infinity, alignment: .center)
                                .padding(.vertical)
                        } else {
                            ForEach(tags.sorted { $0.name < $1.name }) { tag in
                                tagRow(tag)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Select Tags")
        .onAppear {
            loadTags()
        }
    }

    private func tagRow(_ tag: RemoteTag) -> some View {
        Button {
            toggleTag(tag)
        } label: {
            HStack {
                VStack(alignment: .leading) {
                    Text(tag.name)
                    if let count = tag.postCount {
                        Text("\(count) posts")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                if selectedTagIds.contains(tag.id) {
                    Image(systemName: "checkmark")
                        .foregroundStyle(Color.accentColor)
                }
            }
        }
        .foregroundColor(.primary)
    }

    private func toggleTag(_ tag: RemoteTag) {
        if let index = selectedTagIds.firstIndex(of: tag.id) {
            selectedTagIds.remove(at: index)
            if index < selectedTagNames.count {
                selectedTagNames.remove(at: index)
            }
        } else {
            selectedTagIds.append(tag.id)
            selectedTagNames.append(tag.name)
        }
    }

    private func removeTag(id: String) {
        if let index = selectedTagIds.firstIndex(of: id) {
            selectedTagIds.remove(at: index)
            if index < selectedTagNames.count {
                selectedTagNames.remove(at: index)
            }
        }
    }

    private func addTag() {
        let name = tagInput.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !name.isEmpty else { return }

        // Check if tag already exists
        if let existing = tags.first(where: { $0.name.lowercased() == name }) {
            if !selectedTagIds.contains(existing.id) {
                selectedTagIds.append(existing.id)
                selectedTagNames.append(existing.name)
            }
            tagInput = ""
            showingSuggestions = false
            return
        }

        // Create new tag on server
        isCreating = true
        let client = PostalgicAPIClient(server: server)

        Task {
            do {
                let created = try await client.createTag(blogId: blogId, name: name)
                await MainActor.run {
                    tags.append(created)
                    selectedTagIds.append(created.id)
                    selectedTagNames.append(created.name)
                    tagInput = ""
                    showingSuggestions = false
                    isCreating = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isCreating = false
                }
            }
        }
    }

    private func loadTags() {
        isLoading = true
        let client = PostalgicAPIClient(server: server)

        Task {
            do {
                let fetched = try await client.fetchTags(blogId: blogId)
                await MainActor.run {
                    tags = fetched
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isLoading = false
                }
            }
        }
    }
}
