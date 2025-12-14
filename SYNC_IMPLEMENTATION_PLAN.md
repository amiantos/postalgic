# Postalgic Sync Implementation Plan

## Overview

Enable bidirectional sync between the iOS app and Self-Hosted app using the published website as "cloud storage". When a site is published, a `/sync/` directory containing encrypted blog data is uploaded alongside the HTML site. Either app can import from a URL or sync changes.

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
└─────────────┘         │    data.enc          │         └─────────────────┘
                        └──────────────────────┘
```

## Sync Directory Structure

When publishing, generate a `/sync/` directory:

```
/sync/
├── manifest.json          # Unencrypted metadata (version, timestamps)
└── data.enc               # Encrypted JSON bundle (all blog data)
```

### manifest.json (Unencrypted)

```json
{
  "version": "1.0",
  "syncVersion": 42,
  "lastModified": "2025-01-15T12:00:00.000Z",
  "appSource": "ios",
  "appVersion": "1.2.3",
  "blogName": "My Blog",
  "encryptionMethod": "aes-256-gcm",
  "salt": "base64-encoded-salt",
  "iv": "base64-encoded-iv",
  "checksum": "sha256-of-encrypted-data"
}
```

### data.enc (Encrypted)

Encrypted JSON containing all blog data:

```json
{
  "blog": {
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
  },
  "posts": [
    {
      "id": "uuid",
      "title": "My First Post",
      "content": "# Hello World\n\nThis is my first post.",
      "stub": "my-first-post",
      "isDraft": false,
      "createdAt": "2025-01-15T12:00:00.000Z",
      "updatedAt": "2025-01-15T14:30:00.000Z",
      "categoryId": "category-uuid",
      "tagIds": ["tag-uuid-1", "tag-uuid-2"],
      "embed": {
        "type": "image",
        "position": "above",
        "images": [
          { "filename": "photo.jpg", "order": 0 }
        ]
      }
    }
  ],
  "categories": [
    {
      "id": "uuid",
      "name": "Technology",
      "description": "Posts about tech",
      "stub": "technology",
      "createdAt": "2025-01-01T00:00:00.000Z"
    }
  ],
  "tags": [
    {
      "id": "uuid",
      "name": "swift",
      "stub": "swift",
      "createdAt": "2025-01-01T00:00:00.000Z"
    }
  ],
  "sidebar": [
    {
      "id": "uuid",
      "type": "text",
      "title": "About",
      "content": "Welcome to my blog!",
      "order": 0
    },
    {
      "id": "uuid",
      "type": "linkList",
      "title": "Links",
      "order": 1,
      "links": [
        { "title": "GitHub", "url": "https://github.com/me", "order": 0 }
      ]
    }
  ],
  "staticFiles": [
    {
      "filename": "favicon.png",
      "mimeType": "image/png",
      "isSpecialFile": true,
      "specialFileType": "favicon",
      "data": "base64-encoded-data"
    }
  ],
  "embedImages": [
    {
      "filename": "photo.jpg",
      "data": "base64-encoded-data"
    }
  ],
  "theme": {
    "identifier": "custom-theme",
    "name": "My Custom Theme",
    "templates": {
      "index": "<!DOCTYPE html>...",
      "post": "<!DOCTYPE html>..."
    }
  }
}
```

---

## Encryption Specification

### Key Derivation

- **Algorithm**: PBKDF2 with SHA-256
- **Iterations**: 100,000
- **Salt**: 16 random bytes (stored in manifest)
- **Key Length**: 32 bytes (256 bits)

### Encryption

- **Algorithm**: AES-256-GCM
- **IV**: 12 random bytes (stored in manifest)
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
    let iv = AES.GCM.Nonce()
    let sealedBox = try AES.GCM.seal(data, using: key, nonce: iv)
    return (sealedBox.ciphertext + sealedBox.tag, Data(iv))
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
3. User enters sync password
4. App fetches `https://myblog.com/sync/data.enc`
5. App decrypts data using password + salt/iv from manifest
6. App creates new blog with imported data
7. App stores sync URL and password for future syncs

**UI**: "Import Site" button → URL input → Password input → Import progress

### 2. Sync Down (Pull Changes)

**Flow**:
1. App fetches remote `manifest.json`
2. Compare `syncVersion` with local `lastSyncedVersion`
3. If remote is newer:
   a. Fetch and decrypt `data.enc`
   b. Merge remote data into local (last modified wins)
   c. Update `lastSyncedVersion`
4. If local is newer or equal: No action needed

