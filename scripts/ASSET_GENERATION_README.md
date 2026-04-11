# MajuRun Asset Generation Guide

## Overview

3-step process:
1. **You** generate images/videos on openart.ai (manual, ~2–3 hours)
2. **Script** uploads everything to Cloudinary automatically
3. **Script** seeds Firestore with sample posts automatically

---

## Step 1 — Generate on OpenArt

Open these prompt files and generate each asset:
- `assets/OPENART_PROMPTS.md` — all static images and GIFs
- `assets/SEEDANCE_PROMPTS.md` — all Seedance 2.0 videos
- `assets/SEED_POST_PROMPTS.md` — seed post images and videos

**Save downloads into this folder structure:**
```
assets_to_upload/           ← create this at project root
  badges/
  celebrations/
  plan_covers/
  onboarding/
  empty_states/
  mascot/
  gifs/
  seed_posts/
  videos/
```

**Tips to go faster on OpenArt:**
- Set batch to 4 images per generation
- Use Assets → History to bulk download at end of session
- For Seedance: queue multiple videos, they run in background

---

## Step 2 — Upload to Cloudinary

### One-time setup
```bash
cd scripts
npm install cloudinary dotenv
```

Create `scripts/.env` file:
```
CLOUDINARY_CLOUD_NAME=your_cloud_name
CLOUDINARY_API_KEY=your_api_key
CLOUDINARY_API_SECRET=your_api_secret
```

Get these from: cloudinary.com → Dashboard (top of page)

### Run the upload script
```bash
node scripts/upload_to_cloudinary.js
```

**What it does:**
- Uploads every file in `assets_to_upload/` to Cloudinary
- Saves all URLs to `scripts/output/asset_urls.json`
- Auto-generates `lib/core/constants/asset_urls.dart` with all constants

**Re-run safe:** already-uploaded files are skipped automatically.

---

## Step 3 — Seed Firestore

### One-time setup
Download Firebase service account key:
- Firebase Console → Project Settings → Service Accounts
- Click "Generate new private key"
- Save as `scripts/firebase_service_account.json`

```bash
cd scripts
npm install firebase-admin
```

### Run the seed script
```bash
node scripts/seed_firestore.js
```

**What it does:**
- Creates 21 realistic seed posts in Firestore `posts` collection
- Uses real Cloudinary URLs from Step 2
- Posts are spread over past 30 days with realistic like/comment counts
- Safe to re-run: detects existing seed posts

**To reset and re-seed:**
```bash
node scripts/seed_firestore.js --force
```

---

## Using AssetUrls in Flutter

```dart
import 'package:majurun/core/constants/asset_urls.dart';

// Get celebration image for a run
final imageUrl = AssetUrls.celebrationForDistance(5.2);

// Get badge image by name
final badgeUrl = AssetUrls.badgeForName('5K');

// Get streak badge
final streakUrl = AssetUrls.badgeForStreak(30);

// Direct access
Image.network(AssetUrls.badge5k)
Image.network(AssetUrls.planCover10k)
```

---

## Files Created

| File | Purpose |
|---|---|
| `scripts/upload_to_cloudinary.js` | Bulk upload to Cloudinary |
| `scripts/seed_firestore.js` | Create seed posts in Firestore |
| `scripts/ASSET_GENERATION_README.md` | This file |
| `lib/core/constants/asset_urls.dart` | Flutter constants (auto-generated) |
| `assets/OPENART_PROMPTS.md` | Static image prompts |
| `assets/SEEDANCE_PROMPTS.md` | Video prompts |
| `assets/SEED_POST_PROMPTS.md` | Seed post prompts |

---

## Cloudinary Folder Structure (after upload)

```
majurun/
  assets/
    badges/
    celebrations/
    plan_covers/
    onboarding/
    empty_states/
    mascot/
    gifs/
    seed_posts/
    videos/
```
