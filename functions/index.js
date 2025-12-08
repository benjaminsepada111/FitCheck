const functions = require('firebase-functions');
const admin = require('firebase-admin');

admin.initializeApp();

const COOLDOWN_SECONDS = 200; // 200 seconds cooldown
const MAX_RESENDS_PER_HOUR = 5; // Maximum 5 resends per hour per email
const RATE_LIMIT_WINDOW_MS = 60 * 60 * 1000; // 1 hour in milliseconds

/**
 * Resend verification email with rate limiting and cooldown enforcement
 */
exports.resendVerificationEmail = functions.https.onCall(async (data, context) => {
  // Verify user is authenticated
  if (!context.auth) {
    throw new functions.https.HttpsError(
      'unauthenticated',
      'User must be authenticated to resend verification email'
    );
  }

  const userId = context.auth.uid;
  const userEmail = context.auth.token.email || data.email;

  if (!userEmail) {
    throw new functions.https.HttpsError(
      'invalid-argument',
      'Email is required'
    );
  }

  try {
    // Get user document from Firestore
    const userDocRef = admin.firestore().collection('emailVerificationLimits').doc(userId);
    const userDoc = await userDocRef.get();
    const now = admin.firestore.Timestamp.now();
    const nowMs = Date.now();

    let userData = userDoc.exists ? userDoc.data() : null;
    let resendHistory = userData?.resendHistory || [];
    let lastResendTime = userData?.lastResendTime || null;

    // Check cooldown period
    if (lastResendTime) {
      const lastResendMs = lastResendTime.toMillis();
      const timeSinceLastResend = nowMs - lastResendMs;
      const cooldownMs = COOLDOWN_SECONDS * 1000;

      if (timeSinceLastResend < cooldownMs) {
        const remainingCooldown = Math.ceil((cooldownMs - timeSinceLastResend) / 1000);
        return {
          success: false,
          error: 'cooldown',
          remainingCooldownSeconds: remainingCooldown,
          message: `Please wait ${remainingCooldown} seconds before resending`
        };
      }
    }

    // Check rate limiting (max 5 resends per hour)
    const oneHourAgo = nowMs - RATE_LIMIT_WINDOW_MS;
    resendHistory = resendHistory.filter(timestamp => timestamp.toMillis() > oneHourAgo);

    if (resendHistory.length >= MAX_RESENDS_PER_HOUR) {
      const oldestResend = resendHistory[0].toMillis();
      const waitTime = Math.ceil((oldestResend + RATE_LIMIT_WINDOW_MS - nowMs) / 1000);
      return {
        success: false,
        error: 'rate_limit',
        remainingCooldownSeconds: waitTime,
        message: `Rate limit exceeded. Maximum ${MAX_RESENDS_PER_HOUR} resends per hour. Please wait ${Math.ceil(waitTime / 60)} minutes.`
      };
    }

    // Verify user exists and email matches
    const userRecord = await admin.auth().getUser(userId);
    if (userRecord.email !== userEmail) {
      throw new functions.https.HttpsError(
        'permission-denied',
        'Email does not match authenticated user'
      );
    }

    // Check if email is already verified
    if (userRecord.emailVerified) {
      return {
        success: false,
        error: 'already_verified',
        message: 'Email is already verified'
      };
    }

    // Update Firestore with new resend attempt BEFORE sending email
    // This prevents race conditions if user tries to resend from multiple tabs
    resendHistory.push(now);
    
    await userDocRef.set({
      email: userEmail,
      lastResendTime: now,
      resendHistory: resendHistory,
      updatedAt: now
    }, { merge: true });

    // Return success with cooldown info and link
    // Note: The client will use Firebase Auth SDK to send the email
    // We're just enforcing rate limits and cooldown here
    return {
      success: true,
      remainingCooldownSeconds: COOLDOWN_SECONDS,
      message: 'Rate limit check passed. You can now send the verification email.'
    };

  } catch (error) {
    console.error('Error resending verification email:', error);
    throw new functions.https.HttpsError(
      'internal',
      'Failed to resend verification email',
      error.message
    );
  }
});

/**
 * Get remaining cooldown time for verification email resend
 */
exports.getVerificationCooldown = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError(
      'unauthenticated',
      'User must be authenticated'
    );
  }

  const userId = context.auth.uid;
  const userDocRef = admin.firestore().collection('emailVerificationLimits').doc(userId);
  const userDoc = await userDocRef.get();

  if (!userDoc.exists || !userDoc.data()?.lastResendTime) {
    return {
      remainingCooldownSeconds: 0,
      canResend: true
    };
  }

  const lastResendTime = userDoc.data().lastResendTime.toMillis();
  const nowMs = Date.now();
  const timeSinceLastResend = nowMs - lastResendTime;
  const cooldownMs = COOLDOWN_SECONDS * 1000;

  if (timeSinceLastResend >= cooldownMs) {
    return {
      remainingCooldownSeconds: 0,
      canResend: true
    };
  }

  const remainingCooldown = Math.ceil((cooldownMs - timeSinceLastResend) / 1000);
  return {
    remainingCooldownSeconds: remainingCooldown,
    canResend: false
  };
});

