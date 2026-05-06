/**
 * Faith Journal – Cloud Functions
 * Sends push notifications for friend requests via FCM.
 * getAdMobEarnings: admin-only callable (Firebase Auth custom claim admin:true).
 */

const functions = require("firebase-functions");
const admin = require("firebase-admin");
const { GoogleAuth } = require("google-auth-library");
const { RtcTokenBuilder, RtcRole } = require("agora-token");

admin.initializeApp();

/** Must match `AdminService.allowedAdminEmail` in the iOS app. */
const ALLOWED_ADMIN_EMAIL = "ronellbradley@hotmail.com".toLowerCase();

/**
 * Same rules as the app: `admin` custom claim, or allowlisted email (token or Auth user record).
 * Uses Admin SDK as fallback when the ID token omits email (e.g. some Sign in with Apple cases).
 * @param {import("firebase-functions").https.CallableContext} context
 */
async function isAdminForCallableAsync(context) {
  if (!context.auth || !context.auth.uid) return false;
  const t = context.auth.token || {};
  if (t.admin === true) return true;
  if (t.email && String(t.email).toLowerCase() === ALLOWED_ADMIN_EMAIL) return true;
  const fromIdentities = t.firebase && t.firebase.identities && t.firebase.identities.email;
  if (Array.isArray(fromIdentities) && fromIdentities.some((e) => e && String(e).toLowerCase() === ALLOWED_ADMIN_EMAIL)) {
    return true;
  }
  try {
    const user = await admin.auth().getUser(context.auth.uid);
    const emails = [user.email, ...user.providerData.map((p) => p && p.email)].map((e) => (e ? String(e).toLowerCase() : ""));
    return emails.includes(ALLOWED_ADMIN_EMAIL);
  } catch (e) {
    functions.logger.warn("isAdminForCallableAsync getUser failed", e);
    return false;
  }
}

/** Default AdMob publisher ID (Faith Journal production). Set ADMOB_PUBLISHER_ID in config to override. */
const DEFAULT_PUBLISHER_ID = "pub-3565666509316178";

/**
 * When a new friend request document is created (status pending),
 * send a push notification to the recipient using their stored FCM token.
 */
exports.onFriendRequestCreated = functions.firestore
  .document("friends/{friendId}")
  .onCreate(async (snap, context) => {
    const data = snap.data();
    const status = data.status;
    if (status !== "pending") return null;

    const requestedBy = data.requestedBy;
    const userA = data.userA;
    const userB = data.userB;
    const recipientId = requestedBy === userA ? userB : userA;

    if (!recipientId) return null;

    const db = admin.firestore();

    // Get requester display name for the notification
    let requesterName = "Someone";
    try {
      const profileSnap = await db.doc(`userSearchProfiles/${requestedBy}`).get();
      if (profileSnap.exists && profileSnap.data().displayName) {
        requesterName = profileSnap.data().displayName;
      } else {
        const userSnap = await db.doc(`users/${requestedBy}`).get();
        if (userSnap.exists) {
          const d = userSnap.data();
          requesterName = d.displayName || d.name || d.email || requesterName;
        }
      }
    } catch (e) {
      functions.logger.warn("Could not resolve requester name", e);
    }

    // Get recipient FCM token (stored by the app in users/{userId})
    let fcmToken = null;
    try {
      const userSnap = await db.doc(`users/${recipientId}`).get();
      if (userSnap.exists && userSnap.data().fcmToken) {
        fcmToken = userSnap.data().fcmToken;
      }
    } catch (e) {
      functions.logger.warn("Could not read recipient FCM token", e);
    }

    if (!fcmToken) {
      functions.logger.info("No FCM token for recipient", { recipientId });
      return null;
    }

    const title = "Friend request";
    const body = `${requesterName} wants to be friends`;

    try {
      await admin.messaging().send({
        token: fcmToken,
        notification: { title, body },
        data: {
          type: "friend_request",
          friendId: context.params.friendId,
        },
        apns: {
          payload: {
            aps: {
              sound: "default",
              "mutable-content": 1,
            },
          },
          fcmOptions: {
            imageUrl: undefined,
          },
        },
        android: {
          priority: "high",
          notification: { channelId: "friend_requests" },
        },
      });
      functions.logger.info("Friend request push sent", { recipientId, friendId: context.params.friendId });
    } catch (err) {
      functions.logger.error("Failed to send friend request push", { err, recipientId });
      // If token is invalid, consider removing it so we don't keep failing
      if (err.code === "messaging/invalid-registration-token" || err.code === "messaging/registration-token-not-registered") {
        try {
          await db.doc(`users/${recipientId}`).update({ fcmToken: admin.firestore.FieldValue.delete() });
        } catch (e) {
          functions.logger.warn("Could not remove invalid FCM token", e);
        }
      }
    }

    return null;
  });

