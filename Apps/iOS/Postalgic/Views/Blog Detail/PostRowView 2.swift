//
//  PostRowView.swift
//  Postalgic
//
//  Created by Brad Root on 4/26/25.
//

import SwiftData
import SwiftUI

struct PostRowView: View {
    var post: Post
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                if let title = post.title {
                    Text(title)
                        .font(.headline)
                } else {
                    Text(post.content.prefix(50))
                        .font(.headline)
                        .lineLimit(1)
                }
                
                if post.isDraft {
                    Spacer()
                    Text("DRAFT")
                        .font(.caption)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color("PPink"))
                        .cornerRadius(4)
                }
            }
            
            HStack {
                Text(post.createdAt, format: .dateTime)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                if let category = post.category {
                    Spacer()
                    Text(category.name)
                        .font(.caption)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color("PGreen"))
                        .cornerRadius(4)
                }
            }
            
            if !post.tags.isEmpty {
                HStack {
                    ForEach(post.tags.prefix(3)) { tag in
                        Text(tag.name)
                            .font(.caption)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color("PBlue"))
                            .cornerRadius(4)
                    }
                    if post.tags.count > 3 {
                        Text("+\(post.tags.count - 3)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    let modelContainer = PreviewData.previewContainer
    
    return PostRowView(post: try! modelContainer.mainContext.fetch(FetchDescriptor<Post>()).first!)
        .padding()
        .modelContainer(modelContainer)
}