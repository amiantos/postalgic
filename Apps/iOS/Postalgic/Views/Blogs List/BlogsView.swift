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
    @State private var showingHelpSheet = false

    var body: some View {
        NavigationStack {
            List {
                ForEach(blogs.sorted(by: { $0.createdAt > $1.createdAt })) {
                    blog in
                    NavigationLink {
                        BlogDashboardView(blog: blog)
                    } label: {
                        HStack {
                            // Display favicon if available
                            if let favicon = blog.favicon, let image = UIImage(data: favicon.data) {
                                Image(uiImage: image)
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: 36, height: 36)
                                    .clipShape(RoundedRectangle(cornerRadius: 4))
                            } else {
                                // Placeholder icon when no favicon
                                Image(systemName: "globe")
                                    .foregroundColor(.secondary)
                                    .frame(width: 36, height: 36)
                            }
                            
                            VStack(alignment: .leading) {
                                Text(blog.name)
                                    .font(.headline)
                                if !blog.url.isEmpty {
                                    Text(blog.url)
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                            }.padding(.leading, 6)
                        }
                    }
                }
            }
            .sheet(isPresented: $showingHelpSheet) {
                HelpView()
            }
            .toolbar {
                ToolbarItem {
                    Button(action: { showingBlogForm = true }) {
                        Label("Add Blog", systemImage: "plus")
                    }
                }
                ToolbarItemGroup(placement: .topBarLeading) {
                    Button {
                        showingHelpSheet.toggle()
                    } label: {
                        Label("Help", systemImage: "questionmark.circle")
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
