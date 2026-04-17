// functions/index.js
const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { onSchedule } = require("firebase-functions/v2/scheduler");
const { logger } = require("firebase-functions/v2");
const { RecaptchaEnterpriseServiceClient } = require('@google-cloud/recaptcha-enterprise');
const admin = require("firebase-admin");

if (!admin.apps.length) {
  admin.initializeApp();
}

// Optional: keep your global options if you want
const { setGlobalOptions } = require("firebase-functions/v2");
setGlobalOptions({ maxInstances: 10 });

const client = new RecaptchaEnterpriseServiceClient();

exports.verifyRecaptcha = onCall(
  {
    region: "asia-southeast1",           // Good choice for Singapore
    // memory: "256MB",                  // optional - uncomment if you need more memory
    // timeoutSeconds: 60,               // optional
  },
  async (request) => {
    const { token, action } = request.data;

    if (!token || !action) {
      throw new HttpsError("invalid-argument", "Token and action are required.");
    }

    try {
      // ───────────────────────────────────────────────
      // VERY IMPORTANT: Replace this with your REAL project ID
      // Find it here: https://console.cloud.google.com/
      // (top bar → project selector)
      const projectId = "majurun-8d8b5";
      // ───────────────────────────────────────────────

      const projectPath = client.projectPath(projectId);

      const [assessment] = await client.createAssessment({
        parent: projectPath,
        assessment: {
          event: {
            token: token,
            siteKey: "6LfJE2gsAAAAAP2xeAzsC95tz7jAzim7wAjtarF0",
            expectedAction: action,
          },
        },
      });

      if (!assessment.tokenProperties.valid) {
        logger.warn("Invalid reCAPTCHA token", {
          tokenProperties: assessment.tokenProperties,
        });
        return {
          valid: false,
          score: 0.0,
          reason: "Invalid or expired token",
        };
      }

      const score = assessment.riskAnalysis?.score ?? 0.0;

      logger.info(`reCAPTCHA assessment`, {
        action,
        score,
        reasons: assessment.riskAnalysis?.reasons || [],
      });

      return {
        valid: score >= 0.3,          // ← adjust this threshold if needed
        score: score,
      };
    } catch (error) {
      logger.error("reCAPTCHA verification failed", error);
      throw new HttpsError("internal", "reCAPTCHA verification failed");
    }
  }
);

const ADMIN_EMAIL = "majurun.app@gmail.com";

// Delete a user: Firebase Auth + all Firestore data
exports.adminDeleteUser = onCall(
  { region: "asia-southeast1" },
  async (request) => {
    if (!request.auth || request.auth.token.email !== ADMIN_EMAIL) {
      throw new HttpsError("permission-denied", "Admin only.");
    }
    const { uid } = request.data;
    if (!uid) throw new HttpsError("invalid-argument", "uid required.");

    const db = admin.firestore();
    const userRef = db.collection("users").doc(uid);

    // Delete subcollections
    const subcollections = ["runHistory", "routes", "shoes", "goals", "settings", "training_history", "followers", "following", "blockedUsers"];
    for (const sub of subcollections) {
      const snap = await userRef.collection(sub).get();
      const batch = db.batch();
      snap.docs.forEach((d) => batch.delete(d.ref));
      if (!snap.empty) await batch.commit();
    }

    // Delete user's posts
    const postsSnap = await db.collection("posts").where("userId", "==", uid).get();
    for (const postDoc of postsSnap.docs) {
      // Delete post comments
      const commentsSnap = await postDoc.ref.collection("comments").get();
      const batch = db.batch();
      commentsSnap.docs.forEach((c) => batch.delete(c.ref));
      batch.delete(postDoc.ref);
      await batch.commit();
    }

    // Delete Firestore user doc
    await userRef.delete();

    // Delete Firebase Auth account
    try {
      await admin.auth().deleteUser(uid);
    } catch (e) {
      logger.warn("Auth delete failed (may not exist):", e.message);
    }

    logger.info(`Admin deleted user ${uid}`);
    return { success: true };
  }
);