**Conflict Resolution (Last Modified Wins)**:
- Compare `updatedAt` timestamps for each item
- Keep the version with the more recent timestamp
- For new items (no local match by ID), add them
- For deleted items: If remote doesn't have an item that local has, and remote's `syncVersion` is higher, delete local item

### 3. Publish with Sync (Push Changes)

**Flow**:
1. Before publishing, sync down first (pull any remote changes)
2. Generate site HTML as usual
3. Generate sync data bundle:
   a. Serialize all blog data to JSON
   b. Generate new salt and IV
   c. Encrypt with sync password
   d. Create manifest with new `syncVersion`
4. Upload both HTML site and `/sync/` directory
5. Update local `lastSyncedVersion`

### 4. Auto-Sync Triggers

**iOS App**:
- When opening a blog (sync down)
- Before publishing (sync down, then push)
- Manual "Sync Now" button

**Self-Hosted App**:
- When loading blog in editor (sync down)
- Before publishing (sync down, then push)
- Manual "Sync Now" button

---

## Implementation Phases

### Phase 1: Sync Data Generation

**iOS Changes**:

1. **Add sync settings to Blog model** (`Models.swift`)
   ```swift
   // Add to Blog class (around line 100)
   var syncEnabled: Bool = false
   var lastSyncedVersion: Int = 0
   var lastSyncedAt: Date?
   ```

2. **Add sync password to KeychainService** (`KeychainService.swift`)
   ```swift
   // Add to PasswordType enum (line 24)
   case syncPassword = "syncPassword"
   ```

3. **Create SyncDataGenerator service** (new file)
   - `SyncDataGenerator.swift`
   - Serializes blog data to JSON (reuse ExportService patterns)
   - Encrypts data with password
   - Generates manifest

4. **Modify StaticSiteGenerator** (`StaticSiteGenerator.swift`)
   - After generating HTML, also generate `/sync/` directory
   - Only if `blog.syncEnabled == true`

**Self-Hosted Changes**:

1. **Add sync config to database** (`database.js`)
   ```javascript
   // Add to schema (after line 226)
   CREATE TABLE IF NOT EXISTS sync_config (
     blog_id TEXT PRIMARY KEY,
     sync_enabled INTEGER DEFAULT 0,
     last_synced_version INTEGER DEFAULT 0,
     last_synced_at TEXT,
     FOREIGN KEY (blog_id) REFERENCES blogs(id) ON DELETE CASCADE
   )
   ```

2. **Create syncGenerator service** (new file)
   - `server/services/syncGenerator.js`
   - Serializes blog data to JSON
   - Encrypts data with password
   - Generates manifest

3. **Modify siteGenerator** (`siteGenerator.js`)
   - After generating HTML, also generate `/sync/` directory
   - Only if sync is enabled for the blog

### Phase 2: Import from URL

**iOS Changes**:

1. **Create SyncImporter service** (new file)
   - `SyncImporter.swift`
   - Fetches manifest and encrypted data from URL
   - Decrypts and parses JSON
   - Creates blog and all related entities

2. **Create ImportFromURLView** (new file)
   - `Views/ImportFromURLView.swift`
   - URL input field
   - Password input field
   - Import button with progress

3. **Add to main navigation**
   - "Import from URL" option in blog list or settings

**Self-Hosted Changes**:

1. **Create syncImporter service** (new file)
   - `server/services/syncImporter.js`
   - Fetches manifest and encrypted data
   - Decrypts and parses JSON
   - Creates blog records

2. **Add sync import API route** (new file)
   - `server/routes/sync.js`
   - `POST /api/sync/import` - Import from URL

3. **Create ImportFromURL Vue component** (new file)
   - `client/components/ImportFromURL.vue`
   - URL and password inputs
   - Import progress display

### Phase 3: Sync Down (Pull)

**iOS Changes**:

1. **Create SyncService** (new file)
   - `SyncService.swift`
   - `syncDown(blog:)` - Fetches and merges remote changes
   - `shouldSync(blog:)` - Checks if sync needed
   - Conflict resolution logic

2. **Add sync status to BlogDetailView**
   - Last synced timestamp
   - "Sync Now" button
   - Sync status indicator

3. **Auto-sync on blog open**
   - Call `syncDown()` when viewing blog

**Self-Hosted Changes**:

1. **Create syncService** (new file)
   - `server/services/syncService.js`
   - `syncDown(blogId, url, password)` - Fetches and merges
   - Conflict resolution logic

2. **Add sync API endpoints**
   - `POST /api/blogs/:blogId/sync/pull` - Trigger sync down

3. **Add sync UI to blog editor**
   - Sync status display
   - Manual sync button

### Phase 4: Publish with Sync

**iOS Changes**:

