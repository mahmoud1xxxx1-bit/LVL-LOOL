const functions = require('firebase-functions');
const admin = require('firebase-admin');
admin.initializeApp();
const db = admin.firestore();

const DUEL_STAKE = 500;
const DUEL_WIN_GOLD = 1000;
const DUEL_WIN_RP = 30;
const DUEL_LOSE_RP = -15;
const DUEL_DRAW_GOLD = 350;
const DUEL_LIMIT_MS = 180000;

// Progress is server-capped. The client may report movement, but it can never
// advance the stored value faster than this envelope. This prevents instant
// completion/progress injection and keeps the reward decision server-side.
const MAX_PROGRESS_PER_SECOND = 0.10;
const MIN_PROGRESS_UPDATE_MS = 750;
const MIN_COMPLETION_MS = 10000;

function activeDuelStatuses() {
  return ['searching', 'playing'];
}

async function findExistingActiveDuel(transaction, uid) {
  const p1 = await transaction.get(
    db.collection('duels').where('player1', '==', uid).where('status', 'in', activeDuelStatuses()).limit(1)
  );
  if (!p1.empty) return p1.docs[0];

  const p2 = await transaction.get(
    db.collection('duels').where('player2', '==', uid).where('status', 'in', activeDuelStatuses()).limit(1)
  );
  if (!p2.empty) return p2.docs[0];

  return null;
}

exports.findOrCreateDuel = functions.https.onCall(async (data, context) => {
  if (!context.auth) throw new functions.https.HttpsError('unauthenticated', 'User must be logged in.');
  const uid = context.auth.uid;

  return await db.runTransaction(async (transaction) => {
    const userRef = db.collection('users').doc(uid);
    const userDoc = await transaction.get(userRef);
    const userData = userDoc.data() || { gold: 0, rp: 1000 };

    const activeMatch = await findExistingActiveDuel(transaction, uid);
    if (activeMatch) {
      const activeData = activeMatch.data();
      transaction.set(userRef, { activeDuel: activeMatch.id }, { merge: true });
      return { matchId: activeMatch.id, status: activeData.status };
    }

    if (userData.activeDuel) {
      transaction.set(userRef, { activeDuel: admin.firestore.FieldValue.delete() }, { merge: true });
    }

    const gold = Number(userData.gold || 0);
    if (gold < DUEL_STAKE) {
      throw new functions.https.HttpsError('failed-precondition', 'Not enough gold');
    }

    const waitingMatches = await transaction.get(
      db.collection('duels').where('status', '==', 'searching').limit(10)
    );

    for (const matchDoc of waitingMatches.docs) {
      const match = matchDoc.data();
      if (match.player1 && match.player1 !== uid && !match.player2) {
        const now = admin.firestore.Timestamp.now();
        transaction.set(userRef, {
          gold: admin.firestore.FieldValue.increment(-DUEL_STAKE),
          activeDuel: matchDoc.id
        }, { merge: true });
        transaction.update(matchDoc.ref, {
          player2: uid,
          status: 'playing',
          startTime: now,
          p1LastUpdate: now,
          p2LastUpdate: now
        });
        return { matchId: matchDoc.id, status: 'playing' };
      }
    }

    const newMatchRef = db.collection('duels').doc();
    transaction.set(userRef, {
      gold: admin.firestore.FieldValue.increment(-DUEL_STAKE),
      activeDuel: newMatchRef.id
    }, { merge: true });

    transaction.set(newMatchRef, {
      player1: uid,
      player2: null,
      status: 'searching',
      stageId: Math.floor(Math.random() * 75) + 101,
      seed: Math.floor(Math.random() * 1000000),
      startTime: null,
      p1Progress: 0,
      p2Progress: 0,
      p1LastUpdate: null,
      p2LastUpdate: null,
      p1CompletionReady: false,
      p2CompletionReady: false,
      winner: null
    });

    return { matchId: newMatchRef.id, status: 'searching' };
  });
});

