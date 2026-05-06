#!/usr/bin/env node
/**
 * One-time script: delete all Firestore liveSessions where hostId matches
 * the Firebase Auth UID for the given emails.
 *
 * Usage (from project root; uses Firebase CLI project from .firebaserc):
 *   npx firebase exec --only firestore -- node scripts/delete_live_sessions_by_email.js
 *   # OR with gcloud ADC (gcloud auth application-default login):
 *   node scripts/delete_live_sessions_by_email.js
 *   # OR with service account key:
 *   GOOGLE_APPLICATION_CREDENTIALS=key.json node scripts/delete_live_sessions_by_email.js
 *   node scripts/delete_live_sessions_by_email.js path/to/serviceAccountKey.json
 */

const admin = require('firebase-admin');
const path = require('path');
const fs = require('fs');

const EMAILS = ['ronellbradley@gmail.com', 'ronellbradley@hotmail.com'];

function getProjectId() {
  try {
    const firebaserc = path.resolve(process.cwd(), '.firebaserc');
    const data = JSON.parse(fs.readFileSync(firebaserc, 'utf8'));
    return data.projects?.default || process.env.GCLOUD_PROJECT || process.env.GOOGLE_CLOUD_PROJECT;
  } catch {
    return process.env.GCLOUD_PROJECT || process.env.GOOGLE_CLOUD_PROJECT;
  }
}

async function main() {
  const projectId = getProjectId();
  if (!projectId) {
    console.error('Could not determine Firebase project. Add .firebaserc or set GCLOUD_PROJECT.');
    process.exit(1);
  }

  const keyPath = process.env.GOOGLE_APPLICATION_CREDENTIALS || process.argv[2];
  if (keyPath) {
    const resolvedPath = path.isAbsolute(keyPath) ? keyPath : path.resolve(process.cwd(), keyPath);
    try {
      const key = JSON.parse(fs.readFileSync(resolvedPath, 'utf8'));
      admin.initializeApp({ credential: admin.credential.cert(key), projectId });
    } catch (e) {
      console.error('Failed to read service account key:', e.message);
      process.exit(1);
    }
  } else {
    try {
      admin.initializeApp({ credential: admin.credential.applicationDefault(), projectId });
    } catch (e) {
      console.error('Failed to initialize (need GOOGLE_APPLICATION_CREDENTIALS or gcloud auth application-default login):', e.message);
      process.exit(1);
    }
  }

  const auth = admin.auth();
  const db = admin.firestore();
  const uids = new Set();

  for (const email of EMAILS) {
    try {
      const user = await auth.getUserByEmail(email);
      uids.add(user.uid);
      console.log('Resolved %s -> UID %s', email, user.uid);
    } catch (e) {
      if (e.code === 'auth/user-not-found') {
        console.log('No user found for %s, skipping.', email);
      } else {
        console.error('Error looking up %s:', email, e.message);
      }
    }
  }

  if (uids.size === 0) {
    console.log('No UIDs to delete sessions for. Exiting.');
    process.exit(0);
  }

  let totalDeleted = 0;
  for (const uid of uids) {
    const snapshot = await db.collection('liveSessions').where('hostId', '==', uid).get();
    if (snapshot.empty) {
      console.log('No liveSessions for UID %s', uid);
      continue;
    }
    const batch = db.batch();
    snapshot.docs.forEach((doc) => batch.delete(doc.ref));
    await batch.commit();
    totalDeleted += snapshot.size;
    console.log('Deleted %d liveSession(s) for UID %s', snapshot.size, uid);
  }

  console.log('Done. Total deleted: %d', totalDeleted);
  process.exit(0);
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
