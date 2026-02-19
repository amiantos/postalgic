//
//  RemoteCategorySelectionView.swift
//  Postalgic
//
//  Created by Claude on 2/18/26.
//

import SwiftUI

struct RemoteCategorySelectionView: View {
    @Environment(\.dismiss) private var dismiss

    let server: RemoteServer
    let blogId: String
    @Binding var selectedCategoryId: String?
    @Binding var selectedCategoryName: String?

    @State private var categories: [RemoteCategory] = []
    @State private var isLoading = true
    @State private var errorMessage: String?

    // Add category inline
    @State private var showingAddCategory = false
    @State private var newCategoryName = ""
    @State private var isCreating = false

    var body: some View {
        List {
            if isLoading {
                HStack {
                    ProgressView()
                        .padding(.trailing, 8)
                    Text("Loading categories...")
                        .foregroundStyle(.secondary)
                }
            } else if let errorMessage {
                Text(errorMessage)
                    .foregroundStyle(.red)
            } else {
                // None option
                Button {
                    selectedCategoryId = nil
                    selectedCategoryName = nil
                    dismiss()
                } label: {
                    HStack {
                        Text("None")
                            .foregroundColor(.primary)
                        Spacer()
                        if selectedCategoryId == nil {
                            Image(systemName: "checkmark")
                                .foregroundColor(.blue)
                        }
                    }
                }

                ForEach(categories.sorted { $0.name < $1.name }) { category in
                    Button {
                        selectedCategoryId = category.id
                        selectedCategoryName = category.name
                        dismiss()
                    } label: {
                        HStack {
                            VStack(alignment: .leading) {
                                Text(category.name)
                                if let count = category.postCount {
                                    Text("\(count) posts")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            Spacer()
                            if selectedCategoryId == category.id {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                    .foregroundColor(.primary)
                }
            }
        }
        .navigationTitle("Select Category")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingAddCategory = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .alert("New Category", isPresented: $showingAddCategory) {
            TextField("Category name", text: $newCategoryName)
            Button("Cancel", role: .cancel) {
                newCategoryName = ""
            }
            Button("Create") {
                createCategory()
            }
        }
        .onAppear {
            loadCategories()
        }
    }

    private func loadCategories() {
        isLoading = true
        let client = PostalgicAPIClient(server: server)

        Task {
            do {
                let fetched = try await client.fetchCategories(blogId: blogId)
                await MainActor.run {
                    categories = fetched
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

    private func createCategory() {
        let name = newCategoryName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        newCategoryName = ""

        let client = PostalgicAPIClient(server: server)

        Task {
            do {
                let created = try await client.createCategory(blogId: blogId, name: name)
                await MainActor.run {
                    categories.append(created)
                    // Auto-select the new category
                    selectedCategoryId = created.id
                    selectedCategoryName = created.name
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
}
