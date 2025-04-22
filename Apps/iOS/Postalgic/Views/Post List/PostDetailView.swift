//
//  PostDetailView.swift
//  Postalgic
//
//  Created by Brad Root on 4/19/25.
//

import SwiftUI
import SwiftData

struct PostDetailView: View {
    @Environment(\.modelContext) private var modelContext
    var post: Post
    @State private var showingEditSheet = false
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    if let title = post.title {
                        Text(title)
                            .font(.largeTitle)
                            .fontWeight(.bold)
                    }
                    
                    if post.isDraft {
                        Spacer()
                        Text("DRAFT")
                            .font(.headline)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Color("PPink"))
                            .cornerRadius(8)
                    }
                }
                
                if let primaryLink = post.primaryLink {
                    Link(primaryLink, destination: URL(string: primaryLink) ?? URL(string: "https://example.com")!)
                        .font(.headline)
                }
                
                HStack {
                    Text(post.createdAt, format: .dateTime)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    
                    if let category = post.category {
                        Spacer()
                        Text(category.name)
                            .font(.subheadline)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Color("PGreen"))
                            .cornerRadius(8)
                    }
                }
                
                if !post.tags.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack {
                            ForEach(post.tags) { tag in
                                Text(tag.name)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 5)
                                    .background(Color("PBlue"))
                                    .cornerRadius(8)
                            }
                        }
                    }
                }
                
                Divider()
                
                Text(.init(post.content))
                    .textSelection(.enabled)
                    .font(.body)
                
                Spacer()
            }
            .padding()
        }
        .navigationTitle(post.title ?? "Post")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(action: { showingEditSheet = true }) {
                    Text("Edit")
                }
            }
        }
        .sheet(isPresented: $showingEditSheet) {
            PostEditView(post: post)
        }
    }
}

#Preview {
    PostDetailView(post: Post(title: "Test Post", content: "This is a test post with **bold** and *italic* text."))
        .modelContainer(for: [Post.self, Tag.self, Category.self], inMemory: true)
}
