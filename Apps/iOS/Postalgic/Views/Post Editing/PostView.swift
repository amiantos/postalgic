import SwiftUI
import UIKit
import SwiftData

/// Captures the initial state of a post for dirty tracking
private struct PostSnapshot {
    let title: String?
    let content: String
    let createdAt: Date
    let categoryId: String?
    let tagIds: Set<String>
    let hasEmbed: Bool
    let embedType: String?
    let embedUrl: String?
    let embedImageCount: Int

    init(post: Post) {
        self.title = post.title
        self.content = post.content
        self.createdAt = post.createdAt
        self.categoryId = post.category?.syncId
        self.tagIds = Set(post.tags.compactMap { $0.syncId })
        self.hasEmbed = post.embed != nil
        self.embedType = post.embed?.type
        self.embedUrl = post.embed?.url
        self.embedImageCount = post.embed?.images.count ?? 0
    }

    func hasChanged(from post: Post) -> Bool {
        if title != post.title { return true }
        if content != post.content { return true }
        if createdAt != post.createdAt { return true }
        if categoryId != post.category?.syncId { return true }
        if tagIds != Set(post.tags.compactMap { $0.syncId }) { return true }
        if hasEmbed != (post.embed != nil) { return true }
        if embedType != post.embed?.type { return true }
        if embedUrl != post.embed?.url { return true }
        if embedImageCount != (post.embed?.images.count ?? 0) { return true }
        return false
    }
}

