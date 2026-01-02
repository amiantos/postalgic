#!/usr/bin/env node
/**
 * Compare two Postalgic debug export bundles
 *
 * Usage: node compare-bundles.js <bundle1.zip> <bundle2.zip>
 *
 * Outputs:
 * - Files only in bundle 1
 * - Files only in bundle 2
 * - Files with different content (with diff preview for text files)
 */

import fs from 'fs';
import path from 'path';
import crypto from 'crypto';
import { execSync } from 'child_process';
import AdmZip from 'adm-zip';

function calculateHash(buffer) {
  return crypto.createHash('sha256').update(buffer).digest('hex');
}

function extractZip(zipPath, extractTo) {
  const zip = new AdmZip(zipPath);
  zip.extractAllTo(extractTo, true);
}

function getAllFiles(dir, baseDir = dir) {
  const files = new Map();

  function walk(currentDir) {
    const entries = fs.readdirSync(currentDir, { withFileTypes: true });
    for (const entry of entries) {
      const fullPath = path.join(currentDir, entry.name);
      const relativePath = path.relative(baseDir, fullPath);

      if (entry.isDirectory()) {
        walk(fullPath);
      } else {
        const content = fs.readFileSync(fullPath);
        files.set(relativePath, {
          hash: calculateHash(content),
          size: content.length,
          content: content
        });
      }
    }
  }

  walk(dir);
  return files;
}

function isTextFile(filename) {
  const textExtensions = ['.html', '.css', '.js', '.json', '.xml', '.txt', '.md'];
  return textExtensions.some(ext => filename.toLowerCase().endsWith(ext));
}

function showDiff(file1Path, file2Path, filename) {
  try {
    const result = execSync(`diff -u "${file1Path}" "${file2Path}" | head -50`, {
      encoding: 'utf8',
      stdio: ['pipe', 'pipe', 'pipe']
    });
    return result;
  } catch (e) {
    // diff returns exit code 1 when files differ
    return e.stdout || '';
  }
}

async function main() {
  const args = process.argv.slice(2);

  if (args.length !== 2) {
    console.log('Usage: node compare-bundles.js <bundle1.zip> <bundle2.zip>');
    console.log('');
    console.log('Compares two Postalgic debug export bundles and shows differences.');
    process.exit(1);
  }

  const [bundle1Path, bundle2Path] = args;

  if (!fs.existsSync(bundle1Path)) {
    console.error(`Error: File not found: ${bundle1Path}`);
    process.exit(1);
  }

  if (!fs.existsSync(bundle2Path)) {
    console.error(`Error: File not found: ${bundle2Path}`);
    process.exit(1);
  }

  // Create temp directories
  const tempDir = fs.mkdtempSync('/tmp/postalgic-compare-');
  const extract1 = path.join(tempDir, 'bundle1');
  const extract2 = path.join(tempDir, 'bundle2');

  try {
    console.log('Extracting bundles...');
    extractZip(bundle1Path, extract1);
    extractZip(bundle2Path, extract2);

    console.log('Scanning files...');
    const files1 = getAllFiles(extract1);
    const files2 = getAllFiles(extract2);

    const allPaths = new Set([...files1.keys(), ...files2.keys()]);

    const onlyIn1 = [];
    const onlyIn2 = [];
    const different = [];
    const identical = [];

    for (const filePath of allPaths) {
      const file1 = files1.get(filePath);
      const file2 = files2.get(filePath);

      if (!file1) {
        onlyIn2.push(filePath);
      } else if (!file2) {
        onlyIn1.push(filePath);
      } else if (file1.hash !== file2.hash) {
        different.push(filePath);
      } else {
        identical.push(filePath);
      }
    }

    console.log('\n' + '='.repeat(60));
    console.log('COMPARISON RESULTS');
    console.log('='.repeat(60));

    console.log(`\nBundle 1: ${path.basename(bundle1Path)}`);
    console.log(`Bundle 2: ${path.basename(bundle2Path)}`);
    console.log(`\nTotal files: ${allPaths.size}`);
    console.log(`Identical: ${identical.length}`);
    console.log(`Different: ${different.length}`);
    console.log(`Only in bundle 1: ${onlyIn1.length}`);
    console.log(`Only in bundle 2: ${onlyIn2.length}`);

    if (onlyIn1.length > 0) {
      console.log('\n' + '-'.repeat(60));
      console.log('FILES ONLY IN BUNDLE 1:');
      console.log('-'.repeat(60));
      for (const f of onlyIn1.sort()) {
        console.log(`  ${f}`);
      }
    }

    if (onlyIn2.length > 0) {
      console.log('\n' + '-'.repeat(60));
      console.log('FILES ONLY IN BUNDLE 2:');
      console.log('-'.repeat(60));
      for (const f of onlyIn2.sort()) {
        console.log(`  ${f}`);
      }
    }

    if (different.length > 0) {
      console.log('\n' + '-'.repeat(60));
      console.log('FILES WITH DIFFERENT CONTENT:');
      console.log('-'.repeat(60));

      for (const f of different.sort()) {
        const file1 = files1.get(f);
        const file2 = files2.get(f);
        console.log(`\n  ${f}`);
        console.log(`    Bundle 1: ${file1.size} bytes, hash: ${file1.hash.substring(0, 16)}...`);
        console.log(`    Bundle 2: ${file2.size} bytes, hash: ${file2.hash.substring(0, 16)}...`);

        // Show diff for text files
        if (isTextFile(f)) {
          const file1Path = path.join(extract1, f);
          const file2Path = path.join(extract2, f);
          const diff = showDiff(file1Path, file2Path, f);
          if (diff.trim()) {
            console.log('\n    Diff preview (first 50 lines):');
            const lines = diff.split('\n').map(l => '    ' + l);
            console.log(lines.join('\n'));
          }
        }
      }
    }

    if (different.length === 0 && onlyIn1.length === 0 && onlyIn2.length === 0) {
      console.log('\n✅ Bundles are IDENTICAL!');
    } else {
      console.log('\n❌ Bundles have differences.');
    }

  } finally {
    // Cleanup
    fs.rmSync(tempDir, { recursive: true, force: true });
  }
}

main().catch(err => {
  console.error('Error:', err.message);
  process.exit(1);
});
