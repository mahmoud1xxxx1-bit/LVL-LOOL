const functions = require('firebase-functions');
const admin = require('firebase-admin');
admin.initializeApp();
const db = admin.firestore();

exports.findOrCreateDuel = functions.https.onCall(async (data, context) => {
    if (!context.auth) throw new functions.https.HttpsError('unauthenticated', 'User must be logged in.');
    const uid = context.auth.uid;
    
    return await db.runTransaction(async (transaction) => {
        const userRef = db.collection('users').doc(uid);
        const userDoc = await transaction.get(userRef);
        const userData = userDoc.data() || { gold: 0, rp: 1000 };
        
        // If user already has an active duel
        if (userData.activeDuel) {
            const existingMatchRef = db.collection('duels').doc(userData.activeDuel);
            const existingMatchDoc = await transaction.get(existingMatchRef);
            if (existingMatchDoc.exists) {
                const status = existingMatchDoc.data().status;
                if (status === 'searching' || status === 'playing') {
                    // Do not deduct gold, just return existing match
                    return { matchId: existingMatchDoc.id, status: status };
                }
            }
            // If the duel finished/timeout, clear it (it will be overwritten below)
        }
        
        const gold = userData.gold || 0;
        if (gold < 500) {
            throw new functions.https.HttpsError('failed-precondition', 'Not enough gold');
        }
        
        // Search for waiting match
        const waitingMatches = await transaction.get(db.collection('duels').where('status', '==', 'searching').limit(1));
        
        if (!waitingMatches.empty) {
            const matchDoc = waitingMatches.docs[0];
            if (matchDoc.data().player1 !== uid) {
                // Join existing match
                transaction.set(userRef, { gold: admin.firestore.FieldValue.increment(-500), activeDuel: matchDoc.id }, { merge: true });
                transaction.update(matchDoc.ref, {
                    player2: uid,
                    status: 'playing',
                    startTime: admin.firestore.FieldValue.serverTimestamp()
                });
                return { matchId: matchDoc.id, status: 'playing' };
            }
        }
        
        // Create new match
        const newMatchRef = db.collection('duels').doc();
        transaction.set(userRef, { gold: admin.firestore.FieldValue.increment(-500), activeDuel: newMatchRef.id }, { merge: true });
        
        transaction.set(newMatchRef, {
            player1: uid,
            player2: null,
            status: 'searching',
            stageId: Math.floor(Math.random() * 75) + 101, // 101 to 175
            seed: Math.floor(Math.random() * 1000000),
            startTime: null,
            p1Progress: 0,
            p2Progress: 0,
            winner: null
        });
        
        return { matchId: newMatchRef.id, status: 'searching' };
    });
});

exports.updateDuelProgress = functions.https.onCall(async (data, context) => {
    if (!context.auth) throw new functions.https.HttpsError('unauthenticated', 'User must be logged in.');
    const uid = context.auth.uid;
    const { matchId, progress } = data;
    
    if (typeof progress !== 'number' || progress < 0 || progress > 1) {
        throw new functions.https.HttpsError('invalid-argument', 'Invalid progress value');
    }
    
    // We can use a transaction or direct update. For performance on progress, we use update with precondition, or get then update.
    // To strictly enforce no-backward progress without transaction: we can just use transaction.
    return await db.runTransaction(async (transaction) => {
        const matchRef = db.collection('duels').doc(matchId);
        const matchDoc = await transaction.get(matchRef);
        if (!matchDoc.exists) throw new functions.https.HttpsError('not-found', 'Match not found');
        
        const match = matchDoc.data();
        if (match.status !== 'playing') return { success: false, reason: 'not playing' };
        
        const now = admin.firestore.Timestamp.now();
        const elapsed = now.seconds - match.startTime.seconds;
        
        if (match.player1 === uid) {
            const oldProg = match.p1Progress || 0;
            const lastUpdate = match.p1LastUpdate ? match.p1LastUpdate.seconds : match.startTime.seconds;
            const timeDiff = now.seconds - lastUpdate;
            
            if (progress > oldProg) {
                // impossible jump check: max 20% progress per second
                const maxAllowed = oldProg + (Math.max(1, timeDiff) * 0.20);
                if (progress > maxAllowed && progress === 1.0 && timeDiff < 3) {
                     // Speedhack detected!
                     return { success: false, reason: 'impossible jump' };
                }
                transaction.update(matchRef, { p1Progress: Math.min(progress, maxAllowed), p1LastUpdate: now });
            }
        } else if (match.player2 === uid) {
            const oldProg = match.p2Progress || 0;
            const lastUpdate = match.p2LastUpdate ? match.p2LastUpdate.seconds : match.startTime.seconds;
            const timeDiff = now.seconds - lastUpdate;
            
            if (progress > oldProg) {
                const maxAllowed = oldProg + (Math.max(1, timeDiff) * 0.20);
                if (progress > maxAllowed && progress === 1.0 && timeDiff < 3) {
                     return { success: false, reason: 'impossible jump' };
                }
                transaction.update(matchRef, { p2Progress: Math.min(progress, maxAllowed), p2LastUpdate: now });
            }
        } else {
            throw new functions.https.HttpsError('permission-denied', 'Not in this match');
        }
        
        return { success: true };
    });
});

