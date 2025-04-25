//
//  BlogsView.swift
//  Postalgic
//
//  Created by Brad Root on 4/19/25.
//

import SwiftData
import SwiftUI
struct BlogsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var blogs: [Blog]
    @State private var showingBlogForm = false

    var body: some View {
        NavigationStack {
            List {
                ForEach(blogs.sorted(by: { $0.createdAt > $1.createdAt })) {
                    blog in
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
            }
            .toolbar {
                ToolbarItem {
                    Button(action: { showingBlogForm = true }) {
                        Label("Add Blog", systemImage: "plus")
                    }
                }
            }
            .navigationTitle("Your Blogs")
            .sheet(isPresented: $showingBlogForm) {
                BlogFormView().interactiveDismissDisabled()
            }
        }
    }
}

#Preview {
    BlogsView()
        .modelContainer(PreviewData.previewContainer)
}
