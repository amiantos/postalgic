//
//  TemplateCustomizationView.swift
//  Postalgic
//
//  Created by Brad Root on 4/26/25.
//

import SwiftUI
import SwiftData

struct TemplateCustomizationView: View {
    @Environment(\.dismiss) private var dismiss
    
    @Query private var blogs: [Blog]
    var blog: Blog
    
    @State private var selectedTemplateType: String = "layout"
    @State private var templateContent: String = ""
    @State private var isEditing: Bool = false
    @State private var errorMessage: String = ""
    @State private var availableTemplateTypes: [String] = []
    @State private var showingResetAllConfirmation: Bool = false
    
    // Create a template generator for this blog to access templates
    private var templateGenerator: StaticSiteGenerator {
        StaticSiteGenerator(blog: blog)
    }
    
    var body: some View {
        NavigationStack {
            VStack {
                if !errorMessage.isEmpty {
                    Text(errorMessage)
                        .foregroundColor(.red)
                }
                
                TextEditor(text: $templateContent)
                    .font(.system(.caption, design: .monospaced))
                    .frame(minHeight: 400)
                    .disabled(!isEditing)
            }
            .navigationTitle("Customize")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItemGroup(placement: .topBarLeading) {
                    if isEditing {
                        Button("Cancel", role: .destructive) {
                            isEditing = false
                            loadTemplate(type: selectedTemplateType)
                        }
                    } else {
                        Button("Close") {
                            dismiss()
                        }
                    }
                }
                ToolbarItemGroup(placement: .primaryAction) {
                    if isEditing {
                        Button("Save") {
                            saveTemplate()
                            isEditing = false
                        }
                    } else {
                        Picker("Template Type", selection: $selectedTemplateType) {
                            ForEach(availableTemplateTypes, id: \.self) { type in
                                Text(type)
                                    .tag(type)
                            }
                        }
                        .onChange(of: selectedTemplateType) { _, newValue in
                            loadTemplate(type: newValue)
                        }
                        
                        Button("Edit") {
                            isEditing = true
                        }
                    }
                }
                ToolbarItemGroup(placement: .secondaryAction) {
                    if !isEditing {
                        Button("Reset to Default", role: .destructive) {
                            resetTemplate()
                        }
                        
                        Divider()
                        
                        Button("Reset All Templates", role: .destructive) {
                            showingResetAllConfirmation = true
                        }
                    }
                }
            }
            .onAppear {
                availableTemplateTypes = templateGenerator.availableTemplateTypes()
                loadTemplate(type: selectedTemplateType)
            }
            .confirmationDialog(
                "Reset All Templates",
                isPresented: $showingResetAllConfirmation,
                actions: {
                    Button("Reset All", role: .destructive) {
                        resetAllTemplates()
                    }
                    Button("Cancel", role: .cancel) {}
                },
                message: {
                    Text("This will reset ALL template customizations to their default values. This action cannot be undone.")
                }
            )
        }
    }
    
    // Load the current template content
    private func loadTemplate(type: String) {
        do {
            templateContent = try templateGenerator.getTemplateContent(for: type)
            errorMessage = ""
        } catch {
            errorMessage = "Failed to load template: \(error.localizedDescription)"
        }
    }
    
    // Save the edited template
    private func saveTemplate() {
        templateGenerator.registerCustomTemplate(templateContent, for: selectedTemplateType)
        isEditing = false
        errorMessage = "Template saved successfully"
    }
    
    // Reset the template to default
    private func resetTemplate() {
        // Registering an empty template will cause the default to be used
        templateGenerator.registerCustomTemplate("", for: selectedTemplateType)
        loadTemplate(type: selectedTemplateType)
        errorMessage = "Template reset to default"
    }
    
    // Reset all templates to their defaults
    private func resetAllTemplates() {
        // Reset each available template type
        for templateType in availableTemplateTypes {
            templateGenerator.registerCustomTemplate("", for: templateType)
        }
        
        // Reload the current template
        loadTemplate(type: selectedTemplateType)
        errorMessage = "All templates have been reset to defaults"
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Blog.self, configurations: config)
    let example = Blog(name: "My Blog", url: "https://example.com")
    
    return TemplateCustomizationView(blog: example)
        .modelContainer(container)
}
