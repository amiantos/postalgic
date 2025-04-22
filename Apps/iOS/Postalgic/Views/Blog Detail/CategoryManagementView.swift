//
//  CategoryManagementView.swift
//  Postalgic
//
//  Created by Brad Root on 4/19/25.
//

import SwiftData
import SwiftUI

struct CategoryManagementView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    var blog: Blog

    @Query private var allCategories: [Category]

    private var categories: [Category] {
        return allCategories.filter { $0.blog?.id == blog.id }
    }

    @State private var showingAddCategory = false
    @State private var selectedCategory: Category?
    @State private var isEditing = false

    var body: some View {
        NavigationStack {
            List {
                ForEach(categories.sorted { $0.name < $1.name }) { category in
                    CategoryRowView(category: category)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            selectedCategory = category
                            isEditing = true
                        }
                }
                .onDelete(perform: deleteCategories)
            }
            .navigationTitle("Categories")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    EditButton()
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        showingAddCategory = true
                    }) {
                        Image(systemName: "plus")
                    }
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showingAddCategory) {
                CategoryFormView(mode: .add, blog: blog)
            }
            .sheet(
                isPresented: $isEditing,
                onDismiss: {
                    selectedCategory = nil
                }
            ) {
                if let category = selectedCategory {
                    CategoryFormView(mode: .edit(category), blog: blog)
                }
            }
        }
    }

    private func deleteCategories(at offsets: IndexSet) {
        let sortedCategories = categories.sorted { $0.name < $1.name }
        for index in offsets {
            let categoryToDelete = sortedCategories[index]

            // Nullify category for any post that uses it
            for post in categoryToDelete.posts {
                post.category = nil
            }

            modelContext.delete(categoryToDelete)
        }
    }
}

struct CategoryRowView: View {
    let category: Category

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(category.name)
                .font(.headline)

            if let categoryDescription = category.categoryDescription,
                !categoryDescription.isEmpty
            {
                Text(categoryDescription)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Text(
                "\(category.posts.count) \(category.posts.count == 1 ? "post" : "posts")"
            )
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
}

struct CategoryFormView: View {
    enum Mode {
        case add
        case edit(Category)
    }

    let mode: Mode
    let blog: Blog

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var description = ""

    var title: String {
        switch mode {
        case .add:
            return "Add Category"
        case .edit:
            return "Edit Category"
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Name", text: $name)
                        .onChange(of: name) { _, newValue in
                            // Automatically capitalize while typing
                            let capitalized = newValue.capitalized
                            if capitalized != newValue {
                                name = capitalized
                            }
                        }

                    TextField("Description (optional)", text: $description)
                }
            }
            .navigationTitle(title)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveCategory()
                        dismiss()
                    }
                    .disabled(name.isEmpty)
                }
            }
            .onAppear {
                if case .edit(let category) = mode {
                    name = category.name
                    description = category.categoryDescription ?? ""
                }
            }
        }
    }

    private func saveCategory() {
        switch mode {
        case .add:
            let newCategory = Category(
                name: name,
                categoryDescription: description.isEmpty ? nil : description
            )
            modelContext.insert(newCategory)
            newCategory.blog = blog
            blog.categories.append(newCategory)

        case .edit(let category):
            category.name = name.capitalized
            category.categoryDescription =
                description.isEmpty ? nil : description

            // Ensure category is associated with blog
            if category.blog == nil {
                category.blog = blog
                blog.categories.append(category)
            }
        }
    }
}

#Preview {
    //    let container = ModelContainer(for: Blog.self, Category.self, Post.self, inMemory: true)
    //    let context = ModelContext(container)
    //    let blog = Blog(name: "Test Blog", url: "https://example.com")
    //    context.insert(blog)
    //
    //    CategoryManagementView(blog: blog)
    //        .modelContainer(container)
}
