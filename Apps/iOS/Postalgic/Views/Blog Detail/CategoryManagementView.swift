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

    var body: some View {
        NavigationStack {
            List {
                ForEach(categories.sorted { $0.name < $1.name }) { category in
                    NavigationLink(destination: EditCategoryView(category: category, blog: blog)) {
                        CategoryRowView(category: category)
                    }
                }
                .onDelete(perform: deleteCategories)
            }
            .navigationTitle("Categories")
            .toolbar {
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
                AddCategoryView(blog: blog).interactiveDismissDisabled()
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

struct AddCategoryView: View {
    let blog: Blog

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var description = ""

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
            .navigationTitle("Add Category")
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
        }
    }

    private func saveCategory() {
        let newCategory = Category(
            name: name,
            categoryDescription: description.isEmpty ? nil : description
        )
        modelContext.insert(newCategory)
        newCategory.blog = blog
        blog.categories.append(newCategory)
    }
}

struct EditCategoryView: View {
    let blog: Blog
    @Bindable var category: Category
    
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.presentationMode) private var presentationMode

    @State private var name: String
    @State private var description: String
    @State private var hasChanges = false

    init(category: Category, blog: Blog) {
        self.category = category
        self.blog = blog
        _name = State(initialValue: category.name)
        _description = State(initialValue: category.categoryDescription ?? "")
    }

    var body: some View {
        Form {
            Section {
                TextField("Name", text: $name)
                    .onChange(of: name) { _, newValue in
                        // Automatically capitalize while typing
                        let capitalized = newValue.capitalized
                        if capitalized != newValue {
                            name = capitalized
                        }
                        checkForChanges()
                    }

                TextField("Description (optional)", text: $description)
                    .onChange(of: description) { _, _ in
                        checkForChanges()
                    }
            }
        }
        .navigationTitle("Edit Category")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Save") {
                    saveCategory()
                    dismiss()
                }
                .disabled(name.isEmpty || !hasChanges)
            }
        }
        .interactiveDismissDisabled(hasChanges)
        .onChange(of: presentationMode.wrappedValue.isPresented) { wasPresented, isPresented in
            if wasPresented && !isPresented && hasChanges {
                // The view is being dismissed, but we have unsaved changes
                // This is handled by interactiveDismissDisabled now
            }
        }
    }
    
    private func checkForChanges() {
        hasChanges = name != category.name || 
                    description != (category.categoryDescription ?? "")
    }

    private func saveCategory() {
        category.name = name.capitalized
        category.categoryDescription = description.isEmpty ? nil : description

        // Ensure category is associated with blog
        if category.blog == nil {
            category.blog = blog
            blog.categories.append(category)
        }
    }
}

#Preview {
    let modelContainer = PreviewData.previewContainer
    
    return NavigationStack {
        // Fetch the first blog from the container to ensure it's properly in the context
        CategoryManagementView(blog: try! modelContainer.mainContext.fetch(FetchDescriptor<Blog>()).first!)
    }
    .modelContainer(modelContainer)
}

