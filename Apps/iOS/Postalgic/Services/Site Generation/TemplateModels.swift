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
    
    // Method to convert to a dictionary for Mustache
    func toDictionary() -> [String: Any] {
        var dict: [String: Any] = [
            "displayTitle": post.displayTitle,
            "hasTitle": post.title?.isEmpty == false,
            "formattedDate": post.formattedDate,
            "urlPath": post.urlPath,
            "hasTags": !post.tags.isEmpty
        ]
        
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
        
        dict["contentHtml"] = finalContent
        
        // Add tags if present
        if !post.tags.isEmpty {
            dict["tags"] = post.tags.map { tag in
                return [
                    "name": tag.name,
                    "urlPath": tag.name.urlPathFormatted()
                ]
            }
        }
        
        // Add category if present
        dict["hasCategory"] = post.category != nil
        if let category = post.category {
            dict["categoryName"] = category.name
            dict["categoryUrlPath"] = category.name.urlPathFormatted()
            
            if let description = category.categoryDescription {
                dict["categoryDescription"] = description
            }
        }
        
        // ISO8601 formatted date for sitemap and general use
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        dict["lastmod"] = formatter.string(from: post.createdAt)
        
        // Atom feed requires RFC-3339 dates (ISO8601 with specific formatting)
        dict["published"] = formatter.string(from: post.createdAt)
        dict["updated"] = formatter.string(from: post.createdAt)
        
        // RFC 822 formatted date for RSS (required by RSS 2.0)
        let rfcDateFormatter = DateFormatter()
        rfcDateFormatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss zzz"
        rfcDateFormatter.locale = Locale(identifier: "en_US_POSIX")
        rfcDateFormatter.timeZone = TimeZone(abbreviation: "GMT")
        dict["pubDate"] = rfcDateFormatter.string(from: post.createdAt)
        
        // Blog author information
        if let authorName = blog.authorName {
            dict["blogAuthor"] = authorName
        }
        
        if let authorEmail = blog.authorEmail {
            dict["blogAuthorEmail"] = authorEmail
        }
        
        if let authorUrl = blog.authorUrl {
            dict["blogAuthorUrl"] = authorUrl
        }
        
        return dict
    }
}

/// Structure that represents a category in templates
struct CategoryTemplateData {
    let category: Category
    let posts: [Post]
    let markdownParser: MarkdownParser
    
    func toDictionary() -> [String: Any] {
        var dict: [String: Any] = [
            "name": category.name,
            "urlPath": category.name.urlPathFormatted(),
            "postCount": posts.count
        ]
        
        let hasDescription = category.categoryDescription?.isEmpty == false
        dict["hasDescription"] = hasDescription
        
        if hasDescription, let description = category.categoryDescription {
            dict["description"] = description
        }
        
        let formatter = ISO8601DateFormatter()
        dict["lastmod"] = formatter.string(from: Date())
        
        return dict
    }
}

/// Structure that represents a tag in templates
struct TagTemplateData {
    let tag: Tag
    let posts: [Post]
    let markdownParser: MarkdownParser
    
    func toDictionary() -> [String: Any] {
        var dict: [String: Any] = [
            "name": tag.name,
            "urlPath": tag.name.urlPathFormatted(),
            "postCount": posts.count
        ]
        
        let formatter = ISO8601DateFormatter()
        dict["lastmod"] = formatter.string(from: Date())
        
        return dict
    }
}

/// Structure that represents a month in the archives template
struct ArchiveMonthData {
    let month: Int
    let monthName: String
    let posts: [ArchivePostData]
    
    func toDictionary() -> [String: Any] {
        return [
            "month": month,
            "monthName": monthName,
            "posts": posts.map { $0.toDictionary() }
        ]
    }
}

/// Structure that represents a post in the archives template
struct ArchivePostData {
    let post: Post
    
    func toDictionary() -> [String: Any] {
        let day = Calendar.current.component(.day, from: post.createdAt)
        return [
            "displayTitle": post.displayTitle,
            "urlPath": post.urlPath,
            "day": day,
            "dayPadded": String(format: "%02d", day)
        ]
    }
}

/// Structure that represents a year in the archives template
struct ArchiveYearData {
    let year: Int
    let months: [ArchiveMonthData]
    
    func toDictionary() -> [String: Any] {
        return [
            "year": year,
            "months": months.map { $0.toDictionary() }
        ]
    }
}

/// Collection of helper functions to convert model data to template data
struct TemplateDataConverter {
    static let markdownParser = MarkdownParser()
    
    /// Converts a Post to a dictionary for template rendering
    /// - Parameters:
    ///   - post: The post to convert
    ///   - blog: The blog the post belongs to
    ///   - inList: Whether this post is being displayed in a list view (default: true)
    /// - Returns: Dictionary for template rendering
    static func convert(post: Post, blog: Blog, inList: Bool = true) -> [String: Any] {
        var result = PostTemplateData(post: post, blog: blog, markdownParser: markdownParser).toDictionary()
        result["inList"] = inList
        return result
    }
    
    /// Converts a Category to a dictionary for template rendering
    static func convert(category: Category, posts: [Post]) -> [String: Any] {
        let templateData = CategoryTemplateData(category: category, posts: posts, markdownParser: markdownParser)
        return templateData.toDictionary()
    }
    
    /// Converts a Tag to a dictionary for template rendering
    static func convert(tag: Tag, posts: [Post]) -> [String: Any] {
        let templateData = TagTemplateData(tag: tag, posts: posts, markdownParser: markdownParser)
        return templateData.toDictionary()
    }
    
    /// Creates archive data organized by year and month
    static func createArchiveData(from posts: [Post]) -> [[String: Any]] {
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
        
        // Convert to dictionaries for template rendering
        return archiveYears.map { $0.toDictionary() }
    }
}