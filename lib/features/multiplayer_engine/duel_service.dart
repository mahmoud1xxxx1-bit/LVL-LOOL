import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

class DuelService {
  static final _functions = FirebaseFunctions.instance;
  static final _firestore = FirebaseFirestore.instance;
  static final _auth = FirebaseAuth.instance;

  static Future<Map<String, dynamic>> findOrCreateDuel() async {
    final result = await _functions.httpsCallable('findOrCreateDuel').call();
    return Map<String, dynamic>.from(result.data);
  }

  static Future<void> claimDuelWin(String matchId) async {
    await _functions.httpsCallable('claimDuelWin').call({'matchId': matchId});
  }

  static Future<void> resolveTimeout(String matchId) async {
    await _functions.httpsCallable('resolveTimeout').call({'matchId': matchId});
  }

  static Future<int> claimSoloWin(int stageId) async {
    final result = await _functions.httpsCallable('claimSoloWin').call({'stageId': stageId});
    return result.data['gold'] as int;
  }

  static Stream<DocumentSnapshot> streamMatch(String matchId) {
    return _firestore.collection('duels').doc(matchId).snapshots();
  }

  static Future<void> updateProgress(String matchId, double progress) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    
    // Server-authoritative progress update via Cloud Function
    // This enforces progress cannot decrease and stays within 0..1
    try {
      await _functions.httpsCallable('updateDuelProgress').call({
        'matchId': matchId, 
        'progress': progress
      });
    } catch (e) {
      // Ignored for fast telemetry
    }
  }
}
