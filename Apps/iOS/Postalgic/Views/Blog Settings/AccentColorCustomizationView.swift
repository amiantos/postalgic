//
//  AccentColorCustomizationView.swift
//  Postalgic
//
//  Created by Brad Root on 5/10/25.
//

import SwiftData
import SwiftUI
import WebKit

struct AccentColorCustomizationView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    var blog: Blog
    
    @State private var accentColor: Color
    @State private var colorHex: String
    @State private var htmlPreview: String = ""
    
    init(blog: Blog) {
        self.blog = blog
        
        // Initialize with the blog's accent color or the default
        let colorString = blog.accentColor ?? "#FFA100"
        _colorHex = State(initialValue: colorString)
        _accentColor = State(initialValue: Color(hex: colorString) ?? .orange)
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Color picker - no onChange handler to avoid glitches
                    ColorPicker("Select Accent Color", selection: $accentColor)
                        .padding()
                    
                    // Hex code input
                    HStack {
                        Text("Hex Color: ")
                        TextField("Hex Color Code", text: $colorHex)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                            .onSubmit {
                                if let color = Color(hex: colorHex) {
                                    accentColor = color
                                } else {
                                    // Invalid hex, revert to color picker's hex
                                    colorHex = accentColor.toHex() ?? "#FFA100"
                                }
                            }
                    }
                    .padding()
                    
                    Divider()
                    
                    // Update Preview Button
                    Button(action: {
                        // Update hex from color picker
                        colorHex = accentColor.toHex() ?? "#FFA100"
                        updatePreviewHTML()
                    }) {
                        Label("Update Preview", systemImage: "arrow.clockwise")
                    }
                    .buttonStyle(.bordered)
                    .padding(.bottom)
                    
                    // Preview section with WebView
                    VStack(alignment: .leading) {
                        Text("Preview")
                            .font(.headline)
                            .padding(.horizontal)
                        
                        WebView(htmlString: htmlPreview)
                            .frame(height: 400)
                            .cornerRadius(10)
                            .padding(.horizontal)
                    }
                    
                    Spacer()
                }
                .padding(.vertical)
                .onAppear {
                    colorHex = accentColor.toHex() ?? "#FFA100"
                    updatePreviewHTML()
                }
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
                            // Update hex from color picker one last time
                            colorHex = accentColor.toHex() ?? "#FFA100"
                            saveAccentColor()
                        }
                    }
                }
            }
        }
    }
    
    // Generate HTML preview with current accent color
    private func updatePreviewHTML() {
        // Make sure hex has # prefix
        var safeHex = colorHex.trimmingCharacters(in: .whitespacesAndNewlines)
        if !safeHex.hasPrefix("#") {
            safeHex = "#" + safeHex
        }
        
        // Include a timestamp in CSS to force WebView refresh
        let timestamp = Date().timeIntervalSince1970
        
        htmlPreview = """
        <!DOCTYPE html>
        <html>
        <head>
            <meta name="viewport" content="width=device-width, initial-scale=1">
            <style data-timestamp="\(timestamp)">
                :root {
                    --primary-color: #4a5568;
                    --accent-color: \(safeHex);
                    --background-color: #efefef;
                    --text-color: #2d3748;
                    --light-gray: #dedede;
                    --medium-gray: #a0aec0;
                    --category-color: \(safeHex);
                }

                body {
                    font-family: -apple-system, BlinkMacSystemFont, sans-serif;
                    background-color: var(--background-color);
                    color: var(--text-color);
                    padding: 20px;
                    line-height: 1.6;
                }

                a {
                    color: var(--accent-color);
                    text-decoration: none;
                }

                .header-separator {
                    height: 28px;
                    width: 100%;
                    background-color: var(--accent-color);
                    --mask:
                      radial-gradient(10.96px at 50% calc(100% + 5.6px),#0000 calc(99% - 4px),#000 calc(101% - 4px) 99%,#0000 101%) calc(50% - 14px) calc(50% - 5.5px + .5px)/28px 11px repeat-x,
                      radial-gradient(10.96px at 50% -5.6px,#0000 calc(99% - 4px),#000 calc(101% - 4px) 99%,#0000 101%) 50% calc(50% + 5.5px)/28px 11px repeat-x;
                    -webkit-mask: var(--mask);
                    mask: var(--mask);
                    margin: 15px 0;
                }

                .category a {
                    display: inline-block;
                    color: white;
                    background-color: var(--category-color);
                    border: 1px solid var(--category-color);
                    padding: 3px 8px;
                    border-radius: 1em;
                    font-size: 0.8em;
                }

                .section {
                    margin-bottom: 20px;
                }

                h3 {
                    margin-bottom: 8px;
                    color: var(--primary-color);
                }
            </style>
        </head>
        <body>
            <div class="section">
                <h3>Header Separator</h3>
                <div class="header-separator"></div>
            </div>

            <div class="section">
                <h3>Text with Link</h3>
                <p>This is regular text on your blog, and <a href="#">this is a link</a> to demonstrate how the accent color looks.</p>
            </div>
            
            <div class="section">
                <h3>Category Tag</h3>
                <div class="category"><a href="#">Category Name</a></div>
            </div>
        </body>
        </html>
        """
    }
    
    // Save the selected accent color to the blog model
    private func saveAccentColor() {
        // Clean up the hex value before saving
        var safeHex = colorHex.trimmingCharacters(in: .whitespacesAndNewlines)
        if !safeHex.hasPrefix("#") {
            safeHex = "#" + safeHex
        }
        
        blog.accentColor = safeHex
        try? modelContext.save()
        dismiss()
    }
}

// WebView for rendering HTML preview
struct WebView: UIViewRepresentable {
    let htmlString: String
    
    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.isOpaque = false
        webView.backgroundColor = UIColor.clear
        webView.scrollView.backgroundColor = UIColor.clear
        return webView
    }
    
    func updateUIView(_ webView: WKWebView, context: Context) {
        webView.loadHTMLString(htmlString, baseURL: nil)
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
