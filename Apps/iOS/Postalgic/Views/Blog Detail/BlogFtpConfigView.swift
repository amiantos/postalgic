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
    
    @State private var host: String = ""
    @State private var port: String = "21"
    @State private var username: String = ""
    @State private var password: String = ""
    @State private var remotePath: String = "/"
    @State private var useSFTP: Bool = false
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("FTP/SFTP Server")) {
                    TextField("Host (e.g. ftp.example.com)", text: $host)
                        .keyboardType(.URL)
                        .textContentType(.URL)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                    
                    TextField("Port", text: $port)
                        .keyboardType(.numberPad)
                    
                    Toggle("Use SFTP (Secure FTP)", isOn: $useSFTP)
                        .onChange(of: useSFTP) { oldValue, newValue in
                            if newValue && port == "21" {
                                port = "22"
                            } else if !newValue && port == "22" {
                                port = "21"
                            }
                        }
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
                        Text("FTP/SFTP Settings")
                            .font(.headline)
                        
                        Text("• Standard FTP uses port 21")
                            .font(.caption)
                        
                        Text("• SFTP (SSH File Transfer Protocol) uses port 22")
                            .font(.caption)
                            
                        Text("• Include the full hostname without 'ftp://' or 'sftp://'")
                            .font(.caption)
                    }
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle("FTP/SFTP Configuration")
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
                
                if let ftpPassword = blog.ftpPassword {
                    password = ftpPassword
                }
                
                if let ftpPath = blog.ftpPath {
                    remotePath = ftpPath
                }
                
                useSFTP = blog.ftpUseSFTP ?? false
            }
        }
    }
    
    private func saveConfig() {
        blog.ftpHost = host.trimmingCharacters(in: .whitespacesAndNewlines)
        blog.ftpPort = Int(port) ?? (useSFTP ? 22 : 21)
        blog.ftpUsername = username.trimmingCharacters(in: .whitespacesAndNewlines)
        blog.ftpPassword = password
        blog.ftpPath = remotePath.trimmingCharacters(in: .whitespacesAndNewlines)
        blog.ftpUseSFTP = useSFTP
    }
}

#Preview {
    BlogFtpConfigView(blog: PreviewData.blog)
        .modelContainer(PreviewData.previewContainer)
}