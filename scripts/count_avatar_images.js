#!/usr/bin/env node
/**
 * Count how many users have an avatar image URL in Firebase.
 * Checks: userSearchProfiles.avatarURL, users.profileImageURL (or profile image field).
 * Requires: GOOGLE_APPLICATION_CREDENTIALS
 * Run: node scripts/count_avatar_images.js
 */

const admin = require('firebase-admin');

async function main() {
  if (!admin.apps.length) {
    if (!process.env.GOOGLE_APPLICATION_CREDENTIALS) {
      console.error('Set GOOGLE_APPLICATION_CREDENTIALS');
      process.exit(1);
    }
    admin.initializeApp({ credential: admin.credential.applicationDefault() });
  }
  const db = admin.firestore();

  let withAvatarSearch = 0;
  let withAvatarUsers = 0;
  const searchSnap = await db.collection('userSearchProfiles').get();
  searchSnap.docs.forEach((doc) => {
    const url = doc.data().avatarURL;
    if (url && typeof url === 'string' && url.trim().length > 0) withAvatarSearch++;
  });

  const usersSnap = await db.collection('users').get();
  usersSnap.docs.forEach((doc) => {
    const data = doc.data();
    const url = data.profileImageURL || data.avatarURL || data.avatarPhotoURL;
    if (url && typeof url === 'string' && url.trim().length > 0) withAvatarUsers++;
  });

  // Unique users with avatar (might have in both collections)
  const userIdsSearch = new Set();
  searchSnap.docs.forEach((doc) => {
    const url = doc.data().avatarURL;
    if (url && typeof url === 'string' && url.trim().length > 0) userIdsSearch.add(doc.id);
  });
  const userIdsUsers = new Set();
  usersSnap.docs.forEach((doc) => {
    const data = doc.data();
    const url = data.profileImageURL || data.avatarURL || data.avatarPhotoURL;
    if (url && typeof url === 'string' && url.trim().length > 0) userIdsUsers.add(doc.id);
  });
  const combined = new Set([...userIdsSearch, ...userIdsUsers]);

  console.log('Avatar images in Firebase');
  console.log('========================');
  console.log('userSearchProfiles with avatarURL:  ', withAvatarSearch);
  console.log('users with profileImageURL/avatar:  ', withAvatarUsers);
  console.log('Unique users with at least one avatar:', combined.size);
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
