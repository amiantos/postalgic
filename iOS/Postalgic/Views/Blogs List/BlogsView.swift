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
    @Query private var remoteServers: [RemoteServer]
    @State private var showingBlogForm = false
    @State private var showingImportFromURL = false
    @State private var showingHelpSheet = false
    @State private var showingIntroduction = false
    @State private var showingRemoteServers = false

    // Remote blogs loaded from servers
    @State private var remoteBlogEntries: [RemoteBlogEntry] = []
    @State private var isLoadingRemote = false

    var body: some View {
        NavigationStack {
            Group {
                if blogs.isEmpty && remoteBlogEntries.isEmpty && !isLoadingRemote {
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

                        HStack(spacing: 12) {
                            Button(action: { showingBlogForm = true }) {
                                Text("Create Blog")
                            }
                            .buttonStyle(.borderedProminent)

                            Button(action: { showingImportFromURL = true }) {
                                Text("Import from URL")
                            }
                            .buttonStyle(.bordered)
                        }
                        .padding(.top, 8)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        // Local blogs section
                        if !blogs.isEmpty {
                            Section {
                                ForEach(blogs.sorted(by: { $0.createdAt > $1.createdAt })) {
                                    blog in
                                    NavigationLink {
                                        BlogDashboardView(blog: blog)
                                    } label: {
                                        localBlogRow(blog: blog)
                                    }
                                }
                            }
                        }

                        // Remote blogs - grouped by server
                        ForEach(serversWithBlogs, id: \.server.id) { entry in
                            Section(header: remoteServerHeader(entry.server)) {
                                ForEach(entry.blogs) { remoteBlog in
                                    NavigationLink {
                                        RemoteBlogDashboardView(server: entry.server, blog: remoteBlog)
                                    } label: {
                                        remoteBlogRow(blog: remoteBlog, server: entry.server)
                                    }
                                }
                            }
                        }

                        // Show loading indicator for remote blogs
                        if isLoadingRemote {
                            Section {
                                HStack {
                                    ProgressView()
                                        .padding(.trailing, 8)
                                    Text("Loading remote blogs...")
                                        .foregroundStyle(.secondary)
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
                    Menu {
                        Button(action: { showingBlogForm = true }) {
                            Label("Create New Blog", systemImage: "plus")
                        }
                        Button(action: { showingImportFromURL = true }) {
                            Label("Import from URL", systemImage: "arrow.down.circle")
                        }
                        Divider()
                        Button(action: { showingRemoteServers = true }) {
                            Label("Remote Servers", systemImage: "server.rack")
                        }
                    } label: {
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
            .sheet(isPresented: $showingBlogForm) {
                BlogFormView().interactiveDismissDisabled()
            }
            .sheet(isPresented: $showingImportFromURL) {
                ImportFromURLView()
            }
            .sheet(isPresented: $showingRemoteServers) {
                RemoteServersSettingsView()
            }
            .onAppear {
                if !UserDefaults.standard.bool(forKey: "hasSeenIntroduction") {
                    showingIntroduction = true
                }
                loadRemoteBlogs()
            }
            .onChange(of: remoteServers.count) { _, _ in
                loadRemoteBlogs()
            }
        }
    }

    // MARK: - Row Views

    private func localBlogRow(blog: Blog) -> some View {
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

    private func remoteBlogRow(blog: RemoteBlog, server: RemoteServer) -> some View {
        HStack {
            // Remote blog favicon placeholder
            ZStack {
                Image(systemName: "globe")
                    .foregroundColor(.secondary)
                    .frame(width: 36, height: 36)
                Image(systemName: "server.rack")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .offset(x: 12, y: 12)
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

    private func remoteServerHeader(_ server: RemoteServer) -> some View {
        HStack(spacing: 4) {
            Image(systemName: "server.rack")
                .font(.caption2)
            Text(server.name)
        }
    }

    // MARK: - Computed Properties

    private var serversWithBlogs: [(server: RemoteServer, blogs: [RemoteBlog])] {
        var result: [(server: RemoteServer, blogs: [RemoteBlog])] = []
        for entry in remoteBlogEntries {
            if let existing = result.firstIndex(where: { $0.server.id == entry.server.id }) {
                result[existing].blogs.append(entry.blog)
            } else {
                result.append((server: entry.server, blogs: [entry.blog]))
            }
        }
        return result
    }

    // MARK: - Remote Blog Loading

    private func loadRemoteBlogs() {
        guard !remoteServers.isEmpty else {
            remoteBlogEntries = []
            return
        }

        isLoadingRemote = true

        Task {
            var entries: [RemoteBlogEntry] = []

            for server in remoteServers {
                let client = PostalgicAPIClient(server: server)
                do {
                    let blogs = try await client.fetchBlogs()
                    for blog in blogs {
                        entries.append(RemoteBlogEntry(server: server, blog: blog))
                    }
                } catch {
                    // Silently skip servers that fail to connect
                    Log.error("Failed to fetch blogs from \(server.name): \(error)")
                }
            }

            await MainActor.run {
                remoteBlogEntries = entries
                isLoadingRemote = false
            }
        }
    }
}

// MARK: - Remote Blog Entry

struct RemoteBlogEntry: Identifiable {
    let server: RemoteServer
    let blog: RemoteBlog

    var id: String { "\(server.id)-\(blog.id)" }
}

#Preview {
    BlogsView()
        .modelContainer(PreviewData.previewContainer)
}