exports.updateDuelProgress = functions.https.onCall(async (data, context) => {
  if (!context.auth) throw new functions.https.HttpsError('unauthenticated', 'User must be logged in.');

  const uid = context.auth.uid;
  const { matchId, progress } = data;

  if (typeof matchId !== 'string' || !matchId) {
    throw new functions.https.HttpsError('invalid-argument', 'Invalid matchId');
  }
  if (typeof progress !== 'number' || !Number.isFinite(progress) || progress < 0 || progress > 1) {
    throw new functions.https.HttpsError('invalid-argument', 'Invalid progress value');
  }

  return await db.runTransaction(async (transaction) => {
    const matchRef = db.collection('duels').doc(matchId);
    const matchDoc = await transaction.get(matchRef);
    if (!matchDoc.exists) throw new functions.https.HttpsError('not-found', 'Match not found');

    const match = matchDoc.data();
    if (match.status !== 'playing' || !match.startTime) {
      return { success: false, reason: 'not playing' };
    }

    const now = admin.firestore.Timestamp.now();
    const nowMs = now.toMillis();
    const startMs = match.startTime.toMillis();
    const elapsedMs = nowMs - startMs;

    let progressField;
    let lastUpdateField;
    let completionField;

    if (match.player1 === uid) {
      progressField = 'p1Progress';
      lastUpdateField = 'p1LastUpdate';
      completionField = 'p1CompletionReady';
    } else if (match.player2 === uid) {
      progressField = 'p2Progress';
      lastUpdateField = 'p2LastUpdate';
      completionField = 'p2CompletionReady';
    } else {
      throw new functions.https.HttpsError('permission-denied', 'Not in this match');
    }

    const oldProgress = Number(match[progressField] || 0);
    const lastUpdateMs = match[lastUpdateField] ? match[lastUpdateField].toMillis() : startMs;
    const sinceLastMs = Math.max(0, nowMs - lastUpdateMs);

    if (progress <= oldProgress) {
      return { success: true, progress: oldProgress };
    }

    // A client cannot jump to 1.0 (or any other arbitrary value). The server
    // computes the maximum legal advancement from server time and old progress.
    const elapsedEnvelope = Math.max(0, elapsedMs / 1000) * MAX_PROGRESS_PER_SECOND;
    const maxByTime = Math.min(1, elapsedEnvelope);
    const maxByUpdate = oldProgress + (sinceLastMs / 1000) * MAX_PROGRESS_PER_SECOND;
    const allowed = Math.min(1, maxByTime, maxByUpdate);

    if (sinceLastMs < MIN_PROGRESS_UPDATE_MS && progress > oldProgress) {
      throw new functions.https.HttpsError('resource-exhausted', 'Progress updates are too frequent');
    }

    const accepted = Math.min(progress, allowed);
    const completed = accepted >= 1 &&
        oldProgress >= 0.90 &&
        elapsedMs >= MIN_COMPLETION_MS;

    transaction.update(matchRef, {
      [progressField]: accepted,
      [lastUpdateField]: now,
      [completionField]: completed
    });

    return {
      success: true,
      progress: accepted,
      completionReady: completed
    };
  });
});

exports.claimDuelWin = functions.https.onCall(async (data, context) => {
  if (!context.auth) throw new functions.https.HttpsError('unauthenticated', 'User must be logged in.');
  const uid = context.auth.uid;
  const matchId = data.matchId;

  if (typeof matchId !== 'string' || !matchId) {
    throw new functions.https.HttpsError('invalid-argument', 'Invalid matchId');
  }

  return await db.runTransaction(async (transaction) => {
    const matchRef = db.collection('duels').doc(matchId);
    const matchDoc = await transaction.get(matchRef);
    if (!matchDoc.exists) throw new functions.https.HttpsError('not-found', 'Match not found');

    const match = matchDoc.data();
    if (match.status !== 'playing') {
      throw new functions.https.HttpsError('failed-precondition', 'Match is not active');
    }
    if (match.player1 !== uid && match.player2 !== uid) {
      throw new functions.https.HttpsError('permission-denied', 'You are not in this match');
    }

    const myProgress = match.player1 === uid ? Number(match.p1Progress || 0) : Number(match.p2Progress || 0);
    const myReady = match.player1 === uid ? match.p1CompletionReady === true : match.p2CompletionReady === true;

    const now = admin.firestore.Timestamp.now();
    const elapsedMs = now.toMillis() - match.startTime.toMillis();

    if (elapsedMs >= DUEL_LIMIT_MS) {
      throw new functions.https.HttpsError('out-of-range', 'Time limit exceeded');
    }
    if (!myReady || myProgress < 1) {
      throw new functions.https.HttpsError('failed-precondition', 'Server completion proof not reached');
    }

    const opponentId = match.player1 === uid ? match.player2 : match.player1;

    transaction.update(matchRef, {
      status: 'finished',
      winner: uid,
      endTime: now
    });

    transaction.set(db.collection('users').doc(uid), {
      gold: admin.firestore.FieldValue.increment(DUEL_WIN_GOLD),
      rp: admin.firestore.FieldValue.increment(DUEL_WIN_RP),
      activeDuel: admin.firestore.FieldValue.delete()
    }, { merge: true });

    if (opponentId) {
      transaction.set(db.collection('users').doc(opponentId), {
        rp: admin.firestore.FieldValue.increment(DUEL_LOSE_RP),
        activeDuel: admin.firestore.FieldValue.delete()
      }, { merge: true });
    }

    return { success: true, status: 'finished' };
  });
});

