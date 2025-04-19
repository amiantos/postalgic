//
//  BlogsView.swift
//  Postalgic
//
//  Created by Brad Root on 4/19/25.
//

import SwiftUI
import SwiftData

struct BlogsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var blogs: [Blog]
    @State private var showingBlogForm = false
    
    var body: some View {
        NavigationSplitView {
            List {
                ForEach(blogs.sorted(by: { $0.createdAt > $1.createdAt })) { blog in
                    NavigationLink {
                        BlogDetailView(blog: blog)
                    } label: {
                        VStack(alignment: .leading) {
                            Text(blog.name)
                                .font(.headline)
                            Text(blog.url)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .onDelete(perform: deleteBlogs)
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    EditButton()
                }
                ToolbarItem {
                    Button(action: { showingBlogForm = true }) {
                        Label("Add Blog", systemImage: "plus")
                    }
                }
            }
            .navigationTitle("Blogs")
            .sheet(isPresented: $showingBlogForm) {
                BlogFormView()
            }
        } detail: {
            Text("Select a blog")
        }
    }
    
    private func deleteBlogs(offsets: IndexSet) {
        withAnimation {
            for index in offsets {
                modelContext.delete(blogs[index])
            }
        }
    }
}

#Preview {
    BlogsView()
        .modelContainer(for: [Blog.self, Post.self], inMemory: true)
}
