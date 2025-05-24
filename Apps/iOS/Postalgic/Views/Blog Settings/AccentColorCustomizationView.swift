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
    @State private var backgroundColor: Color
    @State private var textColor: Color
    @State private var lightShade: Color
    @State private var mediumShade: Color
    @State private var darkShade: Color
    @State private var htmlPreview: String = ""
    
    init(blog: Blog) {
        self.blog = blog
        let accentColorString = blog.accentColor ?? "#FFA100"
        _accentColor = State(initialValue: Color(hex: accentColorString) ?? .orange)
        
        let backgroundColorString = blog.backgroundColor ?? "#efefef"
        _backgroundColor = State(initialValue: Color(hex: backgroundColorString) ?? Color(hex: "#efefef")!)
        
        let textColorString = blog.textColor ?? "#2d3748"
        _textColor = State(initialValue: Color(hex: textColorString) ?? Color(hex: "#2d3748")!)
        
        let lightShadeString = blog.lightShade ?? "#dedede"
        _lightShade = State(initialValue: Color(hex: lightShadeString) ?? Color(hex: "#dedede")!)
        
        let mediumShadeString = blog.mediumShade ?? "#a0aec0"
        _mediumShade = State(initialValue: Color(hex: mediumShadeString) ?? Color(hex: "#a0aec0")!)
        
        let darkShadeString = blog.darkShade ?? "#4a5568"
        _darkShade = State(initialValue: Color(hex: darkShadeString) ?? Color(hex: "#4a5568")!)
    }
    
    var body: some View {
        NavigationStack {
            List {
                Section("Theme Colors") {
                    ColorPicker("Accent Color", selection: $accentColor, supportsOpacity: false)
                    ColorPicker("Background Color", selection: $backgroundColor, supportsOpacity: false)
                    ColorPicker("Text Color", selection: $textColor, supportsOpacity: false)
                    ColorPicker("Light Shade", selection: $lightShade, supportsOpacity: false)
                    ColorPicker("Medium Shade", selection: $mediumShade, supportsOpacity: false)
                    ColorPicker("Dark Shade", selection: $darkShade, supportsOpacity: false)
                }
                
                Section("Default Template Preview") {
                    WebView(htmlString: htmlPreview)
                        .frame(height: 380)
                        .cornerRadius(10)
                }
            }
            .onAppear {
                updatePreviewHTML()
            }
            .onChange(of: accentColor, initial: false, { oldValue, newValue in
                updatePreviewHTML()
            })
            .onChange(of: backgroundColor, initial: false, { oldValue, newValue in
                updatePreviewHTML()
            })
            .onChange(of: textColor, initial: false, { oldValue, newValue in
                updatePreviewHTML()
            })
            .onChange(of: lightShade, initial: false, { oldValue, newValue in
                updatePreviewHTML()
            })
            .onChange(of: mediumShade, initial: false, { oldValue, newValue in
                updatePreviewHTML()
            })
            .onChange(of: darkShade, initial: false, { oldValue, newValue in
                updatePreviewHTML()
            })
            .navigationTitle("Customize Colors")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button("Reset to Default") {
                            resetToDefaultColors()
                        }
                        Button("Reset to Dark Mode") {
                            resetToDarkMode()
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveColors()
                    }
                }
            }
        }
    }
    
    // Generate HTML preview with current colors
    private func updatePreviewHTML() {
        guard let accentHex = accentColor.toHex(),
              let backgroundHex = backgroundColor.toHex(),
              let textHex = textColor.toHex(),
              let lightHex = lightShade.toHex(),
              let mediumHex = mediumShade.toHex(),
              let darkHex = darkShade.toHex() else { return }
        
        // Include a timestamp in CSS to force WebView refresh
        let timestamp = Date().timeIntervalSince1970
        
        htmlPreview = """
        <!DOCTYPE html>
        <html>
        <head>
            <meta name="viewport" content="width=device-width, initial-scale=1">
            <style data-timestamp="\(timestamp)">
                :root {
                    --accent-color: \(accentHex);
                    --background-color: \(backgroundHex);
                    --text-color: \(textHex);
                    --light-shade: \(lightHex);
                    --medium-shade: \(mediumHex);
                    --dark-shade: \(darkHex);
                }

                body {
                    font-family: -apple-system, BlinkMacSystemFont, sans-serif;
                    background-color: var(--background-color);
                    color: var(--text-color);
                    padding: 12px;
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
        
                .category, .tag {
                    display: inline-block;
                    margin-right:5px;
                }

                .category a {
                    display: inline-block;
                    color: white;
                    background-color: var(--accent-color);
                    border: 1px solid var(--accent-color);
                    padding: 3px 8px;
                    border-radius: 1em;
                    font-size: 0.8em;
                }
        
                .tag a {
                    display: inline-block;
                    color: var(--accent-color);
                    background-color: var(--background-color);
                    border: 1px solid var(--accent-color);
                    padding: 3px 8px;
                    border-radius: 1em;
                    font-size: 0.8em;
                }

                .section {
                    margin-bottom: 20px;
                }

                h3 {
                    margin-bottom: 8px;
                    color: var(--dark-shade);
                }
        
                h2 {
                    color: var(--text-color);
                    font-size: 1.5em;
                    font-weight: bold;
                    margin-bottom:0px;
                    margin-top:10px;
                }
        
                .post-date {
                    color: var(--medium-shade);
                    font-size: 0.9em;
                    display: inline-block;
                    margin-top:0px;
                }
        
                .menu-button {
                    display: block;
                    padding: 8px 0;
                    font-weight: 600;
                    font-size: 1.1rem;
                    color: var(--dark-shade);
                    text-decoration:none;
                }
        
                .menu-sample {
                    margin-bottom: 25px;
                    border-bottom: 1px solid var(--light-shade);
                }
            </style>
        </head>
        <body>
            <div class="section">
                <h2>Example Post Title</h2>
                <div class="post-date">May 24, 2025 at 1:50 AM</div>
                
                <p>This is regular text on your blog, and <a href="#">this is a link</a> to demonstrate how the accent color looks.</p>
                <div class="category"><a href="#">Category Name</a></div>
                <div class="tag"><a href="#">#tag name</a></div>
                <div class="header-separator"></div>
                <div class="menu-sample">
                    <a class="menu-button">Menu Nav Item</a>
                </div>
            </div>
        </body>
        </html>
        """
    }
    
    // Reset all colors to their default values
    private func resetToDefaultColors() {
        accentColor = Color(hex: "#FFA100")!
        backgroundColor = Color(hex: "#efefef")!
        textColor = Color(hex: "#2d3748")!
        lightShade = Color(hex: "#dedede")!
        mediumShade = Color(hex: "#a0aec0")!
        darkShade = Color(hex: "#4a5568")!
    }
    
    // Reset to dark mode colors (reversed shades, keep accent color)
    private func resetToDarkMode() {
        accentColor = Color(hex: "#FFA100")! // Keep the same accent color
        backgroundColor = Color(hex: "#1a202c")! // Dark background
        textColor = Color(hex: "#e2e8f0")! // Light text
        lightShade = Color(hex: "#2d3748")! // Reversed: was dark, now light shade
        mediumShade = Color(hex: "#4a5568")! // Reversed: was medium, stays medium-dark
        darkShade = Color(hex: "#cbd5e0")! // Reversed: was light, now dark shade
    }
    
    // Save all selected colors to the blog model
    private func saveColors() {
        guard let accentHex = accentColor.toHex(),
              let backgroundHex = backgroundColor.toHex(),
              let textHex = textColor.toHex(),
              let lightHex = lightShade.toHex(),
              let mediumHex = mediumShade.toHex(),
              let darkHex = darkShade.toHex() else { return }
        
        blog.accentColor = accentHex
        blog.backgroundColor = backgroundHex
        blog.textColor = textHex
        blog.lightShade = lightHex
        blog.mediumShade = mediumHex
        blog.darkShade = darkHex
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
