#!/usr/bin/env node
/**
 * Sets Auth custom claims for Faith Journal admin-only Settings actions.
 * Matches the iOS app: token claim `admin: true` and/or `role` of `admin` / `superadmin`.
 *
 * The official Firebase CLI cannot set custom claims; this uses the Admin SDK (same API as Cloud Functions).
 *
 * Prerequisite: download a service account key (JSON) from Firebase Console:
 *   Project settings → Service accounts → Generate new private key
 *   Never commit that file to git.
 *
 * Usage:
 *   export GOOGLE_APPLICATION_CREDENTIALS="/absolute/path/to/serviceAccount.json"
 *   node scripts/set-firebase-admin-claims.cjs --email you@example.com
 *   node scripts/set-firebase-admin-claims.cjs --uid <FirebaseAuth_UID>
 *   node scripts/set-firebase-admin-claims.cjs --email you@example.com --credential /path/to/key.json
 *
 * If you save the downloaded key as `service-account-key.json` in the repo root (gitignored), you can omit --credential and GOOGLE_APPLICATION_CREDENTIALS.
 *
 * Remove admin claims (overwrites to empty object):
 *   node scripts/set-firebase-admin-claims.cjs --email you@example.com --clear
 */

"use strict";

const fs = require("fs");
const path = require("path");
const admin = require("firebase-admin");

function parseArgs(argv) {
  const out = {
    email: null,
    uid: null,
    credential: null,
    clear: false,
    help: false,
  };
  for (let i = 2; i < argv.length; i++) {
    const a = argv[i];
    if (a === "--help" || a === "-h") out.help = true;
    else if (a === "--email") out.email = argv[++i];
    else if (a === "--uid") out.uid = argv[++i];
    else if (a === "--credential") out.credential = argv[++i];
    else if (a === "--clear") out.clear = true;
    else {
      console.error("Unknown argument:", a);
      out.help = true;
    }
  }
  return out;
}

function printHelp() {
  console.log(`
set-firebase-admin-claims.cjs — set { admin: true, role: "admin" } on a user

Environment:
  GOOGLE_APPLICATION_CREDENTIALS   path to service account JSON (recommended)

Flags:
  --email <addr>       look up user by email
  --uid <uid>          use Firebase Auth UID directly
  --credential <path>  service account JSON (if not using env var)
  --clear              remove all custom claims for this user
  -h, --help           this message

Credential resolution (first match wins):
  1) --credential
  2) GOOGLE_APPLICATION_CREDENTIALS
  3) <repo>/service-account-key.json
  4) <repo>/serviceAccountKey.json

Example:
  GOOGLE_APPLICATION_CREDENTIALS="$HOME/keys/faith-journal-admin.json" \\
    node scripts/set-firebase-admin-claims.cjs --email you@example.com
`);
}

async function main() {
  const args = parseArgs(process.argv);
  if (args.help || (!args.email && !args.uid)) {
    printHelp();
    process.exit(args.help ? 0 : 1);
  }

  const repoRoot = path.join(__dirname, "..");
  const credentialCandidates = [
    args.credential,
    process.env.GOOGLE_APPLICATION_CREDENTIALS,
    path.join(repoRoot, "service-account-key.json"),
    path.join(repoRoot, "serviceAccountKey.json"),
  ].filter(Boolean);

  const credPath = credentialCandidates.find((p) => fs.existsSync(p));

  if (!credPath) {
    console.error(
      "Missing credentials. Do one of:\n" +
        "  • export GOOGLE_APPLICATION_CREDENTIALS=\"/path/to/your-adminsdk.json\"\n" +
        "  • node ... --credential /path/to/your-adminsdk.json\n" +
        "  • Save the key as: " +
        path.join(repoRoot, "service-account-key.json") +
        " (filename is gitignored)"
    );
    process.exit(1);
  }

  const abs = path.resolve(credPath);
  const serviceAccount = JSON.parse(fs.readFileSync(abs, "utf8"));

  if (admin.apps.length === 0) {
    admin.initializeApp({
      credential: admin.credential.cert(serviceAccount),
    });
  }

  let uid = args.uid;
  if (!uid) {
    const user = await admin.auth().getUserByEmail(args.email);
    uid = user.uid;
    console.log("Resolved email → uid:", uid);
  }

  if (args.clear) {
    await admin.auth().setCustomUserClaims(uid, {});
    console.log("Cleared custom claims for uid:", uid);
  } else {
    await admin.auth().setCustomUserClaims(uid, { admin: true, role: "admin" });
    console.log("Set admin claims for uid:", uid);
  }

  const rec = await admin.auth().getUser(uid);
  console.log("customClaims:", JSON.stringify(rec.customClaims || {}, null, 2));
  console.log("\nUser must obtain a new ID token (sign out/in in the app, or wait for refresh).");
}

main().catch((err) => {
  console.error(err.message || err);
  process.exit(1);
});
