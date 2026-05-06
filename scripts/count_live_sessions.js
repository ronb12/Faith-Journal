#!/usr/bin/env node
/**
 * Count (and optionally list) all live sessions in Firestore.
 * Requires: GOOGLE_APPLICATION_CREDENTIALS set to service account JSON path.
 * Run: node scripts/count_live_sessions.js
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

  const snapshot = await db.collection('liveSessions').get();
  const count = snapshot.size;
  const activeCount = snapshot.docs.filter((doc) => doc.data().isActive === true).length;
  console.log('Total live sessions in Firebase:', count);
  console.log('Open (active) live sessions:', activeCount);

  if (count > 0) {
    const auth = admin.auth();
    const hostIds = [...new Set(snapshot.docs.map((doc) => doc.data().hostId).filter(Boolean))];
    const uidToEmail = {};
    for (const uid of hostIds) {
      try {
        const user = await auth.getUser(uid);
        uidToEmail[uid] = user.email || user.displayName || '(no email/name)';
      } catch {
        uidToEmail[uid] = null; // not a Firebase Auth UID (e.g. UUID)
      }
    }
    console.log('\nSessions (who created each):');
    snapshot.docs.forEach((doc) => {
      const d = doc.data();
      const title = d.title || '(no title)';
      const hostId = d.hostId || '';
      const hostName = d.hostName || '(no name)';
      const email = uidToEmail[hostId];
      const who = email ? `${hostName} (${email})` : hostName + (hostId ? ` [hostId: ${hostId}]` : '');
      const isActive = d.isActive ? 'active' : 'inactive';
      console.log('  -', doc.id, '|', title, '|', who, '|', isActive);
    });
  }
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
