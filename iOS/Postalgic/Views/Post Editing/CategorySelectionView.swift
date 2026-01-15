//
//  CategorySelectionView.swift
//  Postalgic
//
//  Created by Claude on 5/11/25.
//

import SwiftData
import SwiftUI

struct CategorySelectionView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    var blog: Blog
    var post: Post
    
    @Query(sort: \Category.name) private var categories: [Category]
    @State private var showingAddCategory = false
    @State private var selectedCategory: Category?
    
    init(blog: Blog, post: Post) {
        self.blog = blog
        self.post = post
        self._selectedCategory = State(initialValue: post.category)
        
        // Configure the query to fetch all categories for this blog
        let id = blog.persistentModelID
        let catPredicate = #Predicate<Category> { category in
            category.blog?.persistentModelID == id
        }
        
        self._categories = Query(filter: catPredicate)
    }
    
    var body: some View {
        NavigationStack {
            List {
                if categories.isEmpty {
                    Text("No categories yet. Add some to help organize your blog's content.")
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical)
                } else {
                    // None option
                    Button {
                        selectedCategory = nil
                        updatePostCategory()
                        dismiss()
                    } label: {
                        HStack {
                            Text("None")
                                .foregroundColor(.primary)
                            Spacer()
                            if selectedCategory == nil {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                    
                    ForEach(categories.sorted { $0.name < $1.name }) { category in
                        Button {
                            selectedCategory = category
                            updatePostCategory()
                            dismiss()
                        } label: {
                            HStack {
                                CategoryRowView(category: category)
                                Spacer()
                                if let selectedCat = selectedCategory, selectedCat.id == category.id {
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
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        showingAddCategory = true
                    }) {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddCategory) {
                AddCategoryView(blog: blog)
                    .interactiveDismissDisabled()
                    .onDisappear {
                        // Force refresh the View to see the new category
                        // This happens automatically due to the @Query property wrapper
                    }
            }
        }
    }
    
    private func updatePostCategory() {
        // Handle category changes
        if post.category != selectedCategory {
            // Remove post from previous category
            if let oldCategory = post.category {
                if let index = oldCategory.posts.firstIndex(where: { $0.id == post.id }) {
                    oldCategory.posts.remove(at: index)
                }
            }
            
            // Add post to new category
            post.category = selectedCategory
            if let newCategory = selectedCategory {
                newCategory.posts.append(post)
            }
            
            try? modelContext.save()
        }
    }
}

#Preview {
    let modelContainer = PreviewData.previewContainer
    let blog = try! modelContainer.mainContext.fetch(FetchDescriptor<Blog>()).first!
    let post = Post(content: "Test content", isDraft: true)
    post.blog = blog
    
    return CategorySelectionView(blog: blog, post: post)
        .modelContainer(modelContainer)
}
