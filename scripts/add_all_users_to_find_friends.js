#!/usr/bin/env node
/**
 * Add all Firebase Auth users to userSearchProfiles (and create friend codes)
 * so they can be found in Find Friends (search + add by code).
 * Requires: GOOGLE_APPLICATION_CREDENTIALS set to service account JSON path.
 * Run: node scripts/add_all_users_to_find_friends.js
 */

const admin = require('firebase-admin');

const FRIEND_CODE_CHARS = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';

function generateFriendCode() {
  return Array.from({ length: 6 }, () => FRIEND_CODE_CHARS[Math.floor(Math.random() * FRIEND_CODE_CHARS.length)]).join('');
}

function displayNameFromUser(user) {
  const name = (user.displayName || '').trim();
  if (name) return name;
  const email = (user.email || '').trim();
  if (email) {
    const local = email.split('@')[0] || '';
    if (local) return local.replace(/[._]/g, ' ').replace(/\b\w/g, (c) => c.toUpperCase());
  }
  return 'Friend';
}

async function ensureFriendCode(db, userId, displayName) {
  const profileRef = db.collection('userSearchProfiles').doc(userId);
  const snap = await profileRef.get();
  const existing = snap.exists && snap.data().friendCode;
  if (existing && existing.length === 6) return existing;
  let code = generateFriendCode();
  for (let tries = 0; tries < 10; tries++) {
    const codeRef = db.collection('friendCodes').doc(code);
    const codeSnap = await codeRef.get();
    if (!codeSnap.exists) {
      await codeRef.set({
        userId,
        displayName: displayName || 'Friend',
        createdAt: admin.firestore.FieldValue.serverTimestamp()
      });
      await profileRef.set({ friendCode: code }, { merge: true });
      return code;
    }
    if (codeSnap.data().userId === userId) {
      await profileRef.set({ friendCode: code }, { merge: true });
      return code;
    }
    code = generateFriendCode();
  }
  return null;
}

async function main() {
  if (!admin.apps.length) {
    if (!process.env.GOOGLE_APPLICATION_CREDENTIALS) {
      console.error('Set GOOGLE_APPLICATION_CREDENTIALS to your Firebase service account JSON path.');
      process.exit(1);
    }
    admin.initializeApp({ credential: admin.credential.applicationDefault() });
  }
  const auth = admin.auth();
  const db = admin.firestore();

  let total = 0;
  let pageToken;
  const updated = [];

  console.log('Listing Firebase Auth users and adding to userSearchProfiles...\n');

  do {
    const list = await auth.listUsers(1000, pageToken);
    list.users.forEach((user) => {
      total++;
      const displayName = displayNameFromUser(user);
      const nameLower = displayName.toLowerCase();
      const tokens = nameLower.split(/\s+/).filter(Boolean);
      const emailLower = (user.email || '').trim().toLowerCase();
      updated.push({ uid: user.uid, displayName, email: user.email });
    });
    pageToken = list.pageToken;
  } while (pageToken);

  console.log('Found', total, 'Auth user(s). Writing to userSearchProfiles...\n');

  for (const u of updated) {
    const name = u.displayName.trim() || 'Friend';
    const nameLower = name.toLowerCase();
    const tokens = nameLower.split(/\s+/).filter(Boolean);
    const emailLower = (u.email || '').trim().toLowerCase();
    const ref = db.collection('userSearchProfiles').doc(u.uid);
    const data = {
      userId: u.uid,
      displayName: name,
      displayNameLower: nameLower,
      updatedAt: admin.firestore.FieldValue.serverTimestamp()
    };
    if (tokens.length) data.searchTokens = tokens;
    if (emailLower) data.emailLower = emailLower;
    await ref.set(data, { merge: true });
    const code = await ensureFriendCode(db, u.uid, name);
    console.log('  ', u.uid, '|', name, '|', u.email || '(no email)', '| code:', code || '(skip)');
  }

  console.log('\nDone. Added/updated', updated.length, 'users to userSearchProfiles (and friend codes). They can now be found in Find Friends.');
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
