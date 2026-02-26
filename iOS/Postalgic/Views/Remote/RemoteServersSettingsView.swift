//
//  RemoteServersSettingsView.swift
//  Postalgic
//
//  Created by Claude on 2/18/26.
//

import SwiftData
import SwiftUI

struct RemoteServersSettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var servers: [RemoteServer]

    @State private var showingAddServer = false

    var body: some View {
        NavigationStack {
            List {
                if servers.isEmpty {
                    ContentUnavailableView {
                        Label("No Remote Servers", systemImage: "server.rack")
                    } description: {
                        Text("Add a self-hosted Postalgic server to manage your blogs remotely.")
                    }
                } else {
                    ForEach(servers.sorted(by: { $0.createdAt > $1.createdAt })) { server in
                        NavigationLink {
                            EditRemoteServerView(server: server)
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(server.name)
                                    .font(.headline)
                                Text(server.url)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .onDelete(perform: deleteServers)
                }
            }
            .navigationTitle("Remote Servers")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingAddServer = true
                    } label: {
                        Label("Add Server", systemImage: "plus")
                    }
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showingAddServer) {
                AddRemoteServerView()
            }
        }
    }

    private func deleteServers(at offsets: IndexSet) {
        let sorted = servers.sorted(by: { $0.createdAt > $1.createdAt })
        for index in offsets {
            let server = sorted[index]
            server.deletePassword()
            modelContext.delete(server)
        }
        try? modelContext.save()
    }
}

// MARK: - Add Remote Server

struct AddRemoteServerView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var url = ""
    @State private var username = ""
    @State private var password = ""

    @State private var isTesting = false
    @State private var testResult: TestResult?

    enum TestResult {
        case success(String)
        case failure(String)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Server Details") {
                    TextField("Display Name", text: $name)
                        .textContentType(.organizationName)
                        .autocorrectionDisabled()
                    TextField("Server URL", text: $url)
                        .textContentType(.URL)
                        .keyboardType(.URL)
                        .autocapitalization(.none)
                        .autocorrectionDisabled()
                    Text("e.g. https://postalgic.example.com")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("Credentials") {
                    TextField("Username", text: $username)
                        .textContentType(.username)
                        .autocapitalization(.none)
                        .autocorrectionDisabled()
                    SecureField("Password", text: $password)
                        .textContentType(.password)
                }

                Section {
                    Button {
                        testConnection()
                    } label: {
                        HStack {
                            Text("Test Connection")
                            Spacer()
                            if isTesting {
                                ProgressView()
                            }
                        }
                    }
                    .disabled(isTesting || url.isEmpty || username.isEmpty || password.isEmpty)

                    if let result = testResult {
                        switch result {
                        case .success(let message):
                            Label(message, systemImage: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                        case .failure(let message):
                            Label(message, systemImage: "xmark.circle.fill")
                                .foregroundStyle(.red)
                        }
                    }
                }

                Section {
                    Button("Add Server") {
                        saveServer()
                    }
                    .disabled(name.isEmpty || url.isEmpty || username.isEmpty || password.isEmpty)
                }
            }
            .navigationTitle("Add Server")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }

    private func testConnection() {
        isTesting = true
        testResult = nil

        let normalizedURL = url.hasSuffix("/") ? String(url.dropLast()) : url
        let client = PostalgicAPIClient(baseURL: normalizedURL, username: username, password: password)

        Task {
            do {
                try await client.testConnection()
                await MainActor.run {
                    testResult = .success("Connection successful!")
                    isTesting = false
                }
            } catch {
                await MainActor.run {
                    testResult = .failure(error.localizedDescription)
                    isTesting = false
                }
            }
        }
    }

    private func saveServer() {
        let server = RemoteServer(name: name, url: url, username: username)
        modelContext.insert(server)
        try? modelContext.save()
        // Set password AFTER insert+save so persistentModelID is stable
        server.setPassword(password)
        dismiss()
    }
}

// MARK: - Edit Remote Server

struct EditRemoteServerView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let server: RemoteServer

    @State private var name: String = ""
    @State private var url: String = ""
    @State private var username: String = ""
    @State private var password: String = ""

    @State private var isTesting = false
    @State private var testResult: AddRemoteServerView.TestResult?
    @State private var showingDeleteConfirmation = false

    var body: some View {
        Form {
            Section("Server Details") {
                TextField("Display Name", text: $name)
                    .autocorrectionDisabled()
                TextField("Server URL", text: $url)
                    .textContentType(.URL)
                    .keyboardType(.URL)
                    .autocapitalization(.none)
                    .autocorrectionDisabled()
            }

            Section("Credentials") {
                TextField("Username", text: $username)
                    .textContentType(.username)
                    .autocapitalization(.none)
                    .autocorrectionDisabled()
                SecureField("Password", text: $password)
                    .textContentType(.password)
            }

            Section {
                Button {
                    testConnection()
                } label: {
                    HStack {
                        Text("Test Connection")
                        Spacer()
                        if isTesting {
                            ProgressView()
                        }
                    }
                }
                .disabled(isTesting || url.isEmpty || username.isEmpty || password.isEmpty)

                if let result = testResult {
                    switch result {
                    case .success(let message):
                        Label(message, systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    case .failure(let message):
                        Label(message, systemImage: "xmark.circle.fill")
                            .foregroundStyle(.red)
                    }
                }
            }

            Section {
                Button("Save Changes") {
                    saveChanges()
                }
                .disabled(name.isEmpty || url.isEmpty || username.isEmpty || password.isEmpty)
            }

            Section {
                Button("Remove Server", role: .destructive) {
                    showingDeleteConfirmation = true
                }
            }
        }
        .navigationTitle("Edit Server")
        .onAppear {
            name = server.name
            url = server.url
            username = server.username
            password = server.getPassword() ?? ""
        }
        .alert("Remove Server", isPresented: $showingDeleteConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Remove", role: .destructive) {
                deleteServer()
            }
        } message: {
            Text("Are you sure you want to remove this server? This will remove the connection only - no data on the server will be affected.")
        }
    }

    private func testConnection() {
        isTesting = true
        testResult = nil

        let normalizedURL = url.hasSuffix("/") ? String(url.dropLast()) : url
        let client = PostalgicAPIClient(baseURL: normalizedURL, username: username, password: password)

        Task {
            do {
                try await client.testConnection()
                await MainActor.run {
                    testResult = .success("Connection successful!")
                    isTesting = false
                }
            } catch {
                await MainActor.run {
                    testResult = .failure(error.localizedDescription)
                    isTesting = false
                }
            }
        }
    }

    private func saveChanges() {
        server.name = name
        server.url = url.hasSuffix("/") ? String(url.dropLast()) : url
        server.username = username
        server.setPassword(password)
        try? modelContext.save()
        dismiss()
    }

    private func deleteServer() {
        server.deletePassword()
        modelContext.delete(server)
        try? modelContext.save()
        dismiss()
    }
}
