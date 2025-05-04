import SwiftUI
import UIKit
import SwiftData

struct NewPostView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    // The blog the post belongs to
    private var blog: Blog
    
    // Whether we're creating a new post or editing an existing one
    private var isNewPost: Bool
    
    // For editing an existing post
    @State private var existingPost: Post?
    
    // UI State
    @State private var title: String = ""
    @State private var content: String = ""
    @State private var showURLPrompt: Bool = false
    @State private var urlText: String = ""
    @State private var urlLink: String = ""
    @State private var showingPostSettings: Bool = false
    @State private var showPublishView: Bool = false
    
    // For creating a new post
    init(blog: Blog) {
        self.blog = blog
        self.isNewPost = true
        self.existingPost = nil
    }
    
    // For editing an existing post
    init(post: Post) {
        self.blog = post.blog!
        self.isNewPost = false
        self.existingPost = post
        self._title = State(initialValue: post.title ?? "")
        self._content = State(initialValue: post.content)
    }
    
    private var post: Post {
        if let existingPost = existingPost {
            return existingPost
        } else {
            // Create a temporary post if needed for PostFormView
            // This won't be used directly for editing, just as a reference
            let temp = Post(title: title.isEmpty ? nil : title, content: content, isDraft: true)
            temp.blog = blog
            return temp
        }
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                TextField("Title (optional)", text: $title)
                    .font(.title)
                    .padding()
                
                Divider()
                
                MarkdownTextEditor(text: $content, onShowLinkPrompt: { selectedText, selectedRange in
                    self.handleShowLinkPrompt(selectedText: selectedText, selectedRange: selectedRange)
                })
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .navigationTitle(isNewPost ? "New Post" : "Edit Post")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                // Leading toolbar items
                ToolbarItem(placement: .topBarLeading) {
                    if isNewPost {
                        Button("Delete") {
                            dismiss()
                        }
                    } else {
                        Button("Done") {
                            saveChanges(asDraft: existingPost?.isDraft ?? true)
                            dismiss()
                        }
                    }
                }
                
                // Trailing toolbar items
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button(action: {
                            if isNewPost {
                                // Create and save the post first before showing settings
                                let newPost = createNewPost(isDraft: true)
                                existingPost = newPost
                            }
                            showingPostSettings = true
                        }) {
                            Label("Post Settings", systemImage: "gear")
                        }
                        
                        Button(action: {
                            saveChanges(asDraft: true)
                            dismiss()
                        }) {
                            Label("Save as Draft", systemImage: "square.and.arrow.down")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
                
                ToolbarItem(placement: .primaryAction) {
                    Button("Publish") {
                        saveChanges(asDraft: false)
                        showPublishView = true
                    }
                    .disabled(content.isEmpty)
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
            .sheet(isPresented: $showingPostSettings) {
                if let existingPost = existingPost {
                    PostFormView(post: existingPost)
                }
            }
            .sheet(isPresented: $showPublishView, onDismiss: {
                dismiss()
            }) {
                PublishBlogView(blog: blog, autoPublish: true)
            }
        }
    }
    
    private func createNewPost(isDraft: Bool) -> Post {
        // Create a new post
        let newPost = Post(
            title: title.isEmpty ? nil : title,
            content: content,
            isDraft: isDraft
        )
        
        // Set the blog reference and add to blog's posts
        newPost.blog = blog
        blog.posts.append(newPost)
        
        // Insert into model context
        modelContext.insert(newPost)
        
        // Generate stub
        newPost.regenerateStub()
        
        return newPost
    }
    
    private func saveChanges(asDraft: Bool) {
        if isNewPost {
            // Create a new post
            _ = createNewPost(isDraft: asDraft)
        } else if let existingPost = existingPost {
            // Update existing post
            existingPost.title = title.isEmpty ? nil : title
            existingPost.content = content
            existingPost.isDraft = asDraft
            existingPost.regenerateStub()
        }
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
        let flexSpace = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
        let doneButton = UIBarButtonItem(barButtonSystemItem: .done, target: context.coordinator, action: #selector(Coordinator.doneTapped))
        
        toolbar.items = [boldButton, italicButton, quoteButton, linkButton, flexSpace, doneButton]
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
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text, onShowLinkPrompt: onShowLinkPrompt)
    }
    
    class Coordinator: NSObject, UITextViewDelegate {
        @Binding var text: String
        var onShowLinkPrompt: (String?, NSRange?) -> Void
        weak var textView: UITextView?
        
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
                // Split by newlines and add > to each line
                let lines = selectedText.split(separator: "\n")
                let quotedText = lines.map { "> \($0)" }.joined(separator: "\n")
                textView.replace(selectedRange, withText: quotedText)
            } else {
                textView.insertText("> ")
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

#Preview("New Post") {
    let modelContainer = PreviewData.previewContainer
    let blog = try! modelContainer.mainContext.fetch(FetchDescriptor<Blog>()).first!
    
    return NavigationStack {
        NewPostView(blog: blog)
    }
    .modelContainer(modelContainer)
}

#Preview("Edit Post") {
    let modelContainer = PreviewData.previewContainer
    let blog = try! modelContainer.mainContext.fetch(FetchDescriptor<Blog>()).first!
    
    return NavigationStack {
        NewPostView(post: blog.posts.first!)
    }
    .modelContainer(modelContainer)
}