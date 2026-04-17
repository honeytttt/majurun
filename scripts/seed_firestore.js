/**
 * MajuRun — Seed Firestore with users + posts
 *
 * Reads:   scripts/output/asset_urls.json  (produced by upload_assets.py)
 * Writes:  Firestore collections: users, posts
 *
 * SETUP:
 *   1. Download Firebase service account key:
 *      Firebase Console → Project Settings → Service Accounts → Generate new private key
 *      Save as: scripts/firebase_service_account.json
 *   2. npm install firebase-admin
 *   3. node scripts/seed_firestore.js
 *
 * Safe to re-run — checks for existing seed data before inserting.
 * Force re-seed: node scripts/seed_firestore.js --force
 */

const admin = require('firebase-admin');
const path  = require('path');
const fs    = require('fs');

// ─── INIT FIREBASE ────────────────────────────────────────────────────────────
// Uses Application Default Credentials — no service account file needed.
// One-time setup: run  gcloud auth application-default login  in your terminal.
admin.initializeApp({
  credential:  admin.credential.applicationDefault(),
  projectId:   'majurun-8d8b5',
});
const db = admin.firestore();

// ─── LOAD ASSET URLS ──────────────────────────────────────────────────────────
const urlsPath = path.join(__dirname, 'output', 'asset_urls.json');
if (!fs.existsSync(urlsPath)) {
  console.error('❌ Missing: scripts/output/asset_urls.json');
  console.error('   Run first: python scripts/upload_assets.py');
  process.exit(1);
}
const assetUrls = JSON.parse(fs.readFileSync(urlsPath, 'utf8'));
console.log(`📦 Loaded ${Object.keys(assetUrls).length} asset URLs\n`);

function url(key) {
  const v = assetUrls[key];
  if (!v) console.warn(`⚠️  Missing URL for key: ${key}`);
  return v || '';
}

// ─── HELPERS ──────────────────────────────────────────────────────────────────
function daysAgo(n) {
  const d = new Date();
  d.setDate(d.getDate() - n);
  // Vary the time within the day for realism
  d.setHours(Math.floor(Math.random() * 14) + 5); // 5am–7pm
  d.setMinutes(Math.floor(Math.random() * 60));
  return admin.firestore.Timestamp.fromDate(d);
}

// ─── SEED USERS (match the 12 avatars from Section 1A) ───────────────────────
const SEED_USERS = [
  { id: 'seed_user_01', displayName: 'Aini Razak',        avatar: url('seed/avatars/01'), bio: 'Morning runner 🌅 | KL roads are my therapy', totalKm: 312, streak: 14 },
  { id: 'seed_user_02', displayName: 'Marcus Johnson',    avatar: url('seed/avatars/02'), bio: 'Trail running addict. Mountains over treadmills.', totalKm: 687, streak: 32 },
  { id: 'seed_user_03', displayName: 'Fatimah Al-Hassan', avatar: url('seed/avatars/03'), bio: 'Proving every day that nothing stops a determined runner 💚', totalKm: 445, streak: 21 },
  { id: 'seed_user_04', displayName: 'Rahul Sharma',      avatar: url('seed/avatars/04'), bio: 'Marathoner. Sub-4 is the goal. Training hard.', totalKm: 1243, streak: 60 },
  { id: 'seed_user_05', displayName: 'Sarah Mitchell',    avatar: url('seed/avatars/05'), bio: 'Running mum. Parkrun regular. Slow and steady wins.', totalKm: 198, streak: 7 },
  { id: 'seed_user_06', displayName: 'Isabella Torres',   avatar: url('seed/avatars/06'), bio: 'Speed work enthusiast. Track or bust. 🏃‍♀️', totalKm: 523, streak: 28 },
  { id: 'seed_user_07', displayName: 'Kenji Tanaka',      avatar: url('seed/avatars/07'), bio: 'Ultrarunner. 100km is just the warm-up.', totalKm: 2840, streak: 90 },
  { id: 'seed_user_08', displayName: 'Emmanuel Okafor',   avatar: url('seed/avatars/08'), bio: 'Running since 40. Best decision I ever made. 52 and flying.', totalKm: 876, streak: 45 },
  { id: 'seed_user_09', displayName: 'Priya Nair',        avatar: url('seed/avatars/09'), bio: 'New to running. Week 4 of the 5K plan. Loving it!', totalKm: 24,  streak: 4 },
  { id: 'seed_user_10', displayName: 'Rahim Abdullah',    avatar: url('seed/avatars/10'), bio: 'Running the streets of KL before the traffic wakes up 🌆', totalKm: 412, streak: 19 },
  { id: 'seed_user_11', displayName: 'Yuki Nakamura',     avatar: url('seed/avatars/11'), bio: 'Half marathon finisher × 3. Next goal: full marathon 2026.', totalKm: 734, streak: 36 },
  { id: 'seed_user_12', displayName: 'Amara Diallo',      avatar: url('seed/avatars/12'), bio: 'Running for mental health. One km at a time. 💚', totalKm: 156, streak: 9 },
];

