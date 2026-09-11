/**
 * Local Developer Notification Worker
 * Runs locally to process notifications_queue items using the service account key
 * without needing Cloud Functions deployment.
 * 
 * Usage: node scripts/local_notification_worker.js
 */

const admin = require("firebase-admin");
const path = require("path");
const fs = require("fs");

const serviceAccountPath = path.join(__dirname, "..", "assets", "instructor-1d9b7-firebase-adminsdk-fbsvc-b8dc74fa8a.json");

if (fs.existsSync(serviceAccountPath)) {
  const serviceAccount = require(serviceAccountPath);
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount),
  });
  console.log("Firebase Admin initialized with local service account.");

  const db = admin.firestore();
  console.log("Listening for queued notifications in 'notifications_queue'...");

  db.collection("notifications_queue")
    .where("status", "==", "pending")
    .onSnapshot((snapshot) => {
      snapshot.docChanges().forEach(async (change) => {
        if (change.type === "added") {
          const data = change.doc.data();
          console.log(`Processing notification [${change.doc.id}]:`, data.title);
          // In local test mode, mark as sent
          await change.doc.ref.update({
            status: "sent",
            processedAt: admin.firestore.FieldValue.serverTimestamp(),
          });
          console.log(`Notification [${change.doc.id}] marked as sent.`);
        }
      });
    });
} else {
  console.log("Service account file not found. Cloud Functions will handle production.");
}
