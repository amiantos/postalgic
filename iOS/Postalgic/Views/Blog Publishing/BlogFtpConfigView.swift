//
//  BlogFtpConfigView.swift
//  Postalgic
//
//  Created by Brad Root on 4/25/25.
//

import SwiftData
import SwiftUI

struct BlogFtpConfigView: View {
    @Bindable var blog: Blog
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    @State private var host: String = ""
    @State private var port: String = "22"
    @State private var username: String = ""
    @State private var password: String = ""
    @State private var remotePath: String = "/"
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("SFTP Server")) {
                    TextField("Host (e.g. sftp.example.com)", text: $host)
                        .keyboardType(.URL)
                        .textContentType(.URL)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                    
                    TextField("Port", text: $port)
                        .keyboardType(.numberPad)
                }
                
                Section(header: Text("Authentication")) {
                    TextField("Username", text: $username)
                        .textContentType(.username)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                    
                    SecureField("Password", text: $password)
                        .textContentType(.password)
                }
                
                Section(header: Text("Upload Settings")) {
                    TextField("Remote Path", text: $remotePath)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                }
                
                Section(header: Text("Help"), footer: Text("The remote path should be the directory where your site files will be uploaded. For most web hosts, this is the 'public_html' or 'www' directory.")) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("SFTP Settings")
                            .font(.headline)
                        
                        Text("• SFTP (SSH File Transfer Protocol) typically uses port 22")
                            .font(.caption)
                            
                        Text("• Include the full hostname without 'sftp://'")
                            .font(.caption)
                            
                        Text("• Make sure you have SFTP access enabled on your server")
                            .font(.caption)
                    }
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle("SFTP Configuration")
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
                if let ftpHost = blog.ftpHost {
                    host = ftpHost
                }
                
                if let ftpPort = blog.ftpPort {
                    port = String(ftpPort)
                }
                
                if let ftpUsername = blog.ftpUsername {
                    username = ftpUsername
                }
                
                // Get password from keychain or SwiftData model
                password = blog.getFtpPassword() ?? ""
                
                if let ftpPath = blog.ftpPath {
                    remotePath = ftpPath
                }
                
                // Always set to true since we only support SFTP now
                blog.ftpUseSFTP = true
            }
        }
    }
    
    private func saveConfig() {
        blog.ftpHost = host.trimmingCharacters(in: .whitespacesAndNewlines)
        blog.ftpPort = Int(port) ?? 22
        blog.ftpUsername = username.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Store password in keychain
        if !password.isEmpty {
            blog.setFtpPassword(password)
        }
        
        blog.ftpPath = remotePath.trimmingCharacters(in: .whitespacesAndNewlines)
        blog.ftpUseSFTP = true // Always set to true since we only support SFTP now
        
        try? modelContext.save()
    }
}

#Preview {
    BlogFtpConfigView(blog: PreviewData.blog)
        .modelContainer(PreviewData.previewContainer)
}