// ─── SEED POSTS (20 from Section 1B + bonus social posts) ────────────────────
//  userId index maps to SEED_USERS array (0-indexed)
const SEED_POSTS = [
  // ── Section 1B: actual run posts ──────────────────────────────────────────
  {
    mapImageUrl: url('seed/posts/01'),
    content: "Morning miles hit different. 5.2 km before the city woke up 🌅",
    distance: '5.2', pace: '5:48', bpm: 148, planTitle: '5K Beginner Plan',
    userIdx: 0, likeCount: 142, commentCount: 18, daysAgo: 1,
  },
  {
    mapImageUrl: url('seed/posts/02'),
    content: "Every run leaves a trace. Today's route: 8.4 km 🗺️",
    distance: '8.4', pace: '5:32', bpm: 156, planTitle: '10K Builder',
    userIdx: 1, likeCount: 98, commentCount: 11, daysAgo: 2,
  },
  {
    mapImageUrl: url('seed/posts/03'),
    content: "Done. 10K PB shattered. 🏃‍♀️💚",
    distance: '10.1', pace: '4:58', bpm: 172, planTitle: '10K Builder',
    userIdx: 2, likeCount: 387, commentCount: 52, daysAgo: 3,
  },
  {
    mapImageUrl: url('seed/posts/04'),
    content: "Rainy day? Still showed up. 7 km ✅",
    distance: '7.0', pace: '6:10', bpm: 145, planTitle: 'Easy Run',
    userIdx: 4, likeCount: 213, commentCount: 27, daysAgo: 4,
  },
  {
    mapImageUrl: url('seed/posts/05'),
    content: "Squad run Sunday. The best therapy money can't buy 🌊",
    distance: '12.3', pace: '5:55', bpm: 152, planTitle: 'Long Run',
    userIdx: 5, likeCount: 445, commentCount: 67, daysAgo: 5,
  },
  {
    mapImageUrl: url('seed/posts/06'),
    content: "That feeling when you cross the line after months of training. Unmatched. 🏅",
    distance: '21.1', pace: '5:22', bpm: 168, planTitle: 'Half Marathon',
    userIdx: 3, likeCount: 621, commentCount: 89, daysAgo: 6,
  },
  {
    mapImageUrl: url('seed/posts/07'),
    content: "The view always pays for the climb. 14 km trail 🏔️",
    distance: '14.0', pace: '7:05', bpm: 161, planTitle: 'Trail Run',
    userIdx: 6, likeCount: 534, commentCount: 72, daysAgo: 7,
  },
  {
    mapImageUrl: url('seed/posts/08'),
    content: "Night runs and city lights. 6 km recovery 🌙",
    distance: '6.0', pace: '6:30', bpm: 138, planTitle: 'Recovery Run',
    userIdx: 9, likeCount: 267, commentCount: 38, daysAgo: 8,
  },
  {
    mapImageUrl: url('seed/posts/09'),
    content: "The reward that makes every run worth it ☕ 9.1 km done.",
    distance: '9.1', pace: '5:44', bpm: 154, planTitle: '10K Builder',
    userIdx: 7, likeCount: 312, commentCount: 44, daysAgo: 9,
  },
  {
    mapImageUrl: url('seed/posts/10'),
    content: "When it rains, the treadmill doesn't judge. 8 km 🏃‍♂️",
    distance: '8.0', pace: '5:50', bpm: 158, planTitle: 'Treadmill Run',
    userIdx: 10, likeCount: 178, commentCount: 22, daysAgo: 10,
  },
  {
    mapImageUrl: url('seed/posts/11'),
    content: "21.1 km. 2:04:33. New personal best. The training was worth every early morning 🥈",
    distance: '21.1', pace: '5:54', bpm: 165, planTitle: 'Half Marathon',
    userIdx: 11, likeCount: 734, commentCount: 98, daysAgo: 11,
  },
  {
    mapImageUrl: url('seed/posts/12'),
    content: "5:42/km average, 155 BPM, 312 cal. Solid tempo run 📊",
    distance: '8.5', pace: '5:42', bpm: 155, planTitle: 'Speed Intervals',
    userIdx: 3, likeCount: 201, commentCount: 25, daysAgo: 12,
  },
  {
    mapImageUrl: url('seed/posts/13'),
    content: "The stretch you almost skip but never regret 🧘‍♀️",
    distance: '7.2', pace: '6:05', bpm: 143, planTitle: 'Easy Run',
    userIdx: 0, likeCount: 156, commentCount: 19, daysAgo: 13,
  },
  {
    mapImageUrl: url('seed/posts/14'),
    content: "100 km in a month. A goal I didn't think was possible 6 months ago 💚",
    distance: '10.0', pace: '5:38', bpm: 159, planTitle: '10K Builder',
    userIdx: 7, likeCount: 892, commentCount: 134, daysAgo: 14,
  },
  {
    mapImageUrl: url('seed/posts/15'),
    content: "Sand, waves, and 12 km of pure silence 🏖️",
    distance: '12.0', pace: '6:15', bpm: 149, planTitle: 'Long Run',
    userIdx: 5, likeCount: 445, commentCount: 61, daysAgo: 15,
  },
  {
    mapImageUrl: url('seed/posts/16'),
    content: "We came, we ran, we earned it 🥇🥈🥉",
    distance: '21.1', pace: '5:45', bpm: 162, planTitle: 'Half Marathon',
    userIdx: 2, likeCount: 567, commentCount: 83, daysAgo: 16,
  },
  {
    mapImageUrl: url('seed/posts/17'),
    content: "725m elevation gain. My legs filed a formal complaint 😅 13.5 km trail",
    distance: '13.5', pace: '7:22', bpm: 167, planTitle: 'Trail Run',
    userIdx: 6, likeCount: 389, commentCount: 54, daysAgo: 17,
  },
  {
    mapImageUrl: url('seed/posts/18'),
    content: "Parkrun Saturday. Free, friendly, and 5K every week 💚",
    distance: '5.0', pace: '5:55', bpm: 153, planTitle: '5K Beginner Plan',
    userIdx: 4, likeCount: 298, commentCount: 43, daysAgo: 18,
  },
  {
    mapImageUrl: url('seed/posts/19'),
    content: "Some of my best runs happened in the worst weather ☔",
    distance: '9.0', pace: '5:52', bpm: 157, planTitle: 'Easy Run',
    userIdx: 1, likeCount: 334, commentCount: 47, daysAgo: 19,
  },
  {
    mapImageUrl: url('seed/posts/20'),
    content: "New shoes loaded. New goals set. Let's go 👟💚",
    distance: null, pace: null, bpm: null, planTitle: null,
    userIdx: 8, likeCount: 512, commentCount: 71, daysAgo: 20,
  },

  // ── Bonus: motivational cards as feed posts ───────────────────────────────
  {
    mapImageUrl: url('motivational/cards/card_01'),
    content: "Every kilometre is a choice. Choose to keep going. 💪",
    userIdx: 0, likeCount: 234, commentCount: 31, daysAgo: 21,
    tags: ['motivation'],
  },
  {
    mapImageUrl: url('motivational/cards/card_02'),
    content: "Your only competition is yesterday's version of you. 🏃",
    userIdx: 7, likeCount: 178, commentCount: 22, daysAgo: 22,
    tags: ['motivation'],
  },
  {
    mapImageUrl: url('motivational/cards/card_03'),
    content: "The run you almost didn't do is always the best one. 🌅",
    userIdx: 11, likeCount: 312, commentCount: 41, daysAgo: 23,
    tags: ['motivation'],
  },
  {
    mapImageUrl: url('motivational/cards/card_04'),
    content: "Don't stop when you're tired. Stop when you're done. 🔥",
    userIdx: 3, likeCount: 445, commentCount: 58, daysAgo: 24,
    tags: ['motivation'],
  },
  {
    mapImageUrl: url('motivational/cards/card_05'),
    content: "Slow miles are still miles. Every step counts. 🐢",
    userIdx: 8, likeCount: 267, commentCount: 34, daysAgo: 25,
    tags: ['motivation'],
  },

  // ── Bonus: meme posts ────────────────────────────────────────────────────
  {
    mapImageUrl: url('social/memes/meme_01'),
    content: "Runners before a race vs after km 30 of a marathon 😂 Tag someone who gets it.",
    userIdx: 5, likeCount: 678, commentCount: 112, daysAgo: 26,
    tags: ['meme', 'relatable'],
  },
  {
    mapImageUrl: url('social/memes/meme_02'),
    content: "Me at 5am: I should sleep. Also me at 5am: lacing up. 🌙➡️🌅",
    userIdx: 9, likeCount: 445, commentCount: 78, daysAgo: 27,
    tags: ['meme', 'earlybird'],
  },
  {
    mapImageUrl: url('social/memes/meme_03'),
    content: "Non-runners: 'isn't running bad for your knees?' Runners: *immediately signs up for another race*",
    userIdx: 6, likeCount: 534, commentCount: 89, daysAgo: 28,
    tags: ['meme', 'relatable'],
  },
];

