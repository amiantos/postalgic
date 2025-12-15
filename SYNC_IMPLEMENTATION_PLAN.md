# Postalgic Sync Implementation Plan

## Overview

Enable bidirectional sync between the iOS app and Self-Hosted app using the published website as "cloud storage". When a site is published, a `/sync/` directory containing blog data is uploaded alongside the HTML site. Either app can import from a URL or sync changes.

**Key Design Principle**: Use granular files for incremental sync. Only drafts are encrypted since all other content is already public on the website.

## Architecture

```
┌─────────────┐         ┌──────────────────────┐         ┌─────────────────┐
│   iOS App   │ ──────► │   Published Website  │ ◄────── │ Self-Hosted App │
│             │         │                      │         │                 │
│  - Create   │         │  /index.html         │         │  - Create       │
│  - Edit     │         │  /posts/...          │         │  - Edit         │
│  - Publish  │         │  /rss.xml            │         │  - Publish      │
│  - Sync     │         │  /sync/              │ ◄────── │  - Sync         │
│             │ ◄────── │    manifest.json     │         │                 │
└─────────────┘         │    blog.json         │         └─────────────────┘
                        │    posts/*.json      │
                        │    drafts/*.json.enc │
                        │    images/*          │
                        └──────────────────────┘
```

---

## Sync Directory Structure

When publishing, generate a `/sync/` directory with granular files:

```
/sync/
├── manifest.json              # Version info + checksums for ALL files
├── blog.json                  # Blog settings (unencrypted - public anyway)
├── posts/
│   ├── index.json             # List of post IDs with hashes
│   ├── {uuid}.json            # Individual published post
│   └── ...
├── drafts/
│   ├── index.json.enc         # Encrypted list of draft IDs
│   ├── {uuid}.json.enc        # Encrypted individual draft
│   └── ...
├── categories/
│   ├── index.json             # List of category IDs
│   └── {uuid}.json            # Individual category
├── tags/
│   ├── index.json             # List of tag IDs
│   └── {uuid}.json            # Individual tag
├── sidebar/
│   ├── index.json             # List of sidebar object IDs
│   └── {uuid}.json            # Individual sidebar object
├── static-files/
│   ├── index.json             # Metadata (filename, mime, special type)
│   ├── favicon.png            # Actual binary files
│   ├── social-share.png
│   └── ...
├── embed-images/
│   ├── index.json             # List of images with hashes
│   ├── {filename}             # Actual image files
│   └── ...
└── themes/
    └── {identifier}.json      # Custom theme (if any)
```

---

## File Formats

### manifest.json

The manifest contains checksums for every file, enabling incremental sync.

```json
{
  "version": "1.0",
  "syncVersion": 42,
  "lastModified": "2025-01-15T12:00:00.000Z",
  "appSource": "ios",
  "appVersion": "1.2.3",
  "blogName": "My Blog",
  "hasDrafts": true,
  "encryption": {
    "method": "aes-256-gcm",
    "salt": "base64-encoded-salt",
    "iterations": 100000
  },
  "files": {
    "blog.json": {
      "hash": "sha256...",
      "size": 1024,
      "modified": "2025-01-15T12:00:00.000Z"
    },
    "posts/index.json": {
      "hash": "sha256...",
      "size": 256
    },
    "posts/abc123-def456.json": {
      "hash": "sha256...",
      "size": 2048,
      "modified": "2025-01-14T10:00:00.000Z"
    },
    "drafts/index.json.enc": {
      "hash": "sha256...",
      "size": 128,
      "encrypted": true
    },
    "drafts/ghi789-jkl012.json.enc": {
      "hash": "sha256...",
      "size": 512,
      "encrypted": true,
      "iv": "base64-encoded-iv"
    },
    "embed-images/photo-abc123.jpg": {
      "hash": "sha256...",
      "size": 102400
    }
  }
}
```

### blog.json (Unencrypted)

