//
//  BlogFormView.swift
//  Postalgic
//
//  Created by Brad Root on 4/19/25.
//

import SwiftData
import SwiftUI

struct BlogFormView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    // Determines if we're creating a new blog or editing an existing one
    private var isEditing: Bool
    
    // Optional blog for editing mode
    private var blog: Blog?
    
    @State private var name: String
    @State private var url: String
    @State private var generateRobotsTxt: Bool
    @State private var robotsTxtContent: String
    @State private var generateSitemap: Bool
    @State private var sitemapChangeFreq: String
    @State private var sitemapPriority: String
    
    // Initialize for creating a new blog
    init() {
        self.isEditing = false
        self.blog = nil
        _name = State(initialValue: "")
        _url = State(initialValue: "")
        _generateRobotsTxt = State(initialValue: true)
        _robotsTxtContent = State(initialValue: "")
        _generateSitemap = State(initialValue: true)
        _sitemapChangeFreq = State(initialValue: "weekly")
        _sitemapPriority = State(initialValue: "0.5")
    }
    
    // Initialize for editing an existing blog
    init(blog: Blog) {
        self.isEditing = true
        self.blog = blog
        _name = State(initialValue: blog.name)
        _url = State(initialValue: blog.url)
        _generateRobotsTxt = State(initialValue: blog.generateRobotsTxt)
        _robotsTxtContent = State(initialValue: blog.robotsTxtContent ?? "")
        _generateSitemap = State(initialValue: blog.generateSitemap)
        _sitemapChangeFreq = State(initialValue: blog.sitemapChangeFreq)
        _sitemapPriority = State(initialValue: blog.sitemapPriority)
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Blog Details") {
                    TextField("Name", text: $name)
                    TextField("URL", text: $url)
                        .autocapitalization(.none)
                        .autocorrectionDisabled(true)
                        .keyboardType(.URL)
                        .textContentType(.URL)
                }
                
                Section("SEO Settings") {
                    Toggle("Generate robots.txt", isOn: $generateRobotsTxt)
                    
                    if generateRobotsTxt {
                        VStack(alignment: .leading) {
                            Text("Custom robots.txt content (optional)")
                                .font(.caption)
                            
                            TextEditor(text: $robotsTxtContent)
                                .frame(minHeight: 100)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 5)
                                        .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                                )
                            
                            if robotsTxtContent.isEmpty {
                                Text("Default content will be used if left empty.")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    
                    Divider()
                    
                    Toggle("Generate sitemap.xml", isOn: $generateSitemap)
                    
                    if generateSitemap {
                        Picker("Change Frequency", selection: $sitemapChangeFreq) {
                            Text("Always").tag("always")
                            Text("Hourly").tag("hourly")
                            Text("Daily").tag("daily")
                            Text("Weekly").tag("weekly")
                            Text("Monthly").tag("monthly")
                            Text("Yearly").tag("yearly")
                            Text("Never").tag("never")
                        }
                        
                        Picker("Priority", selection: $sitemapPriority) {
                            Text("0.0 (Lowest)").tag("0.0")
                            Text("0.1").tag("0.1")
                            Text("0.2").tag("0.2")
                            Text("0.3").tag("0.3")
                            Text("0.4").tag("0.4")
                            Text("0.5 (Default)").tag("0.5")
                            Text("0.6").tag("0.6")
                            Text("0.7").tag("0.7")
                            Text("0.8").tag("0.8")
                            Text("0.9").tag("0.9")
                            Text("1.0 (Highest)").tag("1.0")
                        }
                    }
                }
            }
            .navigationTitle(isEditing ? "Edit Blog" : "New Blog")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        if isEditing {
                            updateBlog()
                        } else {
                            addBlog()
                        }
                        dismiss()
                    }
                    .disabled(name.isEmpty || url.isEmpty)
                }
            }
        }
    }
    
    private func addBlog() {
        let newBlog = Blog(name: name, url: url)
        newBlog.generateRobotsTxt = generateRobotsTxt
        newBlog.robotsTxtContent = robotsTxtContent.isEmpty ? nil : robotsTxtContent
        newBlog.generateSitemap = generateSitemap
        newBlog.sitemapChangeFreq = sitemapChangeFreq
        newBlog.sitemapPriority = sitemapPriority
        modelContext.insert(newBlog)
    }
    
    private func updateBlog() {
        if let blogToUpdate = blog {
            blogToUpdate.name = name
            blogToUpdate.url = url
            blogToUpdate.generateRobotsTxt = generateRobotsTxt
            blogToUpdate.robotsTxtContent = robotsTxtContent.isEmpty ? nil : robotsTxtContent
            blogToUpdate.generateSitemap = generateSitemap
            blogToUpdate.sitemapChangeFreq = sitemapChangeFreq
            blogToUpdate.sitemapPriority = sitemapPriority
        }
    }
}

#Preview {
    BlogFormView()
        .modelContainer(for: [Blog.self], inMemory: true)
}

#Preview {
    BlogFormView(blog: Blog(name: "Test Blog", url: "https://example.com"))
        .modelContainer(for: [Blog.self], inMemory: true)
}