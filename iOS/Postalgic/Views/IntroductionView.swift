//
//  IntroductionView.swift
//  Postalgic
//
//  Created by Brad Root on 5/24/25.
//

import SwiftUI

struct IntroductionView: View {
    @Binding var isPresented: Bool
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 32) {
                    // Header
                    VStack(spacing: 16) {
                        Image("SoloAppIcon")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 80, height: 80)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                        
                        Text("Welcome to Postalgic")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                        
                        Text("Create beautiful blogs with ease")
                            .font(.title2)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 20)
                    
                    // What is Postalgic section
                    VStack(alignment: .leading, spacing: 16) {
                        Text("What is Postalgic?")
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        VStack(alignment: .leading, spacing: 12) {
                            FeatureRow(
                                icon: "📝",
                                title: "Write & Edit",
                                description: "Create posts with Markdown support and rich embeded content"
                            )
                            
                            FeatureRow(
                                icon: "🎨",
                                title: "Customize",
                                description: "Customize and build custom themes to match your style"
                            )
                            
                            FeatureRow(
                                icon: "🚀",
                                title: "Publish",
                                description: "Generate and deploy your blog to various hosting services automatically"
                            )
                        }
                    }
                    
                    // Recommended hosting section
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Supported Hosting")
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        VStack(spacing: 12) {
                            HostingOptionCard(
                                icon: "🐙",
                                title: "GitHub Pages",
                                description: "Free hosting with your GitHub account. Perfect for getting started.",
                                badge: "Recommended"
                            )
                            
                            HostingOptionCard(
                                icon: "🌐",
                                title: "Git Repository",
                                description: "Deploy to any Git provider (GitHub, GitLab, etc.) for automated workflows."
                            )
                            
                            HostingOptionCard(
                                icon: "☁️",
                                title: "AWS S3",
                                description: "Scalable cloud hosting with CloudFront CDN integration."
                            )
                            
                            HostingOptionCard(
                                icon: "📁",
                                title: "SFTP",
                                description: "Upload to any web server that supports SFTP file transfer."
                            )
                        }
                    }
                    
                    // Get started button
                    VStack(spacing: 16) {
                        Text("Ready to start blogging?")
                            .font(.headline)
                        
                        Button(action: {
                            UserDefaults.standard.set(true, forKey: "hasSeenIntroduction")
                            isPresented = false
                        }) {
                            Text("Get Started")
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.accentColor)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .padding(.horizontal)
                    }
                    .padding(.bottom, 20)
                }
                .padding()
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Skip") {
                        UserDefaults.standard.set(true, forKey: "hasSeenIntroduction")
                        isPresented = false
                    }
                    .foregroundColor(.secondary)
                }
            }
        }
    }
}

struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(spacing: 16) {
            Text(icon)
                .font(.title)
                .frame(width: 30)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                Text(description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
        }
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct HostingOptionCard: View {
    let icon: String
    let title: String
    let description: String
    let badge: String?
    
    init(icon: String, title: String, description: String, badge: String? = nil) {
        self.icon = icon
        self.title = title
        self.description = description
        self.badge = badge
    }
    
    var body: some View {
        HStack(spacing: 16) {
            Text(icon)
                .font(.title)
                .frame(width: 30)
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(title)
                        .font(.headline)
                    
                    if let badge = badge {
                        Text(badge)
                            .font(.caption)
                            .fontWeight(.medium)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(Color.accentColor.opacity(0.2))
                            .foregroundColor(.accentColor)
                            .clipShape(Capsule())
                    }
                    
                    Spacer()
                }
                
                Text(description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

#Preview {
    IntroductionView(isPresented: .constant(true))
}
