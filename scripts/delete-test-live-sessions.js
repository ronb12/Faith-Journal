#!/usr/bin/env node
/**
 * Delete all live session documents from Firebase Firestore.
 * Use for clearing test data. Run from project root.
 *
 * Prerequisites:
 *   1. Service account key: Firebase Console → Project Settings → Service accounts
 *      → Generate new private key. Save as e.g. service-account-key.json in project root
 *      (add to .gitignore).
 *   2. Set env: export GOOGLE_APPLICATION_CREDENTIALS="$(pwd)/service-account-key.json"
 *   Or: gcloud auth application-default login (if using gcloud)
 *
 * Run: node scripts/delete-test-live-sessions.js
 * Or:  GOOGLE_APPLICATION_CREDENTIALS=./service-account-key.json node scripts/delete-test-live-sessions.js
 */

const path = require('path');
const admin = require(path.join(__dirname, '../functions/node_modules/firebase-admin'));

const PROJECT_ID = 'faith-journal-d2a32';

async function deleteAllDocsInCollection(db, colRef, batchSize = 100) {
  const snapshot = await colRef.limit(batchSize).get();
  if (snapshot.empty) return 0;
  const batch = db.batch();
  snapshot.docs.forEach((doc) => batch.delete(doc.ref));
  await batch.commit();
  return snapshot.size + (await deleteAllDocsInCollection(db, colRef, batchSize));
}

async function deleteSessionSubcollections(db, sessionId) {
  const sessionRef = db.collection('sessions').doc(sessionId);
  const subcollections = await sessionRef.listCollections();
  let total = 0;
  for (const sub of subcollections) {
    total += await deleteAllDocsInCollection(db, sub);
  }
  return total;
}

async function main() {
  if (!admin.apps.length) {
    try {
      admin.initializeApp({ projectId: PROJECT_ID });
    } catch (e) {
      console.error('Initialize failed. Set GOOGLE_APPLICATION_CREDENTIALS or run gcloud auth application-default login.');
      process.exit(1);
    }
  }
  const db = admin.firestore();

  console.log('Listing liveSessions...');
  const liveSnap = await db.collection('liveSessions').get();
  const sessionIds = liveSnap.docs.map((d) => d.id);
  console.log(`Found ${sessionIds.length} live session(s).`);

  let deletedLive = 0;
  let deletedPublic = 0;
  let deletedSessions = 0;

  for (const sessionId of sessionIds) {
    // Delete sessions/{sessionId} subcollections (messages, participants, presentation) then doc
    const sessionRef = db.collection('sessions').doc(sessionId);
    const sessionSnap = await sessionRef.get();
    if (sessionSnap.exists) {
      await deleteSessionSubcollections(db, sessionId);
      await sessionRef.delete();
      deletedSessions += 1;
    }

    // Delete liveSessions doc
    await db.collection('liveSessions').doc(sessionId).delete();
    deletedLive += 1;

    // Delete publicSessions doc if exists
    const publicRef = db.collection('publicSessions').doc(sessionId);
    const publicSnap = await publicRef.get();
    if (publicSnap.exists) {
      await publicRef.delete();
      deletedPublic += 1;
    }
  }

  console.log(`Deleted: ${deletedLive} liveSessions, ${deletedPublic} publicSessions, ${deletedSessions} sessions docs.`);
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
