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
    var showDate: Bool = true
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {

            if let title = post.title {
                Text(title).font(.headline)
            }
            
            if showDate {
                Text(post.createdAt, format: .dateTime)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
           
            Text(post.content.prefix(150))
                .font(.body)
                .lineLimit(3)
            
            if post.category != nil || !post.tags.isEmpty || post.isDraft {
                HStack {
                    if post.isDraft {
                        Text("Draft")
                            .font(.caption)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color("PPink"))
                            .cornerRadius(4)
                    }
                    
                    if let category = post.category {
                        Text(category.name)
                            .font(.caption)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color("PGreen"))
                            .cornerRadius(4)
                            .lineLimit(1)
                    }
                    
                    if !post.tags.isEmpty {
                        ForEach(post.tags.prefix(3)) { tag in
                            Text(tag.name)
                                .font(.caption)
                                .foregroundStyle(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color("PBlue"))
                                .cornerRadius(4)
                                .lineLimit(1)
                        }
                        if post.tags.count > 3 {
                            Text("+\(post.tags.count - 3)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
    }
}

#Preview {
    let modelContainer = PreviewData.previewContainer
    
    return PostRowView(post: try! modelContainer.mainContext.fetch(FetchDescriptor<Post>()).first!)
        .padding()
        .modelContainer(modelContainer)
}