/**
 * Admin-only callable: total Firebase Auth user count (paginated listUsers).
 * Requires the same admin rules as the iOS app: custom claim admin:true, or allowlisted email.
 */
exports.adminGetUserCount = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError("unauthenticated", "Must be signed in.");
  }
  if (!(await isAdminForCallableAsync(context))) {
    throw new functions.https.HttpsError(
      "permission-denied",
      "Admin only. Set custom claim admin:true on your account, or sign in with the allowlisted email, then try again."
    );
  }

  let nextPageToken;
  let total = 0;
  try {
    do {
      const page = await admin.auth().listUsers(1000, nextPageToken);
      total += page.users.length;
      nextPageToken = page.pageToken;
    } while (nextPageToken);
  } catch (e) {
    functions.logger.error("adminGetUserCount listUsers failed", e);
    throw new functions.https.HttpsError("internal", e.message || "Failed to list users");
  }

  return { count: total };
});

/**
 * Admin-only callable: fetches AdMob earnings for the last 30 days via AdMob Reporting API.
 * Same admin check as adminGetUserCount.
 * Prerequisites: Enable AdMob API in GCP; grant the Cloud Functions service account
 * "View" access in AdMob console.
 */
exports.getAdMobEarnings = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError("unauthenticated", "Must be signed in.");
  }
  if (!(await isAdminForCallableAsync(context))) {
    throw new functions.https.HttpsError(
      "permission-denied",
      "AdMob earnings are only available to admin accounts (see adminGetUserCount rules)."
    );
  }

  const publisherId = process.env.ADMOB_PUBLISHER_ID || functions.config().admob?.publisher_id || DEFAULT_PUBLISHER_ID;
  const accountName = `accounts/${publisherId}`;

  const auth = new GoogleAuth({
    scopes: ["https://www.googleapis.com/auth/admob.report"],
  });
  const client = await auth.getClient();
  const token = await client.getAccessToken();
  if (!token.token) {
    throw new functions.https.HttpsError("internal", "Failed to get AdMob API credentials.");
  }

  const now = new Date();
  const end = new Date(now.getFullYear(), now.getMonth(), now.getDate());
  const start = new Date(end);
  start.setDate(start.getDate() - 30);

  const reportSpec = {
    reportSpec: {
      dateRange: {
        startDate: { year: start.getFullYear(), month: start.getMonth() + 1, day: start.getDate() },
        endDate: { year: end.getFullYear(), month: end.getMonth() + 1, day: end.getDate() },
      },
      dimensions: ["DATE"],
      metrics: ["ESTIMATED_EARNINGS"],
      timeZone: "America/Los_Angeles",
    },
  };

  const url = `https://admob.googleapis.com/v1/${accountName}/networkReport:generate`;
  const res = await fetch(url, {
    method: "POST",
    headers: {
      "Authorization": `Bearer ${token.token}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify(reportSpec),
  });

  if (!res.ok) {
    const text = await res.text();
    functions.logger.warn("AdMob API error", { status: res.status, body: text });
    throw new functions.https.HttpsError(
      "internal",
      `AdMob API error: ${res.status}. Enable AdMob API in GCP and grant the function's service account access in AdMob.`
    );
  }

  const contentType = res.headers.get("content-type") || "";
  let text = await res.text();
  let currencyCode = "USD";
  const byDate = [];
  let totalMicros = 0;

  if (contentType.includes("application/json") && text) {
    try {
      const parsed = JSON.parse(text);
      const items = Array.isArray(parsed) ? parsed : [parsed];
      for (const item of items) {
        if (item.header && item.header.localizationSettings && item.header.localizationSettings.currencyCode) {
          currencyCode = item.header.localizationSettings.currencyCode;
        }
        if (item.row && item.row.metricValues && item.row.metricValues.ESTIMATED_EARNINGS) {
          const micros = Number(item.row.metricValues.ESTIMATED_EARNINGS.microsValue) || 0;
          totalMicros += micros;
          const dateVal = item.row.dimensionValues && item.row.dimensionValues.DATE ? item.row.dimensionValues.DATE.value : null;
          if (dateVal) byDate.push({ date: dateVal, earningsMicros: micros });
        }
      }
    } catch (e) {
      const lines = text.trim().split("\n").filter(Boolean);
      for (const line of lines) {
        try {
          const item = JSON.parse(line);
          if (item.header && item.header.localizationSettings && item.header.localizationSettings.currencyCode) {
            currencyCode = item.header.localizationSettings.currencyCode;
          }
          if (item.row && item.row.metricValues && item.row.metricValues.ESTIMATED_EARNINGS) {
            const micros = Number(item.row.metricValues.ESTIMATED_EARNINGS.microsValue) || 0;
            totalMicros += micros;
            const dateVal = item.row.dimensionValues && item.row.dimensionValues.DATE ? item.row.dimensionValues.DATE.value : null;
            if (dateVal) byDate.push({ date: dateVal, earningsMicros: micros });
          }
        } catch (_) { /* skip malformed line */ }
      }
    }
  }

  const totalEarnings = totalMicros / 1_000_000;
  const totalEarningsFormatted = new Intl.NumberFormat("en-US", {
    style: "currency",
    currency: currencyCode,
    minimumFractionDigits: 2,
    maximumFractionDigits: 2,
  }).format(totalEarnings);

  return {
    currencyCode,
    totalEarningsMicros: totalMicros,
    totalEarningsFormatted,
    totalEarnings,
    byDate: byDate.sort((a, b) => a.date.localeCompare(b.date)),
    startDate: reportSpec.reportSpec.dateRange.startDate,
    endDate: reportSpec.reportSpec.dateRange.endDate,
  };
});

