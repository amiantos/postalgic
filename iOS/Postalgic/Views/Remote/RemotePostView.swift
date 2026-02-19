//
//  RemotePostView.swift
//  Postalgic
//
//  Created by Claude on 2/18/26.
//

import SwiftUI

struct RemotePostView: View {
    @Environment(\.dismiss) private var dismiss

    let server: RemoteServer
    let blog: RemoteBlog
    let existingPost: RemotePost?

    // Post fields
    @State private var title: String = ""
    @State private var content: String = ""
    @State private var isDraft: Bool = true
    @State private var createdAt: Date = Date()
    @State private var selectedCategoryId: String?
    @State private var selectedTagIds: [String] = []

    // UI state
    @State private var showURLPrompt: Bool = false
    @State private var urlText: String = ""
    @State private var urlLink: String = ""
    @State private var showingDatePicker: Bool = false
    @State private var selectedDate: Date = Date()
    @State private var isSaving: Bool = false
    @State private var errorMessage: String?
    @State private var showingError: Bool = false

    // Category/tag data for display
    @State private var categories: [RemoteCategory] = []
    @State private var tags: [RemoteTag] = []
    @State private var selectedCategoryName: String?
    @State private var selectedTagNames: [String] = []

    // Callback for refresh after save
    var onSave: (() -> Void)?

    private var isNewPost: Bool { existingPost == nil }

    init(server: RemoteServer, blog: RemoteBlog, existingPost: RemotePost? = nil, onSave: (() -> Void)? = nil) {
        self.server = server
        self.blog = blog
        self.existingPost = existingPost
        self.onSave = onSave
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                TextField("Title (optional)", text: $title)
                    .font(.title3)
                    .padding()

                Divider()

                HStack(spacing: 0.0) {
                    NavigationLink(destination: RemoteCategorySelectionView(
                        server: server,
                        blogId: blog.id,
                        selectedCategoryId: $selectedCategoryId,
                        selectedCategoryName: $selectedCategoryName
                    )) {
                        Label(selectedCategoryName ?? "Add Category", systemImage: "folder")
                            .font(.footnote)
                            .padding(.leading)
                            .padding(.vertical, 12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    NavigationLink(destination: RemoteTagSelectionView(
                        server: server,
                        blogId: blog.id,
                        selectedTagIds: $selectedTagIds,
                        selectedTagNames: $selectedTagNames
                    )) {
                        Label(selectedTagIds.isEmpty ? "Add Tags" : "\(selectedTagIds.count) tag\(selectedTagIds.count == 1 ? "" : "s")", systemImage: "tag")
                            .font(.footnote)
                            .padding(.vertical, 12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }.foregroundStyle(.secondary)

                Divider()

                HStack(spacing: 0.0) {
                    Button(action: {
                        selectedDate = createdAt
                        showingDatePicker = true
                    }) {
                        Label(shortFormattedDate, systemImage: "calendar")
                            .font(.footnote)
                            .padding(.leading)
                            .padding(.vertical, 12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }.foregroundStyle(.secondary)

                Divider()

                MarkdownTextEditor(text: $content,
                    onShowLinkPrompt: { selectedText, selectedRange in
                        handleShowLinkPrompt(selectedText: selectedText, selectedRange: selectedRange)
                    },
                    focusOnAppear: isNewPost)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItemGroup(placement: .topBarLeading) {
                    Button(isNewPost ? "Cancel" : "Close") {
                        dismiss()
                    }
                }

                ToolbarItemGroup(placement: .topBarTrailing) {
                    if isSaving {
                        ProgressView()
                    } else {
                        Button("Save as Draft") {
                            savePost(asDraft: true)
                        }

                        Button("Publish") {
                            savePost(asDraft: false)
                        }
                    }
                }
            }
            .alert("Add Link", isPresented: $showURLPrompt) {
                TextField("Text", text: $urlText)
                TextField("URL", text: $urlLink)
                Button("Cancel", role: .cancel) {}
                Button("Add") {
                    insertLink()
                }
            } message: {
                Text("Enter link details")
            }
            .alert("Error", isPresented: $showingError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "An unknown error occurred")
            }
            .sheet(isPresented: $showingDatePicker) {
                NavigationStack {
                    ScrollView {
                        VStack {
                            DatePicker("Post Date", selection: $selectedDate, displayedComponents: [.date, .hourAndMinute])
                                .datePickerStyle(.graphical)
                                .padding(.horizontal)
                            Spacer()
                        }
                    }
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Cancel") {
                                showingDatePicker = false
                            }
                        }
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Save") {
                                createdAt = selectedDate
                                showingDatePicker = false
                            }
                        }
                    }
                    .navigationTitle("Change Post Date")
                }
            }
            .onAppear {
                loadExistingPost()
            }
        }
    }

    // MARK: - Computed Properties

    private var shortFormattedDate: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US")
        formatter.dateStyle = .long
        formatter.timeStyle = .none
        return formatter.string(from: createdAt)
    }

    // MARK: - Data Loading

    private func loadExistingPost() {
        guard let post = existingPost else { return }
        title = post.title ?? ""
        content = post.content
        isDraft = post.isDraft
        selectedCategoryId = post.categoryId ?? post.category?.id
        selectedCategoryName = post.category?.name
        selectedTagIds = post.tags?.map(\.id) ?? post.tagIds ?? []
        selectedTagNames = post.tags?.map(\.name) ?? []

        // Parse the creation date
        let iso8601 = ISO8601DateFormatter()
        iso8601.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = iso8601.date(from: post.createdAt) {
            createdAt = date
        } else {
            iso8601.formatOptions = [.withInternetDateTime]
            if let date = iso8601.date(from: post.createdAt) {
                createdAt = date
            }
        }
    }

    // MARK: - Save

    private func savePost(asDraft: Bool) {
        isSaving = true

        var body: [String: Any] = [
            "content": content,
            "isDraft": asDraft,
            "tagIds": selectedTagIds,
            "createdAt": ISO8601DateFormatter().string(from: createdAt)
        ]

        if !title.isEmpty {
            body["title"] = title
        } else {
            body["title"] = NSNull()
        }

        if let categoryId = selectedCategoryId {
            body["categoryId"] = categoryId
        } else {
            body["categoryId"] = NSNull()
        }

        let client = PostalgicAPIClient(server: server)

        Task {
            do {
                if let existing = existingPost {
                    let _ = try await client.updatePost(blogId: blog.id, postId: existing.id, body: body)
                } else {
                    let _ = try await client.createPost(blogId: blog.id, body: body)
                }

                await MainActor.run {
                    isSaving = false
                    onSave?()
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    isSaving = false
                    errorMessage = error.localizedDescription
                    showingError = true
                }
            }
        }
    }

    // MARK: - Link Handling

    private func handleShowLinkPrompt(selectedText: String?, selectedRange: NSRange?) {
        if let text = selectedText, !text.isEmpty {
            urlText = text

            if let clipboardString = UIPasteboard.general.string,
               let url = URL(string: clipboardString),
               UIApplication.shared.canOpenURL(url) {
                urlLink = clipboardString
                insertLink()
            } else {
                urlLink = ""
                showURLPrompt = true
            }
        } else {
            urlText = ""
            urlLink = ""
            showURLPrompt = true
        }
    }

    private func insertLink() {
        guard !urlText.isEmpty else { return }

        let markdownLink = "[\(urlText)](\(urlLink))"
        let notification = Notification(name: Notification.Name("InsertMarkdownLink"),
                                        object: nil,
                                        userInfo: ["text": markdownLink])
        NotificationCenter.default.post(notification)
    }
}
