//
//  PublishSettingsView.swift
//  Postalgic
//
//  Created by Brad Root on 4/25/25.
//

import SwiftData
import SwiftUI

struct PublishSettingsView: View {
    @Bindable var blog: Blog
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedTab = 0
    @State private var showingAwsConfigView = false
    @State private var showingFtpConfigView = false
    
    var body: some View {
        NavigationStack {
            VStack {
                // Header section with site URL
                VStack(alignment: .leading, spacing: 10) {
                    Text("Blog URL")
                        .font(.headline)
                    TextField("https://yourblog.com", text: $blog.url)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .keyboardType(.URL)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                        .textContentType(.URL)
                }
                .padding(.horizontal)
                .padding(.bottom, 20)
                
                // Publisher selection segment control
                VStack(alignment: .leading) {
                    Text("Publishing Method")
                        .font(.headline)
                        .padding(.horizontal)
                    
                    Picker("Publishing Method", selection: Binding(
                        get: { 
                            return blog.currentPublisherType
                        },
                        set: { 
                            blog.publisherType = $0.rawValue
                        }
                    )) {
                        ForEach(PublisherType.allCases, id: \.self) { type in
                            Text(type.displayName).tag(type)
                        }
                    }
                    .pickerStyle(NavigationLinkPickerStyle())
                    .padding(.horizontal)
                }
                
                // Publisher-specific settings
                switch blog.currentPublisherType {
                case .aws:
                    awsSettingsView
                case .ftp:
                    ftpSettingsView
                case .netlify:
                    netlifySettingsView
                case .none:
                    manualDownloadView
                }
                
                Spacer()
            }
            .padding(.top)
            .navigationTitle("Publish Settings")
            .navigationBarItems(
                trailing: Button("Done") {
                    dismiss()
                }
            )
            .sheet(isPresented: $showingAwsConfigView) {
                BlogAwsConfigView(blog: blog)
            }
            .sheet(isPresented: $showingFtpConfigView) {
                BlogFtpConfigView(blog: blog)
            }
        }
    }
    
    // AWS Settings View
    private var awsSettingsView: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("AWS Configuration")
                .font(.headline)
                .padding(.horizontal)
            
            if blog.hasAwsConfigured {
                // AWS Configured View
                VStack(alignment: .leading) {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(Color("PGreen"))
                        Text("AWS is properly configured")
                            .font(.subheadline)
                            .bold()
                    }
                    
                    VStack(alignment: .leading, spacing: 5) {
                        Text("Region: \(blog.awsRegion ?? "Not set")")
                            .font(.caption)
                        Text("S3 Bucket: \(blog.awsS3Bucket ?? "Not set")")
                            .font(.caption)
                        Text("CloudFront: \(blog.awsCloudFrontDistId?.prefix(10) ?? "Not set")...")
                            .font(.caption)
                        Text("AWS Keys: \(blog.awsAccessKeyId != nil ? "Configured" : "Not set")")
                            .font(.caption)
                    }
                    .foregroundColor(.secondary)
                    .padding(.leading, 25)
                }
                .padding()
                .background(Color("PGreen").opacity(0.1))
                .cornerRadius(10)
                .padding(.horizontal)
                
