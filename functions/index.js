// functions/index.js
const { onCall, HttpsError } = require("firebase-functions/v2/https");
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