1. **Modify publishing flow** (`PublishView.swift` or similar)
   - Add sync step before publish
   - Show sync status in publish progress

2. **Update all publishers**
   - Include `/sync/` directory in uploads
   - `AWSPublisher.swift`
   - `SFTPPublisher.swift`
   - `GitPublisher.swift`
   - `ManualPublisher.swift` (include in ZIP)

**Self-Hosted Changes**:

1. **Modify publish routes** (`publish.js`)
   - Generate sync data during publish
   - Include in all publisher outputs

2. **Update all publishers**
   - `publishers/s3Publisher.js`
   - `publishers/sftpPublisher.js`
   - `publishers/gitPublisher.js`

### Phase 5: UI Polish & Settings

**iOS Changes**:

1. **Sync Settings View**
   - Enable/disable sync toggle
   - Set/change sync password
   - View sync status and history
   - Manual sync button

2. **Sync indicators throughout app**
   - Badge on blog when out of sync
   - Last synced timestamp in blog list

**Self-Hosted Changes**:

1. **Sync settings in blog settings page**
   - Enable/disable sync
   - Set sync password
   - View sync URL (the published site URL)

2. **Sync status in header/sidebar**
   - Last synced indicator
   - Quick sync button

---

## File Changes Summary

### iOS App - New Files

| File | Purpose |
|------|---------|
| `Services/Sync/SyncDataGenerator.swift` | Generate encrypted sync bundle |
| `Services/Sync/SyncImporter.swift` | Import blog from sync URL |
| `Services/Sync/SyncService.swift` | Sync operations (pull/push) |
| `Services/Sync/SyncEncryption.swift` | Encryption/decryption helpers |
| `Views/Sync/ImportFromURLView.swift` | Import UI |
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
| `BlogListView.swift` | Add import from URL option |
| `BlogDetailView.swift` | Add sync status/button |

### Self-Hosted App - New Files

| File | Purpose |
|------|---------|
| `server/services/syncGenerator.js` | Generate encrypted sync bundle |
| `server/services/syncImporter.js` | Import blog from sync URL |
| `server/services/syncService.js` | Sync operations |
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
| `server/routes/blogs.js` | Add sync config endpoints |
| `server/server.js` | Mount sync routes |
| `client/views/BlogSettings.vue` | Add sync settings section |

---

## API Endpoints (Self-Hosted)

### Sync Routes (`/api/sync`)

```
POST /api/sync/import
  Body: { url: string, password: string }
  Response: { success: boolean, blogId: string }

POST /api/blogs/:blogId/sync/enable
  Body: { password: string }
  Response: { success: boolean }

POST /api/blogs/:blogId/sync/disable
  Response: { success: boolean }

POST /api/blogs/:blogId/sync/pull
  Body: { password: string }
  Response: { success: boolean, changes: number }

GET /api/blogs/:blogId/sync/status
  Response: {
    enabled: boolean,
    lastSyncedAt: string,
    lastSyncedVersion: number,
    remoteVersion: number | null
  }
```

---

## Security Considerations

1. **Password never transmitted** - Only used locally for encryption/decryption
2. **Salt and IV are unique per publish** - Prevents replay attacks
3. **No credentials in sync data** - Publisher credentials stay local only
4. **HTTPS required** - Sync URLs should use HTTPS
5. **Checksum validation** - Verify data integrity before decryption

---

## Testing Plan

### Unit Tests

1. **Encryption/Decryption**
   - Round-trip encryption test
   - Cross-platform compatibility (iOS ↔ Node.js)
   - Invalid password handling

2. **Sync Data Generation**
   - All data types serialized correctly
   - Binary files encoded properly
   - Manifest format valid

3. **Conflict Resolution**
   - Last modified wins logic
   - New item handling
   - Deleted item handling

### Integration Tests

1. **Import from URL**
   - Valid URL import
   - Invalid URL handling
   - Wrong password handling

2. **Sync Down**
   - Pull newer remote changes
   - No changes when up to date
   - Merge conflicts resolved

3. **Publish with Sync**
   - Sync files included in publish
   - Version incremented correctly

### Cross-Platform Tests

1. **iOS exports, Self-Hosted imports**
2. **Self-Hosted exports, iOS imports**
3. **Both apps sync same blog**

---

## Migration Notes

- Existing blogs will have `syncEnabled = false` by default
- No data migration needed - sync is opt-in
- First sync from an existing blog creates the sync bundle

---

## Future Enhancements (Out of Scope)

- Real-time sync via WebSockets
- Selective sync (choose what to sync)
- Sync history/versioning
- Multiple device management
- Shared blog collaboration
