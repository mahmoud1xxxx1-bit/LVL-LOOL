
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'firebase/lvllo_auth.dart';
import '../../../../main_lvllo_platformer_app.dart';
import '../../../../core/theme/lvllo_art_backdrop.dart';

class LvlloPlatformerLoginScreen extends StatefulWidget {
  const LvlloPlatformerLoginScreen({super.key});
  @override State<LvlloPlatformerLoginScreen> createState() => _LvlloPlatformerLoginScreenState();
}

class _LvlloPlatformerLoginScreenState extends State<LvlloPlatformerLoginScreen> {
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (FirebaseAuth.instance.currentUser != null) _navigateToHome();
    });
  }

  void _navigateToHome() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => SeasonsMenuScreen()),
    );
  }

  Future<void> _handleSignIn() async {
    setState(() => _isLoading = true);
    try {
      final user = await LvlloPlatformerAuth.signInWithGoogle();
      if (user != null && mounted) _navigateToHome();
    } catch (error) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFF11162F),
          content: Text('SIGN IN FAILED\n$error'),
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).height < 720;
    return Scaffold(
      backgroundColor: const Color(0xFF050716),
      body: LvlloArtBackdrop(
        showDevil: true,
        showGrid: true,
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) => SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Padding(
                  padding: EdgeInsets.fromLTRB(24, compact ? 16 : 28, 24, 20),
                  child: Column(
                    children: [
                      const Spacer(flex: 2),
                      _brandTitle(),
                      SizedBox(height: compact ? 18 : 28),
                      _loginPanel(),
                      const Spacer(flex: 2),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _brandTitle() => Column(
    children: [
      ShaderMask(
        shaderCallback: (bounds) => const LinearGradient(
          colors: [Color(0xFF22E6FF), Color(0xFF7A62FF), Color(0xFFD044FF)],
        ).createShader(bounds),
        child: const Text(
          'LVL LOOL',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white,
            fontSize: 42,
            height: .95,
            fontWeight: FontWeight.w900,
            letterSpacing: 2.2,
            shadows: [Shadow(color: Color(0xAA20DFFF), blurRadius: 22)],
          ),
        ),
      ),
      const SizedBox(height: 8),
      const Text(
        'THE TROLL PLATFORMER',
        style: TextStyle(
          color: Color(0xFF49F1FF),
          fontSize: 9,
          fontWeight: FontWeight.w900,
          letterSpacing: 2.2,
        ),
      ),
    ],
  );

  Widget _loginPanel() => Container(
    width: double.infinity,
    constraints: const BoxConstraints(maxWidth: 390),
    padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
    decoration: BoxDecoration(
      color: const Color(0xD90A1230),
      borderRadius: BorderRadius.circular(22),
      border: Border.all(color: const Color(0x6646EFFF)),
      boxShadow: const [BoxShadow(color: Color(0x5521D9FF), blurRadius: 28, spreadRadius: 2)],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('READY TO RAGE?', style: TextStyle(color: Color(0xFFE5EAF8), fontSize: 18, fontWeight: FontWeight.w900)),
        const SizedBox(height: 7),
        const Text(
          'Enter a deterministic world of traps, timing and\nmuscle memory.',
          style: TextStyle(color: Color(0xFF9AA7C4), fontSize: 9, height: 1.35),
        ),
        const SizedBox(height: 16),
        _googleButton(),
        const SizedBox(height: 9),
        const Center(
          child: Text(
            'Your progress and economy stay on this device/account.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Color(0xFF71809F), fontSize: 7.5),
          ),
        ),
      ],
    ),
  );

  Widget _googleButton() => Material(
    color: Colors.transparent,
    borderRadius: BorderRadius.circular(15),
    child: InkWell(
      onTap: _isLoading ? null : _handleSignIn,
      borderRadius: BorderRadius.circular(15),
      child: Ink(
        height: 52,
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [Color(0xFF20D8EE), Color(0xFF5668FF), Color(0xFFD145E9)]),
          borderRadius: BorderRadius.circular(15),
          boxShadow: const [BoxShadow(color: Color(0x6639E8FF), blurRadius: 20)],
        ),
        child: Center(
          child: _isLoading
              ? const SizedBox(
                  width: 22, height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    valueColor: AlwaysStoppedAnimation(Colors.white),
                  ),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 26, height: 26,
                      decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                      alignment: Alignment.center,
                      child: const Text('G', style: TextStyle(color: Color(0xFF4285F4), fontSize: 16, fontWeight: FontWeight.w900)),
                    ),
                    const SizedBox(width: 9),
                    const Text(
                      'SIGN IN WITH GOOGLE',
                      style: TextStyle(color: Color(0xFF07102B), fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: .7),
                    ),
                  ],
                ),
        ),
      ),
    ),
  );
}
