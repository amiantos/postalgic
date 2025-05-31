//
//  BlogsView.swift
//  Postalgic
//
//  Created by Brad Root on 4/19/25.
//

import SwiftData
import SwiftUI

struct BlogsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var blogs: [Blog]
    @State private var showingBlogForm = false
    @State private var showingHelpSheet = false
    @State private var showingIntroduction = false
    @State private var navigationPath = NavigationPath()

    var body: some View {
        NavigationStack(path: $navigationPath) {
            Group {
                if blogs.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "globe")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary)
                        
                        Text("No blogs yet")
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        Text("Create your first blog to get started")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                        
                        Button(action: { showingBlogForm = true }) {
                            Text("Create Blog")
                        }
                        .buttonStyle(.borderedProminent)
                        .padding(.top, 8)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        ForEach(blogs.sorted(by: { $0.createdAt > $1.createdAt })) {
                            blog in
                            NavigationLink(value: blog) {
                                HStack {
                                    // Display favicon if available
                                    if let favicon = blog.favicon, let image = UIImage(data: favicon.data) {
                                        Image(uiImage: image)
                                            .resizable()
                                            .aspectRatio(contentMode: .fit)
                                            .frame(width: 36, height: 36)
                                            .clipShape(RoundedRectangle(cornerRadius: 4))
                                    } else {
                                        // Placeholder icon when no favicon
                                        Image(systemName: "globe")
                                            .foregroundColor(.secondary)
                                            .frame(width: 36, height: 36)
                                    }
                                    
                                    VStack(alignment: .leading) {
                                        Text(blog.name)
                                            .font(.headline)
                                        if !blog.url.isEmpty {
                                            Text(blog.url)
                                                .font(.subheadline)
                                                .foregroundStyle(.secondary)
                                        }
                                    }.padding(.leading, 6)
                                }
                            }
                        }
                    }
                }
            }
            .sheet(isPresented: $showingHelpSheet) {
                HelpView()
            }
            .fullScreenCover(isPresented: $showingIntroduction) {
                IntroductionView(isPresented: $showingIntroduction)
            }
            .toolbar {
                ToolbarItem {
                    Button(action: { showingBlogForm = true }) {
                        Label("Add Blog", systemImage: "plus")
                    }
                }
                ToolbarItemGroup(placement: .topBarLeading) {
                    Button {
                        showingHelpSheet.toggle()
                    } label: {
                        Label("Help", systemImage: "questionmark.circle")
                    }
                    
                    #if DEBUG
                    Button {
                        showingIntroduction = true
                    } label: {
                        Label("Introduction", systemImage: "info.circle")
                    }
                    #endif
                }
            }
            .navigationTitle("Your Blogs")
            .navigationDestination(for: Blog.self) { blog in
                BlogDashboardView(blog: blog)
            }
            .sheet(isPresented: $showingBlogForm) {
                BlogFormView { newBlog in
                    navigationPath.append(newBlog)
                }.interactiveDismissDisabled()
            }
            .onAppear {
                if !UserDefaults.standard.bool(forKey: "hasSeenIntroduction") {
                    showingIntroduction = true
                }
            }
        }
    }
}

#Preview {
    BlogsView()
        .modelContainer(PreviewData.previewContainer)
}