Blog settings - already visible in CSS/HTML so no need to encrypt.

```json
{
  "name": "My Blog",
  "url": "https://myblog.com",
  "tagline": "A personal blog",
  "authorName": "Jane Doe",
  "authorUrl": "https://janedoe.com",
  "authorEmail": "jane@example.com",
  "timezone": "America/New_York",
  "colors": {
    "accent": "#007AFF",
    "background": "#FFFFFF",
    "text": "#000000",
    "lightShade": "#F5F5F5",
    "mediumShade": "#CCCCCC",
    "darkShade": "#333333"
  },
  "themeIdentifier": "default"
}
```

### posts/index.json

Index of all published posts for quick lookup.

```json
{
  "posts": [
    {
      "id": "abc123-def456",
      "stub": "my-first-post",
      "hash": "sha256...",
      "modified": "2025-01-15T12:00:00.000Z"
    },
    {
      "id": "mno345-pqr678",
      "stub": "another-post",
      "hash": "sha256...",
      "modified": "2025-01-14T08:00:00.000Z"
    }
  ]
}
```

### posts/{uuid}.json (Unencrypted)

Individual post - content is already public on the website.

```json
{
  "id": "abc123-def456",
  "title": "My First Post",
  "content": "# Hello World\n\nThis is my first post.",
  "stub": "my-first-post",
  "createdAt": "2025-01-15T12:00:00.000Z",
  "updatedAt": "2025-01-15T14:30:00.000Z",
  "categoryId": "cat-uuid",
  "tagIds": ["tag-uuid-1", "tag-uuid-2"],
  "embed": {
    "type": "image",
    "position": "above",
    "images": [
      { "filename": "photo-abc123.jpg", "order": 0 }
    ]
  }
}
```

### drafts/index.json.enc (Encrypted)

Encrypted list of draft IDs.

```json
{
  "drafts": [
    {
      "id": "draft-uuid-1",
      "hash": "sha256...",
      "modified": "2025-01-15T16:00:00.000Z"
    }
  ]
}
```

### drafts/{uuid}.json.enc (Encrypted)

Encrypted individual draft - same structure as posts but encrypted.

```json
{
  "id": "draft-uuid-1",
  "title": "Work in Progress",
  "content": "# Draft\n\nThis is not ready yet...",
  "stub": "work-in-progress",
  "createdAt": "2025-01-15T16:00:00.000Z",
  "updatedAt": "2025-01-15T18:00:00.000Z",
  "categoryId": null,
  "tagIds": [],
  "embed": null
}
```

### categories/{uuid}.json

```json
{
  "id": "cat-uuid",
  "name": "Technology",
  "description": "Posts about tech",
  "stub": "technology",
  "createdAt": "2025-01-01T00:00:00.000Z"
}
```

### tags/{uuid}.json

```json
{
  "id": "tag-uuid-1",
  "name": "swift",
  "stub": "swift",
  "createdAt": "2025-01-01T00:00:00.000Z"
}
```

### sidebar/{uuid}.json

```json
{
  "id": "sidebar-uuid",
  "type": "text",
  "title": "About",
  "content": "Welcome to my blog!",
  "order": 0
}
```

Or for link lists:

```json
{
  "id": "sidebar-uuid-2",
  "type": "linkList",
  "title": "Links",
  "order": 1,
  "links": [
    { "title": "GitHub", "url": "https://github.com/me", "order": 0 },
    { "title": "Twitter", "url": "https://twitter.com/me", "order": 1 }
  ]
}
```

### static-files/index.json

```json
{
  "files": [
    {
      "filename": "favicon.png",
      "mimeType": "image/png",
      "isSpecialFile": true,
      "specialFileType": "favicon",
      "hash": "sha256...",
      "size": 4096
    },
    {
      "filename": "social-share.png",
      "mimeType": "image/png",
      "isSpecialFile": true,
      "specialFileType": "socialShare",
      "hash": "sha256...",
      "size": 51200
    }
  ]
}
```