// ---------- Duplicate journal/prayer check (developer-only callable) ----------
const db = admin.firestore();

// ---------- Agora Cloud Recording ----------

const AGORA_RECORDING_MODE = "mix";
const AGORA_RECORDING_UID_BASE = 700000;
const RECORDING_PREFIX = "sessionRecordings";
const DEFAULT_RECORDING_STORAGE_LIMIT_BYTES = Math.floor(4.5 * 1024 * 1024 * 1024);
const DEFAULT_RECORDING_START_BUFFER_BYTES = 512 * 1024 * 1024;
const DEFAULT_MAX_RECORDING_DURATION_SECONDS = 30 * 60;

function configValue(path, envName, fallback = "") {
  if (process.env[envName]) return String(process.env[envName]).trim();
  const parts = path.split(".");
  let current = functions.config();
  for (const part of parts) {
    if (!current || current[part] === undefined) return fallback;
    current = current[part];
  }
  return current === undefined || current === null ? fallback : String(current).trim();
}

function configNumber(path, envName, fallback) {
  const value = Number(configValue(path, envName, String(fallback)));
  return Number.isFinite(value) && value > 0 ? value : fallback;
}

function requiredAgoraRecordingConfig() {
  const appId = configValue("agora.app_id", "AGORA_APP_ID");
  const appCertificate = configValue("agora.app_certificate", "AGORA_APP_CERTIFICATE");
  const customerId = configValue("agora.customer_id", "AGORA_CUSTOMER_ID");
  const customerSecret = configValue("agora.customer_secret", "AGORA_CUSTOMER_SECRET");
  const bucket = configValue("agora_recording.bucket", "AGORA_RECORDING_BUCKET");
  const accessKey = configValue("agora_recording.access_key", "AGORA_RECORDING_ACCESS_KEY");
  const secretKey = configValue("agora_recording.secret_key", "AGORA_RECORDING_SECRET_KEY");
  const vendor = Number(configValue("agora_recording.vendor", "AGORA_RECORDING_VENDOR", "6"));
  const region = Number(configValue("agora_recording.region", "AGORA_RECORDING_REGION", "0"));
  const storageLimitBytes = configNumber(
    "agora_recording.storage_limit_bytes",
    "AGORA_RECORDING_STORAGE_LIMIT_BYTES",
    DEFAULT_RECORDING_STORAGE_LIMIT_BYTES
  );
  const startBufferBytes = configNumber(
    "agora_recording.start_buffer_bytes",
    "AGORA_RECORDING_START_BUFFER_BYTES",
    DEFAULT_RECORDING_START_BUFFER_BYTES
  );
  const maxDurationSeconds = configNumber(
    "agora_recording.max_duration_seconds",
    "AGORA_RECORDING_MAX_DURATION_SECONDS",
    DEFAULT_MAX_RECORDING_DURATION_SECONDS
  );

  const missing = [];
  for (const [key, value] of Object.entries({ appId, appCertificate, customerId, customerSecret, bucket, accessKey, secretKey })) {
    if (!value) missing.push(key);
  }
  if (missing.length) {
    throw new functions.https.HttpsError(
      "failed-precondition",
      `Agora Cloud Recording is not configured. Missing: ${missing.join(", ")}.`
    );
  }
  return {
    appId,
    appCertificate,
    customerId,
    customerSecret,
    bucket,
    accessKey,
    secretKey,
    vendor,
    region,
    storageLimitBytes,
    startBufferBytes,
    maxDurationSeconds,
  };
}

