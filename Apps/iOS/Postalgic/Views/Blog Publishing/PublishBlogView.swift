//
//  PublishBlogView.swift
//  Postalgic
//
//  Created by Brad Root on 4/19/25.
//

import SwiftData
import SwiftUI
import UniformTypeIdentifiers

struct PublishBlogView: View {
    @Bindable var blog: Blog
    var autoPublish: Bool

    init(blog: Blog, autoPublish: Bool = false) {
        self.blog = blog
        self.autoPublish = autoPublish
    }

    @State private var isGenerating = false
    @State private var generatedZipURL: URL?
    @State private var errorMessage: String?
    @State private var publishSuccessMessage: String?
    @State private var statusMessage: String = "Initializing..."
    @State private var forceFullUpload = false

    @State private var showingShareSheet = false
    @State private var showingSuccessAlert = false
    @State private var showingPublishSettingsView = false
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Text("Publish \(blog.name)")
                    .font(.title)
                    .fontWeight(.bold)
                
                if blog.hasAwsConfigured && blog.currentPublisherType == .aws {
                    Text(
                        "Publishing will generate a static website from all your blog posts and securely upload it to your AWS S3 bucket using your AWS access keys. A CloudFront invalidation will be created to ensure your content is served fresh."
                    )
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                } else if blog.hasFtpConfigured && blog.currentPublisherType == .ftp
                {
                    Text(
                        "Publishing will generate a static website from all your blog posts and securely upload it to your web host using SFTP."
                    )
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                } else if blog.currentPublisherType == .none {
                    Text(
                        "Publishing will generate a static website from all your blog posts. The site will be packaged as a ZIP file you can download and upload to any web host."
                    )
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                } else {
                    Text(
                        "Publishing will generate a static website from all your blog posts for uploading to the host of your choice."
                    )
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                }
                
                // Publish Settings Button
                Button(action: {
                    showingPublishSettingsView = true
                }) {
                    HStack {
                        Image(systemName: "gear")
                        Text("Publishing Settings")
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.secondary.opacity(0.1))
                    .foregroundColor(.primary)
                    .cornerRadius(10)
                }
                .padding(.horizontal)
                
                if let errorMessage = errorMessage {
                    Text(errorMessage)
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                        .padding()
                }
                
                if let successMessage = publishSuccessMessage {
                    Text(successMessage)
                        .foregroundColor(Color("PGreen"))
                        .multilineTextAlignment(.center)
                        .padding()
                }
                