### themes/{identifier}.json

```json
{
  "identifier": "custom-theme",
  "name": "My Custom Theme",
  "templates": {
    "index": "<!DOCTYPE html>...",
    "post": "<!DOCTYPE html>...",
    "tag": "<!DOCTYPE html>...",
    "category": "<!DOCTYPE html>...",
    "archives": "<!DOCTYPE html>..."
  }
}
```

---

## Encryption Specification

Only files in the `/drafts/` directory are encrypted.

### Key Derivation

- **Algorithm**: PBKDF2 with SHA-256
- **Iterations**: 100,000
- **Salt**: 16 random bytes (stored in manifest, shared for all drafts)
- **Key Length**: 32 bytes (256 bits)

### Encryption

- **Algorithm**: AES-256-GCM
- **IV**: 12 random bytes (unique per file, stored in manifest)
- **Tag Length**: 16 bytes (128 bits)
- **Output**: Ciphertext + Auth Tag (concatenated)

### Implementation

**iOS (CryptoKit)**:
```swift
import CryptoKit
import CommonCrypto

func deriveKey(password: String, salt: Data) -> SymmetricKey {
    var derivedKey = Data(count: 32)
    derivedKey.withUnsafeMutableBytes { derivedKeyBytes in
        password.data(using: .utf8)!.withUnsafeBytes { passwordBytes in
            salt.withUnsafeBytes { saltBytes in
                CCKeyDerivationPBKDF(
                    CCPBKDFAlgorithm(kCCPBKDF2),
                    passwordBytes.baseAddress, password.utf8.count,
                    saltBytes.baseAddress, salt.count,
                    CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA256),
                    100_000,
                    derivedKeyBytes.baseAddress, 32
                )
            }
        }
    }
    return SymmetricKey(data: derivedKey)
}

func encrypt(data: Data, key: SymmetricKey) throws -> (ciphertext: Data, iv: Data) {
    let nonce = AES.GCM.Nonce()
    let sealedBox = try AES.GCM.seal(data, using: key, nonce: nonce)
    return (sealedBox.ciphertext + sealedBox.tag, Data(nonce))
}

func decrypt(ciphertext: Data, iv: Data, key: SymmetricKey) throws -> Data {
    let nonce = try AES.GCM.Nonce(data: iv)
    let tag = ciphertext.suffix(16)
    let encrypted = ciphertext.dropLast(16)
    let sealedBox = try AES.GCM.SealedBox(nonce: nonce, ciphertext: encrypted, tag: tag)
    return try AES.GCM.open(sealedBox, using: key)
}
```

**Self-Hosted (Node.js crypto)**:
```javascript
const crypto = require('crypto');

function deriveKey(password, salt) {
  return crypto.pbkdf2Sync(password, salt, 100000, 32, 'sha256');
}

function encrypt(data, key) {
  const iv = crypto.randomBytes(12);
  const cipher = crypto.createCipheriv('aes-256-gcm', key, iv);
  const encrypted = Buffer.concat([cipher.update(data), cipher.final()]);
  const tag = cipher.getAuthTag();
  return { ciphertext: Buffer.concat([encrypted, tag]), iv };
}

function decrypt(ciphertext, iv, key) {
  const tag = ciphertext.slice(-16);
  const encrypted = ciphertext.slice(0, -16);
  const decipher = crypto.createDecipheriv('aes-256-gcm', key, iv);
  decipher.setAuthTag(tag);
  return Buffer.concat([decipher.update(encrypted), decipher.final()]);
}
```

---

## Sync Operations

### 1. Import from URL (First Time)

**Flow**:
1. User enters published site URL (e.g., `https://myblog.com`)
2. App fetches `https://myblog.com/sync/manifest.json`
3. If `hasDrafts: true`, prompt for sync password
4. Download all files listed in manifest:
   - Compare with empty local state (download everything)
   - Decrypt draft files using password
