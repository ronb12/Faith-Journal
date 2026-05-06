#!/usr/bin/env node
/**
 * Delete all live sessions in Firestore for a given user (by email).
 * Uses Firebase Admin SDK. Run from project root.
 *
 * Setup:
 *   1. npm install firebase-admin (or: cd scripts && npm install firebase-admin)
 *   2. Download a service account key: Firebase Console → Project Settings → Service accounts → Generate new private key
 *   3. Set path: export GOOGLE_APPLICATION_CREDENTIALS=/path/to/faith-journal-service-account.json
 *
 * Run:
 *   node scripts/delete_live_sessions_for_user.js ronellbradley@gmail.com
 *
 * Or with explicit key path:
 *   GOOGLE_APPLICATION_CREDENTIALS=./path/to/key.json node scripts/delete_live_sessions_for_user.js ronellbradley@gmail.com
 */

const admin = require('firebase-admin');
const email = process.argv[2] || 'ronellbradley@gmail.com';

if (!email || !email.includes('@')) {
  console.error('Usage: node delete_live_sessions_for_user.js <email>');
  process.exit(1);
}

async function main() {
  if (!admin.apps.length) {
    // Uses GOOGLE_APPLICATION_CREDENTIALS; projectId comes from the service account key
    const keyPath = process.env.GOOGLE_APPLICATION_CREDENTIALS;
    if (!keyPath) {
      console.error('Set GOOGLE_APPLICATION_CREDENTIALS to your Firebase service account JSON path.');
      process.exit(1);
    }
    admin.initializeApp({ credential: admin.credential.applicationDefault() });
  }
  const auth = admin.auth();
  const db = admin.firestore();

  console.log('Looking up user by email:', email);
  let uid;
  try {
    const user = await auth.getUserByEmail(email);
    uid = user.uid;
    console.log('Found UID:', uid);
  } catch (e) {
    console.error('No user found for that email:', e.message);
    process.exit(1);
  }

  const snapshot = await db.collection('liveSessions').where('hostId', '==', uid).get();
  const count = snapshot.size;
  if (count === 0) {
    console.log('No live sessions found for this user.');
    return;
  }

  console.log('Deleting', count, 'live session(s)...');
  const batch = db.batch();
  snapshot.docs.forEach((doc) => batch.delete(doc.ref));
  await batch.commit();
  console.log('Done. Deleted', count, 'live session(s) for', email);
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