// Delete a single post + its comments
exports.adminDeletePost = onCall(
  { region: "asia-southeast1" },
  async (request) => {
    if (!request.auth || request.auth.token.email !== ADMIN_EMAIL) {
      throw new HttpsError("permission-denied", "Admin only.");
    }
    const { postId } = request.data;
    if (!postId) throw new HttpsError("invalid-argument", "postId required.");

    const db = admin.firestore();
    const postRef = db.collection("posts").doc(postId);

    const commentsSnap = await postRef.collection("comments").get();
    const batch = db.batch();
    commentsSnap.docs.forEach((c) => batch.delete(c.ref));
    batch.delete(postRef);
    await batch.commit();

    logger.info(`Admin deleted post ${postId}`);
    return { success: true };
  }
);

// ─── DAILY SEED POST SCHEDULER ────────────────────────────────────────────────
// Runs daily at 08:00 Asia/Kuala_Lumpur (00:00 UTC).
// Creates 1–3 posts from seed users using motivational cards, memes, or
// education cards from Cloudinary.  All posts get isSeed: true so they can
// be filtered / wiped independently.

const SEED_USERS = [
  { uid: 'seed_user_01', username: 'Ahmad Razif', avatarUrl: 'https://res.cloudinary.com/ddo14sbqv/image/upload/majurun/seed/avatars/01.jpg' },
  { uid: 'seed_user_02', username: 'Nurul Ain',   avatarUrl: 'https://res.cloudinary.com/ddo14sbqv/image/upload/majurun/seed/avatars/02.jpg' },
  { uid: 'seed_user_03', username: 'Hafiz Kamal', avatarUrl: 'https://res.cloudinary.com/ddo14sbqv/image/upload/majurun/seed/avatars/03.jpg' },
  { uid: 'seed_user_04', username: 'Siti Hajar',  avatarUrl: 'https://res.cloudinary.com/ddo14sbqv/image/upload/majurun/seed/avatars/04.jpg' },
  { uid: 'seed_user_05', username: 'Danial Arif', avatarUrl: 'https://res.cloudinary.com/ddo14sbqv/image/upload/majurun/seed/avatars/05.jpg' },
  { uid: 'seed_user_06', username: 'Aini Razak',  avatarUrl: 'https://res.cloudinary.com/ddo14sbqv/image/upload/majurun/seed/avatars/06.jpg' },
  { uid: 'seed_user_07', username: 'Izzatul Husna', avatarUrl: 'https://res.cloudinary.com/ddo14sbqv/image/upload/majurun/seed/avatars/07.jpg' },
  { uid: 'seed_user_08', username: 'Rizwan Shah', avatarUrl: 'https://res.cloudinary.com/ddo14sbqv/image/upload/majurun/seed/avatars/08.jpg' },
  { uid: 'seed_user_09', username: 'Farhana Zain', avatarUrl: 'https://res.cloudinary.com/ddo14sbqv/image/upload/majurun/seed/avatars/09.jpg' },
  { uid: 'seed_user_10', username: 'Khairul Nizam', avatarUrl: 'https://res.cloudinary.com/ddo14sbqv/image/upload/majurun/seed/avatars/10.jpg' },
  { uid: 'seed_user_11', username: 'Lim Mei Ling', avatarUrl: 'https://res.cloudinary.com/ddo14sbqv/image/upload/majurun/seed/avatars/11.jpg' },
  { uid: 'seed_user_12', username: 'Kavitha Nair', avatarUrl: 'https://res.cloudinary.com/ddo14sbqv/image/upload/majurun/seed/avatars/12.jpg' },
];

// 30 motivational cards
const MOTIVATIONAL_CARDS = Array.from({ length: 30 }, (_, i) => {
  const n = String(i + 1).padStart(2, '0');
  return `https://res.cloudinary.com/ddo14sbqv/image/upload/majurun/motivational/cards/card_${n}.jpg`;
});

