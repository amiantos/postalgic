//
//  SidebarManagementView.swift
//  Postalgic
//
//  Created by Claude on 4/28/25.
//

import SwiftUI
import SwiftData

struct SidebarManagementView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    @Bindable var blog: Blog
    
    @State private var isAddingObject = false
    @State private var sidebarObjectType: SidebarObjectType = .text
    @State private var showingAlert = false
    
    @ViewBuilder
    private func objectDestination(for object: SidebarObject) -> some View {
        if object.objectType == .text {
            EditTextBlockView(sidebarObject: object, blog: blog)
        } else if object.objectType == .linkList {
            EditLinkListView(sidebarObject: object, blog: blog)
        }
    }
    
    var body: some View {
        NavigationStack {
            List {
                Section {
                    if blog.sidebarObjects.isEmpty {
                        Text("No sidebar items yet. Add some to customize your blog's sidebar.")
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.vertical)
                    } else {
                        ForEach(blog.sidebarObjects.sorted(by: { $0.order < $1.order })) { object in
                            NavigationLink(destination: objectDestination(for: object)) {
                                SidebarObjectRow(object: object)
                            }
                        }
                        .onMove { indices, newOffset in
                            let sortedObjects = blog.sidebarObjects.sorted(by: { $0.order < $1.order })
                            let objects = Array(sortedObjects)
                            
                            // Get the items to move
                            var itemsToMove = [SidebarObject]()
                            for index in indices {
                                itemsToMove.append(objects[index])
                            }
                            
                            // Update the order property of each item
                            for (i, object) in objects.enumerated() {
                                if indices.contains(i) {
                                    // Skip the items we're moving
                                    continue
                                }
                                
                                if i < newOffset {
                                    // Items before the insertion point
                                    object.order = i
                                } else {
                                    // Items after the insertion point
                                    object.order = i + itemsToMove.count
                                }
                            }
                            
                            // Update the order of the moved items
                            for (offset, object) in itemsToMove.enumerated() {
                                object.order = newOffset + offset
                            }
                        }
                        .onDelete { indexSet in
                            let sortedObjects = blog.sidebarObjects.sorted(by: { $0.order < $1.order })
                            let objectsToDelete = indexSet.map { sortedObjects[$0] }
                            
                            for object in objectsToDelete {
                                blog.sidebarObjects.removeAll { $0.id == object.id }
                                modelContext.delete(object)
                            }
                            
                            // Reorder remaining objects
                            let remainingObjects = blog.sidebarObjects.sorted(by: { $0.order < $1.order })
                            for (i, object) in remainingObjects.enumerated() {
                                object.order = i
                            }
                        }
                    }
                } header: {
                    Text("Sidebar Objects")
                } footer: {
                    Text("Drag to reorder. Tap to edit. Swipe to delete.")
                }
            }
            .navigationTitle("Manage Sidebar")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button {
                            sidebarObjectType = .text
                            isAddingObject = true
                        } label: {
                            Label("Add Text Block", systemImage: "doc.text")
                        }
                        
                        Button {
                            sidebarObjectType = .linkList
                            isAddingObject = true
                        } label: {
                            Label("Add Link List", systemImage: "link")
                        }
                    } label: {
                        Label("Add", systemImage: "plus")
                    }
                }
            }
            .sheet(isPresented: $isAddingObject) {
                if sidebarObjectType == .text {
                    AddTextBlockView(blog: blog).interactiveDismissDisabled()
                } else {
                    AddLinkListView(blog: blog).interactiveDismissDisabled()
                }
            }
        }
    }
}

struct SidebarObjectRow: View {
    let object: SidebarObject
    
    var body: some View {
        HStack {
            if object.objectType == .text {
                VStack(alignment: .leading) {
                    Text(object.title)
                        .font(.headline)
                    Text("Text Block")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            } else if object.objectType == .linkList {
                VStack(alignment: .leading) {
                    Text(object.title)
                        .font(.headline)
                    Text("Link List (\(object.links.count) links)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
        }
    }
}
