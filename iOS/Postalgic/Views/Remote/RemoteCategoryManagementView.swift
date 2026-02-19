//
//  RemoteCategoryManagementView.swift
//  Postalgic
//
//  Created by Claude on 2/18/26.
//

import SwiftUI

struct RemoteCategoryManagementView: View {
    let server: RemoteServer
    let blogId: String

    @State private var categories: [RemoteCategory] = []
    @State private var isLoading = true
    @State private var errorMessage: String?

    // Add/Edit
    @State private var showingAddAlert = false
    @State private var showingEditAlert = false
    @State private var editingCategory: RemoteCategory?
    @State private var categoryName = ""
    @State private var categoryDescription = ""

    // Delete
    @State private var showingDeleteConfirmation = false
    @State private var deletingCategory: RemoteCategory?

    var body: some View {
        List {
            if isLoading {
                HStack {
                    ProgressView()
                        .padding(.trailing, 8)
                    Text("Loading categories...")
                        .foregroundStyle(.secondary)
                }
            } else if categories.isEmpty {
                ContentUnavailableView {
                    Label("No Categories", systemImage: "folder")
                } description: {
                    Text("Categories help organize your blog posts.")
                }
            } else {
                ForEach(categories.sorted { $0.name < $1.name }) { category in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(category.name)
                                .font(.headline)
                            if let desc = category.description, !desc.isEmpty {
                                Text(desc)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            if let count = category.postCount {
                                Text("\(count) posts")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        editingCategory = category
                        categoryName = category.name
                        categoryDescription = category.description ?? ""
                        showingEditAlert = true
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button(role: .destructive) {
                            deletingCategory = category
                            showingDeleteConfirmation = true
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
            }
        }
        .navigationTitle("Categories")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    categoryName = ""
                    categoryDescription = ""
                    showingAddAlert = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .refreshable {
            await loadCategories()
        }
        .alert("New Category", isPresented: $showingAddAlert) {
            TextField("Name", text: $categoryName)
            TextField("Description (optional)", text: $categoryDescription)
            Button("Cancel", role: .cancel) {}
            Button("Create") { createCategory() }
        }
        .alert("Edit Category", isPresented: $showingEditAlert) {
            TextField("Name", text: $categoryName)
            TextField("Description (optional)", text: $categoryDescription)
            Button("Cancel", role: .cancel) {}
            Button("Save") { updateCategory() }
        }
        .alert("Delete Category", isPresented: $showingDeleteConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) { deleteCategory() }
        } message: {
            Text("Are you sure? Posts in this category will be uncategorized.")
        }
        .onAppear {
            if isLoading {
                Task { await loadCategories() }
            }
        }
    }

    private func loadCategories() async {
        let client = PostalgicAPIClient(server: server)
        do {
            let fetched = try await client.fetchCategories(blogId: blogId)
            await MainActor.run {
                categories = fetched
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

    private func createCategory() {
        let name = categoryName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        let desc = categoryDescription.trimmingCharacters(in: .whitespacesAndNewlines)

        let client = PostalgicAPIClient(server: server)
        Task {
            do {
                let created = try await client.createCategory(blogId: blogId, name: name, description: desc.isEmpty ? nil : desc)
                await MainActor.run {
                    categories.append(created)
                }
            } catch {
                await MainActor.run { errorMessage = error.localizedDescription }
            }
        }
    }

    private func updateCategory() {
        guard let editing = editingCategory else { return }
        let name = categoryName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        let desc = categoryDescription.trimmingCharacters(in: .whitespacesAndNewlines)

        let client = PostalgicAPIClient(server: server)
        Task {
            do {
                let updated = try await client.updateCategory(blogId: blogId, categoryId: editing.id, name: name, description: desc.isEmpty ? nil : desc)
                await MainActor.run {
                    if let index = categories.firstIndex(where: { $0.id == editing.id }) {
                        categories[index] = updated
                    }
                }
            } catch {
                await MainActor.run { errorMessage = error.localizedDescription }
            }
        }
    }

    private func deleteCategory() {
        guard let deleting = deletingCategory else { return }

        let client = PostalgicAPIClient(server: server)
        Task {
            do {
                try await client.deleteCategory(blogId: blogId, categoryId: deleting.id)
                await MainActor.run {
                    categories.removeAll { $0.id == deleting.id }
                }
            } catch {
                await MainActor.run { errorMessage = error.localizedDescription }
            }
        }
    }
}