                Button(action: {
                    showingAwsConfigView = true
                }) {
                    Text("Edit AWS Configuration")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .padding(.horizontal)
            } else {
                // AWS Not Configured View
                VStack(alignment: .leading) {
                    HStack {
                        Image(systemName: "exclamationmark.circle.fill")
                            .foregroundColor(.orange)
                        Text("AWS is not fully configured")
                            .font(.subheadline)
                            .bold()
                    }
                    
                    Text("You need to configure your AWS credentials to publish directly to an S3 bucket with CloudFront invalidation.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.leading, 25)
                }
                .padding()
                .background(Color.orange.opacity(0.1))
                .cornerRadius(10)
                .padding(.horizontal)
                
                Button(action: {
                    showingAwsConfigView = true
                }) {
                    Text("Configure AWS")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .padding(.horizontal)
            }
            
            Text("AWS publishing lets you directly upload your static site to an S3 bucket and automatically create CloudFront invalidations to ensure your content is served fresh.")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.horizontal)
            
            Spacer()
        }
    }
    
    // FTP Settings View
    private var ftpSettingsView: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("SFTP Configuration")
                .font(.headline)
                .padding(.horizontal)
            
            if blog.hasFtpConfigured {
                // FTP Configured View
                VStack(alignment: .leading) {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(Color("PGreen"))
                        Text("SFTP is properly configured")
                            .font(.subheadline)
                            .bold()
                    }
                    
                    VStack(alignment: .leading, spacing: 5) {
                        Text("Host: \(blog.ftpHost ?? "Not set")")
                            .font(.caption)
                        Text("Port: \(blog.ftpPort != nil ? String(blog.ftpPort!) : "Not set")")
                            .font(.caption)
                        Text("Protocol: SFTP (Secure)")
                            .font(.caption)
                        Text("Username: \(blog.ftpUsername ?? "Not set")")
                            .font(.caption)
                        Text("Remote Path: \(blog.ftpPath ?? "Not set")")
                            .font(.caption)
                    }
                    .foregroundColor(.secondary)
                    .padding(.leading, 25)
                }
                .padding()
                .background(Color("PGreen").opacity(0.1))
                .cornerRadius(10)
                .padding(.horizontal)
                
                Button(action: {
                    showingFtpConfigView = true
                }) {
                    Text("Edit SFTP Configuration")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .padding(.horizontal)
            } else {
                // FTP Not Configured View
                VStack(alignment: .leading) {
                    HStack {
                        Image(systemName: "exclamationmark.circle.fill")
                            .foregroundColor(.orange)
                        Text("SFTP is not fully configured")
                            .font(.subheadline)
                            .bold()
                    }
                    
                    Text("You need to configure your SFTP credentials to publish directly to your web server.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.leading, 25)
                }
                .padding()
                .background(Color.orange.opacity(0.1))
                .cornerRadius(10)
                .padding(.horizontal)
                
                Button(action: {
                    showingFtpConfigView = true
                }) {
                    Text("Configure SFTP")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .padding(.horizontal)
            }
            
            Text("SFTP publishing lets you directly upload your static site to any web hosting service that supports secure file transfer protocol.")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.horizontal)
            
            Spacer()
        }
    }
    
    // Netlify Settings View (placeholder for future implementation)
    private var netlifySettingsView: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Netlify Configuration")
                .font(.headline)
                .padding(.horizontal)
            
            VStack(alignment: .leading) {
                HStack {
                    Image(systemName: "hammer.fill")
                        .foregroundColor(.blue)
                    Text("Coming Soon")
                        .font(.subheadline)
                        .bold()
                }
                
                Text("Netlify publishing is not yet available. Please choose another publishing method for now.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.leading, 25)
            }
            .padding()
            .background(Color.blue.opacity(0.1))
            .cornerRadius(10)
            .padding(.horizontal)
            
            Spacer()
        }
    }
    
    // Manual Download View
    private var manualDownloadView: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Manual Download Settings")
                .font(.headline)
                .padding(.horizontal)
            
            VStack(alignment: .leading) {
                HStack {
                    Image(systemName: "info.circle.fill")
                        .foregroundColor(.blue)
                    Text("Manual Download Mode")
                        .font(.subheadline)
                        .bold()
                }
                
                Text("Your site will be generated as a ZIP file that you can download and manually upload to any web host of your choice.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.leading, 25)
            }
            .padding()
            .background(Color.blue.opacity(0.1))
            .cornerRadius(10)
            .padding(.horizontal)
            
            Text("Make sure the Blog URL above matches where you'll be hosting your site, so all internal links and the sitemap work correctly.")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.horizontal)
            
            Spacer()
        }
    }
}

#Preview("AWS Configured") {
    PublishSettingsView(blog: PreviewData.blogWithContent())
        .modelContainer(PreviewData.previewContainer)
}

#Preview("AWS Not Configured") {
    PublishSettingsView(blog: PreviewData.blog)
        .modelContainer(PreviewData.previewContainer)
}
