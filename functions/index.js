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

// Admin check via Firebase Custom Claim only.
// Grant via: admin.auth().setCustomUserClaims(uid, { admin: true })
function requireAdmin(request) {
  if (!request.auth || request.auth.token.admin !== true) {
    throw new HttpsError("permission-denied", "Admin only.");
  }
}

// Delete a user: Firebase Auth + all Firestore data
exports.adminDeleteUser = onCall(
  { region: "asia-southeast1" },
  async (request) => {
    requireAdmin(request);
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
    requireAdmin(request);
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

// ─── SUBSCRIPTION VERIFICATION ───────────────────────────────────────────────
// Validates an IAP receipt server-side and writes entitlement to Firestore.
// The client sends the raw verificationData; this function is the ONLY place
// that writes isPro=true — the client never writes entitlement directly.
//
// Setup required (run once, secrets never go in code):
//   iOS:   firebase functions:secrets:set APPLE_SHARED_SECRET
//   Android: grant the service account billing.readonly on Play Console,
//            then firebase functions:secrets:set GOOGLE_PLAY_PACKAGE
//
exports.verifySubscription = onCall(
  { region: "asia-southeast1" },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Must be logged in.");
    }

    const { productId, purchaseToken, receiptData, platform } = request.data;
    if (!productId || !platform) {
      throw new HttpsError("invalid-argument", "productId and platform required.");
    }

    const uid = request.auth.uid;
    const db = admin.firestore();

    let isValid = false;
    let expiryDate = null;

    if (platform === "android") {
      // ── Android: validate via Google Play Developer API ──────────────────
      // Requires Google service account with Subscriptions.readonly permission.
      // purchaseToken comes from PurchaseDetails.verificationData.serverVerificationData
      if (!purchaseToken) throw new HttpsError("invalid-argument", "purchaseToken required for Android.");

      try {
        const { google } = require("googleapis");
        const auth = new google.auth.GoogleAuth({
          scopes: ["https://www.googleapis.com/auth/androidpublisher"],
        });
        const androidPublisher = google.androidpublisher({ version: "v3", auth });
        const packageName = process.env.GOOGLE_PLAY_PACKAGE;

        const result = await androidPublisher.purchases.subscriptions.get({
          packageName,
          subscriptionId: productId,
          token: purchaseToken,
        });

        const subscription = result.data;
        // paymentState 1 = received, 2 = free trial
        isValid = subscription.paymentState === 1 || subscription.paymentState === 2;
        if (isValid && subscription.expiryTimeMillis) {
          expiryDate = new Date(parseInt(subscription.expiryTimeMillis));
        }
      } catch (err) {
        logger.error("Android receipt validation failed", err);
        throw new HttpsError("internal", "Receipt validation failed.");
      }

    } else if (platform === "ios") {
      // ── iOS: validate via App Store receipt validation endpoint ───────────
      // receiptData = PurchaseDetails.verificationData.serverVerificationData (base64)
      if (!receiptData) throw new HttpsError("invalid-argument", "receiptData required for iOS.");

      try {
        const https = require("https");
        const sharedSecret = process.env.APPLE_SHARED_SECRET;

        const validateWithApple = (url) => new Promise((resolve, reject) => {
          const body = JSON.stringify({ "receipt-data": receiptData, "password": sharedSecret, "exclude-old-transactions": true });
          const options = {
            hostname: url,
            path: "/verifyReceipt",
            method: "POST",
            headers: { "Content-Type": "application/json", "Content-Length": Buffer.byteLength(body) },
          };
          const req = https.request(options, (res) => {
            let data = "";
            res.on("data", (chunk) => data += chunk);
            res.on("end", () => resolve(JSON.parse(data)));
          });
          req.on("error", reject);
          req.write(body);
          req.end();
        });

        let appleResponse = await validateWithApple("buy.itunes.apple.com");
        // Status 21007 = sandbox receipt sent to production endpoint → retry with sandbox
        if (appleResponse.status === 21007) {
          appleResponse = await validateWithApple("sandbox.itunes.apple.com");
        }
        if (appleResponse.status !== 0) {
          logger.warn("Apple receipt invalid, status:", appleResponse.status);
          throw new HttpsError("invalid-argument", "Receipt invalid.");
        }

        // Find the latest transaction for this product
        const latestReceipts = appleResponse.latest_receipt_info || [];
        const matching = latestReceipts
          .filter((r) => r.product_id === productId)
          .sort((a, b) => parseInt(b.expires_date_ms) - parseInt(a.expires_date_ms));

        if (matching.length > 0) {
          const latest = matching[0];
          expiryDate = new Date(parseInt(latest.expires_date_ms));
          isValid = expiryDate > new Date();
        }
      } catch (err) {
        if (err instanceof HttpsError) throw err;
        logger.error("iOS receipt validation failed", err);
        throw new HttpsError("internal", "Receipt validation failed.");
      }

    } else {
      throw new HttpsError("invalid-argument", `Unknown platform: ${platform}`);
    }

    if (!isValid) {
      logger.warn(`verifySubscription: invalid receipt for uid=${uid} product=${productId}`);
      return { success: false, reason: "Receipt invalid or expired." };
    }

    // ── Trusted write: only Cloud Function grants entitlement ────────────────
    const isYearly = productId.includes("yearly") || productId.includes("annual");
    await db.collection("users").doc(uid).update({
      isPro: true,
      subscriptionType: isYearly ? "yearly" : "monthly",
      subscriptionExpiry: expiryDate ? admin.firestore.Timestamp.fromDate(expiryDate) : null,
      entitlementSource: "server_verified",
      lastVerifiedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    logger.info(`verifySubscription: granted Pro to uid=${uid} product=${productId} expiry=${expiryDate}`);
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