exports.resolveTimeout = functions.https.onCall(async (data, context) => {
  if (!context.auth) throw new functions.https.HttpsError('unauthenticated', 'User must be logged in.');
  const matchId = data.matchId;

  if (typeof matchId !== 'string' || !matchId) {
    throw new functions.https.HttpsError('invalid-argument', 'Invalid matchId');
  }

  return await db.runTransaction(async (transaction) => {
    const matchRef = db.collection('duels').doc(matchId);
    const matchDoc = await transaction.get(matchRef);
    if (!matchDoc.exists) throw new functions.https.HttpsError('not-found', 'Match not found');

    const match = matchDoc.data();
    if (match.status !== 'playing') return { status: match.status };

    const uid = context.auth.uid;
    if (match.player1 !== uid && match.player2 !== uid) {
      throw new functions.https.HttpsError('permission-denied', 'You are not in this match');
    }

    const now = admin.firestore.Timestamp.now();
    const elapsedMs = now.toMillis() - match.startTime.toMillis();
    if (elapsedMs < DUEL_LIMIT_MS) {
      throw new functions.https.HttpsError('failed-precondition', 'Time has not expired yet');
    }

    const p1Progress = Number(match.p1Progress || 0);
    const p2Progress = Number(match.p2Progress || 0);

    let winnerId = null;
    let loserId = null;

    if (p1Progress > p2Progress) {
      winnerId = match.player1;
      loserId = match.player2;
    } else if (p2Progress > p1Progress) {
      winnerId = match.player2;
      loserId = match.player1;
    }

    if (winnerId) {
      transaction.update(matchRef, {
        status: 'timeout_win',
        winner: winnerId,
        endTime: now
      });
      transaction.set(db.collection('users').doc(winnerId), {
        gold: admin.firestore.FieldValue.increment(DUEL_WIN_GOLD),
        rp: admin.firestore.FieldValue.increment(DUEL_WIN_RP),
        activeDuel: admin.firestore.FieldValue.delete()
      }, { merge: true });
      if (loserId) {
        transaction.set(db.collection('users').doc(loserId), {
          rp: admin.firestore.FieldValue.increment(DUEL_LOSE_RP),
          activeDuel: admin.firestore.FieldValue.delete()
        }, { merge: true });
      }
      return { status: 'win', winner: winnerId };
    }

    transaction.update(matchRef, { status: 'draw', winner: 'none', endTime: now });
    if (match.player1) {
      transaction.set(db.collection('users').doc(match.player1), {
        gold: admin.firestore.FieldValue.increment(DUEL_DRAW_GOLD),
        activeDuel: admin.firestore.FieldValue.delete()
      }, { merge: true });
    }
    if (match.player2) {
      transaction.set(db.collection('users').doc(match.player2), {
        gold: admin.firestore.FieldValue.increment(DUEL_DRAW_GOLD),
        activeDuel: admin.firestore.FieldValue.delete()
      }, { merge: true });
    }
    return { status: 'draw' };
  });
});

exports.claimSoloWin = functions.https.onCall(async (data, context) => {
  if (!context.auth) throw new functions.https.HttpsError('unauthenticated', 'User must be logged in.');
  const uid = context.auth.uid;
  const stageId = data.stageId;

  if (typeof stageId !== 'number' || stageId < 101 || stageId > 175 || !Number.isInteger(stageId)) {
    throw new functions.https.HttpsError('invalid-argument', 'Invalid stage');
  }

  const now = admin.firestore.Timestamp.now();
  const todayStr = new Date(now.toMillis()).toISOString().split('T')[0];
  const claimId = todayStr + '_' + stageId;

  return await db.runTransaction(async (transaction) => {
    const userRef = db.collection('users').doc(uid);
    const claimRef = userRef.collection('solo_claims').doc(claimId);
    const claimDoc = await transaction.get(claimRef);

    if (claimDoc.exists) {
      throw new functions.https.HttpsError('already-exists', 'Already claimed today');
    }

    // The reward is granted only by this transaction. Firestore clients cannot
    // write users/gold/rp or solo_claims directly because of the rules.
    transaction.set(claimRef, { claimedAt: now, stageId });
    const userDoc = await transaction.get(userRef);

    if (!userDoc.exists) {
      transaction.set(userRef, { gold: 250, rp: 1000 });
    } else {
      transaction.update(userRef, { gold: admin.firestore.FieldValue.increment(250) });
    }

    return { success: true, gold: 250 };
  });
});
