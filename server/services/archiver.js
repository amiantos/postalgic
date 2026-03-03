import archiver from 'archiver';
import fs from 'fs';
import path from 'path';

/**
 * Create a ZIP archive from a directory
 * @param {string} sourceDir - Directory to archive
 * @returns {Promise<Buffer>} - ZIP file buffer
 */
export async function createZipArchive(sourceDir) {
  return new Promise((resolve, reject) => {
    const chunks = [];

    const archive = archiver('zip', {
      zlib: { level: 9 } // Maximum compression
    });

    archive.on('data', (chunk) => chunks.push(chunk));
    archive.on('end', () => resolve(Buffer.concat(chunks)));
    archive.on('error', (err) => reject(err));

    // Add the directory contents
    archive.directory(sourceDir, false);

    archive.finalize();
  });
}

/**
 * Create a ZIP archive and save to file
 * @param {string} sourceDir - Directory to archive
 * @param {string} outputPath - Path to save ZIP file
 * @returns {Promise<string>} - Path to created ZIP file
 */
export async function createZipFile(sourceDir, outputPath) {
  return new Promise((resolve, reject) => {
    const output = fs.createWriteStream(outputPath);

    const archive = archiver('zip', {
      zlib: { level: 9 }
    });

    output.on('close', () => resolve(outputPath));
    archive.on('error', (err) => reject(err));

    archive.pipe(output);
    archive.directory(sourceDir, false);
    archive.finalize();
  });
}
