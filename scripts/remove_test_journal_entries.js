#!/usr/bin/env node
/**
 * Remove legacy test journal entries from Firestore.
 *
 * Dry run:
 *   node scripts/remove_test_journal_entries.js
 *
 * Delete matches:
 *   node scripts/remove_test_journal_entries.js --delete
 */

const admin = require('firebase-admin');

const PROJECT_ID = 'faith-journal-d2a32';
const shouldDelete = process.argv.includes('--delete');

function normalize(value) {
  return String(value || '').trim().toLowerCase();
}

function isLegacyTestEntry(data) {
  const title = normalize(data.title);
  const content = normalize(data.content);
  const tags = Array.isArray(data.tags) ? data.tags.map(normalize) : [];

  if (title === 'test' || content === 'test') return true;
  if (title === 'test entry' || title === 'test journal entry') return true;
  if (title.includes('test journal entry') || title.includes('cloudkit test entry')) return true;
  if (content.includes('test journal entry created') || content.includes('created via cli')) return true;
  if (content.includes('cloudkit sync') || content.includes('cloudkit verification')) return true;
  if (tags.includes('test') && (title.includes('test') || content.includes('test'))) return true;

  return false;
}

async function main() {
  if (!admin.apps.length) {
    admin.initializeApp({ projectId: PROJECT_ID });
  }

  const db = admin.firestore();
  const snapshot = await db.collectionGroup('journalEntries').get();

  const matches = snapshot.docs
    .filter((doc) => isLegacyTestEntry(doc.data()))
    .map((doc) => {
      const data = doc.data();
      return {
        ref: doc.ref,
        path: doc.ref.path,
        title: data.title || '',
      };
    });

  if (matches.length === 0) {
    console.log('No legacy test journal entries found.');
    return;
  }

  console.log(`Found ${matches.length} legacy test journal entr${matches.length === 1 ? 'y' : 'ies'}:`);
  for (const match of matches) {
    console.log(`- ${match.path} :: ${match.title}`);
  }

  if (!shouldDelete) {
    console.log('Dry run only. Re-run with --delete to remove these entries.');
    return;
  }

  const batchSize = 400;
  for (let i = 0; i < matches.length; i += batchSize) {
    const batch = db.batch();
    for (const match of matches.slice(i, i + batchSize)) {
      batch.delete(match.ref);
    }
    await batch.commit();
  }

  console.log(`Deleted ${matches.length} legacy test journal entr${matches.length === 1 ? 'y' : 'ies'}.`);
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});
