//
//  PostDetailView.swift
//  Postalgic
//
//  Created by Brad Root on 4/19/25.
//

import SwiftUI
import SwiftData

struct PostDetailView: View {
    var post: Post
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if let title = post.title {
                    Text(title)
                        .font(.largeTitle)
                        .fontWeight(.bold)
                }
                
                if let primaryLink = post.primaryLink {
                    Link(primaryLink, destination: URL(string: primaryLink) ?? URL(string: "https://example.com")!)
                        .font(.headline)
                }
                
                Text(post.createdAt, format: .dateTime)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                
                if !post.tags.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack {
                            ForEach(post.tags) { tag in
                                Text(tag.name)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 5)
                                    .background(Color.blue.opacity(0.2))
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
    }
}

#Preview {
    PostDetailView(post: Post(title: "Test Post", content: "This is a test post with **bold** and *italic* text."))
        .modelContainer(for: [Post.self, Tag.self], inMemory: true)
}
