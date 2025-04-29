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
    @State private var showingLinkForm = false
    @State private var selectedLink: LinkItem?
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Link List")) {
                    TextField("Title", text: $title)
                }
                
                Section {
                    if let sidebarObject = sidebarObject, !sidebarObject.links.isEmpty {
                        ForEach(sidebarObject.links.sorted(by: { $0.order < $1.order })) { link in
                            LinkRow(link: link)
                                .onTapGesture {
                                    selectedLink = link
                                }
                        }
                        .onMove { indices, newOffset in
                            let sortedLinks = sidebarObject.links.sorted(by: { $0.order < $1.order })
                            let links = Array(sortedLinks)
                            
                            // Get the items to move
                            var itemsToMove = [LinkItem]()
                            for index in indices {
                                itemsToMove.append(links[index])
                            }
                            
                            // Update the order property of each item
                            for (i, link) in links.enumerated() {
                                if indices.contains(i) {
                                    // Skip the items we're moving
                                    continue
                                }
                                
                                if i < newOffset {
                                    // Items before the insertion point
                                    link.order = i
                                } else {
                                    // Items after the insertion point
                                    link.order = i + itemsToMove.count
                                }
                            }
                            
                            // Update the order of the moved items
                            for (offset, link) in itemsToMove.enumerated() {
                                link.order = newOffset + offset
                            }
                        }
                        .onDelete { indexSet in
                            let sortedLinks = sidebarObject.links.sorted(by: { $0.order < $1.order })
                            let linksToDelete = indexSet.map { sortedLinks[$0] }
                            
                            for link in linksToDelete {
                                sidebarObject.links.removeAll { $0.id == link.id }
                                modelContext.delete(link)
                            }
                            
                            // Reorder remaining links
                            let remainingLinks = sidebarObject.links.sorted(by: { $0.order < $1.order })
                            for (i, link) in remainingLinks.enumerated() {
                                link.order = i
                            }
                        }
                    } else if sidebarObject != nil {
                        Text("No links added yet. Tap '+' to add a link.")
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.vertical)
                    }
                } header: {
                    Text("Links")
                } footer: {
                    Text("Drag to reorder. Tap to edit.")
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
                
                if sidebarObject != nil {
                    ToolbarItem(placement: .primaryAction) {
                        Button {
                            showingLinkForm = true
                        } label: {
                            Label("Add Link", systemImage: "plus")
                        }
                    }
                }
                
                if let sidebarObject = sidebarObject, !sidebarObject.links.isEmpty {
                    ToolbarItem(placement: .topBarTrailing) {
                        EditButton()
                    }
                }
            }
            .onAppear {
                loadData()
            }
            .sheet(isPresented: $showingLinkForm) {
                LinkFormView(onSave: { linkTitle, linkUrl in
                    addNewLink(title: linkTitle, url: linkUrl)
                })
            }
            .sheet(item: $selectedLink) { link in
                LinkEditFormView(link: link)
            }
        }
    }
    
    private func loadData() {
        if let sidebarObject = sidebarObject {
            title = sidebarObject.title
            isEditing = true
        }
    }
    
    private func addNewLink(title: String, url: String) {
        guard let sidebarObject = sidebarObject else {
            // For adding a link to a new sidebar object, we'll create it on save
            return
        }
        
        let nextOrder = sidebarObject.links.count
        let newLink = LinkItem(title: title, url: url, order: nextOrder)
        newLink.sidebarObject = sidebarObject
        sidebarObject.links.append(newLink)
    }
    
    private func saveLinkList() {
        if isEditing, let sidebarObject = sidebarObject {
            // Update existing link list
            sidebarObject.title = title
        } else {
            // Create a new link list with the next available order
            let nextOrder = blog.sidebarObjects.count
            let newSidebarObject = SidebarObject(title: title, type: .linkList, order: nextOrder)
            newSidebarObject.blog = blog
            blog.sidebarObjects.append(newSidebarObject)
            
            // If we have any temporary links, add them now
            // (This code path won't be reached since we don't save temporary links anymore, 
            // but keeping it for future extensibility)
        }
    }
}

struct LinkRow: View {
    let link: LinkItem
    
    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(link.title)
                    .font(.headline)
                Text(link.url)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .foregroundColor(.secondary)
        }
    }
}

struct LinkFormView: View {
    @Environment(\.dismiss) private var dismiss
    
    @State private var title = ""
    @State private var url = ""
    
    let onSave: (String, String) -> Void
    
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
            .navigationTitle("Add Link")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(title, url)
                        dismiss()
                    }
                    .disabled(title.isEmpty || url.isEmpty)
                }
            }
        }
    }
}

struct LinkEditFormView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    @Bindable var link: LinkItem
    
    @State private var title: String
    @State private var url: String
    
    init(link: LinkItem) {
        self.link = link
        _title = State(initialValue: link.title)
        _url = State(initialValue: link.url)
    }
    
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
            .navigationTitle("Edit Link")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        link.title = title
                        link.url = url
                        dismiss()
                    }
                    .disabled(title.isEmpty || url.isEmpty)
                }
            }
        }
    }
}