// ─── MAIN ─────────────────────────────────────────────────────────────────────
async function main() {
  console.log('🌱 MajuRun Firestore Seeder\n');

  const force = process.argv.includes('--force');

  // ── Check existing seed ──────────────────────────────────────────────────
  const existing = await db.collection('posts')
    .where('isSeed', '==', true)
    .limit(1)
    .get();

  if (!existing.empty) {
    if (!force) {
      console.log('⚠️  Seed data already exists.');
      console.log('   To re-seed: node scripts/seed_firestore.js --force\n');
      process.exit(0);
    }
    console.log('♻️  --force: deleting existing seed data...');
    // Delete seed posts
    const allPosts = await db.collection('posts').where('isSeed', '==', true).get();
    const batch1 = db.batch();
    allPosts.docs.forEach(d => batch1.delete(d.ref));
    await batch1.commit();
    // Delete seed users
    const allUsers = await db.collection('users').where('isSeed', '==', true).get();
    const batch2 = db.batch();
    allUsers.docs.forEach(d => batch2.delete(d.ref));
    await batch2.commit();
    console.log(`   Deleted ${allPosts.size} posts + ${allUsers.size} users\n`);
  }

  // ── Create seed users ────────────────────────────────────────────────────
  console.log(`👤 Creating ${SEED_USERS.length} seed users...`);
  const userBatch = db.batch();
  for (const user of SEED_USERS) {
    const ref = db.collection('users').doc(user.id);
    userBatch.set(ref, {
      displayName:  user.displayName,
      photoURL:     user.avatar,
      bio:          user.bio,
      totalKm:      user.totalKm,
      currentStreak: user.streak,
      isSeed:       true,
      createdAt:    admin.firestore.FieldValue.serverTimestamp(),
    });
    console.log(`  ✅ ${user.displayName}`);
  }
  await userBatch.commit();

  // ── Create seed posts ────────────────────────────────────────────────────
  console.log(`\n📝 Creating ${SEED_POSTS.length} seed posts...`);

  // Firestore batches max 500 writes — split if needed
  const chunkSize = 490;
  for (let i = 0; i < SEED_POSTS.length; i += chunkSize) {
    const chunk = SEED_POSTS.slice(i, i + chunkSize);
    const batch = db.batch();
    for (const post of chunk) {
      const user = SEED_USERS[post.userIdx % SEED_USERS.length];
      const ref  = db.collection('posts').doc();
      batch.set(ref, {
        userId:       user.id,
        username:     user.displayName,
        userAvatar:   user.avatar,
        type:         'run_activity',
        isSeed:       true,
        content:      post.content,
        mapImageUrl:  post.mapImageUrl || null,
        distance:     post.distance    || null,
        pace:         post.pace        || null,
        bpm:          post.bpm         || null,
        planTitle:    post.planTitle   || null,
        tags:         post.tags        || [],
        likes:        [],
        likeCount:    post.likeCount   || 0,
        commentCount: post.commentCount || 0,
        routePoints:  [],
        createdAt:    daysAgo(post.daysAgo || 0),
      });
      console.log(`  ✅ ${post.content.substring(0, 55)}...`);
    }
    await batch.commit();
  }

  console.log(`\n${'─'.repeat(50)}`);
  console.log(`✅ ${SEED_USERS.length} users + ${SEED_POSTS.length} posts seeded`);
  console.log(`${'─'.repeat(50)}`);
  console.log('\n✨ Done! Open the app — the feed should now look alive.');
  process.exit(0);
}

main().catch(err => {
  console.error('💥 Fatal error:', err);
  process.exit(1);
});
