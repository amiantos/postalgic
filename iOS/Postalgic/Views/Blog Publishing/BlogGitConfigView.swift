//
//  BlogGitConfigView.swift
//  Postalgic
//
//  Created by Claude on 5/14/25.
//

import SwiftData
import SwiftUI

struct BlogGitConfigView: View {
    @Bindable var blog: Blog
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    @State private var repositoryUrl: String = ""
    @State private var username: String = ""
    @State private var password: String = ""
    @State private var branch: String = "main"
    @State private var commitMessage: String = "Update site content"
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Git Repository")) {
                    TextField("Repository URL (e.g. https://github.com/user/repo.git)", text: $repositoryUrl)
                        .keyboardType(.URL)
                        .textContentType(.URL)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                }
                
                Section(header: Text("Authentication")) {
                    TextField("Username", text: $username)
                        .textContentType(.username)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                    
                    SecureField("Password or Token", text: $password)
                        .textContentType(.password)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                }
                
                Section(header: Text("Branch Settings")) {
                    TextField("Branch Name", text: $branch)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                }
                
                Section(header: Text("Commit Settings")) {
                    TextField("Commit Message", text: $commitMessage)
                        .disableAutocorrection(true)
                }
                
                Section(header: Text("Help"), footer: Text("For GitHub, you can use a personal access token with the 'repo' scope as your password. For GitLab, use a personal access token with the 'write_repository' scope.")) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Git Repository Settings")
                            .font(.headline)
                        
                        Text("• Use HTTPS URLs for repositories (not SSH)")
                            .font(.caption)
                        
                        Text("• The branch will be created if it doesn't exist")
                            .font(.caption)
                    }
                    .padding(.vertical, 4)
                    
                    Link("GitHub Pages Tutorial", destination: URL(string: "https://postalgic.app/help/github-pages-setup/")!)
                }
                
                Section(
                    footer: Text(
                        "You can remove Git configuration at any time."
                    )
                ) {
                    Button(action: {
                        // Clear Git configuration
                        blog.gitRepositoryUrl = nil
                        blog.gitUsername = nil
                        
                        // Clear password from keychain if available
                        try? KeychainService.deletePassword(for: blog.persistentModelID, type: .git)
                        password = ""
                        
                        blog.gitBranch = nil
                        blog.gitCommitMessage = nil
                        try? modelContext.save()
                    }) {
                        Text("Clear Git Configuration")
                            .foregroundColor(.red)
                    }
                }
            }
            .navigationTitle("Git Repository Configuration")
            .navigationBarItems(
                leading: Button("Cancel") {
                    dismiss()
                },
                trailing: Button("Save") {
                    saveConfig()
                    dismiss()
                }
            )
            .onAppear {
                // Load existing values if available
                if let gitRepositoryUrl = blog.gitRepositoryUrl {
                    repositoryUrl = gitRepositoryUrl
                }
                
                if let gitUsername = blog.gitUsername {
                    username = gitUsername
                }
                
                // Get password from keychain or SwiftData model
                password = blog.getGitPassword() ?? ""
                
                if let gitBranch = blog.gitBranch {
                    branch = gitBranch
                }
                
                if let gitCommitMessage = blog.gitCommitMessage {
                    commitMessage = gitCommitMessage
                }
            }
        }
    }
    
    private func saveConfig() {
        blog.gitRepositoryUrl = repositoryUrl.trimmingCharacters(in: .whitespacesAndNewlines)
        blog.gitUsername = username.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Store password in keychain
        if !password.isEmpty {
            blog.setGitPassword(password)
        }
        
        blog.gitBranch = branch.trimmingCharacters(in: .whitespacesAndNewlines)
        blog.gitCommitMessage = commitMessage.trimmingCharacters(in: .whitespacesAndNewlines)
        
        try? modelContext.save()
    }
}

#Preview {
    BlogGitConfigView(blog: PreviewData.blog)
        .modelContainer(PreviewData.previewContainer)
}
