
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;

class LvlloPlatformerAuth {
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  static Future<User?> signInWithGoogle() async {
    try {
      if (kIsWeb) {
        final GoogleAuthProvider googleProvider = GoogleAuthProvider();
        final UserCredential userCredential = await _auth.signInWithPopup(googleProvider);
        final User? user = userCredential.user;
        if (user != null) {
          await _syncUserData(user);
        }
        return user;
      } else {
        final googleSignIn = GoogleSignIn.instance;
        try {
          await googleSignIn.initialize(
            serverClientId: '351650195477-okbctajcbqg812eclubim7cckfkn49s9.apps.googleusercontent.com',
          );
        } catch (_) {}
        
        final googleUser = await googleSignIn.authenticate();
        final googleAuth = googleUser.authentication;
        final idToken = googleAuth.idToken;
        if (idToken == null || idToken.isEmpty) {
          throw Exception('Google Sign-in did not return an ID token.');
        }
        final credential = GoogleAuthProvider.credential(idToken: idToken);
        
        final UserCredential userCredential = await _auth.signInWithCredential(credential);
        final User? user = userCredential.user;

        if (user != null) {
          await _syncUserData(user);
        }
        return user;
      }
    } catch (e) {
      debugPrint('Error signing in with Google: $e');
      throw Exception(e.toString());
    }
  }

  static Future<void> _syncUserData(User user) async {
    final docRef = _db.collection('users').doc(user.uid);
    final snapshot = await docRef.get();

    if (!snapshot.exists) {
      // Create new user profile based on the architecture
      await docRef.set({
        'displayName': user.displayName ?? 'Player',
        'avatarId': 1,
        'freeNameChangeUsed': false,
        'createdAt': FieldValue.serverTimestamp(),
        'lastLogin': FieldValue.serverTimestamp(),
        'gold': 0,
        'gems': 0,
        'lives': 10, // Default max
        'nextLifeRefillTime': FieldValue.serverTimestamp(),
        'penaltyDate': '',
        'penaltyCount': 0,
        'isVip': false,
        'vipExpirationDate': null,
        'highestLevelUnlocked': 1,
        'settings': {
          'sound': true,
          'music': true,
          'language': 'en'
        }
      });
    } else {
      // Update last login
      await docRef.update({
        'lastLogin': FieldValue.serverTimestamp(),
      });
    }
  }

  static Future<void> signOut() async {
    await GoogleSignIn.instance.signOut();
    await _auth.signOut();
  }
}

