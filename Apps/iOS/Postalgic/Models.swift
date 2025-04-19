//
//  Models.swift
//  Postalgic
//
//  Created by Brad Root on 4/19/25.
//

import Foundation
import SwiftData

@Model
final class Blog {
    var name: String
    var url: String
    var createdAt: Date
    
    // AWS Configuration
    var awsRegion: String?
    var awsS3Bucket: String?
    var awsCloudFrontDistId: String?
    var awsIdentityPoolId: String?
    
    @Relationship(deleteRule: .cascade, inverse: \Post.blog)
    var posts: [Post] = []
    
    init(name: String, url: String, createdAt: Date = Date()) {
        self.name = name
        self.url = url
        self.createdAt = createdAt
    }
    
    var hasAwsConfigured: Bool {
        return awsRegion != nil && 
               !awsRegion!.isEmpty && 
               awsS3Bucket != nil && 
               !awsS3Bucket!.isEmpty && 
               awsCloudFrontDistId != nil && 
               !awsCloudFrontDistId!.isEmpty && 
               awsIdentityPoolId != nil && 
               !awsIdentityPoolId!.isEmpty
    }
}

@Model
final class Post {
    var title: String?
    var content: String
    var primaryLink: String?
    var createdAt: Date
    
    var blog: Blog?
    
    init(title: String? = nil, content: String, primaryLink: String? = nil, createdAt: Date = Date()) {
        self.title = title
        self.content = content
        self.primaryLink = primaryLink
        self.createdAt = createdAt
    }
    
    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        formatter.timeStyle = .short
        return formatter.string(from: createdAt)
    }
    
    var urlPath: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy/MM/dd/HHmmss"
        return formatter.string(from: createdAt)
    }
    
    var displayTitle: String {
        return title ?? String(content.prefix(50))
    }
}