5. Create blog with all imported data
6. Store sync URL and password (in Keychain/secure storage)

**UI**: "Import from URL" → URL input → Password (if drafts) → Progress bar

### 2. Sync Down (Pull Changes)

**Flow**:
1. Fetch remote `manifest.json`
2. Compare `syncVersion` with local `lastSyncedVersion`
3. If remote is newer or files differ:
   a. Compare file hashes in manifest with local hashes
   b. Download only files with different hashes
   c. For encrypted files, decrypt using stored password
   d. Merge using "last modified wins" strategy
   e. Update local `lastSyncedVersion`
4. If local is equal or newer: No downloads needed

**Incremental Sync Example**:
```
Remote manifest.files:
  - blog.json: hash=aaa (unchanged)
  - posts/post1.json: hash=bbb (unchanged)
  - posts/post2.json: hash=ccc (CHANGED - was ddd)
  - posts/post3.json: hash=eee (NEW)
  - drafts/draft1.json.enc: hash=fff (unchanged)

Local hashes:
  - blog.json: hash=aaa
  - posts/post1.json: hash=bbb
  - posts/post2.json: hash=ddd  ← different!
  - drafts/draft1.json.enc: hash=fff

Result: Download only posts/post2.json and posts/post3.json (2 files, not 5)
```

### 3. Publish with Sync (Push Changes)

**Flow**:
1. Before publishing, sync down first (pull any remote changes)
2. Generate site HTML as usual
3. Generate sync directory:
   a. Create/update all JSON files
   b. Encrypt draft files with password
   c. Calculate hashes for all files
   d. Generate new manifest with incremented `syncVersion`
4. Upload both HTML site and `/sync/` directory
5. Update local `lastSyncedVersion` and hashes

### 4. Conflict Resolution (Last Modified Wins)

When both local and remote have changes to the same item:

```
Local post updated: 2025-01-15T14:00:00Z
Remote post updated: 2025-01-15T16:00:00Z
→ Remote wins (more recent)

Local post updated: 2025-01-15T18:00:00Z
Remote post updated: 2025-01-15T16:00:00Z
→ Local wins (more recent)
```

**Deletion Handling**:
- If remote manifest doesn't have an item that local has:
  - Check if remote `syncVersion` > local `lastSyncedVersion`
  - If yes: Item was deleted remotely → delete locally
  - If no: Item is new locally → keep it

### 5. Auto-Sync Triggers

**iOS App**:
- When opening a blog with sync enabled (sync down in background)
- Before publishing (sync down, then push)
- Manual "Sync Now" button
- Pull-to-refresh in blog view

**Self-Hosted App**:
- When loading blog editor (sync down in background)
- Before publishing (sync down, then push)
- Manual "Sync Now" button

---

## Sync Performance Comparison

| Scenario | Old (Single Bundle) | New (Granular Files) |
|----------|---------------------|----------------------|
| Check if sync needed | Download manifest (~1KB) + data.enc (~50MB) | Download manifest only (~5KB) |
| First import (1000 posts, 500 images) | Download ~50MB bundle | Download ~50MB (parallel, resumable) |
| Sync after editing 1 post | Download ~50MB bundle | Download ~2KB (1 file) |
| Sync after adding 1 image | Download ~50MB bundle | Download ~100KB (1 file) |
| Sync with no changes | Download ~50MB bundle | Download ~5KB manifest, nothing else |

---

## Implementation Phases

### Phase 1: Sync Data Generation

**iOS Changes**:

1. **Add sync settings to Blog model** (`Models.swift`)
   ```swift
   // Add to Blog class
   var syncEnabled: Bool = false
   var lastSyncedVersion: Int = 0
   var lastSyncedAt: Date?
   var localFileHashes: [String: String] = [:]  // For tracking local state
   ```

