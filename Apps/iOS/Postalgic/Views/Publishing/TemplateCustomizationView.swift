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
                        .padding()
                }
                
                Picker("Template Type", selection: $selectedTemplateType) {
                    ForEach(availableTemplateTypes, id: \.self) { type in
                        Text(type.capitalized)
                            .tag(type)
                    }
                }
                .pickerStyle(.automatic)
                .padding()
                .onChange(of: selectedTemplateType) { _, newValue in
                    loadTemplate(type: newValue)
                }
                
                TextEditor(text: $templateContent)
                    .font(.system(.body, design: .monospaced))
                    .frame(minHeight: 400)
                    .padding()
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                    )
                    .disabled(!isEditing)
                
                HStack {
                    if isEditing {
                        Button("Cancel") {
                            isEditing = false
                            loadTemplate(type: selectedTemplateType)
                        }
                        .buttonStyle(.bordered)
                        
                        Button("Save") {
                            saveTemplate()
                        }
                        .buttonStyle(.borderedProminent)
                    } else {
                        Button("Reset to Default") {
                            resetTemplate()
                        }
                        .buttonStyle(.bordered)
                        
                        Button("Edit") {
                            isEditing = true
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
                .padding()
            }
            .navigationTitle("Customize Templates")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                availableTemplateTypes = templateGenerator.availableTemplateTypes()
                loadTemplate(type: selectedTemplateType)
            }
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
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Blog.self, configurations: config)
    let example = Blog(name: "My Blog", url: "https://example.com")
    
    return TemplateCustomizationView(blog: example)
        .modelContainer(container)
}
