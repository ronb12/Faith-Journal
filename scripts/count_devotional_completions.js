#!/usr/bin/env node
/**
 * Count devotional completions (marked read/done) in Firebase.
 * Path: users/{userId}/devotionalCompletions/{dateString}
 * Requires: GOOGLE_APPLICATION_CREDENTIALS set to service account JSON path.
 * Run: node scripts/count_devotional_completions.js
 */

const admin = require('firebase-admin');

async function main() {
  if (!admin.apps.length) {
    if (!process.env.GOOGLE_APPLICATION_CREDENTIALS) {
      console.error('Set GOOGLE_APPLICATION_CREDENTIALS to your Firebase service account JSON path.');
      process.exit(1);
    }
    admin.initializeApp({ credential: admin.credential.applicationDefault() });
  }
  const db = admin.firestore();
  const auth = admin.auth();

  const usersSnap = await db.collection('users').get();
  let total = 0;
  let markedCompleted = 0;
  const byUser = [];

  for (const userDoc of usersSnap.docs) {
    const uid = userDoc.id;
    let email = '(unknown)';
    try {
      const user = await auth.getUser(uid);
      email = user.email || user.displayName || email;
    } catch {
      const d = userDoc.data();
      if (d.name) email = d.name;
      if (d.email) email = d.email;
    }
    const snap = await db.collection('users').doc(uid).collection('devotionalCompletions').get();
    let userTotal = 0;
    let userCompleted = 0;
    snap.docs.forEach((doc) => {
      const d = doc.data();
      userTotal++;
      if (d.isCompleted === true) userCompleted++;
    });
    total += userTotal;
    markedCompleted += userCompleted;
    if (userTotal > 0) {
      byUser.push({ email, uid, total: userTotal, completed: userCompleted });
    }
  }

  byUser.sort((a, b) => b.total - a.total);

  console.log('Devotional completions (marked read/done)');
  console.log('==========================================');
  console.log('Total completion records:   ', total);
  console.log('Marked completed (isCompleted=true):', markedCompleted);
  console.log('');
  console.log('By user:');
  byUser.forEach(({ email, total: t, completed: c }) => {
    console.log('  ', t.toString().padStart(4), 'records,', c.toString().padStart(4), 'completed |', email);
  });
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