function agoraAuthHeader(customerId, customerSecret) {
  return `Basic ${Buffer.from(`${customerId}:${customerSecret}`).toString("base64")}`;
}

async function agoraRequest({ appId, customerId, customerSecret }, endpoint, body, method = "POST") {
  const headers = {
    "Authorization": agoraAuthHeader(customerId, customerSecret),
    "Accept": "application/json",
  };
  const options = { method, headers };
  if (body !== undefined) {
    headers["Content-Type"] = "application/json;charset=utf-8";
    options.body = JSON.stringify(body);
  }
  const res = await fetch(`https://api.agora.io/v1/apps/${appId}/cloud_recording/${endpoint}`, {
    ...options,
  });

  const text = await res.text();
  let json = {};
  if (text) {
    try {
      json = JSON.parse(text);
    } catch (_) {
      json = { raw: text };
    }
  }

  if (!res.ok) {
    functions.logger.warn("Agora Cloud Recording API error", { endpoint, status: res.status, body: json });
    throw new functions.https.HttpsError("internal", `Agora Cloud Recording API error ${res.status}`, json);
  }
  return json;
}

function recordingUidForSession(sessionId) {
  let hash = 0;
  for (const ch of String(sessionId)) {
    hash = ((hash << 5) - hash + ch.charCodeAt(0)) | 0;
  }
  return String(AGORA_RECORDING_UID_BASE + Math.abs(hash % 200000));
}

function channelNameForSession(sessionId) {
  return `faith-journal-${sessionId}`;
}

function recordingToken(config, channelName, uid) {
  const now = Math.floor(Date.now() / 1000);
  return RtcTokenBuilder.buildTokenWithUid(
    config.appId,
    config.appCertificate,
    channelName,
    Number(uid),
    RtcRole.PUBLISHER,
    now + 60 * 60 * 6
  );
}

async function getSessionForHost(sessionId, uid) {
  const publicRef = db.collection("liveSessions").doc(sessionId);
  let snap = await publicRef.get();
  if (snap.exists) {
    const data = snap.data() || {};
    if (data.hostId !== uid) {
      throw new functions.https.HttpsError("permission-denied", "Only the host can manage cloud recording.");
    }
    return { ref: publicRef, data, isPrivate: false };
  }

  const privateRef = db.collection("users").doc(uid).collection("liveSessions").doc(sessionId);
  snap = await privateRef.get();
  if (snap.exists) {
    const data = snap.data() || {};
    if (data.hostId !== uid) {
      throw new functions.https.HttpsError("permission-denied", "Only the host can manage cloud recording.");
    }
    return { ref: privateRef, data, isPrivate: true };
  }

  throw new functions.https.HttpsError("not-found", "Live session was not found in Firestore.");
}