struct PostView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let blog: Blog
    @State private var post: Post

    @State private var showURLPrompt: Bool = false
    @State private var urlText: String = ""
    @State private var urlLink: String = ""

    @State private var showingSettings: Bool = false
    @State private var showingPublishView: Bool = false

    // For embed functionality
    @State private var showingEmbedTypeAlert: Bool = false
    @State private var showingEmbedActionAlert: Bool = false
    @State private var showingURLEmbed: Bool = false
    @State private var showingImageEmbed: Bool = false
    @State private var showingDatePicker: Bool = false
    @State private var selectedDate: Date

    // For dirty state tracking
    @State private var initialSnapshot: PostSnapshot?
    private let isNewPost: Bool

    init(blog: Blog) {
        self.blog = blog
        self.post = Post(content: "", isDraft: true)
        self._selectedDate = State(initialValue: Date())
        self.isNewPost = true
    }

    init(post: Post) {
        guard let blog = post.blog else { fatalError("Cannot init this view with a post with no blog associated with it")}
        self.blog = blog
        self.post = post
        self._selectedDate = State(initialValue: post.createdAt)
        self.isNewPost = false
    }

    // Computed properties for embed button label
    var embedLabelText: String {
        if let embed = post.embed {
            switch embed.embedType {
            case .youtube:
                return "YouTube Video"
            case .link:
                return "Link Embeded"
            case .image:
                let count = embed.images.count
                return count == 1 ? "1 Image" : "\(count) Images"
            }
        } else {
            return "Embed Content"
        }
    }

    var embedIconName: String {
        if let embed = post.embed {
            switch embed.embedType {
            case .youtube:
                return "play.rectangle"
            case .link:
                return "link"
            case .image:
                return "photo"
            }
        } else {
            return "paperclip"
        }
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                TextField("Title (optional)", text: Binding(
                    get: { post.title ?? "" },
                    set: { post.title = $0.isEmpty ? nil : $0 }
                ))
                .font(.title3)
                .padding()
                
                Divider()
                
                HStack(spacing: 0.0) {
                    NavigationLink(destination: CategorySelectionView(blog: blog, post: post)) {
                        Label(post.category?.name ?? "Add Category", systemImage: "folder")
                            .font(.footnote)
                            .padding(.leading)
                            .padding(.vertical, 12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

//                    Divider().frame(height: 10)

                    NavigationLink(destination: TagSelectionView(blog: blog, post: post)) {
                        Label(post.tags.isEmpty ? "Add Tags" : "\(post.tags.count) tag\(post.tags.count == 1 ? "" : "s")", systemImage: "tag")
                            .font(.footnote)
                            .padding(.vertical, 12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }.foregroundStyle(.secondary)

                Divider()

                HStack(spacing: 0.0) {
                    Button(action: {
                        if post.embed == nil {
                            showingEmbedTypeAlert = true
                        } else {
                            showingEmbedActionAlert = true
                        }
                    }) {
                        Label(embedLabelText, systemImage: embedIconName)
                            .font(.footnote)
                            .padding(.leading)
                            .padding(.vertical, 12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    
                    Button(action: {
                        selectedDate = post.createdAt
                        showingDatePicker = true
                    }) {
                        Label(post.shortFormattedDate, systemImage: "calendar")
                            .font(.footnote)
                            .padding(.vertical, 12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }.foregroundStyle(.secondary)

                Divider()

                MarkdownTextEditor(text: Binding(
                    get: { post.content },
                    set: { post.content = $0 }
                ),
                onShowLinkPrompt: {
                    selectedText, selectedRange in
                    self.handleShowLinkPrompt(selectedText: selectedText, selectedRange: selectedRange)
                },
                focusOnAppear: true)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItemGroup(placement: .topBarLeading) {
                    if post.blog == nil {
                        Button("Cancel", role: .destructive) {
                            modelContext.delete(post)
                            dismiss()
                        }
                    } else {
                        Button("Save & Close") {
                            savePost()
                            dismiss()
                        }
                    }
                    
                    Button {
                        if let url = URL(string: "https://postalgic.app/help/markdown-support/") {
                           UIApplication.shared.open(url)
                        }
                    } label: {
                        Label("Help", systemImage: "questionmark.circle")
                    }
                    
                }

                ToolbarItemGroup(placement: .topBarTrailing) {
                    if post.blog == nil || !post.isDraft {
                        Button("Save as Draft") {
                            if post.blog == nil {
                                post.blog = blog
                                modelContext.insert(post)
                                blog.posts.append(post)
                            }
                            post.isDraft = true
                            // Ensure stub is generated even for drafts
                            if !post.content.isEmpty || (post.title != nil && !post.title!.isEmpty) {
                                post.regenerateStub()
                            }
                            savePost()
                            dismiss()
                        }
                    }


                    Button("Publish") {
                        if post.blog == nil {
                            post.blog = blog
                            modelContext.insert(post)
                            blog.posts.append(post)
                        }
                        post.isDraft = false
                        post.regenerateStub()
                        savePost()
                        showingPublishView = true
                    }
                }
            }
            // Link prompt alert
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
            // Embed type selection alert
            .alert("Add Embed", isPresented: $showingEmbedTypeAlert) {
                Button("URL or YouTube Video") {
                    showingURLEmbed = true
                }
                Button("Images") {
                    showingImageEmbed = true
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Choose the type of content to embed")
            }
            // Embed action alert
            .alert("Embed Options", isPresented: $showingEmbedActionAlert) {
                Button("Edit") {
                    if let embed = post.embed {
                        switch embed.embedType {
                        case .youtube, .link:
                            showingURLEmbed = true
                        case .image:
                            showingImageEmbed = true
                        }
                    }
                }
                Button("Remove", role: .destructive) {
                    if let oldEmbed = post.embed {
                        modelContext.delete(oldEmbed)
                        post.embed = nil
                        savePost()
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("What would you like to do with this embed?")
            }
            // Publish sheet
            .sheet(isPresented: $showingPublishView, onDismiss: {
                // Dismiss the PostView when the PublishBlogView is dismissed
                dismiss()
            }) {
                PublishBlogView(blog: blog, autoPublish: true)
            }
            // URL embed sheet
            .sheet(isPresented: $showingURLEmbed) {
                URLEmbedView(post: post, onTitleUpdate: { newTitle in
                    post.title = newTitle
                })
            }
            // Image embed sheet
            .sheet(isPresented: $showingImageEmbed) {
                ImageEmbedView(post: post)
            }
            
            // Date picker sheet
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
                                // Update the post's date
                                post.createdAt = selectedDate
                                savePost()
                                showingDatePicker = false
                            }
                        }
                    }
                    .navigationTitle("Change Post Date")
                }
            }
            .onAppear {
                // Capture initial state for dirty tracking (only for existing posts)
                if !isNewPost && initialSnapshot == nil {
                    initialSnapshot = PostSnapshot(post: post)
                }
            }
        }
    }

    /// Saves the post and updates `updatedAt` if the post has changed
    private func savePost() {
        // For existing posts, check if content has changed
        if !isNewPost, let snapshot = initialSnapshot {
            if snapshot.hasChanged(from: post) {
                post.updatedAt = Date()
            }
        }
        try? modelContext.save()
    }

    func handleShowLinkPrompt(selectedText: String?, selectedRange: NSRange?) {
        if let text = selectedText, !text.isEmpty {
            // Text is selected
            urlText = text
            
            // Check clipboard for URL
            if let clipboardString = UIPasteboard.general.string,
               let url = URL(string: clipboardString),
               UIApplication.shared.canOpenURL(url) {
                
                // Use clipboard URL
                urlLink = clipboardString
                insertLink()
            } else {
                // No URL in clipboard, show prompt for URL
                urlLink = ""
                showURLPrompt = true
            }
        } else {
            // No text selected, prompt for both text and URL
            urlText = ""
            urlLink = ""
            showURLPrompt = true
        }
    }
    
    func insertLink() {
        guard !urlText.isEmpty else { return }
        
        let markdownLink = "[\(urlText)](\(urlLink))"
        let notification = Notification(name: Notification.Name("InsertMarkdownLink"), 
                                        object: nil, 
                                        userInfo: ["text": markdownLink])
        NotificationCenter.default.post(notification)
    }
}

struct MarkdownTextEditor: UIViewRepresentable {
    @Binding var text: String
    var onShowLinkPrompt: (String?, NSRange?) -> Void
    var focusOnAppear: Bool = false

    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        textView.font = UIFont.preferredFont(forTextStyle: .body)
        textView.isScrollEnabled = true
        textView.isEditable = true
        textView.text = text
        textView.contentInset = UIEdgeInsets(top: 12, left: 12, bottom: 12, right: 12)
        textView.delegate = context.coordinator
        
        // Create and configure toolbar
        let toolbar = UIToolbar(frame: CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: 44))
        
        let boldButton = UIBarButtonItem(image: UIImage(systemName: "bold"), style: .plain, target: context.coordinator, action: #selector(Coordinator.boldTapped))
        let italicButton = UIBarButtonItem(image: UIImage(systemName: "italic"), style: .plain, target: context.coordinator, action: #selector(Coordinator.italicTapped))
        let quoteButton = UIBarButtonItem(image: UIImage(systemName: "text.quote"), style: .plain, target: context.coordinator, action: #selector(Coordinator.quoteTapped))
        let linkButton = UIBarButtonItem(image: UIImage(systemName: "link"), style: .plain, target: context.coordinator, action: #selector(Coordinator.linkTapped))
        let brButton = UIBarButtonItem(title: "BR", style: .plain, target: context.coordinator, action: #selector(Coordinator.brTapped))
        let spacer = UIBarButtonItem(barButtonSystemItem: .fixedSpace, target: nil, action: nil)
        spacer.width = 10
        let flexSpace = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
        let doneButton = UIBarButtonItem(barButtonSystemItem: .done, target: context.coordinator, action: #selector(Coordinator.doneTapped))
        
        toolbar.items = [boldButton, spacer, italicButton, spacer, quoteButton, spacer, linkButton, spacer, brButton, flexSpace, doneButton]
        toolbar.sizeToFit()
        
        textView.inputAccessoryView = toolbar
        
        // Setup link insertion notification observer
        NotificationCenter.default.addObserver(
            context.coordinator,
            selector: #selector(Coordinator.insertMarkdownLink(_:)),
            name: Notification.Name("InsertMarkdownLink"),
            object: nil
        )
        
        return textView
    }
    
    func updateUIView(_ textView: UITextView, context: Context) {
        if textView.text != text {
            textView.text = text
        }

        // Set focus if requested
        if focusOnAppear && !context.coordinator.didFocus {
            textView.becomeFirstResponder()
            context.coordinator.didFocus = true
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text, onShowLinkPrompt: onShowLinkPrompt)
    }
    
    class Coordinator: NSObject, UITextViewDelegate {
        @Binding var text: String
        var onShowLinkPrompt: (String?, NSRange?) -> Void
        weak var textView: UITextView?
        var didFocus: Bool = false

        init(text: Binding<String>, onShowLinkPrompt: @escaping (String?, NSRange?) -> Void) {
            self._text = text
            self.onShowLinkPrompt = onShowLinkPrompt
        }
        
        func textViewDidChange(_ textView: UITextView) {
            self.textView = textView
            text = textView.text
        }
        
        func textViewDidBeginEditing(_ textView: UITextView) {
            self.textView = textView
        }
        
        // Toolbar button actions
        @objc func boldTapped() {
            guard let textView = textView else { return }
            
            if let selectedRange = textView.selectedTextRange, !textView.selectedTextRange!.isEmpty {
                let selectedText = textView.text(in: selectedRange) ?? ""
                let boldText = "**\(selectedText)**"
                textView.replace(selectedRange, withText: boldText)
            } else {
                // Insert empty bold tags and position cursor between them
                let currentPosition = textView.selectedTextRange?.start ?? textView.beginningOfDocument
                textView.insertText("****")
                
                if let newPosition = textView.position(from: currentPosition, offset: 2) {
                    textView.selectedTextRange = textView.textRange(from: newPosition, to: newPosition)
                }
            }
            
            text = textView.text
        }
        
        @objc func italicTapped() {
            guard let textView = textView else { return }
            
            if let selectedRange = textView.selectedTextRange, !textView.selectedTextRange!.isEmpty {
                let selectedText = textView.text(in: selectedRange) ?? ""
                let italicText = "*\(selectedText)*"
                textView.replace(selectedRange, withText: italicText)
            } else {
                // Insert empty italic tags and position cursor between them
                let currentPosition = textView.selectedTextRange?.start ?? textView.beginningOfDocument
                textView.insertText("**")
                
                if let newPosition = textView.position(from: currentPosition, offset: 1) {
                    textView.selectedTextRange = textView.textRange(from: newPosition, to: newPosition)
                }
            }
            
            text = textView.text
        }
        
        @objc func quoteTapped() {
            guard let textView = textView else { return }
            
            if let selectedRange = textView.selectedTextRange, !textView.selectedTextRange!.isEmpty {
                let selectedText = textView.text(in: selectedRange) ?? ""
                let lines = selectedText.split(separator: "\n", omittingEmptySubsequences: false)
                
                if lines.count == 1 {
                    // Single line: just add > to the start
                    let quotedText = "> \(selectedText)"
                    textView.replace(selectedRange, withText: quotedText)
                } else {
                    // Multiple lines: add > to first line and \ to end of first line, then \ to end of subsequent lines (except last)
                    var quotedLines: [String] = []
                    for (index, line) in lines.enumerated() {
                        if index == 0 {
                            quotedLines.append("> \(line) \\")
                        } else if index == lines.count - 1 {
                            quotedLines.append("\(line)")
                        } else {
                            quotedLines.append("\(line) \\")
                        }
                    }
                    let quotedText = quotedLines.joined(separator: "\n")
                    textView.replace(selectedRange, withText: quotedText)
                }
            } else {
                // No selection: add > to start of current line
                let currentPosition = textView.selectedTextRange?.start ?? textView.beginningOfDocument
                let lineRange = textView.textRange(from: textView.beginningOfDocument, to: currentPosition)
                let textBeforeCursor = textView.text(in: lineRange!) ?? ""
                
                // Find the start of the current line
                let lines = textBeforeCursor.components(separatedBy: "\n")
                let currentLineStartOffset = textBeforeCursor.count - (lines.last?.count ?? 0)
                
                if let startOfLine = textView.position(from: textView.beginningOfDocument, offset: currentLineStartOffset) {
                    let rangeAtStartOfLine = textView.textRange(from: startOfLine, to: startOfLine)
                    textView.selectedTextRange = rangeAtStartOfLine
                    textView.insertText("> ")
                } else {
                    textView.insertText("> ")
                }
            }
            
            text = textView.text
        }
        
        @objc func linkTapped() {
            guard let textView = textView else { return }
            
            var selectedText: String? = nil
            var selectedRange: NSRange? = nil
            
            if let range = textView.selectedTextRange, !range.isEmpty {
                selectedText = textView.text(in: range)
                selectedRange = textView.selectedRange
            }
            
            onShowLinkPrompt(selectedText, selectedRange)
        }
        
        @objc func brTapped() {
            guard let textView = textView else { return }
            
            // Find the end of the current line
            let currentPosition = textView.selectedTextRange?.start ?? textView.beginningOfDocument
            let endOfDocument = textView.endOfDocument
            let textFromCursor = textView.textRange(from: currentPosition, to: endOfDocument)
            let remainingText = textView.text(in: textFromCursor!) ?? ""
            
            // Find the next newline or end of document
            let lines = remainingText.components(separatedBy: "\n")
            let currentLineLength = lines.first?.count ?? 0
            
            if let endOfLine = textView.position(from: currentPosition, offset: currentLineLength) {
                textView.selectedTextRange = textView.textRange(from: endOfLine, to: endOfLine)
                textView.insertText(" \\")
            } else {
                textView.insertText(" \\")
            }
            
            text = textView.text
        }
        
        @objc func doneTapped() {
            textView?.resignFirstResponder()
        }
        
        @objc func insertMarkdownLink(_ notification: Notification) {
            guard let textView = textView,
                  let userInfo = notification.userInfo,
                  let linkText = userInfo["text"] as? String else { return }
            
            if textView.selectedRange.length > 0 {
                // Replace selected text with link
                if let range = textView.selectedTextRange {
                    textView.replace(range, withText: linkText)
                }
            } else {
                // Insert at cursor position
                textView.insertText(linkText)
            }
            
            text = textView.text
        }
    }
}

#Preview {
    PostView(blog: PreviewData.blog)
}
