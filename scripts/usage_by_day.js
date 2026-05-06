#!/usr/bin/env node
/**
 * Analyze Firebase data to see which users had activity on which days.
 * "Activity" = journal entry, mood entry, devotional completion, or prayer request.
 * Requires: GOOGLE_APPLICATION_CREDENTIALS set to service account JSON path.
 * Run: node scripts/usage_by_day.js [days]   (default: 30)
 */

const admin = require('firebase-admin');

const DAYS = parseInt(process.argv[2] || '30', 10) || 30;

function toDateKey(date) {
  const d = new Date(date);
  return d.getFullYear() + '-' + String(d.getMonth() + 1).padStart(2, '0') + '-' + String(d.getDate()).padStart(2, '0');
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

  const end = new Date();
  const start = new Date(end);
  start.setDate(start.getDate() - DAYS);
  console.log('Activity window:', toDateKey(start), 'to', toDateKey(end), '(' + DAYS + ' days)\n');

  const usersSnap = await db.collection('users').get();
  const uidToEmail = new Map();
  const userActivityByDay = new Map(); // uid -> Set of dateKey
  let totalActivityDocs = 0;

  for (const userDoc of usersSnap.docs) {
    const uid = userDoc.id;
    if (!userActivityByDay.has(uid)) userActivityByDay.set(uid, new Set());

    try {
      const user = await auth.getUser(uid);
      uidToEmail.set(uid, user.email || user.displayName || '(no email)');
    } catch {
      const d = userDoc.data();
      uidToEmail.set(uid, d.name || d.email || '(unknown)');
    }

    // Journal entries: date or createdAt
    const journalSnap = await db.collection('users').doc(uid).collection('journalEntries').get();
    journalSnap.docs.forEach((doc) => {
      const d = doc.data();
      totalActivityDocs++;
      const t = d.date && d.date.toDate ? d.date.toDate() : (d.createdAt && d.createdAt.toDate ? d.createdAt.toDate() : null);
      if (t && t >= start && t <= end) userActivityByDay.get(uid).add(toDateKey(t));
    });

    // Mood entries
    try {
      const moodSnap = await db.collection('users').doc(uid).collection('moodEntries').get();
      moodSnap.docs.forEach((doc) => {
        const d = doc.data();
        totalActivityDocs++;
        const t = d.date && d.date.toDate ? d.date.toDate() : (d.createdAt && d.createdAt.toDate ? d.createdAt.toDate() : null);
        if (t && t >= start && t <= end) userActivityByDay.get(uid).add(toDateKey(t));
      });
    } catch (_) {}

    // Devotional completions (document ID is often date string)
    try {
      const devoSnap = await db.collection('users').doc(uid).collection('devotionalCompletions').get();
      devoSnap.docs.forEach((doc) => {
        totalActivityDocs++;
        const dateKey = doc.id; // e.g. "2026-02-15"
        if (/^\d{4}-\d{2}-\d{2}$/.test(dateKey) && dateKey >= toDateKey(start) && dateKey <= toDateKey(end)) {
          userActivityByDay.get(uid).add(dateKey);
        }
        const d = doc.data();
        const t = d.completedAt && d.completedAt.toDate ? d.completedAt.toDate() : (d.date && d.date.toDate ? d.date.toDate() : null);
        if (t && t >= start && t <= end) userActivityByDay.get(uid).add(toDateKey(t));
      });
    } catch (_) {}

    // Prayer requests
    try {
      const prayerSnap = await db.collection('users').doc(uid).collection('prayerRequests').get();
      prayerSnap.docs.forEach((doc) => {
        const d = doc.data();
        totalActivityDocs++;
        const t = d.createdAt && d.createdAt.toDate ? d.createdAt.toDate() : null;
        if (t && t >= start && t <= end) userActivityByDay.get(uid).add(toDateKey(t));
      });
    } catch (_) {}
  }

  // Build day -> count of unique users
  const dayToUserCount = new Map();
  userActivityByDay.forEach((dates, uid) => {
    dates.forEach((dateKey) => {
      dayToUserCount.set(dateKey, (dayToUserCount.get(dateKey) || 0) + 1);
    });
  });

  const sortedDays = [...dayToUserCount.entries()].sort((a, b) => a[0].localeCompare(b[0]));
  console.log('Unique users with activity per day:');
  console.log('-----------------------------------');
  if (sortedDays.length === 0) {
    console.log('  (no activity in window)');
  } else {
    sortedDays.forEach(([day, count]) => console.log('  ', day, '|', count, 'user(s)'));
  }

  const usersWithAnyActivity = [...userActivityByDay.entries()].filter(([, dates]) => dates.size > 0);
  const totalUniqueUsers = usersSnap.size;
  const activeUsers = usersWithAnyActivity.length;
  const daysWithAtLeastOneUser = sortedDays.length;

  console.log('\nSummary:');
  console.log('--------');
  console.log('  Total users in Firebase:     ', totalUniqueUsers);
  console.log('  Users with activity in window:', activeUsers);
  console.log('  Days with ≥1 active user:   ', daysWithAtLeastOneUser, 'of', DAYS);
  console.log('  Total activity documents:   ', totalActivityDocs);

  console.log('\nPer-user: active days in window');
  console.log('--------------------------------');
  const byActiveDays = [...usersWithAnyActivity]
    .map(([uid, dates]) => ({ uid, email: uidToEmail.get(uid) || uid, days: dates.size }))
    .sort((a, b) => b.days - a.days);
  byActiveDays.forEach(({ email, days }) => {
    const pct = DAYS > 0 ? ((100 * days) / DAYS).toFixed(0) : 0;
    console.log('  ', days.toString().padStart(2), 'days (' + pct + '%) |', email);
  });
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
