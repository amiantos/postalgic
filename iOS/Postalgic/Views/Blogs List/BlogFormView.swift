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
    @State private var authorName: String
    @State private var authorEmail: String
    @State private var authorUrl: String
    @State private var tagline: String
    @State private var timezone: String
    @State private var simpleAnalyticsEnabled: Bool
    @State private var simpleAnalyticsDomain: String

    // Available timezones (matching Self-Hosted options)
    private static let timezones: [(group: String, zones: [(id: String, label: String)])] = [
        ("", [("UTC", "UTC")]),
        ("Americas", [
            ("America/New_York", "Eastern Time (US & Canada)"),
            ("America/Chicago", "Central Time (US & Canada)"),
            ("America/Denver", "Mountain Time (US & Canada)"),
            ("America/Los_Angeles", "Pacific Time (US & Canada)"),
            ("America/Anchorage", "Alaska"),
            ("Pacific/Honolulu", "Hawaii"),
            ("America/Phoenix", "Arizona"),
            ("America/Toronto", "Toronto"),
            ("America/Vancouver", "Vancouver"),
            ("America/Mexico_City", "Mexico City"),
            ("America/Sao_Paulo", "São Paulo"),
            ("America/Buenos_Aires", "Buenos Aires")
        ]),
        ("Europe", [
            ("Europe/London", "London"),
            ("Europe/Paris", "Paris"),
            ("Europe/Berlin", "Berlin"),
            ("Europe/Amsterdam", "Amsterdam"),
            ("Europe/Madrid", "Madrid"),
            ("Europe/Rome", "Rome"),
            ("Europe/Stockholm", "Stockholm"),
            ("Europe/Moscow", "Moscow")
        ]),
        ("Asia", [
            ("Asia/Tokyo", "Tokyo"),
            ("Asia/Shanghai", "Shanghai"),
            ("Asia/Hong_Kong", "Hong Kong"),
            ("Asia/Singapore", "Singapore"),
            ("Asia/Seoul", "Seoul"),
            ("Asia/Kolkata", "Mumbai/Kolkata"),
            ("Asia/Dubai", "Dubai"),
            ("Asia/Bangkok", "Bangkok")
        ]),
        ("Pacific", [
            ("Australia/Sydney", "Sydney"),
            ("Australia/Melbourne", "Melbourne"),
            ("Australia/Perth", "Perth"),
            ("Pacific/Auckland", "Auckland")
        ]),
        ("Africa", [
            ("Africa/Johannesburg", "Johannesburg"),
            ("Africa/Cairo", "Cairo"),
            ("Africa/Lagos", "Lagos")
        ])
    ]

    // Initialize for creating a new blog
    init() {
        self.isEditing = false
        self.blog = nil
        _name = State(initialValue: "")
        _authorName = State(initialValue: "")
        _authorEmail = State(initialValue: "")
        _authorUrl = State(initialValue: "")
        _tagline = State(initialValue: "")
        _timezone = State(initialValue: "UTC")
        _simpleAnalyticsEnabled = State(initialValue: false)
        _simpleAnalyticsDomain = State(initialValue: "")
    }

    // Initialize for editing an existing blog
    init(blog: Blog) {
        self.isEditing = true
        self.blog = blog
        _name = State(initialValue: blog.name)
        _authorName = State(initialValue: blog.authorName ?? "")
        _authorEmail = State(initialValue: blog.authorEmail ?? "")
        _authorUrl = State(initialValue: blog.authorUrl ?? "")
        _tagline = State(initialValue: blog.tagline ?? "")
        _timezone = State(initialValue: blog.timezone)
        _simpleAnalyticsEnabled = State(initialValue: blog.simpleAnalyticsEnabled)
        _simpleAnalyticsDomain = State(initialValue: blog.simpleAnalyticsDomain ?? "")
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Blog Title and Tagline") {
                    TextField("Title", text: $name)
                    TextField("Tagline (optional)", text: $tagline)
                }

                Section {
                    TextField("Author Name (optional)", text: $authorName)
                    TextField("Author Email (optional)", text: $authorEmail)
                        .autocapitalization(.none)
                        .autocorrectionDisabled(true)
                        .keyboardType(.emailAddress)
                        .textContentType(.emailAddress)
                    TextField("Author URL (optional)", text: $authorUrl)
                        .autocapitalization(.none)
                        .autocorrectionDisabled(true)
                        .keyboardType(.URL)
                        .textContentType(.URL)
                } header: {
                    Text("Author Information")
                } footer: {
                    Text("If provided, author information will be added to posts and included in the RSS feed.")
                }

                Section {
                    Picker("Timezone", selection: $timezone) {
                        ForEach(Self.timezones, id: \.group) { group in
                            if group.group.isEmpty {
                                ForEach(group.zones, id: \.id) { zone in
                                    Text(zone.label).tag(zone.id)
                                }
                            } else {
                                Section(header: Text(group.group)) {
                                    ForEach(group.zones, id: \.id) { zone in
                                        Text(zone.label).tag(zone.id)
                                    }
                                }
                            }
                        }
                    }
                } footer: {
                    Text("Dates on your published blog will display in this timezone.")
                }

                Section {
                    Toggle("Enable Simple Analytics", isOn: $simpleAnalyticsEnabled)
                    if simpleAnalyticsEnabled {
                        TextField("Domain Override (optional)", text: $simpleAnalyticsDomain)
                            .autocapitalization(.none)
                            .autocorrectionDisabled(true)
                            .keyboardType(.URL)
                    }
                } header: {
                    Text("Analytics")
                } footer: {
                    if simpleAnalyticsEnabled {
                        Text("Your blog's domain will be used by default. Only set the domain override if you're using a custom domain in Simple Analytics.")
                    } else {
                        Text("Add privacy-friendly analytics to your blog with Simple Analytics. Requires a Simple Analytics account.")
                    }
                }
            }
            .navigationTitle(isEditing ? "Metadata" : "New Blog")
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
                    .disabled(name.isEmpty)
                }
            }
        }
    }
    
    private func addBlog() {
        let newBlog = Blog(
            name: name, 
            url: "",
            authorName: authorName.isEmpty ? nil : authorName,
            authorEmail: authorEmail.isEmpty ? nil : authorEmail,
            authorUrl: authorUrl.isEmpty ? nil : authorUrl,
            tagline: tagline.isEmpty ? nil : tagline
        )
        modelContext.insert(newBlog)
        try? modelContext.save()
    }
    
    private func updateBlog() {
        if let blogToUpdate = blog {
            blogToUpdate.name = name
            blogToUpdate.authorName = authorName.isEmpty ? nil : authorName
            blogToUpdate.authorEmail = authorEmail.isEmpty ? nil : authorEmail
            blogToUpdate.authorUrl = authorUrl.isEmpty ? nil : authorUrl
            blogToUpdate.tagline = tagline.isEmpty ? nil : tagline
            blogToUpdate.timezone = timezone
            blogToUpdate.simpleAnalyticsEnabled = simpleAnalyticsEnabled
            blogToUpdate.simpleAnalyticsDomain = simpleAnalyticsDomain.isEmpty ? nil : simpleAnalyticsDomain
        }
    }
}

#Preview("New Blog") {
    BlogFormView()
        .modelContainer(PreviewData.previewContainer)
}

#Preview("Edit Blog") {
    BlogFormView(blog: PreviewData.blogWithContent())
        .modelContainer(PreviewData.previewContainer)
}
