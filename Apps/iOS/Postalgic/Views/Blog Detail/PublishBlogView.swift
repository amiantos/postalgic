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

    @State private var isGenerating = false
    @State private var generatedZipURL: URL?
    @State private var errorMessage: String?
    @State private var publishSuccessMessage: String?

    @State private var showingShareSheet = false
    @State private var showingSuccessAlert = false
    @State private var showingPublishSettingsView = false

    var body: some View {
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
            } else {
                Text(
                    "Publishing will generate a static website from all your blog posts. The site will be packaged as a ZIP file you can download and upload to any web host."
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
                Text("Generating site...")
            } else {
                // Main publishing controls
                VStack(spacing: 12) {
                    // AWS Publishing Button
                    if blog.hasAwsConfigured && blog.currentPublisherType == .aws {
                        Button(action: {
                            generateSite()
                        }) {
                            HStack {
                                Image(systemName: "arrow.up.to.line")
                                    .font(.system(size: 16, weight: .bold))
                                Text("Publish to AWS")
                                    .fontWeight(.semibold)
                            }
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color("PBlue"))
                            .foregroundColor(.primary)
                            .cornerRadius(10)
                        }
                        .padding(.horizontal)

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
                    if generatedZipURL != nil, blog.currentPublisherType == .none {
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
                    } else if blog.currentPublisherType != .aws || !blog.hasAwsConfigured {
                        // Generic publish button for other publisher types or misconfigured AWS
                        Button(action: {
                            generateSite()
                        }) {
                            Label("Generate & Publish Site", systemImage: "arrow.up.doc")
                                .padding()
                                .frame(maxWidth: .infinity)
                                .background(Color("PBlue"))
                                .foregroundColor(.primary)
                                .cornerRadius(10)
                        }
                        .padding(.horizontal)
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
            Button("OK", role: .cancel) {}
        } message: {
            if blog.hasAwsConfigured && blog.currentPublisherType == .aws {
                Text(
                    "Your site has been successfully published to AWS using your access keys. The CloudFront invalidation has been created."
                )
            } else {
                Text(
                    "Your site has been successfully generated. You can now share the ZIP file."
                )
            }
        }
    }

    private func generateSite() {
        isGenerating = true
        errorMessage = nil
        publishSuccessMessage = nil

        Task {
            do {
                let generator = StaticSiteGenerator(blog: blog)
                let result = try await generator.generateSite()

                DispatchQueue.main.async {
                    if blog.currentPublisherType == .aws && blog.hasAwsConfigured {
                        // AWS publishing was used
                        self.publishSuccessMessage =
                            "Site successfully published to AWS!"
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