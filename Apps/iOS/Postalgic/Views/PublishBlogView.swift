//
//  PublishBlogView.swift
//  Postalgic
//
//  Created by Brad Root on 4/19/25.
//

import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct PublishBlogView: View {
    var blog: Blog
    
    @State private var isGenerating = false
    @State private var generatedZipURL: URL?
    @State private var errorMessage: String?
    
    @State private var showingShareSheet = false
    @State private var showingSuccessAlert = false
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Publish \(blog.name)")
                .font(.title)
                .fontWeight(.bold)
            
            Text("Publishing will generate a static website from all your blog posts. The site will be packaged as a ZIP file you can download and upload to any web host.")
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            if let errorMessage = errorMessage {
                Text(errorMessage)
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
                    .padding()
            }
            
            if isGenerating {
                ProgressView()
                    .padding()
                Text("Generating site...")
            } else if let _ = generatedZipURL {
                Button(action: {
                    showingShareSheet = true
                }) {
                    Label("Share ZIP File", systemImage: "square.and.arrow.up")
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                .padding(.horizontal)
            } else {
                Button(action: {
                    generateSite()
                }) {
                    Label("Generate Site", systemImage: "globe")
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                .padding(.horizontal)
            }
        }
        .padding()
        .sheet(isPresented: $showingShareSheet) {
            if let zipURL = generatedZipURL {
                ShareSheet(items: [zipURL])
            }
        }
        .alert("Site Generated", isPresented: $showingSuccessAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Your site has been successfully generated. You can now share the ZIP file.")
        }
    }
    
    private func generateSite() {
        isGenerating = true
        errorMessage = nil
        
        Task {
            do {
                let generator = StaticSiteGenerator(blog: blog)
                let zipURL = try await generator.generateSite()
                
                DispatchQueue.main.async {
                    self.generatedZipURL = zipURL
                    self.isGenerating = false
                    self.showingSuccessAlert = true
                }
            } catch {
                DispatchQueue.main.async {
                    self.errorMessage = "Error generating site: \(error.localizedDescription)"
                    self.isGenerating = false
                }
            }
        }
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    var items: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: items, applicationActivities: nil)
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

#Preview {
    PublishBlogView(blog: Blog(name: "Test Blog", url: "https://example.com"))
        .modelContainer(for: [Blog.self, Post.self], inMemory: true)
}