const functions = require("firebase-functions");
const admin = require("firebase-admin");

admin.initializeApp();

/**
 * Cloud Function triggered when a notification is queued by an authorized teacher.
 * Dispatches via FCM HTTP v1 using Firebase Admin SDK in a trusted server environment.
 */
exports.dispatchQueuedNotification = functions.firestore
  .document("notifications_queue/{notificationId}")
  .onCreate(async (snap, context) => {
    const data = snap.data();
    if (!data || data.status !== "pending") return null;

    const { targetType, targetId, title, body, dataPayload } = data;

    try {
      let message = {
        notification: {
          title: title,
          body: body,
        },
        data: dataPayload || {},
      };

      if (targetType === "all") {
        // Send to global student topic
        message.topic = "all_students";
        await admin.messaging().send(message);
      } else if (targetType === "course" && targetId) {
        // Send to specific course topic
        message.topic = `course_${targetId}`;
        await admin.messaging().send(message);
      } else if (targetType === "student" && targetId) {
        // Send to specific student's registered FCM tokens
        const userDoc = await admin.firestore().collection("users").doc(targetId).get();
        if (userDoc.exists) {
          const tokens = userDoc.data().fcmTokens || [];
          if (tokens.length > 0) {
            const multicastMessage = {
              notification: { title, body },
              data: dataPayload || {},
              tokens: tokens,
            };
            await admin.messaging().sendEachForMulticast(multicastMessage);
          }
        }
      }

      // Mark as processed in Firestore
      return snap.ref.update({
        status: "sent",
        processedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    } catch (error) {
      console.error("Error dispatching FCM notification:", error);
      return snap.ref.update({
        status: "failed",
        error: error.message,
        processedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    }
  });
