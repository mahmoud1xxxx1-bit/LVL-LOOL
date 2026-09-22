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
            ? const _Login()
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

class _Login extends StatefulWidget {
  const _Login();

  @override
  State<_Login> createState() => _LoginState();
}

class _LoginState extends State<_Login> {
  bool loading = false;

  Future<void> _signIn() async {
    setState(() => loading = true);
    try {
      await LvlloPlatformerAuth.signInWithGoogle();
    } catch (e) {
      if (!mounted) return;
      setState(() => loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Sign in failed: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CosmicBackground(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(22),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: CosmicPanel(
                glow: true,
                padding: const EdgeInsets.fromLTRB(26, 30, 26, 26),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const LvlloBrandMark(size: 118),
                    const SizedBox(height: 16),
                    const Text('LVL LOOL', style: TextStyle(fontSize: 40, fontWeight: FontWeight.w900, letterSpacing: 4)),
                    const SizedBox(height: 5),
                    const Text('THE TROLL PLATFORMER', style: TextStyle(color: GameColors.accentBright, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 2)),
                    const SizedBox(height: 34),
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text('READY TO RAGE?', style: TextStyle(fontSize: 23, fontWeight: FontWeight.w900)),
                    ),
                    const SizedBox(height: 7),
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Enter a deterministic world of traps, timing and muscle memory.',
                        style: TextStyle(color: GameColors.muted, fontSize: 12, height: 1.4),
                      ),
                    ),
                    const SizedBox(height: 20),
                    CosmicPrimaryButton(
                      onPressed: loading ? null : _signIn,
                      child: loading
                          ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: GameColors.backgroundDeep))
                          : const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.login_rounded),
                                SizedBox(width: 9),
                                Text('SIGN IN WITH GOOGLE'),
                              ],
                            ),
                    ),
                    const SizedBox(height: 11),
                    const Text(
                      'Your progress and economy stay on this device/account.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: GameColors.muted, fontSize: 9),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
