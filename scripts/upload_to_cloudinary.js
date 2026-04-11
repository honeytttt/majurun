/**
 * MajuRun — Bulk Upload Assets to Cloudinary
 *
 * Scans a local folder of images/videos downloaded from OpenArt,
 * uploads each to Cloudinary under /majurun/assets/,
 * and writes all URLs to:
 *   - scripts/output/asset_urls.json  (raw data)
 *   - lib/core/constants/asset_urls.dart (ready to use in Flutter)
 *
 * SETUP:
 *   1. npm install cloudinary dotenv
 *   2. Create scripts/.env with your Cloudinary credentials (see below)
 *   3. Put downloaded images in the folder structure below
 *   4. Run: node scripts/upload_to_cloudinary.js
 *
 * FOLDER STRUCTURE (put your OpenArt downloads here):
 *   assets_to_upload/
 *     badges/          ← badge_5k.png, badge_10k.png, etc.
 *     celebrations/    ← celebration_5k.jpg, etc.
 *     plan_covers/     ← plan_cover_5k.jpg, etc.
 *     onboarding/      ← onboarding_welcome.jpg, etc.
 *     empty_states/    ← empty_no_runs.png, etc.
 *     mascot/          ← mascot_running.png, etc.
 *     gifs/            ← badge_5k_animated.gif, etc.
 *     seed_posts/      ← seed_motivation_1.jpg, etc.
 *     videos/          ← video_celebration_5k.mp4, etc.
 *
 * scripts/.env file contents:
 *   CLOUDINARY_CLOUD_NAME=your_cloud_name
 *   CLOUDINARY_API_KEY=your_api_key
 *   CLOUDINARY_API_SECRET=your_api_secret
 */

const cloudinary = require('cloudinary').v2;
const fs = require('fs');
const path = require('path');
require('dotenv').config({ path: path.join(__dirname, '.env') });

// ─── CONFIG ──────────────────────────────────────────────────────────────────

cloudinary.config({
  cloud_name: process.env.CLOUDINARY_CLOUD_NAME,
  api_key:    process.env.CLOUDINARY_API_KEY,
  api_secret: process.env.CLOUDINARY_API_SECRET,
});

const UPLOAD_ROOT = path.join(__dirname, '..', 'assets_to_upload');
const OUTPUT_DIR  = path.join(__dirname, 'output');
const DART_OUTPUT = path.join(__dirname, '..', 'lib', 'core', 'constants', 'asset_urls.dart');

// Map subfolder → Cloudinary folder + resource type
const FOLDER_CONFIG = {
  'badges':       { folder: 'majurun/assets/badges',       type: 'image' },
  'celebrations': { folder: 'majurun/assets/celebrations',  type: 'image' },
  'plan_covers':  { folder: 'majurun/assets/plan_covers',   type: 'image' },
  'onboarding':   { folder: 'majurun/assets/onboarding',    type: 'image' },
  'empty_states': { folder: 'majurun/assets/empty_states',  type: 'image' },
  'mascot':       { folder: 'majurun/assets/mascot',        type: 'image' },
  'gifs':         { folder: 'majurun/assets/gifs',          type: 'image' }, // GIFs upload as image type
  'seed_posts':   { folder: 'majurun/assets/seed_posts',    type: 'image' },
  'videos':       { folder: 'majurun/assets/videos',        type: 'video' },
};

// ─── HELPERS ─────────────────────────────────────────────────────────────────

function getAllFiles(dir) {
  if (!fs.existsSync(dir)) return [];
  return fs.readdirSync(dir).filter(f => {
    const ext = path.extname(f).toLowerCase();
    return ['.jpg', '.jpeg', '.png', '.gif', '.mp4', '.webp'].includes(ext);
  });
}

function fileNameToKey(fileName) {
  // badge_5k.png → badge5k
  // plan_cover_half_marathon.jpg → planCoverHalfMarathon
  return path.basename(fileName, path.extname(fileName))
    .replace(/[^a-zA-Z0-9_]/g, '_')
    .replace(/_([a-z])/g, (_, c) => c.toUpperCase())
    .replace(/^_/, '');
}

async function uploadFile(filePath, folder, resourceType) {
  const publicId = path.basename(filePath, path.extname(filePath));
  try {
    const result = await cloudinary.uploader.upload(filePath, {
      folder,
      public_id: publicId,
      resource_type: resourceType,
      overwrite: false, // skip if already uploaded
      transformation: resourceType === 'image'
        ? [{ quality: 'auto', fetch_format: 'auto' }]
        : [],
    });
    return result.secure_url;
  } catch (err) {
    // If already exists, get the URL
    if (err.error?.http_code === 400 && err.error?.message?.includes('already exists')) {
      const url = `https://res.cloudinary.com/${process.env.CLOUDINARY_CLOUD_NAME}/${resourceType}/upload/${folder}/${publicId}`;
      console.log(`  ⏭️  Already exists: ${publicId}`);
      return url;
    }
    throw err;
  }
}

