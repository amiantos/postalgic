//
//  SyncSettingsView.swift
//  Postalgic
//
//  Created by Claude on 12/14/25.
//

import SwiftUI
import SwiftData

struct SyncSettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    var blog: Blog

    @State private var syncEnabled: Bool
    @State private var password: String = ""
    @State private var confirmPassword: String = ""
    @State private var showingPassword = false
    @State private var showingConfirmPassword = false
    @State private var showingChangePassword = false
    @State private var errorMessage: String?
    @State private var showingDisableConfirmation = false

    init(blog: Blog) {
        self.blog = blog
        _syncEnabled = State(initialValue: blog.syncEnabled)
    }

    private var hasExistingPassword: Bool {
        blog.getSyncPassword() != nil
    }

    private var passwordsMatch: Bool {
        !password.isEmpty && password == confirmPassword
    }

    private var canEnableSync: Bool {
        if hasExistingPassword {
            return true
        }
        return passwordsMatch
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Toggle("Enable Sync", isOn: $syncEnabled)
                        .onChange(of: syncEnabled) { oldValue, newValue in
                            if newValue && !hasExistingPassword && password.isEmpty {
                                // Don't enable yet, need password first
                                syncEnabled = false
                            } else if newValue {
                                enableSync()
                            } else if blog.syncEnabled {
                                // Only show disable confirmation if sync is actually enabled
                                showingDisableConfirmation = true
                            }
                        }
                } header: {
                    Text("Sync Status")
                } footer: {
                    if blog.syncEnabled {
                        if let lastSynced = blog.lastSyncedAt {
                            Text("Last synced: \(lastSynced.formatted(date: .abbreviated, time: .shortened))")
                        } else {
                            Text("Sync data will be generated when you publish your blog.")
                        }
                    } else {
                        Text("When enabled, sync data will be generated alongside your published site, allowing you to import your blog on other devices.")
                    }
                }

                if !blog.syncEnabled {
                    Section {
                        if hasExistingPassword && !showingChangePassword {
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                Text("Password is set")
                                    .foregroundColor(.secondary)
                                Spacer()
                                Button("Change") {
                                    showingChangePassword = true
                                }
                            }
                        } else {
                            HStack {
                                if showingPassword {
                                    TextField("Password", text: $password)
                                        .textContentType(.newPassword)
                                        .autocorrectionDisabled()
                                        .textInputAutocapitalization(.never)
                                } else {
                                    SecureField("Password", text: $password)
                                        .textContentType(.newPassword)
                                }
                                Button {
                                    showingPassword.toggle()
                                } label: {
                                    Image(systemName: showingPassword ? "eye.slash" : "eye")
                                        .foregroundColor(.secondary)
                                }
                            }

                            HStack {
                                if showingConfirmPassword {
                                    TextField("Confirm Password", text: $confirmPassword)
                                        .textContentType(.newPassword)
                                        .autocorrectionDisabled()
                                        .textInputAutocapitalization(.never)
                                } else {
                                    SecureField("Confirm Password", text: $confirmPassword)
                                        .textContentType(.newPassword)
                                }
                                Button {
                                    showingConfirmPassword.toggle()
                                } label: {
                                    Image(systemName: showingConfirmPassword ? "eye.slash" : "eye")
                                        .foregroundColor(.secondary)
                                }
                            }

                            if !password.isEmpty && !confirmPassword.isEmpty && !passwordsMatch {
                                Text("Passwords do not match")
                                    .foregroundColor(.red)
                                    .font(.caption)
                            }
                        }

                        Button {
                            enableSync()
                        } label: {
                            HStack {
                                Spacer()
                                Text("Enable Sync")
                                Spacer()
                            }
                        }
                        .disabled(!canEnableSync)
                    } header: {
                        Text("Sync Password")
                    } footer: {
                        Text("This password encrypts your draft posts. You'll need it to import your blog on another device. Keep it safe - it cannot be recovered.")
                    }
                }

                if blog.syncEnabled {
                    Section {
                        Button {
                            showingChangePassword = true
                        } label: {
                            Label("Change Sync Password", systemImage: "key")
                        }
                    } header: {
                        Text("Security")
                    } footer: {
                        Text("Changing your password will require you to re-import on any other devices using the new password.")
                    }
                }

                if let error = errorMessage {
                    Section {
                        Text(error)
                            .foregroundColor(.red)
                    }
                }
            }
            .navigationTitle("Sync Settings")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
            .alert("Disable Sync", isPresented: $showingDisableConfirmation) {
                Button("Cancel", role: .cancel) {
                    syncEnabled = true
                }
                Button("Disable", role: .destructive) {
                    disableSync()
                }
            } message: {
                Text("This will stop generating sync data when you publish. Your sync password will be kept in case you want to re-enable later.")
            }
            .sheet(isPresented: $showingChangePassword) {
                ChangePasswordView(blog: blog)
            }
        }
    }

    private func enableSync() {
        errorMessage = nil

        // If we need to set a new password
        if !hasExistingPassword || showingChangePassword {
            guard passwordsMatch else {
                errorMessage = "Passwords do not match"
                return
            }

            guard password.count >= 8 else {
                errorMessage = "Password must be at least 8 characters"
                return
            }

            // Save password to keychain
            blog.setSyncPassword(password)
        }

        // Enable sync
        blog.syncEnabled = true
        try? modelContext.save()

        syncEnabled = true
        password = ""
        confirmPassword = ""
        showingChangePassword = false
    }

    private func disableSync() {
        blog.syncEnabled = false
        try? modelContext.save()
        syncEnabled = false
    }
}

