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
    @State private var showingTemplateCustomizationView = false

    var body: some View {
        NavigationStack {
            List {
                // Header section with site URL
                Section(header: Text("Publishing Details")) {
                    TextField("https://yourblog.com", text: $blog.url)
                        .keyboardType(.URL)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                        .textContentType(.URL)

                    Picker(
                        "Publishing Method",
                        selection: Binding(
                            get: {
                                return blog.currentPublisherType
                            },
                            set: {
                                blog.publisherType = $0.rawValue
                            }
                        )
                    ) {
                        ForEach(PublisherType.allCases, id: \.self) { type in
                            Text(type.displayName).tag(type)
                        }
                    }
                    .pickerStyle(NavigationLinkPickerStyle())
                }

                // Template customization section
                Section(header: Text("Site Templates")) {
                    Button("Customize Templates") {
                        showingTemplateCustomizationView.toggle()
                    }
                    .frame(maxWidth: .infinity)
                    
                    Text("Customize the look and feel of your static site by editing the HTML templates.")
                        .font(.callout)
                        .foregroundColor(.secondary)
                }
                
                switch blog.currentPublisherType {
                case .aws:
                    awsSettingsView
                case .ftp:
                    ftpSettingsView
                case .netlify:
                    netlifySettingsView
                case .none:
                    manualDownloadView
                case .github:
                    githubSettingsView
                case .gitlab:
                    gitlabSettingsView
                case .digitalOcean:
                    digitalOceanSettingsView
                }
            }
            .listStyle(InsetGroupedListStyle())
            .navigationTitle("Publish Settings")
            .navigationBarItems(
                trailing: Button("Done") {
                    dismiss()
                }
            )
            .sheet(isPresented: $showingAwsConfigView) {
                BlogAwsConfigView(blog: blog).interactiveDismissDisabled()
            }
            .sheet(isPresented: $showingFtpConfigView) {
                BlogFtpConfigView(blog: blog).interactiveDismissDisabled()
            }
            .sheet(isPresented: $showingTemplateCustomizationView) {
                TemplateCustomizationView(blog: blog).interactiveDismissDisabled()
            }
        }
    }

    // AWS Settings View
    private var awsSettingsView: some View {
        Section(
            header: Text("AWS Configuration"),
            footer: Text(
                "AWS publishing lets you directly upload your static site to an S3 bucket and automatically create CloudFront invalidations to ensure your content is served fresh."
            )
        ) {
            if blog.hasAwsConfigured {
                Label {
                    Text("AWS is fully configured")
                } icon: {
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(
                        .pGreen
                    )
                }
            } else {
                Label {
                    Text("AWS is not fully configured")
                } icon: {
                    Image(systemName: "x.circle.fill").foregroundStyle(
                        .pYellow
                    )
                }
            }

            Button("Configure AWS") {
                showingAwsConfigView.toggle()
            }.buttonStyle(.automatic)
        }
    }

    // FTP Settings View
    private var ftpSettingsView: some View {
        Section(
            header: Text("SFTP Configuration"),
            footer: Text(
                "SFTP publishing lets you directly upload your static site to any web hosting service that supports secure file transfer protocol."
            )
        ) {
            if blog.hasFtpConfigured {
                Label {
                    Text("SFTP is fully configured")
                } icon: {
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(
                        .pGreen
                    )
                }
            } else {
                Label {
                    Text("SFTP is not fully configured")
                } icon: {
                    Image(systemName: "x.circle.fill").foregroundStyle(
                        .pYellow
                    )
                }
            }

            Button("Configure SFTP") {
                showingFtpConfigView.toggle()
            }.buttonStyle(.automatic).frame(maxWidth: .infinity)

        }

    }

    // Netlify Settings View (placeholder for future implementation)
    private var netlifySettingsView: some View {
        Section(header: Text("Netlify Configuration")) {
            Label {
                Text("Coming Soon")
            } icon: {
                Image(systemName: "hammer.fill").foregroundStyle(.pYellow)
            }

            Text(
                "Netlify publishing is not yet available. Please choose another publishing method for now."
            )
            .font(.callout)
            .foregroundColor(.secondary)
        }
    }
    
    private var githubSettingsView: some View {
        Section(header: Text("GitHub Configuration")) {
            Label {
                Text("Coming Soon")
            } icon: {
                Image(systemName: "hammer.fill").foregroundStyle(.pYellow)
            }

            Text(
                "GitHub publishing is not yet available. Please choose another publishing method for now."
            )
            .font(.callout)
            .foregroundColor(.secondary)
        }
    }
    
    private var gitlabSettingsView: some View {
        Section(header: Text("GitLab Configuration")) {
            Label {
                Text("Coming Soon")
            } icon: {
                Image(systemName: "hammer.fill").foregroundStyle(.pYellow)
            }

            Text(
                "GitLab publishing is not yet available. Please choose another publishing method for now."
            )
            .font(.callout)
            .foregroundColor(.secondary)
        }
    }
    
    private var digitalOceanSettingsView: some View {
        Section(header: Text("DigitalOcean Configuration")) {
            Label {
                Text("Coming Soon")
            } icon: {
                Image(systemName: "hammer.fill").foregroundStyle(.pYellow)
            }

            Text(
                "DigitalOcean publishing is not yet available. Please choose another publishing method for now."
            )
            .font(.callout)
            .foregroundColor(.secondary)
        }
    }

    // Manual Download View
    private var manualDownloadView: some View {
        Section(header: Text("Manual Download Information")) {
            Label {
                Text("Manual download mode")
            } icon: {
                Image(systemName: "checkmark.circle.fill").foregroundStyle(
                    .pGreen
                )
            }

            Text(
                "Your site will be generated as a ZIP file that you can download and manually upload to any web host of your choice.\n\nMake sure the Blog URL above matches where you'll be hosting your site, so all internal links and the sitemap work correctly."
            )
            .font(.callout)
            .foregroundColor(.secondary)
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