function pickRecordingFile(serverResponse) {
  const files = serverResponse && Array.isArray(serverResponse.fileList) ? serverResponse.fileList : [];
  const names = files
    .map((item) => typeof item === "string" ? item : (item && (item.fileName || item.filename || item.name)))
    .filter(Boolean);
  return names.find((name) => name.endsWith(".mp4"))
    || names.find((name) => name.endsWith(".m3u8"))
    || names[0]
    || null;
}

function recordingFileURL(bucket, fileName) {
  if (!fileName) return null;
  return `https://storage.googleapis.com/${bucket}/${String(fileName).split("/").map(encodeURIComponent).join("/")}`;
}

function formatBytes(bytes) {
  const gb = bytes / (1024 * 1024 * 1024);
  return `${gb.toFixed(gb >= 1 ? 2 : 3)} GB`;
}

async function recordingStorageUsage(config) {
  const [files] = await admin.storage().bucket(config.bucket).getFiles({ prefix: `${RECORDING_PREFIX}/` });
  const totalBytes = files.reduce((sum, file) => sum + Number((file.metadata && file.metadata.size) || 0), 0);
  return { totalBytes, fileCount: files.length };
}

async function assertRecordingBudgetAvailable(config) {
  const usage = await recordingStorageUsage(config);
  const projectedBytes = usage.totalBytes + config.startBufferBytes;
  if (projectedBytes >= config.storageLimitBytes) {
    throw new functions.https.HttpsError(
      "resource-exhausted",
      `Replay recording is paused to protect the free Google Cloud Storage tier. Current recordings use ${formatBytes(usage.totalBytes)} of the ${formatBytes(config.storageLimitBytes)} app limit. Delete older replays or raise AGORA_RECORDING_STORAGE_LIMIT_BYTES to allow more.`
    );
  }
  return usage;
}

function millisFromFirestoreTimestamp(value) {
  if (!value) return 0;
  if (typeof value.toMillis === "function") return value.toMillis();
  if (typeof value._seconds === "number") return value._seconds * 1000;
  if (typeof value.seconds === "number") return value.seconds * 1000;
  return 0;
}

function recordingAgeSeconds(state) {
  const startMs = millisFromFirestoreTimestamp(state.startedAt) || millisFromFirestoreTimestamp(state.createdAt);
  return startMs ? Math.floor((Date.now() - startMs) / 1000) : 0;
}

async function updateLiveSessionRecordingState(sessionId, hostUid, update) {
  const publicRef = db.collection("liveSessions").doc(sessionId);
  const publicSnap = await publicRef.get();
  if (publicSnap.exists) await publicRef.set(update, { merge: true });

  if (hostUid) {
    const privateRef = db.collection("users").doc(hostUid).collection("liveSessions").doc(sessionId);
    const privateSnap = await privateRef.get();
    if (privateSnap.exists) await privateRef.set(update, { merge: true });
  }
}