                if isGenerating {
                    ProgressView()
                        .padding()
                    Text(statusMessage)
                        .padding(.horizontal)
                        .multilineTextAlignment(.center)
                } else {
                    // Main publishing controls
                    VStack(spacing: 12) {
                        // AWS Publishing Button
                        if blog.hasAwsConfigured
                            && blog.currentPublisherType == .aws
                        {
                            VStack(spacing: 12) {
                                Button(action: {
                                    forceFullUpload = false
                                    generateSite()
                                }) {
                                    HStack {
                                        Image(systemName: "arrow.up.to.line")
                                            .font(.system(size: 16, weight: .bold))
                                        Text("Smart Publish to AWS")
                                            .fontWeight(.semibold)
                                    }
                                    .padding()
                                    .frame(maxWidth: .infinity)
                                    .background(Color("PBlue"))
                                    .foregroundColor(.primary)
                                    .cornerRadius(10)
                                }
                                .padding(.horizontal)
                                
                                Button(action: {
                                    forceFullUpload = true
                                    generateSite()
                                }) {
                                    HStack {
                                        Image(systemName: "arrow.up.to.line.square")
                                            .font(.system(size: 16, weight: .bold))
                                        Text("Full Publish to AWS")
                                            .fontWeight(.semibold)
                                    }
                                    .padding()
                                    .frame(maxWidth: .infinity)
                                    .background(Color("PYellow"))
                                    .foregroundColor(.primary)
                                    .cornerRadius(10)
                                }
                                .padding(.horizontal)
                            }
                            
                            // View Published Site Button (shown if success message exists)
                            if publishSuccessMessage != nil {
                                Button(action: {
                                    if let url = URL(string: blog.url) {
                                        UIApplication.shared.open(url)
                                    }
                                }) {
                                    HStack {
                                        Image(systemName: "safari")
                                        Text("View Published Site")
                                    }
                                    .padding()
                                    .frame(maxWidth: .infinity)
                                    .background(Color("PGreen"))
                                    .foregroundColor(.primary)
                                    .cornerRadius(10)
                                }
                                .padding(.horizontal)
                                .disabled(blog.url.isEmpty)
                            }
                        }
                        // FTP Publishing Button
                        else if blog.hasFtpConfigured
                                    && blog.currentPublisherType == .ftp
                        {
                            VStack(spacing: 12) {
                                Button(action: {
                                    forceFullUpload = false
                                    generateSite()
                                }) {
                                    HStack {
                                        Image(systemName: "arrow.up.to.line")
                                            .font(.system(size: 16, weight: .bold))
                                        Text("Smart Publish via SFTP")
                                            .fontWeight(.semibold)
                                    }
                                    .padding()
                                    .frame(maxWidth: .infinity)
                                    .background(Color("PBlue"))
                                    .foregroundColor(.primary)
                                    .cornerRadius(10)
                                }
                                .padding(.horizontal)
                                
                                Button(action: {
                                    forceFullUpload = true
                                    generateSite()
                                }) {
                                    HStack {
                                        Image(systemName: "arrow.up.to.line.square")
                                            .font(.system(size: 16, weight: .bold))
                                        Text("Full Publish via SFTP")
                                            .fontWeight(.semibold)
                                    }
                                    .padding()
                                    .frame(maxWidth: .infinity)
                                    .background(Color("PYellow"))
                                    .foregroundColor(.primary)
                                    .cornerRadius(10)
                                }
                                .padding(.horizontal)
                            }
                            
                            // View Published Site Button (shown if success message exists)
                            if publishSuccessMessage != nil {
                                Button(action: {
                                    if let url = URL(string: blog.url) {
                                        UIApplication.shared.open(url)
                                    }
                                }) {
                                    HStack {
                                        Image(systemName: "safari")
                                        Text("View Published Site")
                                    }
                                    .padding()
                                    .frame(maxWidth: .infinity)
                                    .background(Color("PGreen"))
                                    .foregroundColor(.primary)
                                    .cornerRadius(10)
                                }
                                .padding(.horizontal)
                                .disabled(blog.url.isEmpty)
                            }
                        }
                        // Local ZIP Generation Option
                        else if generatedZipURL != nil,
                                blog.currentPublisherType == .none
                        {
                            Button(action: {
                                showingShareSheet = true
                            }) {
                                Label(
                                    "Share ZIP File",
                                    systemImage: "square.and.arrow.up"
                                )
                                .padding()
                                .frame(maxWidth: .infinity)
                                .background(Color("PBlue"))
                                .foregroundColor(.primary)
                                .cornerRadius(10)
                            }
                            .padding(.horizontal)
                        } else if blog.currentPublisherType == .none {
                            Button(action: {
                                generateSite()
                            }) {
                                Label("Generate Site ZIP", systemImage: "globe")
                                    .padding()
                                    .frame(maxWidth: .infinity)
                                    .background(Color("PBlue"))
                                    .foregroundColor(.primary)
                                    .cornerRadius(10)
                            }
                            .padding(.horizontal)
                        } else {
                            if blog.currentPublisherType == .aws || blog.currentPublisherType == .ftp {
                                Label {
                                    Text(
                                        "Please check that you've fully configured \(blog.currentPublisherType.rawValue) for publication. Once configured, a publish button will appear here."
                                    ).font(.callout)
                                } icon: {
                                    Image(systemName: "x.circle.fill").foregroundStyle(
                                        .pYellow
                                    )
                                }.foregroundStyle(.secondary)
                                    .padding(.horizontal)
                            } else {
                                Label {
                                    Text(
                                        "\(blog.currentPublisherType.rawValue) support is coming soon, please pick a different publishing method in Publishing Settings in the meantime."
                                    ).font(.callout)
                                } icon: {
                                    Image(systemName: "x.circle.fill").foregroundStyle(
                                        .pYellow
                                    )
                                }.foregroundStyle(.secondary)
                                    .padding(.horizontal)
                            }
                        }
                        
                        
                        if blog.url.isEmpty {
                            Text(
                                "⚠️ Warning! Please set a canonical URL for your blog in Publishing Settings or portions of your generated site will not work properly."
                            )
                            .italic()
                            .multilineTextAlignment(.center)
                            .padding()
                        }
                    }
                }
            }
            .padding()
            .sheet(isPresented: $showingShareSheet) {
                if let zipURL = generatedZipURL {
                    ShareSheet(items: [zipURL])
                }
            }
            .sheet(isPresented: $showingPublishSettingsView) {
                PublishSettingsView(blog: blog)
            }
            .alert("Site Generated", isPresented: $showingSuccessAlert) {
                Button("OK", role: .cancel) {
                    if autoPublish {
                        dismiss()
                    }
                }
            } message: {
                if blog.hasAwsConfigured && blog.currentPublisherType == .aws {
                    Text(
                        "Your site has been successfully published to AWS using your access keys. The CloudFront invalidation has been created."
                    )
                } else if blog.hasFtpConfigured && blog.currentPublisherType == .ftp
                {
                    Text(
                        "Your site has been successfully published to your web host using SFTP."
                    )
                } else {
                    Text(
                        "Your site has been successfully generated. You can now share the ZIP file."
                    )
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
        }
        .onAppear {
            setupNotificationObservers()
            if autoPublish {
                // Use smart publishing for auto-publish by default
                forceFullUpload = false
                generateSite()
            }
        }
        .onDisappear {
            removeNotificationObservers()
        }
        
    }

    private func setupNotificationObservers() {
        NotificationCenter.default.addObserver(forName: .publishStatusUpdated, object: nil, queue: .main) { [self] notification in
            if let status = notification.object as? String {
                self.statusMessage = status
            }
        }
    }
    
    private func removeNotificationObservers() {
        NotificationCenter.default.removeObserver(self, name: .publishStatusUpdated, object: nil)
    }
    
    private func generateSite() {
        isGenerating = true
        errorMessage = nil
        publishSuccessMessage = nil
        statusMessage = "Preparing to generate site..."

        Task {
            do {
                // Pass modelContext and forceFullUpload flags to StaticSiteGenerator
                let generator = StaticSiteGenerator(
                    blog: blog, 
                    modelContext: modelContext,
                    forceFullUpload: forceFullUpload
                )
                
                let publishMode = forceFullUpload ? "full" : "smart"
                statusMessage = "Generating site content for \(publishMode) publishing..."
                let result = try await generator.generateSite()

                DispatchQueue.main.async {
                    if blog.currentPublisherType == .aws
                        && blog.hasAwsConfigured
                    {
                        // AWS publishing was used
                        self.publishSuccessMessage =
                            "Site successfully published to AWS!"
                    } else if blog.currentPublisherType == .ftp
                        && blog.hasFtpConfigured
                    {
                        // FTP publishing was used
                        self.publishSuccessMessage =
                            "Site successfully published via SFTP!"
                    } else if blog.currentPublisherType == .none {
                        // ZIP file was generated
                        self.generatedZipURL = result
                    } else {
                        // Other publisher was used
                        self.publishSuccessMessage =
                            "Site successfully published!"
                    }

                    self.isGenerating = false
                    self.showingSuccessAlert = true
                }
            } catch {
                DispatchQueue.main.async {
                    self.errorMessage = "Error: \(error.localizedDescription)"
                    self.statusMessage = "Error occurred during publishing"
                    self.isGenerating = false
                }
            }
        }
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    var items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(
            activityItems: items,
            applicationActivities: nil
        )
        return controller
    }

    func updateUIViewController(
        _ uiViewController: UIActivityViewController,
        context: Context
    ) {}
}

#Preview("Regular Blog") {
    NavigationStack {
        PublishBlogView(blog: PreviewData.blog)
    }
    .modelContainer(PreviewData.previewContainer)
}

#Preview("AWS Configured") {
    NavigationStack {
        PublishBlogView(blog: PreviewData.blogWithContent())
    }
    .modelContainer(PreviewData.previewContainer)
}