2. **Add sync password to KeychainService** (`KeychainService.swift`)
   ```swift
   // Add to PasswordType enum
   case syncPassword = "syncPassword"
   ```

3. **Create SyncDataGenerator service** (new file: `Services/Sync/SyncDataGenerator.swift`)
   - Generate individual JSON files for each entity
   - Encrypt draft files
   - Calculate SHA-256 hashes
   - Generate manifest.json

4. **Create SyncEncryption helper** (new file: `Services/Sync/SyncEncryption.swift`)
   - Key derivation from password
   - Encrypt/decrypt functions
   - IV generation and management

5. **Modify StaticSiteGenerator** (`StaticSiteGenerator.swift`)
   - After generating HTML, call SyncDataGenerator
   - Only if `blog.syncEnabled == true`

**Self-Hosted Changes**:

1. **Add sync config to database** (`database.js`)
   ```sql
   CREATE TABLE IF NOT EXISTS sync_config (
     blog_id TEXT PRIMARY KEY,
     sync_enabled INTEGER DEFAULT 0,
     last_synced_version INTEGER DEFAULT 0,
     last_synced_at TEXT,
     local_file_hashes TEXT,  -- JSON object
     FOREIGN KEY (blog_id) REFERENCES blogs(id) ON DELETE CASCADE
   )
   ```

2. **Create syncGenerator service** (new file: `server/services/syncGenerator.js`)
   - Generate individual JSON files
   - Encrypt draft files
   - Calculate hashes
   - Generate manifest

3. **Create syncEncryption helper** (new file: `server/services/syncEncryption.js`)
   - Key derivation
   - Encrypt/decrypt functions

4. **Modify siteGenerator** (`siteGenerator.js`)
   - After generating HTML, call syncGenerator
   - Only if sync is enabled

### Phase 2: Import from URL

**iOS Changes**:

1. **Create SyncImporter service** (new file: `Services/Sync/SyncImporter.swift`)
   - Fetch manifest from URL
   - Download all files (with progress)
   - Decrypt drafts
   - Create blog and entities

2. **Create ImportFromURLView** (new file: `Views/Sync/ImportFromURLView.swift`)
   - URL input field
   - Password input (shown if hasDrafts)
   - Progress indicator
   - Error handling

3. **Add to BlogListView**
   - "Import from URL" button/menu option

**Self-Hosted Changes**:

1. **Create syncImporter service** (new file: `server/services/syncImporter.js`)
   - Fetch manifest and files
   - Decrypt drafts
   - Create database records

2. **Add sync routes** (new file: `server/routes/sync.js`)
   - `POST /api/sync/import` - Import from URL

3. **Create ImportFromURL component** (new file: `client/components/ImportFromURL.vue`)
   - URL and password inputs
   - Progress display

### Phase 3: Incremental Sync Down (Pull)

**iOS Changes**:

1. **Create SyncService** (new file: `Services/Sync/SyncService.swift`)
   - `checkForUpdates(blog:)` - Fetch manifest, compare versions
   - `syncDown(blog:)` - Download changed files only
   - `mergeChanges(local:remote:)` - Last modified wins
   - Track local file hashes for comparison

2. **Add sync UI to BlogDetailView**
   - Last synced timestamp
   - "Sync Now" button
   - Sync status indicator (up to date, syncing, changes available)

3. **Background sync on blog open**
   - Non-blocking sync check when viewing blog

**Self-Hosted Changes**:

1. **Create syncService** (new file: `server/services/syncService.js`)
   - `checkForUpdates(blogId)` - Compare with remote
   - `syncDown(blogId, password)` - Download and merge
   - Hash tracking and comparison

2. **Add sync API endpoints** (in `routes/sync.js`)
   - `GET /api/blogs/:blogId/sync/status` - Check sync status
   - `POST /api/blogs/:blogId/sync/pull` - Trigger sync down

3. **Add sync UI to blog editor**
   - Sync status indicator
   - Manual sync button

