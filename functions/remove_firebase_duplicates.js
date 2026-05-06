/**
 * Remove duplicate journal entries and prayer requests from Firestore.
 *
 * Run from functions folder:
 *   cd functions
 *   DRY_RUN=1 GOOGLE_APPLICATION_CREDENTIALS=../serviceAccountKey.json node remove_firebase_duplicates.js
 *
 * Dry run (report only, no deletes): DRY_RUN=1
 * Run for real (removes duplicates): omit DRY_RUN or set DRY_RUN=0
 */

const admin = require("firebase-admin");
const DRY_RUN = process.env.DRY_RUN === "1" || process.env.DRY_RUN === "true";

if (!admin.apps.length) {
  try {
    admin.initializeApp();
  } catch (e) {
    console.error("Firebase Admin init failed. Set GOOGLE_APPLICATION_CREDENTIALS to your service account JSON path.");
    console.error("Download from Firebase Console → Project settings → Service accounts → Generate new private key.");
    process.exit(1);
  }
}

const db = admin.firestore();

function safeDate(d) {
  if (!d) return "";
  if (d.toDate && typeof d.toDate === "function") return d.toDate().toISOString();
  if (d instanceof Date) return d.toISOString();
  return String(d);
}

function journalKey(doc) {
  const d = doc.data();
  const title = (d && d.title) || "";
  const content = (d && d.content) || "";
  const date = safeDate(d && d.date);
  return `${title}\n${content}\n${date}`;
}

function prayerKey(doc) {
  const d = doc.data();
  const title = (d && d.title) || "";
  const details = (d && d.details) || "";
  const date = safeDate(d && d.date);
  return `${title}\n${details}\n${date}`;
}

function getCreatedAt(doc) {
  const d = doc.data();
  const t = (d && d.createdAt) || (d && d.date);
  if (!t) return 0;
  if (t.toDate && typeof t.toDate === "function") return t.toDate().getTime();
  if (t instanceof Date) return t.getTime();
  return 0;
}

async function removeJournalDuplicates(userId) {
  const col = db.collection("users").doc(userId).collection("journalEntries");
  const snap = await col.get();
  const docs = snap.docs;
  if (docs.length === 0) return { deletedById: 0, deletedByContent: 0 };

  const byDataId = new Map();
  for (const doc of docs) {
    const id = (doc.data() && doc.data().id) || null;
    if (!id) continue;
    if (!byDataId.has(id)) byDataId.set(id, []);
    byDataId.get(id).push(doc);
  }

  let deletedById = 0;
  const toDeleteById = [];
  for (const [, group] of byDataId) {
    if (group.length <= 1) continue;
    const canonical = group.find((d) => d.id === (d.data().id || ""));
    const keep = canonical || group.sort((a, b) => getCreatedAt(a) - getCreatedAt(b))[0];
    for (const doc of group) {
      if (doc.id !== keep.id) {
        toDeleteById.push(doc.ref);
        deletedById++;
      }
    }
  }
  for (const ref of toDeleteById) {
    if (!DRY_RUN) await ref.delete();
  }

  const snap2 = await col.get();
  const byContent = new Map();
  for (const doc of snap2.docs) {
    const key = journalKey(doc);
    if (!byContent.has(key)) byContent.set(key, []);
    byContent.get(key).push(doc);
  }

  let deletedByContent = 0;
  for (const [, group] of byContent) {
    if (group.length <= 1) continue;
    group.sort((a, b) => getCreatedAt(a) - getCreatedAt(b));
    for (let i = 1; i < group.length; i++) {
      if (!DRY_RUN) await group[i].ref.delete();
      deletedByContent++;
    }
  }

  return { deletedById, deletedByContent };
}

async function removePrayerDuplicates(userId) {
  const col = db.collection("users").doc(userId).collection("prayerRequests");
  const snap = await col.get();
  const docs = snap.docs;
  if (docs.length === 0) return { deletedById: 0, deletedByContent: 0 };

  const byDataId = new Map();
  for (const doc of docs) {
    const id = (doc.data() && doc.data().id) || null;
    if (!id) continue;
    if (!byDataId.has(id)) byDataId.set(id, []);
    byDataId.get(id).push(doc);
  }

  let deletedById = 0;
  const toDeleteById = [];
  for (const [, group] of byDataId) {
    if (group.length <= 1) continue;
    const canonical = group.find((d) => d.id === (d.data().id || ""));
    const keep = canonical || group.sort((a, b) => getCreatedAt(a) - getCreatedAt(b))[0];
    for (const doc of group) {
      if (doc.id !== keep.id) {
        toDeleteById.push(doc.ref);
        deletedById++;
      }
    }
  }
  for (const ref of toDeleteById) {
    if (!DRY_RUN) await ref.delete();
  }

  const snap2 = await col.get();
  const byContent = new Map();
  for (const doc of snap2.docs) {
    const key = prayerKey(doc);
    if (!byContent.has(key)) byContent.set(key, []);
    byContent.get(key).push(doc);
  }

  let deletedByContent = 0;
  for (const [, group] of byContent) {
    if (group.length <= 1) continue;
    group.sort((a, b) => getCreatedAt(a) - getCreatedAt(b));
    for (let i = 1; i < group.length; i++) {
      if (!DRY_RUN) await group[i].ref.delete();
      deletedByContent++;
    }
  }

  return { deletedById, deletedByContent };
}

async function main() {
  if (DRY_RUN) console.log("DRY RUN – no documents will be deleted.\n");
  console.log("Listing users (users collection document IDs)...");
  const usersSnap = await db.collection("users").get();
  const userIds = usersSnap.docs.map((d) => d.id);
  console.log("Found", userIds.length, "user(s).");

  let totalJournalById = 0,
    totalJournalByContent = 0,
    totalPrayerById = 0,
    totalPrayerByContent = 0;

  for (const userId of userIds) {
    const j = await removeJournalDuplicates(userId);
    const p = await removePrayerDuplicates(userId);
    totalJournalById += j.deletedById;
    totalJournalByContent += j.deletedByContent;
    totalPrayerById += p.deletedById;
    totalPrayerByContent += p.deletedByContent;
    if (j.deletedById || j.deletedByContent || p.deletedById || p.deletedByContent) {
      console.log(
        "User",
        userId,
        "– journal:",
        j.deletedById + j.deletedByContent,
        "deleted; prayer:",
        p.deletedById + p.deletedByContent,
        "deleted"
      );
    }
  }

  console.log("Done.");
  console.log("Journal entries deleted (by duplicate id):", totalJournalById);
  console.log("Journal entries deleted (by duplicate content):", totalJournalByContent);
  console.log("Prayer requests deleted (by duplicate id):", totalPrayerById);
  console.log("Prayer requests deleted (by duplicate content):", totalPrayerByContent);
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
