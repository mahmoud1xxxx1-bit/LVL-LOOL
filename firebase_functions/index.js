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
        const gold = userData.gold || 0;
        
        if (gold < 500) {
            throw new functions.https.HttpsError('failed-precondition', 'Not enough gold');
        }
        
        // Search for waiting match
        const waitingMatches = await transaction.get(db.collection('duels').where('status', '==', 'searching').limit(1));
        
        if (!waitingMatches.empty) {
            // Join existing match
            const matchDoc = waitingMatches.docs[0];
            if (matchDoc.data().player1 !== uid) {
                transaction.update(userRef, { gold: admin.firestore.FieldValue.increment(-500) });
                transaction.update(matchDoc.ref, {
                    player2: uid,
                    status: 'playing',
                    startTime: admin.firestore.FieldValue.serverTimestamp()
                });
                return { matchId: matchDoc.id, status: 'playing' };
            }
        }
        
        // Create new match
        transaction.update(userRef, { gold: admin.firestore.FieldValue.increment(-500) });
        const newMatchRef = db.collection('duels').doc();
        transaction.set(newMatchRef, {
            player1: uid,
            player2: null,
            status: 'searching',
            stage: Math.floor(Math.random() * 75) + 101, // 101 to 175
            seed: Math.floor(Math.random() * 1000000),
            startTime: null,
            p1Progress: 0,
            p2Progress: 0,
            winner: null
        });
        
        return { matchId: newMatchRef.id, status: 'searching' };
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

        const now = admin.firestore.Timestamp.now();
        const elapsedSeconds = now.seconds - match.startTime.seconds;
        if (elapsedSeconds > 185) { 
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
        transaction.update(userRef, {
            gold: admin.firestore.FieldValue.increment(1000),
            rp: admin.firestore.FieldValue.increment(30)
        });
        
        if (opponentId) {
            const oppRef = db.collection('users').doc(opponentId);
            transaction.update(oppRef, {
                rp: admin.firestore.FieldValue.increment(-15)
            });
        }
        
        return { success: true };
    });
});

exports.resolveTimeout = functions.https.onCall(async (data, context) => {
    if (!context.auth) throw new functions.https.HttpsError('unauthenticated', 'User must be logged in.');
    const uid = context.auth.uid;
    const matchId = data.matchId;
    
    return await db.runTransaction(async (transaction) => {
        const matchRef = db.collection('duels').doc(matchId);
        const matchDoc = await transaction.get(matchRef);
        if (!matchDoc.exists) throw new functions.https.HttpsError('not-found', 'Match not found');
        
        const match = matchDoc.data();
        if (match.status !== 'playing') {
            return { status: match.status }; // Already resolved
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
            transaction.update(db.collection('users').doc(winnerId), {
                gold: admin.firestore.FieldValue.increment(1000),
                rp: admin.firestore.FieldValue.increment(30)
            });
            if (loserId) {
                transaction.update(db.collection('users').doc(loserId), {
                    rp: admin.firestore.FieldValue.increment(-15)
                });
            }
            return { status: 'win', winner: winnerId };
        } else {
            transaction.update(matchRef, { status: 'draw', winner: 'none' });
            if (match.player1) transaction.update(db.collection('users').doc(match.player1), { gold: admin.firestore.FieldValue.increment(350) });
            if (match.player2) transaction.update(db.collection('users').doc(match.player2), { gold: admin.firestore.FieldValue.increment(350) });
            return { status: 'draw' };
        }
    });
});


exports.claimSoloWin = functions.https.onCall(async (data, context) => {
    if (!context.auth) throw new functions.https.HttpsError('unauthenticated', 'User must be logged in.');
    const uid = context.auth.uid;
    const stageId = data.stageId;
    
    if (typeof stageId !== 'number' || stageId < 1 || stageId > 75) {
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
