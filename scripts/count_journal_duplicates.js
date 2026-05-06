#!/usr/bin/env node
/**
 * Count journal entries in Firebase and find duplicates (same title + content).
 * Path: users/{userId}/journalEntries/{entryId}
 * Requires: GOOGLE_APPLICATION_CREDENTIALS set to service account JSON path.
 * Run: node scripts/count_journal_duplicates.js
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
  let totalEntries = 0;
  const keyToDocs = new Map();
  const keyToCount = new Map();
  const userCounts = new Map(); // userId -> count
  const uidToEmail = new Map();

  for (const userDoc of usersSnap.docs) {
    const userId = userDoc.id;
    try {
      const user = await auth.getUser(userId);
      uidToEmail.set(userId, user.email || user.displayName || '(no email/name)');
    } catch {
      const name = userDoc.data().name || userDoc.data().nameLower || null;
      uidToEmail.set(userId, name || '(unknown)');
    }
    const entriesSnap = await db.collection('users').doc(userId).collection('journalEntries').get();
    userCounts.set(userId, entriesSnap.size);
    for (const doc of entriesSnap.docs) {
      const d = doc.data();
      const title = (d.title || '').trim();
      const content = (d.content || '').trim();
      const key = title + '\n---\n' + content;
      totalEntries++;
      if (!keyToDocs.has(key)) {
        keyToDocs.set(key, []);
        keyToCount.set(key, 0);
      }
      keyToDocs.get(key).push({ userId, docId: doc.id, title: title || '(no title)', content: content.slice(0, 60) + (content.length > 60 ? '...' : '') });
      keyToCount.set(key, keyToCount.get(key) + 1);
    }
  }

  console.log('Journal entries by user');
  console.log('=======================');
  const sorted = [...userCounts.entries()].sort((a, b) => b[1] - a[1]);
  for (const [uid, count] of sorted) {
    const who = uidToEmail.get(uid) || uid;
    console.log('  ', count.toString().padStart(3), '|', who, '|', uid);
  }
  console.log('  ---');
  console.log('  ', totalEntries.toString().padStart(3), '| TOTAL');
  console.log('');

  const duplicateKeys = [...keyToCount.entries()].filter(([, count]) => count > 1);
  const duplicateEntryCount = duplicateKeys.reduce((sum, [k, count]) => sum + count, 0);
  const uniqueContentCount = keyToDocs.size;
  const extraDuplicates = duplicateEntryCount - duplicateKeys.length; // how many "extra" copies (e.g. 3 same = 2 extra)

  console.log('Journal entries in Firebase');
  console.log('==========================');
  console.log('Total document count:     ', totalEntries);
  console.log('Unique (by title+content):', uniqueContentCount);
  console.log('Duplicate groups:         ', duplicateKeys.length, '(same title+content appearing more than once)');
  console.log('Total duplicate entries:  ', duplicateEntryCount, '(documents that are duplicates)');
  console.log('Extra copies to remove:   ', extraDuplicates, '(keep one per group, remove the rest)');

  if (duplicateKeys.length > 0) {
    console.log('\nDuplicate groups (title | first 60 chars of content):');
    duplicateKeys.slice(0, 30).forEach(([key, count]) => {
      const [t, c] = key.split('\n---\n');
      console.log('  [' + count + 'x]', t || '(no title)', '|', (c || '').slice(0, 50) + (c && c.length > 50 ? '...' : ''));
    });
    if (duplicateKeys.length > 30) console.log('  ... and', duplicateKeys.length - 30, 'more duplicate groups');
  }
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
