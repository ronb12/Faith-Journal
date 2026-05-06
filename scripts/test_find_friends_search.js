#!/usr/bin/env node
/**
 * Test Find Friends search against Firebase (same logic as the app).
 * Usage: node scripts/test_find_friends_search.js [query]
 * Default query: cynthia
 */

const admin = require('firebase-admin');

const query = (process.argv[2] || 'cynthia').trim().toLowerCase();
if (query.length < 2) {
  console.error('Query must be at least 2 characters.');
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

  const start = query;
  const end = query + '\u{f8ff}';
  const seenIds = new Set();
  const results = [];

  console.log('Searching for:', JSON.stringify(query));
  console.log('');

  // 1. Prefix on displayNameLower (userSearchProfiles)
  try {
    const snap = await db.collection('userSearchProfiles')
      .where('displayNameLower', '>=', start)
      .where('displayNameLower', '<=', end)
      .limit(20)
      .get();
    console.log('1. userSearchProfiles (displayNameLower prefix):', snap.size, 'doc(s)');
    snap.docs.forEach((doc) => {
      if (seenIds.has(doc.id)) return;
      seenIds.add(doc.id);
      const d = doc.data();
      results.push({ userId: doc.id, displayName: d.displayName, email: d.emailLower, source: 'prefix' });
    });
  } catch (e) {
    console.log('1. userSearchProfiles prefix error:', e.message);
  }

  // 2. Token search (searchTokens arrayContains)
  try {
    const snap = await db.collection('userSearchProfiles')
      .where('searchTokens', 'array-contains', query)
      .limit(20)
      .get();
    console.log('2. userSearchProfiles (searchTokens arrayContains):', snap.size, 'doc(s)');
    snap.docs.forEach((doc) => {
      if (seenIds.has(doc.id)) return;
      seenIds.add(doc.id);
      const d = doc.data();
      results.push({ userId: doc.id, displayName: d.displayName, email: d.emailLower, source: 'token' });
    });
  } catch (e) {
    console.log('2. userSearchProfiles token error:', e.message);
  }

  // 3. Email prefix (userSearchProfiles)
  try {
    const snap = await db.collection('userSearchProfiles')
      .where('emailLower', '>=', start)
      .where('emailLower', '<=', end)
      .limit(20)
      .get();
    console.log('3. userSearchProfiles (emailLower prefix):', snap.size, 'doc(s)');
    snap.docs.forEach((doc) => {
      if (seenIds.has(doc.id)) return;
      seenIds.add(doc.id);
      const d = doc.data();
      results.push({ userId: doc.id, displayName: d.displayName, email: d.emailLower, source: 'email' });
    });
  } catch (e) {
    console.log('3. userSearchProfiles email error:', e.message);
  }

  // 4. users collection nameLower
  try {
    const snap = await db.collection('users')
      .where('nameLower', '>=', start)
      .where('nameLower', '<=', end)
      .limit(20)
      .get();
    console.log('4. users (nameLower prefix):', snap.size, 'doc(s)');
    snap.docs.forEach((doc) => {
      if (seenIds.has(doc.id)) return;
      const d = doc.data();
      const name = d.name || '';
      if (!name.trim()) return;
      seenIds.add(doc.id);
      results.push({ userId: doc.id, displayName: name, email: (d.email || '').toLowerCase(), source: 'users-name' });
    });
  } catch (e) {
    console.log('4. users nameLower error:', e.message);
  }

  // 5. users collection emailLower
  try {
    const snap = await db.collection('users')
      .where('emailLower', '>=', start)
      .where('emailLower', '<=', end)
      .limit(20)
      .get();
    console.log('5. users (emailLower prefix):', snap.size, 'doc(s)');
    snap.docs.forEach((doc) => {
      if (seenIds.has(doc.id)) return;
      const d = doc.data();
      const name = (d.name || '').trim();
      if (!name) return;
      seenIds.add(doc.id);
      results.push({ userId: doc.id, displayName: name, email: (d.email || '').toLowerCase(), source: 'users-email' });
    });
  } catch (e) {
    console.log('5. users emailLower error:', e.message);
  }

  console.log('');
  console.log('--- Results ---');
  if (results.length === 0) {
    console.log('No users found for query "' + query + '".');
    console.log('(Cynthia may not be in userSearchProfiles yet - have they saved their name in Profile?)');
    return;
  }
  console.log('Found', results.length, 'user(s):');
  results.forEach((r, i) => {
    console.log('  ', i + 1 + '.', r.displayName || '(no name)', '|', r.email || '(no email)', '|', r.userId, '|', r.source);
  });

  const cynthia = results.find((r) =>
    (r.displayName && r.displayName.toLowerCase().includes('cynthia')) ||
    (r.email && r.email.includes('cynthia'))
  );
  if (cynthia) {
    console.log('');
    console.log('Yes - Cynthia is findable by this search.');
  } else {
    console.log('');
    console.log('Cynthia did not appear in this search. Check that their profile has been saved/synced (userSearchProfiles or users has name/email containing "cynthia").');
  }
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
