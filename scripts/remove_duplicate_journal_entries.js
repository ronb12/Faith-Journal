#!/usr/bin/env node
/**
 * Remove duplicate journal entries for a user (by email).
 * Keeps one entry per (title+content), deletes the rest.
 * Requires: GOOGLE_APPLICATION_CREDENTIALS set to service account JSON path.
 * Run: node scripts/remove_duplicate_journal_entries.js <email>
 */

const admin = require('firebase-admin');

const email = process.argv[2];
if (!email || !email.includes('@')) {
  console.error('Usage: node scripts/remove_duplicate_journal_entries.js <email>');
  process.exit(1);
}

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

  console.log('Looking up user:', email);
  let uid;
  try {
    const user = await auth.getUserByEmail(email);
    uid = user.uid;
    console.log('Found UID:', uid);
  } catch (e) {
    console.error('User not found:', e.message);
    process.exit(1);
  }

  const ref = db.collection('users').doc(uid).collection('journalEntries');
  const snapshot = await ref.get();
  if (snapshot.empty) {
    console.log('No journal entries for this user.');
    return;
  }

  // Group by title+content; keep one (oldest by createdAt), mark rest for deletion
  const keyToDocs = new Map(); // key -> [{ id, createdAt }]
  snapshot.docs.forEach((doc) => {
    const d = doc.data();
    const title = (d.title || '').trim();
    const content = (d.content || '').trim();
    const key = title + '\n---\n' + content;
    const createdAt = d.createdAt && d.createdAt.toDate ? d.createdAt.toDate() : new Date(0);
    if (!keyToDocs.has(key)) keyToDocs.set(key, []);
    keyToDocs.get(key).push({ id: doc.id, createdAt });
  });

  const toDelete = [];
  keyToDocs.forEach((docs, key) => {
    if (docs.length <= 1) return;
    // Keep oldest (first by createdAt), delete the rest
    docs.sort((a, b) => a.createdAt - b.createdAt);
    for (let i = 1; i < docs.length; i++) toDelete.push(docs[i].id);
  });

  if (toDelete.length === 0) {
    console.log('No duplicate entries to remove.');
    return;
  }

  console.log('Removing', toDelete.length, 'duplicate entry/entries...');
  const batch = db.batch();
  toDelete.forEach((docId) => batch.delete(ref.doc(docId)));
  await batch.commit();
  console.log('Done. Deleted', toDelete.length, 'duplicate(s) for', email);
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
