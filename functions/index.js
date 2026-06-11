const { onDocumentCreated, onDocumentDeleted } = require("firebase-functions/v2/firestore");
const { initializeApp } = require("firebase-admin/app");
const { getFirestore } = require("firebase-admin/firestore");
const { getMessaging } = require("firebase-admin/messaging");

initializeApp();

/**
 * Triggered whenever a new document is created in the Matches collection.
 * Sends a push notification to both the Lost reporter (owner) and the
 * Found reporter (finder) if they have an FCM token stored in their
 * Users/{uid} document.
 */
exports.notifyOnMatch = onDocumentCreated("Matches/{matchId}", async (event) => {
  const matchId = event.params.matchId;
  const data = event.data.data();

  const uid1 = data.uid1;   // Lost reporter
  const uid2 = data.uid2;   // Found reporter
  const category = data.category || "item";

  const db = getFirestore();

  // Fetch both user docs in parallel
  const [user1Snap, user2Snap] = await Promise.all([
    db.collection("Users").doc(uid1).get(),
    db.collection("Users").doc(uid2).get(),
  ]);

  const token1 = user1Snap.data()?.fcmToken;
  const token2 = user2Snap.data()?.fcmToken;

  const messages = [];

  if (token1) {
    messages.push({
      token: token1,
      notification: {
        title: "Item Match Found!",
        body: `Your lost ${category} may have been found. Tap to view your matches.`,
      },
      data: { matchId },
      android: {
        notification: {
          channelId: "match_notifications",
          priority: "high",
          sound: "default",
        },
      },
      apns: {
        payload: { aps: { sound: "default", badge: 1 } },
      },
    });
  }

  if (token2) {
    messages.push({
      token: token2,
      notification: {
        title: "Item Match Found!",
        body: `A ${category} you found matches a lost report. Tap to coordinate the return.`,
      },
      data: { matchId },
      android: {
        notification: {
          channelId: "match_notifications",
          priority: "high",
          sound: "default",
        },
      },
      apns: {
        payload: { aps: { sound: "default", badge: 1 } },
      },
    });
  }

  if (messages.length === 0) return null;

  const response = await getMessaging().sendEach(messages);
  console.log(
    `Match ${matchId}: sent ${response.successCount} notification(s), ` +
    `${response.failureCount} failure(s).`
  );
  return null;
});

/**
 * Triggered whenever a Reports document is deleted (including manual deletes
 * from the Firestore Console). Finds every Match that referenced the deleted
 * report, resets the counterpart report's status back to 'pending' so it can
 * be matched again, then deletes the Match and its associated Chat + Messages.
 */
exports.onReportDeleted = onDocumentDeleted("Reports/{reportId}", async (event) => {
  const deletedReportId = event.params.reportId;
  const db = getFirestore();

  // Find all matches that reference this report (in either position)
  const [q1, q2] = await Promise.all([
    db.collection("Matches").where("reportId1", "==", deletedReportId).limit(50).get(),
    db.collection("Matches").where("reportId2", "==", deletedReportId).limit(50).get(),
  ]);

  const allMatches = new Map();
  q1.docs.forEach((d) => allMatches.set(d.id, d));
  q2.docs.forEach((d) => allMatches.set(d.id, d));

  if (allMatches.size === 0) return null;

  const batch = db.batch();

  for (const [matchId, matchDoc] of allMatches) {
    const matchData = matchDoc.data();

    // Determine which report is the surviving counterpart
    const counterpartId =
      matchData.reportId1 === deletedReportId
        ? matchData.reportId2
        : matchData.reportId1;

    // Reset counterpart report status to 'pending' so it can be matched again
    if (counterpartId) {
      const counterpartRef = db.collection("Reports").doc(counterpartId);
      batch.update(counterpartRef, { status: "pending" });
    }

    // Delete associated Chat and its Messages subcollection
    const chatId = matchData.chatId;
    if (chatId) {
      // Delete all messages first (subcollections must be deleted individually)
      const messages = await db
        .collection("Chats")
        .doc(chatId)
        .collection("Messages")
        .get();
      messages.docs.forEach((msg) => batch.delete(msg.ref));
      batch.delete(db.collection("Chats").doc(chatId));
    }

    // Delete the Match document itself
    batch.delete(matchDoc.ref);
  }

  await batch.commit();
  console.log(
    `Report ${deletedReportId} deleted — cleaned up ${allMatches.size} match(es).`
  );
  return null;
});