function toDartConstName(key) {
  // ensure starts with lowercase
  return key.charAt(0).toLowerCase() + key.slice(1);
}

function generateDartFile(urlMap) {
  const grouped = {};
  for (const [key, url] of Object.entries(urlMap)) {
    const parts = key.split('/');
    const category = parts[0];
    const name = parts[1];
    if (!grouped[category]) grouped[category] = {};
    grouped[category][name] = url;
  }

  let dart = `// AUTO-GENERATED — do not edit manually
// Run: node scripts/upload_to_cloudinary.js to regenerate
// Generated: ${new Date().toISOString()}

class AssetUrls {
  AssetUrls._();

`;

  for (const [category, items] of Object.entries(grouped)) {
    dart += `  // ─── ${category.toUpperCase().replace(/_/g, ' ')} ───\n`;
    for (const [name, url] of Object.entries(items)) {
      const constName = toDartConstName(fileNameToKey(name));
      dart += `  static const String ${constName} = '${url}';\n`;
    }
    dart += '\n';
  }

  dart += `  // ─── ALL URLS (for iteration) ───
  static const Map<String, String> all = {
`;
  for (const [key, url] of Object.entries(urlMap)) {
    const constName = toDartConstName(fileNameToKey(key.split('/')[1]));
    dart += `    '${constName}': '${url}',\n`;
  }
  dart += `  };\n}\n`;

  return dart;
}

// ─── MAIN ────────────────────────────────────────────────────────────────────

async function main() {
  console.log('🚀 MajuRun Cloudinary Bulk Uploader\n');

  if (!process.env.CLOUDINARY_CLOUD_NAME || !process.env.CLOUDINARY_API_KEY || !process.env.CLOUDINARY_API_SECRET) {
    console.error('❌ Missing Cloudinary credentials in scripts/.env');
    console.error('   Create scripts/.env with:');
    console.error('   CLOUDINARY_CLOUD_NAME=xxx');
    console.error('   CLOUDINARY_API_KEY=xxx');
    console.error('   CLOUDINARY_API_SECRET=xxx');
    process.exit(1);
  }

  if (!fs.existsSync(UPLOAD_ROOT)) {
    console.error(`❌ Upload folder not found: ${UPLOAD_ROOT}`);
    console.error('   Create assets_to_upload/ and put your OpenArt downloads inside');
    process.exit(1);
  }

  if (!fs.existsSync(OUTPUT_DIR)) fs.mkdirSync(OUTPUT_DIR, { recursive: true });

  const urlMap = {};
  let totalUploaded = 0;
  let totalSkipped = 0;
  let totalFailed = 0;

  for (const [subFolder, config] of Object.entries(FOLDER_CONFIG)) {
    const folderPath = path.join(UPLOAD_ROOT, subFolder);
    const files = getAllFiles(folderPath);

    if (files.length === 0) {
      console.log(`📁 ${subFolder}/ — empty, skipping`);
      continue;
    }

    console.log(`📁 ${subFolder}/ — ${files.length} files`);

    for (const file of files) {
      const filePath = path.join(folderPath, file);
      const key = `${subFolder}/${file}`;
      process.stdout.write(`  ⬆️  ${file} ... `);

      try {
        const url = await uploadFile(filePath, config.folder, config.type);
        urlMap[key] = url;
        console.log('✅');
        totalUploaded++;
      } catch (err) {
        console.log(`❌ ${err.message}`);
        totalFailed++;
      }
    }
    console.log('');
  }

  // Save JSON output
  const jsonPath = path.join(OUTPUT_DIR, 'asset_urls.json');
  fs.writeFileSync(jsonPath, JSON.stringify(urlMap, null, 2));
  console.log(`\n💾 Saved URLs to: ${jsonPath}`);

  // Generate and save Dart file
  const dartContent = generateDartFile(urlMap);
  fs.mkdirSync(path.dirname(DART_OUTPUT), { recursive: true });
  fs.writeFileSync(DART_OUTPUT, dartContent);
  console.log(`🎯 Generated Dart file: lib/core/constants/asset_urls.dart`);

  // Summary
  console.log('\n─────────────────────────────────');
  console.log(`✅ Uploaded : ${totalUploaded}`);
  console.log(`⏭️  Skipped  : ${totalSkipped}`);
  console.log(`❌ Failed   : ${totalFailed}`);
  console.log(`📦 Total    : ${Object.keys(urlMap).length} URLs saved`);
  console.log('─────────────────────────────────');
  console.log('\n✨ Done! Add AssetUrls to your Flutter app and use the constants.');
}

main().catch(err => {
  console.error('💥 Fatal error:', err);
  process.exit(1);
});
