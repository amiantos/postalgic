//
//  LinkListFormView.swift
//  Postalgic
//
//  Created by Claude on 4/28/25.
//

import SwiftUI
import SwiftData

struct LinkListFormView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    @Bindable var blog: Blog
    var sidebarObject: SidebarObject?
    
    @State private var title = ""
    @State private var isEditing = false
    @State private var links = [LinkItemData]()
    @State private var showingAddLink = false
    @State private var showingEditLink = false
    @State private var selectedLink: LinkItemData?
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Link List")) {
                    TextField("Title", text: $title)
                }
                
                Section(header: HStack {
                    Text("Links")
                    Spacer()
                    Button(action: {
                        selectedLink = nil
                        showingAddLink = true
                    }) {
                        Image(systemName: "plus.circle")
                    }
                }) {
                    if links.isEmpty {
                        Text("No links added yet. Tap '+' to add a link.")
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.vertical)
                    } else {
                        ForEach(links.indices, id: \.self) { index in
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(links[index].title)
                                        .font(.headline)
                                    Text(links[index].url)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .foregroundColor(.secondary)
                            }
                            .contentShape(Rectangle())
                            .onTapGesture {
                                // Set the selected link before showing the sheet
                                selectedLink = links[index]
                                // Present the edit sheet
                                showingEditLink = true
                            }
                        }
                        .onDelete { indexSet in
                            links.remove(atOffsets: indexSet)
                        }
                        .onMove { source, destination in
                            links.move(fromOffsets: source, toOffset: destination)
                        }
                    }
                }
            }
            .navigationTitle(sidebarObject == nil ? "Add Link List" : "Edit Link List")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveLinkList()
                        dismiss()
                    }
                    .disabled(title.isEmpty)
                }
                if !links.isEmpty {
                    ToolbarItem(placement: .topBarTrailing) {
                        EditButton()
                    }
                }
            }
            .onAppear {
                if let sidebarObject = sidebarObject {
                    title = sidebarObject.title
                    isEditing = true
                    
                    // Convert stored LinkItems to local LinkItemData objects
                    links = sidebarObject.links.sorted { $0.order < $1.order }.map {
                        LinkItemData(id: $0.id, title: $0.title, url: $0.url, order: $0.order)
                    }
                }
            }
        }
        // Sheet for adding a new link
        .sheet(isPresented: $showingAddLink) {
            LinkItemFormView(
                isPresented: $showingAddLink,
                linkItem: nil,
                isEditing: false
            ) { newLinkItem in
                // Add new link
                links.append(newLinkItem)
            }
        }
        // Sheet for editing an existing link
        .sheet(isPresented: $showingEditLink) {
            if let linkToEdit = selectedLink {
                LinkItemFormView(
                    isPresented: $showingEditLink,
                    linkItem: linkToEdit,
                    isEditing: true
                ) { updatedLink in
                    if let index = links.firstIndex(where: { $0.id == linkToEdit.id }) {
                        // Update existing link
                        links[index] = updatedLink
                    }
                }
            }
        }
    }
    
    private func saveLinkList() {
        if isEditing, let sidebarObject = sidebarObject {
            // Update existing link list
            sidebarObject.title = title
            
            // Remove all existing links
            for link in sidebarObject.links {
                modelContext.delete(link)
            }
            sidebarObject.links.removeAll()
            
            // Add updated links
            for (index, linkData) in links.enumerated() {
                let link = LinkItem(title: linkData.title, url: linkData.url, order: index)
                link.sidebarObject = sidebarObject
                sidebarObject.links.append(link)
            }
        } else {
            // Create a new link list with the next available order
            let nextOrder = blog.sidebarObjects.count
            let newSidebarObject = SidebarObject(title: title, type: .linkList, order: nextOrder)
            newSidebarObject.blog = blog
            
            // Add links to the new link list
            for (index, linkData) in links.enumerated() {
                let link = LinkItem(title: linkData.title, url: linkData.url, order: index)
                link.sidebarObject = newSidebarObject
                newSidebarObject.links.append(link)
            }
            
            blog.sidebarObjects.append(newSidebarObject)
        }
    }
}

// Helper struct for managing link data in the form
struct LinkItemData: Identifiable {
    var id: PersistentIdentifier?
    var title: String
    var url: String
    var order: Int
    
    init(id: PersistentIdentifier? = nil, title: String, url: String, order: Int) {
        self.id = id
        self.title = title
        self.url = url
        self.order = order
    }
}

// Form for adding/editing a single link
struct LinkItemFormView: View {
    @Binding var isPresented: Bool
    var linkItem: LinkItemData?
    var isEditing: Bool
    var onSave: (LinkItemData) -> Void
    
    @State private var title = ""
    @State private var url = ""
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Link Details")) {
                    TextField("Title", text: $title)
                    TextField("URL", text: $url)
                        .keyboardType(.URL)
                        .autocapitalization(.none)
                        .autocorrectionDisabled()
                }
            }
            .navigationTitle(isEditing ? "Edit Link" : "Add Link")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        isPresented = false
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        var order = 0
                        if let existingItem = linkItem {
                            order = existingItem.order
                        }
                        
                        let newLink = LinkItemData(
                            id: linkItem?.id,
                            title: title,
                            url: url,
                            order: order
                        )
                        onSave(newLink)
                        isPresented = false
                    }
                    .disabled(title.isEmpty || url.isEmpty)
                }
            }
        }
        .onAppear {
            if let linkItem = linkItem {
                title = linkItem.title
                url = linkItem.url
            } else {
                title = ""
                url = ""
            }
        }
    }
}