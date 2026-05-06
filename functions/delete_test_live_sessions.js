/**
 * Delete test or all live sessions from Firestore.
 *
 * Run from functions folder:
 *   node delete_test_live_sessions.js                  # delete only simulator-test-user-shared
 *   DELETE_ALL=1 node delete_test_live_sessions.js     # delete ALL live sessions
 *   node delete_test_live_sessions.js --dev            # delete sessions for ronellbradley@gmail.com & @hotmail.com
 *
 * Uses Application Default Credentials or GOOGLE_APPLICATION_CREDENTIALS.
 */

const admin = require("firebase-admin");

if (!admin.apps.length) {
  try {
    admin.initializeApp();
  } catch (e) {
    console.error("Firebase Admin init failed. Use gcloud auth application-default login or set GOOGLE_APPLICATION_CREDENTIALS.");
    process.exit(1);
  }
}

const db = admin.firestore();
const TEST_HOST_ID = "simulator-test-user-shared";
const DEV_EMAILS = ["ronellbradley@gmail.com", "ronellbradley@hotmail.com"];

const DELETE_ALL = process.env.DELETE_ALL === "1" || process.env.DELETE_ALL === "true";
const DEV_MODE = process.argv.includes("--dev");

/** Resolve email -> uid via Firestore userSearchProfiles (emailLower). */
async function getUidsForEmailsFromFirestore(db, emails) {
  const uids = [];
  const normalized = emails.map((e) => (e || "").trim().toLowerCase()).filter(Boolean);
  for (const email of normalized) {
    const snap = await db.collection("userSearchProfiles").where("emailLower", "==", email).limit(1).get();
    if (!snap.empty) uids.push(snap.docs[0].id);
  }
  return [...new Set(uids)];
}

async function main() {
  let docsToDelete = [];

  if (DEV_MODE) {
    console.log("Looking up users by email in userSearchProfiles:", DEV_EMAILS.join(", "), "...");
    const uids = await getUidsForEmailsFromFirestore(db, DEV_EMAILS);
    if (uids.length === 0) {
      console.log("No userSearchProfiles found for those emails.");
      return;
    }
    console.log("Found UIDs:", uids.join(", "));
    console.log("Fetching live sessions for these hosts...");
    const snap = await db.collection("liveSessions").get();
    docsToDelete = snap.docs.filter((d) => {
      const hostId = d.data().hostId || "";
      return uids.includes(hostId);
    });
    console.log("Sessions for these users:", docsToDelete.length);
    if (docsToDelete.length > 0) {
      docsToDelete.forEach((d) => {
        const d_ = d.data();
        console.log("  -", d.id, "|", (d_.title || "").slice(0, 50), "| hostId:", d_.hostId);
      });
    }
  } else {
    console.log("Fetching live sessions from Firestore...");
    const snap = await db.collection("liveSessions").get();
    docsToDelete = DELETE_ALL
      ? snap.docs
      : snap.docs.filter((d) => (d.data().hostId || "") === TEST_HOST_ID);

    if (docsToDelete.length === 0) {
      console.log(DELETE_ALL
        ? "No live sessions found."
        : "No test live sessions found (hostId === '" + TEST_HOST_ID + "').");
      return;
    }
  }

  if (docsToDelete.length === 0) {
    console.log("Nothing to delete.");
    return;
  }

  console.log("Deleting", docsToDelete.length, "live session(s)...");
  const BATCH_SIZE = 500;
  for (let i = 0; i < docsToDelete.length; i += BATCH_SIZE) {
    const chunk = docsToDelete.slice(i, i + BATCH_SIZE);
    const batch = db.batch();
    for (const doc of chunk) batch.delete(doc.ref);
    await batch.commit();
  }
  console.log("Deleted", docsToDelete.length, "live session(s).");
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
