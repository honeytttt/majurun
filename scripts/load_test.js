/**
 * MajuRun Load / Stress Test
 * ─────────────────────────────────────────────────────────────────────────────
 * Simulates N concurrent virtual users performing real Firestore operations:
 *   • Read the feed (latest 20 posts)
 *   • Create a new post
 *   • Like a random existing post
 *   • Add a comment
 *   • Read run history
 *
 * Requirements
 *   node >= 18
 *   npm install firebase-admin
 *
 * Setup
 *   1. Go to Firebase Console → Project Settings → Service Accounts
 *   2. Click "Generate new private key" → download JSON
 *   3. Place it at scripts/serviceAccountKey.json  (DO NOT commit this file)
 *   4. Set PROJECT_ID below or export FIREBASE_PROJECT_ID=your-project-id
 *
 * Usage
 *   node scripts/load_test.js --users 10
 *   node scripts/load_test.js --users 50
 *   node scripts/load_test.js --users 100 --ramp 5
 *
 * Options
 *   --users  N       number of concurrent virtual users  (default: 10)
 *   --ramp   S       ramp-up in seconds: add 1 user every S sec (default: 0)
 *   --think  MS      think time between operations in ms  (default: 500)
 */

const admin = require('firebase-admin');
const path  = require('path');

// ─── CONFIG ──────────────────────────────────────────────────────────────────
const PROJECT_ID = process.env.FIREBASE_PROJECT_ID || 'YOUR_PROJECT_ID';
const KEY_PATH   = path.join(__dirname, 'serviceAccountKey.json');

const args       = parseArgs(process.argv.slice(2));
const NUM_USERS  = parseInt(args.users  ?? 10);
const RAMP_SEC   = parseInt(args.ramp   ?? 0);
const THINK_MS   = parseInt(args.think  ?? 500);

// ─── INIT ─────────────────────────────────────────────────────────────────────
admin.initializeApp({
  credential: admin.credential.cert(KEY_PATH),
  projectId:  PROJECT_ID,
});
const db = admin.firestore();

// ─── METRICS ─────────────────────────────────────────────────────────────────
const results = {
  readFeed:    [],
  createPost:  [],
  likePost:    [],
  addComment:  [],
  readHistory: [],
  errors:      0,
};

// ─── OPERATIONS ──────────────────────────────────────────────────────────────
async function readFeed() {
  const t = Date.now();
  await db.collection('posts').orderBy('createdAt', 'desc').limit(20).get();
  return Date.now() - t;
}

async function createPost(userId, username) {
  const t = Date.now();
  await db.collection('posts').add({
    userId,
    username,
    content:   `Load test post by ${username} at ${new Date().toISOString()}`,
    media:     [],
    likes:     [],
    type:      'regular',
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  });
  return Date.now() - t;
}

async function likePost(userId) {
  const t = Date.now();
  // Pick a random post from first page
  const snap = await db.collection('posts').limit(10).get();
  if (snap.empty) return Date.now() - t;
  const doc = snap.docs[Math.floor(Math.random() * snap.docs.length)];
  await db.runTransaction(async (tx) => {
    const post  = await tx.get(doc.ref);
    const likes = Array.from(new Set([...(post.data().likes ?? []), userId]));
    tx.update(doc.ref, { likes });
  });
  return Date.now() - t;
}

async function addComment(userId, username) {
  const t = Date.now();
  const snap = await db.collection('posts').limit(5).get();
  if (snap.empty) return Date.now() - t;
  const doc = snap.docs[Math.floor(Math.random() * snap.docs.length)];
  await doc.ref.collection('comments').add({
    userId,
    username,
    content:   `Test comment from ${username}`,
    likes:     [],
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  });
  return Date.now() - t;
}

async function readRunHistory(userId) {
  const t = Date.now();
  await db.collection('users').doc(userId)
    .collection('runs').orderBy('createdAt', 'desc').limit(10).get();
  return Date.now() - t;
}