async function stopAgoraRecordingState(config, sessionId, stateRef, state, reason) {
  if (!state.resourceId || !state.sid || !state.uid || !state.cname) {
    await stateRef.set({
      status: "error",
      error: "Cloud recording state is incomplete.",
      stoppedReason: reason,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    }, { merge: true });
    await updateLiveSessionRecordingState(sessionId, state.startedBy, {
      isRecording: false,
      lastSyncedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    return { status: "error", reason };
  }

  const stop = await agoraRequest(
    config,
    `resourceid/${state.resourceId}/sid/${state.sid}/mode/${state.mode || AGORA_RECORDING_MODE}/stop`,
    {
      cname: state.cname,
      uid: state.uid,
      clientRequest: {
        async_stop: false,
      },
    }
  );

  const fileName = pickRecordingFile(stop.serverResponse);
  const recordingURL = recordingFileURL(config.bucket, fileName);
  await stateRef.set({
    status: "stopped",
    stoppedAt: admin.firestore.FieldValue.serverTimestamp(),
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    stoppedReason: reason,
    stopResponse: stop,
    fileName: fileName || null,
    recordingURL: recordingURL || null,
  }, { merge: true });

  const liveSessionUpdate = {
    isRecording: false,
    lastSyncedAt: admin.firestore.FieldValue.serverTimestamp(),
  };
  if (recordingURL) liveSessionUpdate.recordingURL = recordingURL;
  await updateLiveSessionRecordingState(sessionId, state.startedBy, liveSessionUpdate);

  return { status: "stopped", recordingURL, fileName, response: stop };
}

exports.startAgoraCloudRecording = functions.https.onCall(async (data, context) => {
  if (!context.auth || !context.auth.uid) {
    throw new functions.https.HttpsError("unauthenticated", "Must be signed in.");
  }
  const sessionId = String(data && data.sessionId ? data.sessionId : "").trim();
  if (!sessionId) {
    throw new functions.https.HttpsError("invalid-argument", "sessionId is required.");
  }

  const config = requiredAgoraRecordingConfig();
  const usage = await assertRecordingBudgetAvailable(config);
  const { ref } = await getSessionForHost(sessionId, context.auth.uid);
  const stateRef = db.collection("sessions").doc(sessionId).collection("recording").doc("current");
  const existing = await stateRef.get();
  if (existing.exists && ["starting", "recording"].includes((existing.data() || {}).status)) {
    const d = existing.data() || {};
    return {
      status: d.status,
      resourceId: d.resourceId || "",
      sid: d.sid || "",
      uid: d.uid || "",
      mode: d.mode || AGORA_RECORDING_MODE,
      alreadyStarted: true,
    };
  }

  const cname = channelNameForSession(sessionId);
  const uid = recordingUidForSession(sessionId);
  const token = recordingToken(config, cname, uid);
  const fileNamePrefix = [RECORDING_PREFIX, sessionId];

  const acquire = await agoraRequest(config, "acquire", {
    cname,
    uid,
    clientRequest: {
      resourceExpiredHour: 24,
      scene: 0,
    },
  });

  const resourceId = acquire.resourceId;
  if (!resourceId) {
    throw new functions.https.HttpsError("internal", "Agora did not return a recording resource ID.", acquire);
  }

  await stateRef.set({
    status: "starting",
    resourceId,
    uid,
    mode: AGORA_RECORDING_MODE,
    cname,
    fileNamePrefix,
    storageUsageBytesAtStart: usage.totalBytes,
    storageFileCountAtStart: usage.fileCount,
    storageLimitBytes: config.storageLimitBytes,
    maxDurationSeconds: config.maxDurationSeconds,
    startedBy: context.auth.uid,
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  }, { merge: true });

  const start = await agoraRequest(
    config,
    `resourceid/${resourceId}/mode/${AGORA_RECORDING_MODE}/start`,
    {
      cname,
      uid,
      clientRequest: {
        token,
        recordingConfig: {
          channelType: 1,
          streamTypes: 2,
          maxIdleTime: 30,
          subscribeVideoUids: ["#allstream#"],
          subscribeAudioUids: ["#allstream#"],
          transcodingConfig: {
            width: 1280,
            height: 720,
            fps: 30,
            bitrate: 2260,
            mixedVideoLayout: 1,
            backgroundColor: "#000000",
          },
        },
        recordingFileConfig: {
          avFileType: ["hls", "mp4"],
        },
        storageConfig: {
          vendor: config.vendor,
          region: config.region,
          bucket: config.bucket,
          accessKey: config.accessKey,
          secretKey: config.secretKey,
          fileNamePrefix,
        },
      },
    }
  );

  const sid = start.sid;
  await stateRef.set({
    status: "recording",
    sid,
    startedAt: admin.firestore.FieldValue.serverTimestamp(),
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    startResponse: start,
  }, { merge: true });
  await ref.set({ isRecording: true, lastSyncedAt: admin.firestore.FieldValue.serverTimestamp() }, { merge: true });

  return { status: "recording", resourceId, sid, uid, mode: AGORA_RECORDING_MODE };
});

exports.stopAgoraCloudRecording = functions.https.onCall(async (data, context) => {
  if (!context.auth || !context.auth.uid) {
    throw new functions.https.HttpsError("unauthenticated", "Must be signed in.");
  }
  const sessionId = String(data && data.sessionId ? data.sessionId : "").trim();
  if (!sessionId) {
    throw new functions.https.HttpsError("invalid-argument", "sessionId is required.");
  }

  const config = requiredAgoraRecordingConfig();
  const { ref } = await getSessionForHost(sessionId, context.auth.uid);
  const stateRef = db.collection("sessions").doc(sessionId).collection("recording").doc("current");
  const stateSnap = await stateRef.get();
  if (!stateSnap.exists) {
    return { status: "not-recording", recordingURL: null };
  }

  const state = stateSnap.data() || {};
  if (!state.resourceId || !state.sid || !state.uid || !state.cname) {
    throw new functions.https.HttpsError("failed-precondition", "Cloud recording state is incomplete.");
  }

  const result = await stopAgoraRecordingState(config, sessionId, stateRef, state, "host_stopped");
  const refUpdate = {
    isRecording: false,
    lastSyncedAt: admin.firestore.FieldValue.serverTimestamp(),
  };
  if (result.recordingURL) refUpdate.recordingURL = result.recordingURL;
  await ref.set(refUpdate, { merge: true });

  return result;
});

exports.queryAgoraCloudRecording = functions.https.onCall(async (data, context) => {
  if (!context.auth || !context.auth.uid) {
    throw new functions.https.HttpsError("unauthenticated", "Must be signed in.");
  }
  const sessionId = String(data && data.sessionId ? data.sessionId : "").trim();
  if (!sessionId) {
    throw new functions.https.HttpsError("invalid-argument", "sessionId is required.");
  }
  const config = requiredAgoraRecordingConfig();
  await getSessionForHost(sessionId, context.auth.uid);
  const stateSnap = await db.collection("sessions").doc(sessionId).collection("recording").doc("current").get();
  if (!stateSnap.exists) return { status: "not-recording" };
  const state = stateSnap.data() || {};
  if (!state.resourceId || !state.sid || !state.uid || !state.cname) return { status: state.status || "unknown" };

  const result = await agoraRequest(
    config,
    `resourceid/${state.resourceId}/sid/${state.sid}/mode/${state.mode || AGORA_RECORDING_MODE}/query`,
    undefined,
    "GET"
  );
  return { status: state.status || "recording", response: result };
});

exports.stopExpiredAgoraRecordings = functions.pubsub.schedule("every 15 minutes").onRun(async () => {
  const config = requiredAgoraRecordingConfig();
  const active = await db.collectionGroup("recording").where("status", "in", ["starting", "recording"]).get();
  const stopped = [];
  const skipped = [];

  for (const doc of active.docs) {
    const state = doc.data() || {};
    const ageSeconds = recordingAgeSeconds(state);
    if (!ageSeconds || ageSeconds < config.maxDurationSeconds) {
      skipped.push({ path: doc.ref.path, ageSeconds });
      continue;
    }

    const sessionDoc = doc.ref.parent.parent;
    const sessionId = sessionDoc ? sessionDoc.id : "";
    if (!sessionId) {
      skipped.push({ path: doc.ref.path, reason: "missing-session-id" });
      continue;
    }

    try {
      const result = await stopAgoraRecordingState(config, sessionId, doc.ref, state, "max_duration_guardrail");
      stopped.push({ sessionId, status: result.status, ageSeconds });
    } catch (e) {
      functions.logger.warn("Failed to stop expired Agora recording", { path: doc.ref.path, sessionId, error: e.message });
      skipped.push({ sessionId, error: e.message });
    }
  }

  functions.logger.info("Agora recording duration guardrail complete", { stopped, skippedCount: skipped.length });
  return { stopped, skippedCount: skipped.length };
});

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

async function removeJournalDuplicates(userId, dryRun) {
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
    if (!dryRun) await ref.delete();
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
      if (!dryRun) await group[i].ref.delete();
      deletedByContent++;
    }
  }

  return { deletedById, deletedByContent };
}

