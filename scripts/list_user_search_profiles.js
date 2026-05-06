#!/usr/bin/env node
/** List all userSearchProfiles docs (for debugging Find Friends). */
const admin = require('firebase-admin');
if (!admin.apps.length) {
  if (!process.env.GOOGLE_APPLICATION_CREDENTIALS) { console.error('Set GOOGLE_APPLICATION_CREDENTIALS'); process.exit(1); }
  admin.initializeApp({ credential: admin.credential.applicationDefault() });
}
const db = admin.firestore();

async function main() {
  const snap = await db.collection('userSearchProfiles').limit(50).get();
  console.log('userSearchProfiles count:', snap.size);
  snap.docs.forEach((doc) => {
    const d = doc.data();
    console.log('  ', doc.id, '|', d.displayName || '(no name)', '|', d.displayNameLower || '', '|', d.emailLower || '', '| tokens:', (d.searchTokens || []).join(','));
  });
}
main().catch((e) => { console.error(e); process.exit(1); });
