#!/usr/bin/env node
/**
 * Delete ALL live sessions in Firestore (entire liveSessions collection).
 * Requires: GOOGLE_APPLICATION_CREDENTIALS set to service account JSON path.
 * Run: node scripts/delete_all_live_sessions.js
 */

const admin = require('firebase-admin');

async function main() {
  if (!admin.apps.length) {
    admin.initializeApp({
      projectId: 'faith-journal-d2a32',
      credential: admin.credential.applicationDefault(),
    });
  }
  const db = admin.firestore();

  const snapshot = await db.collection('liveSessions').get();
  const count = snapshot.size;
  if (count === 0) {
    console.log('No live sessions to delete.');
    return;
  }

  console.log('Deleting', count, 'live session(s)...');
  const batch = db.batch();
  snapshot.docs.forEach((doc) => batch.delete(doc.ref));
  await batch.commit();
  console.log('Done. Deleted', count, 'live session(s).');
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
