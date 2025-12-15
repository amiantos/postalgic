# Sync Compatibility Test Fixtures

This directory contains shared test fixtures for verifying sync data compatibility
between the iOS and Self-Hosted Postalgic apps.

## Structure

- `canonical-blog.json` - Test blog data that both apps should use
- `expected-sync-structure.json` - Expected structure of generated sync data
- `encryption-test-vectors.json` - Test vectors for verifying encryption compatibility

## Usage

Both the iOS XCTests and Self-Hosted Vitest suites load these fixtures to verify
that sync data generation produces compatible output.

## What's Tested

1. **Sync Data Structure** - JSON structure matches between apps
2. **File Naming** - Consistent file naming conventions
3. **Encryption** - AES-256-GCM encryption produces compatible ciphertext
4. **Content Integrity** - Posts, categories, tags, embeds all serialize correctly
