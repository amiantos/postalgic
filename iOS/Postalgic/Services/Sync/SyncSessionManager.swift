//
//  SyncSessionManager.swift
//  Postalgic
//
//  Manages sync session state to avoid repeated sync checks within the same session.
//  Tracks which blogs have been checked for remote changes this session.
//

import Foundation

/// Manages sync session state to prevent repeated sync prompts during a single app session.
/// This is an in-memory tracker that resets when the app fully terminates.
class SyncSessionManager {
    static let shared = SyncSessionManager()

    /// Set of blog IDs that have been checked for sync this session
    private var checkedBlogIds: Set<String> = []

    /// Lock for thread-safe access to checkedBlogIds
    private let lock = NSLock()

    private init() {}

    /// Check if a blog has already been checked for sync changes this session
    /// - Parameter blogId: The UUID string of the blog
    /// - Returns: true if already checked, false otherwise
    func hasCheckedThisSession(blogId: String) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return checkedBlogIds.contains(blogId)
    }

    /// Mark a blog as having been checked for sync changes this session
    /// - Parameter blogId: The UUID string of the blog
    func markAsChecked(blogId: String) {
        lock.lock()
        defer { lock.unlock() }
        checkedBlogIds.insert(blogId)
    }

    /// Clear the checked status for a specific blog (e.g., after a manual sync)
    /// - Parameter blogId: The UUID string of the blog
    func clearCheckedStatus(blogId: String) {
        lock.lock()
        defer { lock.unlock() }
        checkedBlogIds.remove(blogId)
    }

    /// Clear all session tracking (useful for testing or when user logs out)
    func clearSession() {
        lock.lock()
        defer { lock.unlock() }
        checkedBlogIds.removeAll()
    }
}
