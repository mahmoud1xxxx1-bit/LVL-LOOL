import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'core/navigation/game_orientation.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/cosmic_background.dart';
import 'core/theme/design_tokens.dart';
import 'core/theme/lvllo_brand.dart';
import 'features/lvllo_platformer/firebase/lvllo_auth.dart';
import 'features/lvllo_platformer/lvllo_lobby_screen.dart';
import 'features/lvllo_platformer/login_screen.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const LvlloApp());
  WidgetsBinding.instance.addPostFrameCallback((_) {
    unawaited(_initializeNonCriticalServices());
    unawaited(GameOrientation.enterPortrait());
  });
}

Future<void> _initializeNonCriticalServices() async {
  try {
    await MobileAds.instance.initialize();
  } catch (error) {
    debugPrint('LVL LOOL Ads unavailable: $error');
  }
}

class LvlloApp extends StatefulWidget {
  const LvlloApp({super.key});

  @override
  State<LvlloApp> createState() => _LvlloAppState();
}

class _LvlloAppState extends State<LvlloApp> {
  bool _firebaseReady = false;
  bool _firebaseFailed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_initServices());
    });
  }

  Future<void> _initServices() async {
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      ).timeout(const Duration(seconds: 6));
      if (!mounted) return;
      setState(() => _firebaseReady = true);
    } catch (error) {
      debugPrint('LVL LOOL Firebase unavailable: $error');
      if (!mounted) return;
      setState(() => _firebaseFailed = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'LVL LOOL',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      home: _EntryGate(
        firebaseReady: _firebaseReady,
        firebaseFailed: _firebaseFailed,
      ),
    );
  }
}

class _EntryGate extends StatelessWidget {
  const _EntryGate({required this.firebaseReady, required this.firebaseFailed});

  final bool firebaseReady;
  final bool firebaseFailed;

  @override
  Widget build(BuildContext context) {
    if (firebaseFailed) return const LvlloLobbyScreen();
    if (!firebaseReady) return const _Splash();

    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const _Splash();
        }
        return snapshot.data == null
            ? const LvlloPlatformerLoginScreen()
            : const LvlloLobbyScreen();
      },
    );
  }
}

class _Splash extends StatelessWidget {
  const _Splash();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: CosmicBackground(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              LvlloBrandMark(size: 104),
              SizedBox(height: 20),
              Text('LVL LOOL', style: TextStyle(fontSize: 34, fontWeight: FontWeight.w900, letterSpacing: 4)),
              SizedBox(height: 7),
              Text('THE TROLL PLATFORMER', style: TextStyle(color: GameColors.accentBright, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 2)),
            ],
          ),
        ),
      ),
    );
  }
}

