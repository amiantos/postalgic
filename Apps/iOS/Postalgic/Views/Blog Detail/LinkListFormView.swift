//
//  LinkListFormView.swift
//  Postalgic
//
//  Created by Claude on 4/28/25.
//

import SwiftUI
import SwiftData

struct AddLinkListView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    @Bindable var blog: Blog
    
    @State private var title = ""
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Link List")) {
                    TextField("Title", text: $title)
                }
                
                Section {
                    Text("You can add links after creating the link list.")
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical)
                } header: {
                    Text("Links")
                }
            }
            .navigationTitle("Add Link List")
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
            }
        }
    }
    
    private func saveLinkList() {
        // Create a new link list with the next available order
        let nextOrder = blog.sidebarObjects.count
        let newSidebarObject = SidebarObject(title: title, type: .linkList, order: nextOrder)
        newSidebarObject.blog = blog
        blog.sidebarObjects.append(newSidebarObject)
    }
}

struct EditLinkListView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.presentationMode) private var presentationMode
    
    @Bindable var blog: Blog
    @Bindable var sidebarObject: SidebarObject
    
    @State private var title: String
    @State private var hasChanges = false
    @State private var showingLinkForm = false
    
    init(sidebarObject: SidebarObject, blog: Blog) {
        self.sidebarObject = sidebarObject
        self.blog = blog
        _title = State(initialValue: sidebarObject.title)
    }
    
    var body: some View {
        Form {
            Section(header: Text("Link List")) {
                TextField("Title", text: $title)
                    .onChange(of: title) { _, _ in
                        checkForChanges()
                    }
            }
            
            Section {
                if !sidebarObject.links.isEmpty {
                    ForEach(sidebarObject.links.sorted(by: { $0.order < $1.order })) { link in
                        NavigationLink(destination: LinkEditFormView(link: link)) {
                            LinkRow(link: link)
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
                } else {
                    Text("No links added yet. Tap '+' to add a link.")
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical)
                }
            } header: {
                HStack {
                    Text("Links")
                    Spacer()
                    Button {
                        showingLinkForm = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            } footer: {
                Text("Drag to reorder. Tap to edit. Swipe to delete.")
            }
        }
        .navigationTitle("Edit Link List")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Save") {
                    saveLinkList()
                    dismiss()
                }
                .disabled(!hasChanges && title == sidebarObject.title)
            }
            
        }
        .interactiveDismissDisabled(hasChanges)
        .onChange(of: presentationMode.wrappedValue.isPresented) { wasPresented, isPresented in
            if wasPresented && !isPresented && hasChanges {
                // The view is being dismissed, but we have unsaved changes
                // This is handled by interactiveDismissDisabled now
            }
        }
        .sheet(isPresented: $showingLinkForm) {
            LinkFormView(onSave: { linkTitle, linkUrl in
                addNewLink(title: linkTitle, url: linkUrl)
            })
        }
    }
    
    private func checkForChanges() {
        hasChanges = title != sidebarObject.title
    }
    
    private func addNewLink(title: String, url: String) {
        let nextOrder = sidebarObject.links.count
        let newLink = LinkItem(title: title, url: url, order: nextOrder)
        newLink.sidebarObject = sidebarObject
        sidebarObject.links.append(newLink)
    }
    
    private func saveLinkList() {
        // Update existing link list
        sidebarObject.title = title
    }
}

struct LinkListFormView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    @Bindable var blog: Blog
    var sidebarObject: SidebarObject?
    
    var body: some View {
        if let sidebarObject = sidebarObject {
            EditLinkListView(sidebarObject: sidebarObject, blog: blog)
        } else {
            AddLinkListView(blog: blog)
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
                ToolbarItem(placement: .navigationBarLeading) {
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
