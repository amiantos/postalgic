//
//  RemotePublishView.swift
//  Postalgic
//
//  Created by Claude on 2/18/26.
//

import SwiftUI

struct RemotePublishView: View {
    @Environment(\.dismiss) private var dismiss

    let server: RemoteServer
    let blog: RemoteBlog

    @State private var publisherType: String = ""
    @State private var lastPublishedDate: String?
    @State private var isLoadingStatus = true
    @State private var isPublishing = false
    @State private var isComplete = false
    @State private var errorMessage: String?

    // Progress tracking
    @State private var currentPhase: String = ""
    @State private var progressMessage: String = ""
    @State private var currentFile: Int = 0
    @State private var totalFiles: Int = 0
    @State private var currentFilename: String = ""
    @State private var completionMessage: String = ""

    // SSE
    @State private var sseTask: Task<Void, Never>?

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                if isLoadingStatus {
                    ProgressView("Loading publish status...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let error = errorMessage, !isPublishing && !isComplete {
                    VStack(spacing: 16) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 48))
                            .foregroundStyle(.orange)
                        Text(error)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                        Button("Retry") {
                            loadStatus()
                        }
                        .buttonStyle(.bordered)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if publisherType == "manual" || publisherType.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "info.circle")
                            .font(.system(size: 48))
                            .foregroundStyle(.secondary)
                        Text("No Publisher Configured")
                            .font(.headline)
                        Text("Configure a publishing method (AWS S3, SFTP, or Git) in the server's blog settings to publish from here.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if isComplete {
                    completionView
                } else if isPublishing {
                    progressView
                } else {
                    readyToPublishView
                }
            }
            .navigationTitle("Publish")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(isComplete ? "Done" : "Cancel") {
                        sseTask?.cancel()
                        dismiss()
                    }
                }
            }
            .onAppear {
                loadStatus()
            }
            .onDisappear {
                sseTask?.cancel()
            }
        }
    }

    // MARK: - Subviews

    private var readyToPublishView: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: publisherIcon)
                .font(.system(size: 56))
                .foregroundStyle(.accent)

            VStack(spacing: 8) {
                Text("Publish to \(publisherDisplayName)")
                    .font(.title2)
                    .fontWeight(.bold)

                if let lastDate = lastPublishedDate, !lastDate.isEmpty {
                    Text("Last published: \(lastDate)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Button {
                startPublish()
            } label: {
                Label("Publish Now", systemImage: "arrow.up.circle.fill")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
            }
            .buttonStyle(.borderedProminent)
            .padding(.horizontal, 40)

            Spacer()
        }
        .padding()
    }

    private var progressView: some View {
        VStack(spacing: 20) {
            Spacer()

            ProgressView()
                .scaleEffect(1.5)
                .padding(.bottom, 8)

            Text(progressMessage.isEmpty ? "Starting..." : progressMessage)
                .font(.headline)
                .multilineTextAlignment(.center)

            if totalFiles > 0 {
                VStack(spacing: 8) {
                    ProgressView(value: Double(currentFile), total: Double(totalFiles))
                        .padding(.horizontal, 40)

                    Text("\(currentFile) / \(totalFiles) files")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if !currentFilename.isEmpty {
                        Text(currentFilename)
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                }
            }

            if let error = errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }

            Spacer()
        }
        .padding()
    }

    private var completionView: some View {
        VStack(spacing: 20) {
            Spacer()

            if errorMessage != nil {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(.red)

                Text("Publish Failed")
                    .font(.title2)
                    .fontWeight(.bold)

                Text(errorMessage ?? "Unknown error")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                Button("Try Again") {
                    isComplete = false
                    errorMessage = nil
                    startPublish()
                }
                .buttonStyle(.bordered)
            } else {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(.green)

                Text("Published Successfully")
                    .font(.title2)
                    .fontWeight(.bold)

                if !completionMessage.isEmpty {
                    Text(completionMessage)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
            }

            Spacer()
        }
        .padding()
    }

    // MARK: - Computed

    private var publisherIcon: String {
        switch publisherType {
        case "aws": return "cloud.fill"
        case "sftp": return "server.rack"
        case "git": return "point.3.connected.trianglepath.dotted"
        default: return "arrow.up.circle"
        }
    }

    private var publisherDisplayName: String {
        switch publisherType {
        case "aws": return "AWS S3"
        case "sftp": return "SFTP"
        case "git": return "Git"
        default: return publisherType.uppercased()
        }
    }

    // MARK: - Actions

    private func loadStatus() {
        isLoadingStatus = true
        errorMessage = nil

        Task {
            let client = PostalgicAPIClient(server: server)
            do {
                let status = try await client.fetchPublishStatus(blogId: blog.id)
                await MainActor.run {
                    publisherType = status.publisherType
                    lastPublishedDate = status.lastPublishedDate
                    isLoadingStatus = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isLoadingStatus = false
                }
            }
        }
    }

    private func startPublish() {
        isPublishing = true
        isComplete = false
        errorMessage = nil
        currentPhase = ""
        progressMessage = "Starting..."
        currentFile = 0
        totalFiles = 0
        currentFilename = ""
        completionMessage = ""

        let client = PostalgicAPIClient(server: server)

        guard let url = client.publishStreamURL(blogId: blog.id, publisherType: publisherType) else {
            errorMessage = "Unsupported publisher type: \(publisherType)"
            isPublishing = false
            isComplete = true
            return
        }

        let authHeader = client.getAuthHeader()

        sseTask = Task {
            await streamSSE(url: url, authHeader: authHeader)
        }
    }

    private func streamSSE(url: URL, authHeader: String) async {
        var request = URLRequest(url: url)
        request.setValue(authHeader, forHTTPHeaderField: "Authorization")
        request.setValue("text/event-stream", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 300 // 5 minute timeout for long publishes

        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 300
        config.timeoutIntervalForResource = 600
        let session = URLSession(configuration: config)

        do {
            let (bytes, response) = try await session.bytes(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                await MainActor.run {
                    errorMessage = "Invalid response from server"
                    isPublishing = false
                    isComplete = true
                }
                return
            }

            if httpResponse.statusCode == 401 {
                await MainActor.run {
                    errorMessage = "Unauthorized. Check your server credentials."
                    isPublishing = false
                    isComplete = true
                }
                return
            }

            var currentEvent = ""
            var currentData = ""

            for try await line in bytes.lines {
                if Task.isCancelled { break }

                if line.hasPrefix("event: ") {
                    currentEvent = String(line.dropFirst(7))
                } else if line.hasPrefix("data: ") {
                    currentData = String(line.dropFirst(6))
                } else if line.isEmpty {
                    // End of event - process it
                    if !currentEvent.isEmpty && !currentData.isEmpty {
                        await processSSEEvent(event: currentEvent, data: currentData)
                    }
                    currentEvent = ""
                    currentData = ""
                }
            }

            // Stream ended - if we haven't gotten a complete/error event, mark as done
            await MainActor.run {
                if isPublishing && !isComplete {
                    isPublishing = false
                    isComplete = true
                }
            }
        } catch {
            if !Task.isCancelled {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isPublishing = false
                    isComplete = true
                }
            }
        }
    }

    @MainActor
    private func processSSEEvent(event: String, data: String) {
        guard let jsonData = data.data(using: .utf8) else { return }

        switch event {
        case "progress":
            if let dict = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] {
                if let message = dict["message"] as? String {
                    progressMessage = message
                }
                if let phase = dict["phase"] as? String {
                    currentPhase = phase
                }
            }

        case "file":
            if let dict = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] {
                if let current = dict["current"] as? Int {
                    currentFile = current
                }
                if let total = dict["total"] as? Int {
                    totalFiles = total
                }
                if let filename = dict["filename"] as? String {
                    currentFilename = filename
                }
            }

        case "complete":
            if let dict = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] {
                completionMessage = dict["message"] as? String ?? "Published successfully"
            }
            isPublishing = false
            isComplete = true
            errorMessage = nil

        case "error":
            if let dict = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] {
                errorMessage = dict["message"] as? String ?? "Unknown error"
            }
            isPublishing = false
            isComplete = true

        default:
            break
        }
    }
}