// ─── VIRTUAL USER ─────────────────────────────────────────────────────────────
async function virtualUser(id) {
  const userId   = `load_test_user_${id}`;
  const username = `TestRunner${id}`;

  try {
    results.readFeed.push(   await readFeed());
    await sleep(THINK_MS);
    results.createPost.push( await createPost(userId, username));
    await sleep(THINK_MS);
    results.likePost.push(   await likePost(userId));
    await sleep(THINK_MS);
    results.addComment.push( await addComment(userId, username));
    await sleep(THINK_MS);
    results.readHistory.push(await readRunHistory(userId));
  } catch (e) {
    results.errors++;
    console.error(`  ⚠️  User ${id} error: ${e.message}`);
  }
}

// ─── MAIN ────────────────────────────────────────────────────────────────────
async function main() {
  console.log(`\n🚀 MajuRun Load Test`);
  console.log(`   Users: ${NUM_USERS}  |  Ramp: ${RAMP_SEC}s  |  Think: ${THINK_MS}ms\n`);

  const startTime = Date.now();
  const promises  = [];

  for (let i = 1; i <= NUM_USERS; i++) {
    promises.push(virtualUser(i));
    if (RAMP_SEC > 0 && i < NUM_USERS) {
      await sleep((RAMP_SEC * 1000) / NUM_USERS);
    }
    process.stdout.write(`\r  Starting user ${i}/${NUM_USERS}...`);
  }

  await Promise.all(promises);
  const totalMs = Date.now() - startTime;

  // ─── REPORT ────────────────────────────────────────────────────────────────
  console.log(`\n\n${'─'.repeat(60)}`);
  console.log(`  TEST RESULTS  (${NUM_USERS} users, ${(totalMs/1000).toFixed(1)}s total)`);
  console.log(`${'─'.repeat(60)}`);

  const ops = [
    ['Read Feed',    results.readFeed],
    ['Create Post',  results.createPost],
    ['Like Post',    results.likePost],
    ['Add Comment',  results.addComment],
    ['Read History', results.readHistory],
  ];

  console.log(`  ${'Operation'.padEnd(16)} ${'p50'.padStart(6)} ${'p95'.padStart(6)} ${'p99'.padStart(6)} ${'Max'.padStart(6)} ${'Errors'.padStart(8)}`);
  console.log(`  ${'─'.repeat(56)}`);

  for (const [name, times] of ops) {
    if (!times.length) continue;
    times.sort((a, b) => a - b);
    const p50 = percentile(times, 50);
    const p95 = percentile(times, 95);
    const p99 = percentile(times, 99);
    const max = times[times.length - 1];
    console.log(`  ${name.padEnd(16)} ${fmt(p50)} ${fmt(p95)} ${fmt(p99)} ${fmt(max)}`);
  }

  console.log(`${'─'.repeat(60)}`);
  console.log(`  Total errors: ${results.errors} / ${NUM_USERS * 5} operations`);

  const successRate = (((NUM_USERS * 5 - results.errors) / (NUM_USERS * 5)) * 100).toFixed(1);
  console.log(`  Success rate: ${successRate}%`);

  const rating = successRate >= 99 ? '✅ EXCELLENT' :
                 successRate >= 95 ? '⚠️  ACCEPTABLE' : '❌ NEEDS WORK';
  console.log(`  Result: ${rating}\n`);

  // Cleanup: delete all test posts created
  console.log('  🧹 Cleaning up test data...');
  const testPosts = await db.collection('posts')
    .where('content', '>=', 'Load test post')
    .where('content', '<', 'Load test post\uffff')
    .get();
  const batch = db.batch();
  testPosts.docs.forEach(d => batch.delete(d.ref));
  await batch.commit();
  console.log(`  Deleted ${testPosts.size} test posts.\n`);

  await admin.app().delete();
}

// ─── HELPERS ─────────────────────────────────────────────────────────────────
function sleep(ms) { return new Promise(r => setTimeout(r, ms)); }
function percentile(sorted, p) { return sorted[Math.floor(sorted.length * p / 100)] ?? 0; }
function fmt(ms) { return `${ms}ms`.padStart(6); }
function parseArgs(argv) {
  const out = {};
  for (let i = 0; i < argv.length; i += 2) {
    out[argv[i].replace('--', '')] = argv[i + 1];
  }
  return out;
}

main().catch(e => { console.error(e); process.exit(1); });
