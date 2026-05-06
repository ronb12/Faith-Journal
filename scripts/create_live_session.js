#!/usr/bin/env node
/**
 * Create one live session in Firestore so it appears in the app (and optionally create the LiveKit room).
 * Requires: gcloud auth application-default login (or GOOGLE_APPLICATION_CREDENTIALS).
 * Run: node scripts/create_live_session.js
 * Prints the session ID so you can create the room: lk room create faith-<SESSION_ID>
 */

const admin = require('firebase-admin');
const { randomUUID } = require('crypto');

async function main() {
  if (!admin.apps.length) {
    admin.initializeApp({
      projectId: 'faith-journal-d2a32',
      credential: admin.credential.applicationDefault(),
    });
  }
  const db = admin.firestore();

  const sessionId = randomUUID();
  const now = new Date();

  const data = {
    id: sessionId,
    title: 'Test session (CLI)',
    details: 'Created from the command line for testing.',
    hostId: 'cli-created',
    hostName: 'Faith Journal CLI',
    hostBio: '',
    category: 'Bible Study',
    tags: [],
    isPrivate: false,
    isActive: true,
    maxParticipants: 10,
    currentParticipants: 0,
    currentBroadcasters: 0,
    streamMode: 'conference',
    durationLimitMinutes: 30,
    hasWaitingRoom: false,
    waitingRoomEnabled: false,
    startTime: admin.firestore.Timestamp.fromDate(now),
    scheduledStartTime: null,
    endTime: null,
    createdAt: admin.firestore.Timestamp.fromDate(now),
    lastSyncedAt: admin.firestore.Timestamp.fromDate(now),
  };

  await db.collection('liveSessions').doc(sessionId).set(data, { merge: true });
  console.log('Created live session in Firestore.');
  console.log('Session ID:', sessionId);
  console.log('Room name (for LiveKit):', 'faith-' + sessionId);
  console.log('');
  console.log('Create the LiveKit room with:');
  console.log('  lk room create faith-' + sessionId);
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