### Phase 4: Publish with Sync

**iOS Changes**:

1. **Modify publishing flow**
   - Sync down before publishing (if enabled)
   - Show sync status in publish progress
   - Generate sync directory during publish

2. **Update all publishers** to include `/sync/` directory:
   - `AWSPublisher.swift` - Upload sync files to S3
   - `SFTPPublisher.swift` - Upload sync files via SFTP
   - `GitPublisher.swift` - Commit sync files
   - `ManualPublisher.swift` - Include sync in ZIP download

**Self-Hosted Changes**:

1. **Modify publish routes** (`publish.js`)
   - Sync down before generating (if enabled)
   - Generate sync directory during publish

2. **Update all publishers**:
   - `publishers/s3Publisher.js`
   - `publishers/sftpPublisher.js`
   - `publishers/gitPublisher.js`

### Phase 5: UI Polish & Settings

**iOS Changes**:

1. **Create SyncSettingsView** (new file: `Views/Sync/SyncSettingsView.swift`)
   - Enable/disable sync toggle
   - Set/change sync password
   - View sync status and last synced time
   - Manual sync button
   - Clear sync data option

2. **Sync indicators in BlogListView**
   - Badge/icon for blogs with sync enabled
   - Last synced time in blog row

**Self-Hosted Changes**:

1. **Create SyncSettings component** (new file: `client/components/SyncSettings.vue`)
   - Enable/disable sync
   - Set sync password
   - View published URL for sharing

2. **Add sync section to BlogSettings.vue**
   - Sync configuration panel
   - Status display

---

## File Changes Summary

### iOS App - New Files

| File | Purpose |
|------|---------|
| `Services/Sync/SyncDataGenerator.swift` | Generate sync directory with individual files |
| `Services/Sync/SyncImporter.swift` | Import blog from sync URL |
| `Services/Sync/SyncService.swift` | Incremental sync operations |
| `Services/Sync/SyncEncryption.swift` | Encryption/decryption for drafts |
| `Views/Sync/ImportFromURLView.swift` | Import from URL UI |
| `Views/Sync/SyncSettingsView.swift` | Sync configuration UI |

### iOS App - Modified Files

| File | Changes |
|------|---------|
| `Models.swift` | Add sync properties to Blog model |
| `KeychainService.swift` | Add syncPassword type |
| `StaticSiteGenerator.swift` | Generate /sync/ directory |
| `AWSPublisher.swift` | Upload sync files |
| `SFTPPublisher.swift` | Upload sync files |
| `GitPublisher.swift` | Commit sync files |
| `ManualPublisher.swift` | Include sync in ZIP |
| `BlogListView.swift` | Add import from URL, sync indicators |
| `BlogDetailView.swift` | Add sync status/button |

### Self-Hosted App - New Files

| File | Purpose |
|------|---------|
| `server/services/syncGenerator.js` | Generate sync directory |
| `server/services/syncImporter.js` | Import from URL |
| `server/services/syncService.js` | Incremental sync operations |
| `server/services/syncEncryption.js` | Encryption/decryption |
| `server/routes/sync.js` | Sync API endpoints |
| `client/components/ImportFromURL.vue` | Import UI |
| `client/components/SyncSettings.vue` | Sync configuration |

### Self-Hosted App - Modified Files

| File | Changes |
|------|---------|
| `server/utils/database.js` | Add sync_config table |
| `server/utils/storage.js` | Add sync config CRUD |
| `server/services/siteGenerator.js` | Generate /sync/ directory |
| `server/services/publishers/*.js` | Upload sync files |
| `server/routes/blogs.js` | Add sync config to blog responses |
| `server/server.js` | Mount sync routes |
| `client/views/BlogSettings.vue` | Add sync settings section |

---

## API Endpoints (Self-Hosted)

### Sync Routes (`/api/sync`)

