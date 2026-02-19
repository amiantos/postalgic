//
//  PostalgicAPIClient.swift
//  Postalgic
//
//  Created by Claude on 2/18/26.
//

import Foundation

/// HTTP client for communicating with a self-hosted Postalgic server
actor PostalgicAPIClient {

    let baseURL: String
    private let username: String
    private let password: String
    private let session: URLSession

    init(server: RemoteServer) {
        self.baseURL = server.baseURL
        self.username = server.username
        self.password = server.getPassword() ?? ""

        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        self.session = URLSession(configuration: config)
    }

    init(baseURL: String, username: String, password: String) {
        self.baseURL = baseURL.hasSuffix("/") ? String(baseURL.dropLast()) : baseURL
        self.username = username
        self.password = password

        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        self.session = URLSession(configuration: config)
    }

    // MARK: - Connection Test

    /// Tests the connection to the server by fetching the blogs list
    func testConnection() async throws {
        let _: [RemoteBlog] = try await get("/api/blogs")
    }

    // MARK: - Blogs

    func fetchBlogs() async throws -> [RemoteBlog] {
        try await get("/api/blogs")
    }

    func fetchBlog(id: String) async throws -> RemoteBlog {
        try await get("/api/blogs/\(id)")
    }

    func fetchBlogStats(blogId: String) async throws -> RemoteBlogStats {
        try await get("/api/blogs/\(blogId)/stats")
    }

    func fetchBlogFavicon(blogId: String) async throws -> Data {
        try await getRawData("/api/blogs/\(blogId)/favicon")
    }

    // MARK: - Posts

    func fetchPosts(
        blogId: String,
        status: String = "all",
        search: String = "",
        sort: String = "date_desc",
        page: Int = 1,
        limit: Int = 20
    ) async throws -> RemotePostsResponse {
        var queryItems: [URLQueryItem] = [
            URLQueryItem(name: "status", value: status),
            URLQueryItem(name: "sort", value: sort),
            URLQueryItem(name: "page", value: String(page)),
            URLQueryItem(name: "limit", value: String(limit))
        ]
        if !search.isEmpty {
            queryItems.append(URLQueryItem(name: "search", value: search))
        }
        return try await get("/api/blogs/\(blogId)/posts", queryItems: queryItems)
    }

    func fetchPost(blogId: String, postId: String) async throws -> RemotePost {
        try await get("/api/blogs/\(blogId)/posts/\(postId)")
    }

    // MARK: - Categories

    func fetchCategories(blogId: String) async throws -> [RemoteCategory] {
        try await get("/api/blogs/\(blogId)/categories")
    }

    // MARK: - Tags

    func fetchTags(blogId: String) async throws -> [RemoteTag] {
        try await get("/api/blogs/\(blogId)/tags")
    }

    // MARK: - Private Networking

    private func authHeader() -> String {
        let credentials = "\(username):\(password)"
        let data = Data(credentials.utf8)
        return "Basic \(data.base64EncodedString())"
    }

    private func get<T: Decodable>(_ path: String, queryItems: [URLQueryItem] = []) async throws -> T {
        var components = URLComponents(string: "\(baseURL)\(path)")
        if !queryItems.isEmpty {
            components?.queryItems = queryItems
        }

        guard let url = components?.url else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue(authHeader(), forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        switch httpResponse.statusCode {
        case 200...299:
            let decoder = JSONDecoder()
            return try decoder.decode(T.self, from: data)
        case 401:
            throw APIError.unauthorized
        case 404:
            throw APIError.notFound
        default:
            let message = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw APIError.serverError(statusCode: httpResponse.statusCode, message: message)
        }
    }

    private func getRawData(_ path: String) async throws -> Data {
        guard let url = URL(string: "\(baseURL)\(path)") else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue(authHeader(), forHTTPHeaderField: "Authorization")

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        switch httpResponse.statusCode {
        case 200...299:
            return data
        case 401:
            throw APIError.unauthorized
        case 404:
            throw APIError.notFound
        default:
            throw APIError.serverError(statusCode: httpResponse.statusCode, message: "Failed to fetch data")
        }
    }
}

// MARK: - API Errors

enum APIError: LocalizedError {
    case invalidURL
    case invalidResponse
    case unauthorized
    case notFound
    case serverError(statusCode: Int, message: String)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid server URL"
        case .invalidResponse:
            return "Invalid response from server"
        case .unauthorized:
            return "Invalid credentials. Check your username and password."
        case .notFound:
            return "Resource not found"
        case .serverError(let code, let message):
            return "Server error (\(code)): \(message)"
        }
    }
}