struct ChangePasswordView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    var blog: Blog

    @State private var newPassword: String = ""
    @State private var confirmPassword: String = ""
    @State private var showingPassword = false
    @State private var showingConfirmPassword = false
    @State private var errorMessage: String?

    private var passwordsMatch: Bool {
        !newPassword.isEmpty && newPassword == confirmPassword
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        if showingPassword {
                            TextField("New Password", text: $newPassword)
                                .textContentType(.newPassword)
                                .autocorrectionDisabled()
                                .textInputAutocapitalization(.never)
                        } else {
                            SecureField("New Password", text: $newPassword)
                                .textContentType(.newPassword)
                        }
                        Button {
                            showingPassword.toggle()
                        } label: {
                            Image(systemName: showingPassword ? "eye.slash" : "eye")
                                .foregroundColor(.secondary)
                        }
                    }

                    HStack {
                        if showingConfirmPassword {
                            TextField("Confirm Password", text: $confirmPassword)
                                .textContentType(.newPassword)
                                .autocorrectionDisabled()
                                .textInputAutocapitalization(.never)
                        } else {
                            SecureField("Confirm Password", text: $confirmPassword)
                                .textContentType(.newPassword)
                        }
                        Button {
                            showingConfirmPassword.toggle()
                        } label: {
                            Image(systemName: showingConfirmPassword ? "eye.slash" : "eye")
                                .foregroundColor(.secondary)
                        }
                    }

                    if !newPassword.isEmpty && !confirmPassword.isEmpty && !passwordsMatch {
                        Text("Passwords do not match")
                            .foregroundColor(.red)
                            .font(.caption)
                    }
                } header: {
                    Text("New Password")
                } footer: {
                    Text("After changing your password, you'll need to re-import on any other devices using the new password.")
                }

                if let error = errorMessage {
                    Section {
                        Text(error)
                            .foregroundColor(.red)
                    }
                }
            }
            .navigationTitle("Change Password")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        savePassword()
                    }
                    .disabled(!passwordsMatch || newPassword.count < 8)
                }
            }
        }
    }

    private func savePassword() {
        guard passwordsMatch else {
            errorMessage = "Passwords do not match"
            return
        }

        guard newPassword.count >= 8 else {
            errorMessage = "Password must be at least 8 characters"
            return
        }

        blog.setSyncPassword(newPassword)

        // Reset sync hashes since password changed
        blog.localSyncHashes = [:]
        blog.lastSyncedVersion = 0

        try? modelContext.save()
        dismiss()
    }
}

#Preview {
    let modelContainer = PreviewData.previewContainer

    return SyncSettingsView(
        blog: try! modelContainer.mainContext.fetch(FetchDescriptor<Blog>()).first!
    )
    .modelContainer(modelContainer)
}