async function removePrayerDuplicates(userId, dryRun) {
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
    if (!dryRun) await ref.delete();
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
      if (!dryRun) await group[i].ref.delete();
      deletedByContent++;
    }
  }

  return { deletedById, deletedByContent };
}

/**
 * Developer-only callable: check and optionally remove duplicate journal entries and prayer requests.
 * Call with { dryRun: true } to only report (default). Call with { dryRun: false } to remove duplicates.
 */
exports.checkAndRemoveDuplicates = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError("unauthenticated", "Must be signed in.");
  }
  if (!(await isAdminForCallableAsync(context))) {
    throw new functions.https.HttpsError("permission-denied", "Admin only.");
  }

  const dryRun = data && data.dryRun !== false;

  const usersSnap = await db.collection("users").get();
  const userIds = usersSnap.docs.map((d) => d.id);

  let totalJournalById = 0, totalJournalByContent = 0, totalPrayerById = 0, totalPrayerByContent = 0;
  const byUser = [];

  for (const userId of userIds) {
    const j = await removeJournalDuplicates(userId, dryRun);
    const p = await removePrayerDuplicates(userId, dryRun);
    totalJournalById += j.deletedById;
    totalJournalByContent += j.deletedByContent;
    totalPrayerById += p.deletedById;
    totalPrayerByContent += p.deletedByContent;
    if (j.deletedById || j.deletedByContent || p.deletedById || p.deletedByContent) {
      byUser.push({
        userId,
        journal: j.deletedById + j.deletedByContent,
        prayer: p.deletedById + p.deletedByContent,
      });
    }
  }

  return {
    dryRun,
    userCount: userIds.length,
    byUser,
    journalById: totalJournalById,
    journalByContent: totalJournalByContent,
    prayerById: totalPrayerById,
    prayerByContent: totalPrayerByContent,
  };
});