exports.claimDuelWin = functions.https.onCall(async (data, context) => {
    if (!context.auth) throw new functions.https.HttpsError('unauthenticated', 'User must be logged in.');
    const uid = context.auth.uid;
    const matchId = data.matchId;
    
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
        
        const myProgress = match.player1 === uid ? match.p1Progress : match.p2Progress;
        if ((myProgress || 0) < 1) {
            throw new functions.https.HttpsError('failed-precondition', 'Server progress not reached 1.0');
        }

        const now = admin.firestore.Timestamp.now();
        const elapsedSeconds = now.seconds - match.startTime.seconds;
        if (elapsedSeconds > 180) { 
             transaction.update(matchRef, { status: 'timeout' });
             throw new functions.https.HttpsError('out-of-range', 'Time limit exceeded');
        }

        const opponentId = match.player1 === uid ? match.player2 : match.player1;
        
        transaction.update(matchRef, {
            status: 'finished',
            winner: uid,
            endTime: now
        });
        
        const userRef = db.collection('users').doc(uid);
        transaction.set(userRef, {
            gold: admin.firestore.FieldValue.increment(1000),
            rp: admin.firestore.FieldValue.increment(30),
            activeDuel: admin.firestore.FieldValue.delete()
        }, { merge: true });
        
        if (opponentId) {
            const oppRef = db.collection('users').doc(opponentId);
            transaction.set(oppRef, {
                rp: admin.firestore.FieldValue.increment(-15),
                activeDuel: admin.firestore.FieldValue.delete()
            }, { merge: true });
        }
        
        return { success: true };
    });
});

exports.resolveTimeout = functions.https.onCall(async (data, context) => {
    if (!context.auth) throw new functions.https.HttpsError('unauthenticated', 'User must be logged in.');
    const matchId = data.matchId;
    
    return await db.runTransaction(async (transaction) => {
        const matchRef = db.collection('duels').doc(matchId);
        const matchDoc = await transaction.get(matchRef);
        if (!matchDoc.exists) throw new functions.https.HttpsError('not-found', 'Match not found');
        
        const match = matchDoc.data();
        if (match.status !== 'playing') {
            return { status: match.status }; 
        }
        
        const uid = context.auth.uid;
        if (match.player1 !== uid && match.player2 !== uid) {
            throw new functions.https.HttpsError('permission-denied', 'You are not in this match');
        }

        const now = admin.firestore.Timestamp.now();
        const elapsedSeconds = now.seconds - match.startTime.seconds;
        if (elapsedSeconds < 180) { 
             throw new functions.https.HttpsError('failed-precondition', 'Time has not expired yet');
        }
        
        const p1Progress = match.p1Progress || 0;
        const p2Progress = match.p2Progress || 0;
        
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
            transaction.update(matchRef, { status: 'timeout_win', winner: winnerId });
            transaction.set(db.collection('users').doc(winnerId), {
                gold: admin.firestore.FieldValue.increment(1000),
                rp: admin.firestore.FieldValue.increment(30),
                activeDuel: admin.firestore.FieldValue.delete()
            }, { merge: true });
            if (loserId) {
                transaction.set(db.collection('users').doc(loserId), {
                    rp: admin.firestore.FieldValue.increment(-15),
                    activeDuel: admin.firestore.FieldValue.delete()
                }, { merge: true });
            }
            return { status: 'win', winner: winnerId };
        } else {
            transaction.update(matchRef, { status: 'draw', winner: 'none' });
            if (match.player1) transaction.set(db.collection('users').doc(match.player1), { gold: admin.firestore.FieldValue.increment(350), activeDuel: admin.firestore.FieldValue.delete() }, { merge: true });
            if (match.player2) transaction.set(db.collection('users').doc(match.player2), { gold: admin.firestore.FieldValue.increment(350), activeDuel: admin.firestore.FieldValue.delete() }, { merge: true });
            return { status: 'draw' };
        }
    });
});

exports.claimSoloWin = functions.https.onCall(async (data, context) => {
    if (!context.auth) throw new functions.https.HttpsError('unauthenticated', 'User must be logged in.');
    const uid = context.auth.uid;
    const stageId = data.stageId;
    
    // Internal stage IDs for Season 6 are 101 to 175
    if (typeof stageId !== 'number' || stageId < 101 || stageId > 175) {
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
        
        transaction.set(claimRef, { claimedAt: now });
        
        const userDoc = await transaction.get(userRef);
        if (!userDoc.exists) {
            transaction.set(userRef, { gold: 250, rp: 1000 });
        } else {
            transaction.update(userRef, { gold: admin.firestore.FieldValue.increment(250) });
        }
        
        return { success: true, gold: 250 };
    });
});
