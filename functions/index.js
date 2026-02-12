// functions/index.js
const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { logger } = require("firebase-functions/v2");
const { RecaptchaEnterpriseServiceClient } = require('@google-cloud/recaptcha-enterprise');

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