/**
 * HTTP endpoint to check/remove duplicates (for Firebase CLI or curl).
 * Set a secret: firebase functions:config:set duplicates.secret="YOUR_SECRET"
 * Then: curl -X POST "https://REGION-PROJECT.cloudfunctions.net/checkDuplicatesHttp" \
 *   -H "Content-Type: application/json" \
 *   -d '{"secret":"YOUR_SECRET","dryRun":true}'
 */
exports.checkDuplicatesHttp = functions.https.onRequest(async (req, res) => {
  if (req.method !== "POST") {
    res.status(405).json({ error: "Method not allowed" });
    return;
  }

  const secret = (req.body && req.body.secret) || (req.get("x-duplicates-secret") || "");
  const expected = functions.config().duplicates && functions.config().duplicates.secret;
  if (!expected || secret !== expected) {
    res.status(403).json({ error: "Forbidden" });
    return;
  }

  const dryRun = req.body && req.body.dryRun !== false;

  const usersSnap = await db.collection("users").get();
  const userIds = usersSnap.docs.map((d) => d.id);

  let totalJournalById = 0, totalJournalByContent = 0, totalPrayerById = 0, totalPrayerByContent = 0;
  const byUser = [];

  for (const userId of userIds) {
    const j = await removeJournalDuplicates(userId, dryRun);
    const p = await removePrayerDuplicates(userId, dryRun);
    totalJournalById += j.deletedById;
    totalJournalByContent += j.deletedByContent;
    totalPrayerById += p.deletedById;
    totalPrayerByContent += p.deletedByContent;
    if (j.deletedById || j.deletedByContent || p.deletedById || p.deletedByContent) {
      byUser.push({ userId, journal: j.deletedById + j.deletedByContent, prayer: p.deletedById + p.deletedByContent });
    }
  }

  res.json({
    dryRun,
    userCount: userIds.length,
    byUser,
    journalById: totalJournalById,
    journalByContent: totalJournalByContent,
    prayerById: totalPrayerById,
    prayerByContent: totalPrayerByContent,
  });
});