```
POST /api/sync/import
  Body: { url: string, password?: string }
  Response: { success: boolean, blogId: string, message: string }

GET /api/blogs/:blogId/sync/status
  Response: {
    enabled: boolean,
    lastSyncedAt: string | null,
    lastSyncedVersion: number,
    remoteVersion: number | null,
    hasChanges: boolean
  }

POST /api/blogs/:blogId/sync/enable
  Body: { password: string }
  Response: { success: boolean }

POST /api/blogs/:blogId/sync/disable
  Response: { success: boolean }

POST /api/blogs/:blogId/sync/pull
  Body: { password?: string }
  Response: {
    success: boolean,
    filesDownloaded: number,
    filesUpdated: string[],
    filesDeleted: string[]
  }

POST /api/blogs/:blogId/sync/password
  Body: { password: string }
  Response: { success: boolean }
```

---

## Security Considerations

1. **Minimal encryption** - Only drafts are encrypted; public content stays unencrypted
2. **Password never transmitted** - Used only locally for key derivation
3. **Unique IV per file** - Each encrypted file has its own IV stored in manifest
4. **Salt shared per blog** - One salt for all drafts, regenerated on password change
5. **No credentials in sync** - Publisher credentials (AWS, SFTP, Git) stay local
6. **HTTPS required** - Sync URLs should always use HTTPS
7. **Hash validation** - Verify file integrity using SHA-256 before processing

---

## ID Mapping Strategy

When importing from a sync URL, IDs must be preserved exactly to enable future syncs:

- **Use original UUIDs** - Don't generate new IDs on import
- **Relationships preserved** - categoryId, tagIds reference same UUIDs
- **Collision handling** - If importing into app with existing blogs, check for ID conflicts (unlikely with UUIDs)

This differs from the ZIP import which remaps IDs, because sync requires stable IDs across devices.

---

## Testing Plan

### Unit Tests

1. **Encryption/Decryption**
   - Round-trip encryption test
   - Cross-platform compatibility (iOS ↔ Node.js)
   - Invalid password handling
   - Different IV per file

2. **Hash Calculation**
   - Consistent hashes across platforms
   - Hash changes when content changes

3. **Manifest Generation**
   - All files included
   - Correct hashes
   - Proper structure

4. **Conflict Resolution**
   - Last modified wins logic
   - New item handling
   - Deleted item handling

### Integration Tests

1. **Import from URL**
   - Full import with all data types
   - Import with drafts (password required)
   - Import without drafts (no password)
   - Invalid URL handling
   - Wrong password handling

2. **Incremental Sync**
   - Only changed files downloaded
   - New files added
   - Deleted files removed
   - No download when unchanged

3. **Publish with Sync**
   - Sync directory generated
   - All publishers include sync files
   - Version incremented

### Cross-Platform Tests

1. **iOS publishes, Self-Hosted syncs**
2. **Self-Hosted publishes, iOS syncs**
3. **Alternating edits between platforms**
4. **Draft encryption/decryption across platforms**

---

## Migration Notes

- Existing blogs will have `syncEnabled = false` by default
- No data migration needed - sync is opt-in
- First publish after enabling sync creates the sync directory
- Importing a blog via sync sets up bidirectional sync automatically

---

## Edge Cases

1. **Large images**: Download individually, can be interrupted/resumed
2. **Many posts**: Index files list all IDs; individual files downloaded as needed
3. **Password change**: Regenerate salt, re-encrypt all drafts
4. **Corrupted file**: Hash mismatch detected, re-download
5. **Network failure**: Resume from last successful file
6. **Simultaneous edits**: Last modified wins; user can manually reconcile if needed

---

## Future Enhancements (Out of Scope)

- Real-time sync via WebSockets
- Selective sync (choose what to sync)
- Sync history/versioning (keep old versions)
- Multiple device management
- Shared blog collaboration (multiple users)
- Conflict UI (show both versions, let user choose)
