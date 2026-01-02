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

    // Pre-publish sync state
    @State private var isPrePublishSyncing = false
    @State private var prePublishSyncError: String?
    @State private var showingPrePublishSyncError = false

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 30) {
                    // Header Section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Publish \(blog.name)")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                        
                        publishingDescriptionText
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    
                    // Settings Section
                    VStack(alignment: .leading, spacing: 16) {
                        Button(action: {
                            showingPublishSettingsView = true
                        }) {
                            Label("Publishing Settings", systemImage: "gear")
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.large)
                        
                        // Warning Section
                        if blog.url.isEmpty {
                            HStack(spacing: 12) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundStyle(.orange)
                                    .font(.title3)
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Missing Canonical URL")
                                        .font(.headline)
                                        .foregroundStyle(.primary)
                                    
                                    Text("Please set a canonical URL in Publishing Settings for your site to work properly.")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                            }
                            .padding(16)
                            .background(.orange.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                    }
                    
                    // Status Messages Section
                    if let errorMessage = errorMessage {
                        statusCard(
                            icon: "xmark.circle.fill",
                            title: "Error",
                            message: errorMessage,
                            color: .red
                        )
                    }
                    
                    if let successMessage = publishSuccessMessage {
                        statusCard(
                            icon: "checkmark.circle.fill",
                            title: "Success",
                            message: successMessage,
                            color: Color("PGreen")
                        )
                    }
                    
                    // Publishing Progress Section
                    if isGenerating {
                        VStack(spacing: 16) {
                            ProgressView()
                                .scaleEffect(1.2)
                            
                            VStack(spacing: 8) {
                                Text("Publishing...")
                                    .font(.headline)
                                    .foregroundStyle(.primary)
                                
                                Text(statusMessage)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                    .multilineTextAlignment(.center)
                            }
                        }
                        .padding(24)
                        .frame(maxWidth: .infinity)
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                    } else {
                        // Publishing Actions Section
                        publishingActionsSection
                    }
                }
                .padding()
            }
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
                    if autoPublish && generatedZipURL == nil {
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
                } else if blog.hasGitConfigured && blog.currentPublisherType == .git
                {
                    Text(
                        "Your site has been successfully published to your Git repository on the \(blog.gitBranch ?? "main") branch."
                    )
                } else {
                    Text(
                        "Your site has been successfully generated. You can now share the ZIP file."
                    )
                }
            }
            .alert("Sync Failed", isPresented: $showingPrePublishSyncError) {
                Button("Retry") {
                    performPrePublishSyncAndGenerate()
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text(prePublishSyncError ?? "An unknown error occurred while syncing. Please try again.")
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
                performPrePublishSyncAndGenerate()
            }
        }
        .onDisappear {
            removeNotificationObservers()
        }
        
    }
    
    // MARK: - Helper Views
    
    private var publishingDescriptionText: Text {
        if blog.hasAwsConfigured && blog.currentPublisherType == .aws {
            return Text("Publishing will generate a static website from all your blog posts and securely upload it to your AWS S3 bucket using your AWS access keys. A CloudFront invalidation will be created to ensure your content is served fresh.")
        } else if blog.hasFtpConfigured && blog.currentPublisherType == .ftp {
            return Text("Publishing will generate a static website from all your blog posts and securely upload it to your web host using SFTP.")
        } else if blog.hasGitConfigured && blog.currentPublisherType == .git {
            return Text("Publishing will generate a static website from all your blog posts and securely commit and push it to your Git repository.")
        } else if blog.currentPublisherType == .none {
            return Text("Publishing will generate a static website from all your blog posts. The site will be packaged as a ZIP file you can download and upload to any web host.")
        } else {
            return Text("Publishing will generate a static website from all your blog posts for uploading to the host of your choice.")
        }
    }
    
    private func statusCard(icon: String, title: String, message: String, color: Color) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(color)
                .font(.title3)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.primary)
                
                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(16)
        .background(color.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    @ViewBuilder
    private var publishingActionsSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            if blog.hasAwsConfigured && blog.currentPublisherType == .aws {
                awsPublishingSection
            } else if blog.hasFtpConfigured && blog.currentPublisherType == .ftp {
                ftpPublishingSection
            } else if blog.hasGitConfigured && blog.currentPublisherType == .git {
                gitPublishingSection
            } else if blog.currentPublisherType == .none {
                localPublishingSection
            } else {
                unconfiguredPublishingSection
            }
        }
    }
    
    @ViewBuilder
    private var awsPublishingSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("AWS Publishing")
                .font(.title2)
                .fontWeight(.bold)
            
            VStack(spacing: 12) {
                Button(action: {
                    forceFullUpload = false
                    performPrePublishSyncAndGenerate()
                }) {
                    Label("Smart Publish to AWS", systemImage: "arrow.up.to.line")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .tint(Color("PBlue"))

                Button(action: {
                    forceFullUpload = true
                    performPrePublishSyncAndGenerate()
                }) {
                    Label("Full Publish to AWS", systemImage: "arrow.up.to.line.square")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                .tint(Color("PYellow"))
            }
            
            if publishSuccessMessage != nil {
                Button(action: {
                    if let url = URL(string: blog.url) {
                        UIApplication.shared.open(url)
                    }
                }) {
                    Label("View Published Site", systemImage: "safari")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                .tint(Color("PGreen"))
                .disabled(blog.url.isEmpty)
            }
        }
    }
    
    @ViewBuilder
    private var ftpPublishingSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("SFTP Publishing")
                .font(.title2)
                .fontWeight(.bold)
            
            VStack(spacing: 12) {
                Button(action: {
                    forceFullUpload = false
                    performPrePublishSyncAndGenerate()
                }) {
                    Label("Smart Publish via SFTP", systemImage: "arrow.up.to.line")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .tint(Color("PBlue"))

                Button(action: {
                    forceFullUpload = true
                    performPrePublishSyncAndGenerate()
                }) {
                    Label("Full Publish via SFTP", systemImage: "arrow.up.to.line.square")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                .tint(Color("PYellow"))
            }
            
            if publishSuccessMessage != nil {
                Button(action: {
                    if let url = URL(string: blog.url) {
                        UIApplication.shared.open(url)
                    }
                }) {
                    Label("View Published Site", systemImage: "safari")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                .tint(Color("PGreen"))
                .disabled(blog.url.isEmpty)
            }
        }
    }
    
    @ViewBuilder
    private var gitPublishingSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Git Publishing")
                .font(.title2)
                .fontWeight(.bold)
            
            VStack(spacing: 12) {
                Button(action: {
                    forceFullUpload = false
                    performPrePublishSyncAndGenerate()
                }) {
                    Label("Smart Publish to Git Repository", systemImage: "arrow.up.to.line")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .tint(Color("PBlue"))

                Button(action: {
                    forceFullUpload = true
                    performPrePublishSyncAndGenerate()
                }) {
                    Label("Full Publish to Git Repository", systemImage: "arrow.up.to.line.square")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                .tint(Color("PYellow"))
            }
            
            if publishSuccessMessage != nil {
                Button(action: {
                    if let url = URL(string: blog.url) {
                        UIApplication.shared.open(url)
                    }
                }) {
                    Label("View Published Site", systemImage: "safari")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                .tint(Color("PGreen"))
                .disabled(blog.url.isEmpty)
            }
        }
    }
    
    @ViewBuilder
    private var localPublishingSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Local ZIP Generation")
                .font(.title2)
                .fontWeight(.bold)
            
            if generatedZipURL != nil {
                Button(action: {
                    showingShareSheet = true
                }) {
                    Label("Share ZIP File", systemImage: "square.and.arrow.up")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .tint(Color("PBlue"))
            } else {
                Button(action: {
                    performPrePublishSyncAndGenerate()
                }) {
                    Label("Generate Site ZIP", systemImage: "globe")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .tint(Color("PBlue"))
            }
        }
    }
    
    @ViewBuilder
    private var unconfiguredPublishingSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            if blog.currentPublisherType == .aws || blog.currentPublisherType == .ftp {
                HStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                        .font(.title3)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Configuration Required")
                            .font(.headline)
                            .foregroundStyle(.primary)
                        
                        Text("Please check that you've fully configured \(blog.currentPublisherType.rawValue) for publication in Publishing Settings.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                .padding(16)
                .background(.orange.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            } else {
                HStack(spacing: 12) {
                    Image(systemName: "info.circle.fill")
                        .foregroundStyle(.blue)
                        .font(.title3)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Coming Soon")
                            .font(.headline)
                            .foregroundStyle(.primary)
                        
                        Text("\(blog.currentPublisherType.rawValue) support is coming soon. Please pick a different publishing method in Publishing Settings.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                .padding(16)
                .background(.blue.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
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
                    } else if blog.currentPublisherType == .git
                        && blog.hasGitConfigured
                    {
                        // Git publishing was used
                        self.publishSuccessMessage =
                            "Site successfully published to Git repository!"
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

    /// Performs pre-publish sync check if sync is enabled, then generates and publishes the site.
    /// This ensures the local blog is up-to-date with remote changes before publishing.
    private func performPrePublishSyncAndGenerate() {
        // If sync is not enabled or no URL is set, skip sync and go straight to generate
        guard blog.syncEnabled, !blog.url.isEmpty else {
            generateSite()
            return
        }

        isGenerating = true
        isPrePublishSyncing = true
        errorMessage = nil
        publishSuccessMessage = nil
        prePublishSyncError = nil
        statusMessage = "Checking for remote changes..."

        Task {
            do {
                // Check for remote changes
                let checkResult = try await SyncChecker.checkForChanges(blog: blog)

                if checkResult.hasChanges {
                    await MainActor.run {
                        statusMessage = "Syncing remote changes: \(checkResult.changeSummary)..."
                    }

                    // Pull changes before publishing
                    _ = try await IncrementalSync.pullChanges(
                        blog: blog,
                        modelContext: modelContext
                    ) { progress in
                        Task { @MainActor in
                            statusMessage = "Syncing: \(progress.description)"
                        }
                    }
                }

                await MainActor.run {
                    isPrePublishSyncing = false
                    // Continue with site generation
                    generateSite()
                }
            } catch {
                await MainActor.run {
                    isPrePublishSyncing = false
                    isGenerating = false
                    prePublishSyncError = error.localizedDescription
                    showingPrePublishSyncError = true
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
