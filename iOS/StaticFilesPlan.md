# Static Files Feature Implementation Plan

## Overview
Add a comprehensive Static Files management system to Postalgic that allows users to upload and manage custom files for their static sites, including special handling for favicons and social share images.

## 1. Data Model Implementation

### StaticFile Model
Create a new SwiftData model with the following properties:
- `id: UUID` - Primary identifier
- `filename: String` - File path/name (can include "/" for directories)
- `data: Data` - File content stored with external storage
- `mimeType: String` - File MIME type for proper serving
- `isSpecialFile: Bool` - Flag for favicon/social share images
- `specialFileType: SpecialFileType?` - Enum for favicon/social share
- `createdAt: Date` - Creation timestamp
- `blog: Blog` - Parent relationship

### SpecialFileType Enum
```swift
enum SpecialFileType: String, CaseIterable, Codable {
    case favicon = "favicon.ico"
    case socialShareImage = "social-share.png"
}
```

### Blog Model Updates
Add relationship to Blog model:
- `staticFiles: [StaticFile]` with cascade delete

## 2. User Interface Implementation

### StaticFilesView (Main Management View)
- **Navigation**: Add button in BlogSettingsView → "Static Files" section
- **List Display**: Show all static files with filename, type, and size
- **Actions**: Add, edit filename, delete files
- **Special Files**: Dedicated sections/indicators for favicon and social share image
- **File Preview**: Show thumbnails for images, icons for other file types

### StaticFileFormView (Add/Edit Files)
- **File Source Selection**: Photos app vs Files app picker
- **Filename Input**: Text field with validation (uniqueness, valid characters)
- **Directory Support**: Allow "/" in filenames for nested structure
- **Preview**: Show selected file preview before saving
- **Validation**: Check filename uniqueness and format

### Special File Quick Actions
- **Add Favicon Button**: Direct action with predefined filename "favicon.ico"
- **Add Social Share Image Button**: Direct action with predefined filename "social-share.png"
- **Override Handling**: Replace existing special files with confirmation

## 3. File Management System

### File Validation
- **Filename Uniqueness**: Within each blog's static files
- **Path Validation**: Ensure valid directory structure
- **File Size Limits**: Reasonable limits for mobile storage
- **MIME Type Detection**: Automatic detection from file data

### File Operations
- **Import from Photos**: Use PHPickerViewController for image selection
- **Import from Files**: Use UIDocumentPickerViewController for any file type
- **Export/Share**: Allow users to export files back to Files app
- **Duplicate Detection**: Prevent duplicate filenames

## 4. Static Site Generation Integration

### File Organization
- **Output Structure**: Maintain directory structure in generated site
- **Root Placement**: Files go to site root (or specified subdirectories)
- **Asset Handling**: Include static files alongside existing assets

### Special File Integration
- **Favicon**: Automatically add `<link rel="icon" href="/favicon.ico">` to HTML head if favicon exists
- **Social Share Image**: Add Open Graph and Twitter Card meta tags:
  ```html
  <meta property="og:image" content="/social-share.png">
  <meta name="twitter:image" content="/social-share.png">
  ```

### Publisher Integration
- **File Tracking**: Add static files to PublishedFile tracking system
- **Change Detection**: Use content hashing to detect file changes
- **Efficient Uploads**: Only upload changed static files

## 5. Implementation Steps

### Phase 1: Data Model (Priority: High)
1. Create StaticFile model in Models.swift
2. Add SpecialFileType enum
3. Update Blog model with staticFiles relationship
4. Test model relationships and data persistence

### Phase 2: Core Views (Priority: High)
1. Create StaticFilesView with basic list and navigation
2. Implement StaticFileFormView with file picker integration
3. Add navigation from BlogSettingsView
4. Implement basic CRUD operations

### Phase 3: File Operations (Priority: Medium)
1. Integrate PHPickerViewController for Photos
2. Integrate UIDocumentPickerViewController for Files
3. Add file validation and error handling
4. Implement filename uniqueness checking

### Phase 4: Special Files (Priority: Medium)
1. Add dedicated Add Favicon button with auto-filename
2. Add dedicated Add Social Share Image button with auto-filename
3. Implement special file replacement confirmation
4. Add visual indicators for special files in list

### Phase 5: Static Site Integration (Priority: High)
1. Update StaticSiteGenerator to include static files
2. Implement special file HTML head injection
3. Update all publisher types to handle static files
4. Test end-to-end file publishing

### Phase 6: Polish & Testing (Priority: Low)
1. Add file size display and management
2. Implement file preview capabilities
3. Add export/share functionality
4. Comprehensive testing across all publishers

## 6. Technical Considerations

### File Storage
- Use SwiftData's `@Attribute(.externalStorage)` for efficient large file handling
- Consider compression for certain file types
- Implement proper cleanup when files are deleted

### Performance
- Lazy loading for file previews
- Efficient file size calculations
- Minimal memory footprint for large files

### Error Handling
- File import failures
- Network errors during publishing
- File corruption detection
- Storage quota management

### Security
- File type validation to prevent malicious uploads
- Filename sanitization to prevent directory traversal
- Size limits to prevent abuse

## 7. User Experience Flow

### Adding Regular Files
1. Navigate to Static Files from Blog Settings
2. Tap "Add File" button
3. Choose source (Photos or Files)
4. Select file and enter filename
5. Save and see file in list

### Adding Special Files
1. Navigate to Static Files from Blog Settings
2. Tap "Add Favicon" or "Add Social Share Image"
3. Choose source (Photos or Files)
4. File automatically named correctly
5. Confirmation if replacing existing special file

### Publishing Integration
1. Static files automatically included in site generation
2. Special files add appropriate HTML meta tags
3. Only changed files uploaded to save bandwidth
4. Clear indication of published file status

## 8. Testing Strategy

### Unit Tests
- StaticFile model validation
- Filename uniqueness checking
- MIME type detection
- Special file type handling

### Integration Tests
- File picker integration
- Static site generation with files
- Publisher upload verification
- SwiftData relationship integrity

### User Testing
- File management workflow
- Special file setup ease
- Publishing verification
- Error handling clarity

This plan provides a comprehensive roadmap for implementing the Static Files feature while maintaining consistency with existing Postalgic patterns and architecture.