// 20 education cards
const EDU_TOPICS = [
  'edu_breathing_01', 'edu_cadence_01', 'edu_gear_01', 'edu_heat_01',
  'edu_hills_01', 'edu_injury_01', 'edu_injury_02', 'edu_mental_01',
  'edu_mental_02', 'edu_nutrition_01', 'edu_nutrition_02', 'edu_pacing_01',
  'edu_race_day_01', 'edu_recovery_01', 'edu_recovery_02', 'edu_running_form_01',
  'edu_running_form_02', 'edu_training_01', 'edu_training_02', 'edu_warmup_01',
];
const EDU_CARDS = EDU_TOPICS.map(t =>
  `https://res.cloudinary.com/ddo14sbqv/image/upload/majurun/education/cards/${t}.jpg`
);

// Meme cards (reuse motivational for now — replace with actual meme URLs when available)
const MEME_CARDS = Array.from({ length: 20 }, (_, i) => {
  const n = String(i + 1).padStart(2, '0');
  return `https://res.cloudinary.com/ddo14sbqv/image/upload/majurun/motivational/cards/card_${n}.jpg`;
});

const MOTIVATIONAL_CAPTIONS = [
  "Every run starts with a single step. Keep going! 💪",
  "Your only competition is who you were yesterday. 🏃",
  "Rain or shine, we run. 🌧️",
  "The finish line is just the beginning. 🏁",
  "Progress, not perfection. One km at a time. 🌟",
  "Lace up. Show up. Never give up. 👟",
  "Some days the run feels easy. Some days it doesn't. Both days count. ✅",
  "Strong legs. Stronger mind. 🧠",
  "Run like nobody's watching. 🎯",
  "The hardest part is starting. After that, it's all heart. ❤️",
];

const EDU_CAPTIONS = [
  "Did you know? Proper breathing can improve your pace by up to 15%. 🫁",
  "Cadence tip: aim for 170–180 steps per minute for better efficiency. 🎵",
  "Recovery is where gains happen. Don't skip rest days! 😴",
  "Hydration starts before your run, not during. Drink up! 💧",
  "Warm up for 5 minutes before every run — your joints will thank you. 🔥",
  "Core strength = better running posture. 10 min/day makes a difference. 🏋️",
  "Hill training builds power and mental toughness. Embrace the climb! ⛰️",
  "Nutrition tip: eat a light carb snack 30–60 min before a long run. 🍌",
];

function pick(arr) { return arr[Math.floor(Math.random() * arr.length)]; }

exports.dailySeedPosts = onSchedule(
  {
    schedule: "0 0 * * *",   // 00:00 UTC = 08:00 MYT
    timeZone: "UTC",
    region: "asia-southeast1",
  },
  async () => {
    const db = admin.firestore();
    const now = admin.firestore.Timestamp.now();

    // Pick 1–3 posts per day (keeps feed organic, not spammy)
    const count = Math.floor(Math.random() * 3) + 1;
    const batch = db.batch();

    for (let i = 0; i < count; i++) {
      const user = pick(SEED_USERS);
      const type = pick(['motivational', 'motivational', 'education', 'meme']); // 50% motivational

      let imageUrl, caption;
      if (type === 'education') {
        imageUrl = pick(EDU_CARDS);
        caption  = pick(EDU_CAPTIONS);
      } else if (type === 'meme') {
        imageUrl = pick(MEME_CARDS);
        caption  = pick(MOTIVATIONAL_CAPTIONS);
      } else {
        imageUrl = pick(MOTIVATIONAL_CARDS);
        caption  = pick(MOTIVATIONAL_CAPTIONS);
      }

      // Spread posts within the day (0–23h offset in seconds, staggered by i)
      const offsetSec = Math.floor(Math.random() * 72000) + i * 3600;
      const postTime  = new admin.firestore.Timestamp(
        now.seconds - offsetSec,
        now.nanoseconds
      );

      const ref = db.collection('posts').doc();
      batch.set(ref, {
        userId:      user.uid,
        username:    user.username,
        avatarUrl:   user.avatarUrl,
        content:     caption,
        mapImageUrl: imageUrl,
        routePoints: [],
        likes:       [],
        type:        type,
        isSeed:      true,
        createdAt:   postTime,
      });
    }

    await batch.commit();
    logger.info(`dailySeedPosts: created ${count} post(s)`);
  }
);