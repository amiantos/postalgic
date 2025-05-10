//
//  AccentColorCustomizationView.swift
//  Postalgic
//
//  Created by Brad Root on 5/10/25.
//

import SwiftData
import SwiftUI

struct AccentColorCustomizationView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    var blog: Blog
    
    @State private var accentColor: Color
    @State private var colorHex: String
    
    // Sample text for previewing
    private let sampleText = "This is what text looks like on your blog, and this is a link to demonstrate how it looks."
    
    init(blog: Blog) {
        self.blog = blog
        
        // Initialize with the blog's accent color or the default
        let colorString = blog.accentColor ?? "#FFA100"
        _colorHex = State(initialValue: colorString)
        _accentColor = State(initialValue: Color(hex: colorString) ?? .orange)
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                // Color picker
                ColorPicker("Select Accent Color", selection: $accentColor)
                    .padding()
                    .onChange(of: accentColor) { _, newValue in
                        colorHex = newValue.toHex() ?? "#FFA100"
                    }
                
                // Hex code input
                HStack {
                    Text("Hex Color: ")
                    TextField("Hex Color Code", text: $colorHex)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .onChange(of: colorHex) { _, newValue in
                            // Only update the color picker if the hex is valid
                            if let color = Color(hex: newValue) {
                                accentColor = color
                            }
                        }
                }
                .padding()
                
                Divider()
                
                // Preview section
                VStack(alignment: .leading, spacing: 15) {
                    Text("Preview")
                        .font(.headline)
                    
                    // Header separator preview
                    Text("Header Separator:")
                        .font(.subheadline)
                    
                    headerSeparatorPreview
                        .frame(height: 28)
                        .padding(.vertical, 5)
                    
                    // Link preview
                    Text("Link Style:")
                        .font(.subheadline)
                    
                    Text(sampleText)
                        .environment(\.openURL, OpenURLAction { url in
                            return .handled
                        })
                }
                .padding()
                .background(Color(hex: "#efefef") ?? .gray.opacity(0.1))
                .cornerRadius(10)
                
                Spacer()
            }
            .padding()
            .navigationTitle("Customize Accent Color")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveAccentColor()
                    }
                }
            }
        }
    }
    
    // Custom view for the wavy header separator preview
    private var headerSeparatorPreview: some View {
        GeometryReader { geometry in
            ZStack {
                // Wavy line pattern background
                Rectangle()
                    .fill(Color(hex: "#efefef") ?? Color.gray.opacity(0.1))
                    .frame(height: 28)
                
                // This represents the wavy line but with accent color
                Rectangle()
                    .fill(accentColor)
                    .frame(height: 28)
                    .mask(
                        Image(systemName: "waveform")
                            .resizable()
                            .scaledToFit()
                            .padding(.horizontal)
                    )
            }
        }
    }
    
    // Save the selected accent color to the blog model
    private func saveAccentColor() {
        blog.accentColor = colorHex
        try? modelContext.save()
        dismiss()
    }
}

// Helper extensions for color conversion
extension Color {
    init?(hex: String) {
        var hexString = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexString = hexString.replacingOccurrences(of: "#", with: "")
        
        var rgb: UInt64 = 0
        
        guard Scanner(string: hexString).scanHexInt64(&rgb) else {
            return nil
        }
        
        let r = Double((rgb & 0xFF0000) >> 16) / 255.0
        let g = Double((rgb & 0x00FF00) >> 8) / 255.0
        let b = Double(rgb & 0x0000FF) / 255.0
        
        self.init(red: r, green: g, blue: b)
    }
    
    func toHex() -> String? {
        guard let components = UIColor(self).cgColor.components else {
            return nil
        }
        
        let r = Float(components[0])
        let g = Float(components[1])
        let b = Float(components[2])
        
        return String(format: "#%02lX%02lX%02lX", lroundf(r * 255), lroundf(g * 255), lroundf(b * 255))
    }
}

#Preview {
    let modelContainer = PreviewData.previewContainer
    
    return AccentColorCustomizationView(
        blog: try! modelContainer.mainContext.fetch(FetchDescriptor<Blog>())
            .first!
    )
    .modelContainer(modelContainer)
}