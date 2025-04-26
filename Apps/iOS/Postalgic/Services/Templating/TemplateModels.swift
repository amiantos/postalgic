//
//  TemplateModels.swift
//  Postalgic
//
//  Created by Brad Root on 4/26/25.
//

import Foundation
import Mustache
import Ink

/// Structure that represents data for a post in templates
struct PostTemplateData {
    let post: Post
    let blog: Blog
    let markdownParser: MarkdownParser
    
    // Computed properties that will be available in templates
    var displayTitle: String {
        return post.displayTitle
    }
    
    var hasTitle: Bool {
        return post.title?.isEmpty == false
    }
    
    var formattedDate: String {
        return post.formattedDate
    }
    
    var urlPath: String {
        return post.urlPath
    }
    
    var contentHtml: String {
        // Generate post content with embeds
        let postContent = markdownParser.html(from: post.content)
        var finalContent = ""
        
        // Handle embeds based on position
        if let embed = post.embed, embed.embedPosition == .above {
            finalContent += embed.generateHtml() + "\n"
        }
        
        finalContent += postContent
        
        if let embed = post.embed, embed.embedPosition == .below {
            finalContent += "\n" + embed.generateHtml()
        }
        
        return finalContent
    }
    
    var hasTags: Bool {
        return !post.tags.isEmpty
    }
    
    var tags: [[String: String]] {
        return post.tags.map { tag in
            return [
                "name": tag.name,
                "urlPath": tag.name.urlPathFormatted()
            ]
        }
    }
    
    var hasCategory: Bool {
        return post.category != nil
    }
    
    var categoryName: String? {
        return post.category?.name
    }
    
    var categoryDescription: String? {
        return post.category?.categoryDescription
    }
    
    var categoryUrlPath: String? {
        return post.category?.name.urlPathFormatted()
    }
    
    // ISO8601 formatted date for RSS, etc.
    var pubDate: String {
        let formatter = ISO8601DateFormatter()
        return formatter.string(from: post.createdAt)
    }
    
    var lastmod: String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate]
        return formatter.string(from: post.createdAt)
    }
    
    // Blog author information
    var blogAuthor: String? {
        return blog.authorName
    }
    
    var blogAuthorUrl: String? {
        return blog.authorUrl
    }
}

/// Structure that represents a category in templates
struct CategoryTemplateData {
    let category: Category
    let posts: [Post]
    let markdownParser: MarkdownParser
    
    var name: String {
        return category.name
    }
    
    var urlPath: String {
        return category.name.urlPathFormatted()
    }
    
    var hasDescription: Bool {
        return category.categoryDescription?.isEmpty == false
    }
    
    var description: String? {
        return category.categoryDescription
    }
    
    var postCount: Int {
        return posts.count
    }
    
    var lastmod: String {
        let formatter = ISO8601DateFormatter()
        return formatter.string(from: Date())
    }
}

/// Structure that represents a tag in templates
struct TagTemplateData {
    let tag: Tag
    let posts: [Post]
    let markdownParser: MarkdownParser
    
    var name: String {
        return tag.name
    }
    
    var urlPath: String {
        return tag.name.urlPathFormatted()
    }
    
    var postCount: Int {
        return posts.count
    }
    
    var lastmod: String {
        let formatter = ISO8601DateFormatter()
        return formatter.string(from: Date())
    }
}

/// Structure that represents a month in the archives template
struct ArchiveMonthData {
    let month: Int
    let monthName: String
    let posts: [ArchivePostData]
}

/// Structure that represents a post in the archives template
struct ArchivePostData {
    let post: Post
    
    var displayTitle: String {
        return post.displayTitle
    }
    
    var urlPath: String {
        return post.urlPath
    }
    
    var day: Int {
        return Calendar.current.component(.day, from: post.createdAt)
    }
    
    var dayPadded: String {
        return String(format: "%02d", day)
    }
}

/// Structure that represents a year in the archives template
struct ArchiveYearData {
    let year: Int
    let months: [ArchiveMonthData]
}

/// Collection of helper functions to convert model data to template data
struct TemplateDataConverter {
    static let markdownParser = MarkdownParser()
    
    /// Converts a Post to PostTemplateData
    static func convert(post: Post, blog: Blog) -> PostTemplateData {
        return PostTemplateData(post: post, blog: blog, markdownParser: markdownParser)
    }
    
    /// Converts a Category to CategoryTemplateData
    static func convert(category: Category, posts: [Post]) -> CategoryTemplateData {
        return CategoryTemplateData(category: category, posts: posts, markdownParser: markdownParser)
    }
    
    /// Converts a Tag to TagTemplateData
    static func convert(tag: Tag, posts: [Post]) -> TagTemplateData {
        return TagTemplateData(tag: tag, posts: posts, markdownParser: markdownParser)
    }
    
    /// Creates archive data organized by year and month
    static func createArchiveData(from posts: [Post]) -> [ArchiveYearData] {
        let calendar = Calendar.current
        var yearMonthPosts: [Int: [Int: [Post]]] = [:]
        
        // Group posts by year and month
        for post in posts {
            let year = calendar.component(.year, from: post.createdAt)
            let month = calendar.component(.month, from: post.createdAt)
            
            if yearMonthPosts[year] == nil {
                yearMonthPosts[year] = [:]
            }
            
            if yearMonthPosts[year]?[month] == nil {
                yearMonthPosts[year]?[month] = []
            }
            
            yearMonthPosts[year]?[month]?.append(post)
        }
        
        // Sort years in descending order
        let years = yearMonthPosts.keys.sorted(by: >)
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MMMM"
        
        // Create year data
        var archiveYears: [ArchiveYearData] = []
        
        for year in years {
            let months = yearMonthPosts[year]?.keys.sorted(by: >) ?? []
            var archiveMonths: [ArchiveMonthData] = []
            
            for month in months {
                let monthName = dateFormatter.monthSymbols[month - 1]
                let postsInMonth = yearMonthPosts[year]?[month] ?? []
                
                // Sort posts within month by day
                let sortedPosts = postsInMonth.sorted { p1, p2 in
                    let day1 = calendar.component(.day, from: p1.createdAt)
                    let day2 = calendar.component(.day, from: p2.createdAt)
                    return day1 > day2
                }
                
                let archivePosts = sortedPosts.map { ArchivePostData(post: $0) }
                
                archiveMonths.append(ArchiveMonthData(
                    month: month,
                    monthName: monthName,
                    posts: archivePosts
                ))
            }
            
            archiveYears.append(ArchiveYearData(
                year: year,
                months: archiveMonths
            ))
        }
        
        return archiveYears
    }
}