import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../core/theme/cosmic_background.dart';
import '../../core/theme/design_tokens.dart';
import '../../core/theme/lvllo_brand.dart';
import 'troll_game.dart';
import '../../economy_manager.dart';
import '../../services/life_recovery_dialog.dart';
import 'troll_stage_plan.dart';
import '../multiplayer_engine/duel_service.dart';
import 'troll_duel_screen.dart';

class LvlloPlatformerHubScreen extends StatefulWidget {
  const LvlloPlatformerHubScreen({super.key, this.inline = false});
  final bool inline;

  @override
  State<LvlloPlatformerHubScreen> createState() => _LvlloPlatformerHubScreenState();
}

class _LvlloPlatformerHubScreenState extends State<LvlloPlatformerHubScreen> {
  Set<int> _completedStages = <int>{};
  int _gold = 0;
  int _rp = 0;

  @override
  void initState() {
    super.initState();
    _loadProgress();
  }

  Future<void> _loadProgress() async {
    final completed = await EconomyManager.completedStageIds();
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
        if (doc.exists) {
          _gold = doc.data()?['gold'] ?? 0;
          _rp = doc.data()?['rp'] ?? 1000;
        }
      }
    } catch (e) {
      // Ignored for tests where Firebase is not initialized
    }
    
    if (!mounted) return;
    setState(() {
      _completedStages = completed;
    });
  }

  int get _startStage => 101;
  int get _count => 75;

  Future<void> _openStage(int stageId) async {
    final plan = TrollStagePlan.fromStageId(stageId);
    final start = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _StageIntro(plan: plan),
    );
    if (start != true || !mounted) return;

    final economy = await EconomyManager.checkEconomy();
    if (economy['isOwnerTestAccount'] != true && (economy['lives'] as int? ?? 0) <= 0) {
      if (!mounted) return;
      await showLifeRecoveryDialog(context);
      return;
    }

    HapticFeedback.mediumImpact();
    await Navigator.of(context).push(
      PageRouteBuilder<void>(
        transitionDuration: const Duration(milliseconds: 240),
        reverseTransitionDuration: const Duration(milliseconds: 180),
        pageBuilder: (_, __, ___) => TrollGame(
          stageId: stageId,
          startRound: plan.localStage,
          maxRounds: 1,
          levelsPerMechanic: plan.levelsPerMechanic,
          mechanicOffset: plan.mechanicOffset,
          onWin: (_) async {
            await _loadProgress();
            if (context.mounted) Navigator.of(context).pop();
          },
          onNextStage: stageId < 175
              ? () async {
                  if (context.mounted) Navigator.of(context).pop();
                  await Future<void>.delayed(const Duration(milliseconds: 180));
                  if (mounted) _openStage(stageId + 1);
                }
              : null,
          onFail: () async {
            if (context.mounted) Navigator.of(context).pop();
          },
        ),
        transitionsBuilder: (_, animation, __, child) {
          final curved = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
          return FadeTransition(
            opacity: curved,
            child: ScaleTransition(
              scale: Tween<double>(begin: .985, end: 1).animate(curved),
              child: child,
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GameColors.background,
      body: CosmicBackground(
        child: SafeArea(
          bottom: false,
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              if (!widget.inline)
                SliverAppBar(
                  pinned: true,
                  backgroundColor: GameColors.background.withOpacity(.96),
                  surfaceTintColor: Colors.transparent,
                  elevation: 0,
                  leading: IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.arrow_back_rounded),
                  ),
                  title: const Text('WORLD / SOLO', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.6)),
                ),
              SliverPadding(
                padding: EdgeInsets.fromLTRB(16, widget.inline ? 14 : 6, 16, 8),
                sliver: SliverToBoxAdapter(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'LVL LOOL',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          letterSpacing: 2,
                        ),
                      ),
                      Row(
                        children: [
                          Text('RP: ', style: const TextStyle(color: GameColors.accentBright, fontWeight: FontWeight.bold)),
                          const SizedBox(width: 16),
                          Text('GOLD: ', style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold)),
                        ],
                      )
                    ],
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                sliver: SliverToBoxAdapter(
                  child: CosmicPanel(
                    glow: true,
                    padding: const EdgeInsets.all(16),
                    child: InkWell(
                      onTap: () {
                        Navigator.of(context).push(MaterialPageRoute(builder: (_) => const TrollDuelScreen()));
                      },
                      child: Column(
                        children: [
                          const Text('TROLL DUEL', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: GameColors.danger)),
                          const SizedBox(height: 8),
                          const Text('1v1 MULTIPLAYER', style: TextStyle(color: Colors.white70)),
                          const SizedBox(height: 8),
                          const Text('ENTRY: 500 GOLD', style: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              // Isolated visual/gameplay prototype. It does not touch the existing 75 stages.
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                sliver: SliverToBoxAdapter(
                  child: CosmicPanel(
                    glow: true,
                    padding: const EdgeInsets.all(18),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () async {
                        HapticFeedback.mediumImpact();
                        await Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => TrollGame(
                              stageId: 0,
                              startRound: 1,
                              maxRounds: 1,
                              levelsPerMechanic: 1,
                              mechanicOffset: 0,
                              testStage: true,
                              onWin: (_) {
                                if (Navigator.of(context).canPop()) {
                                  Navigator.of(context).pop();
                                }
                              },
                              onFail: () {
                                if (Navigator.of(context).canPop()) {
                                  Navigator.of(context).pop();
                                }
                              },
                            ),
                          ),
                        );
                      },
                      child: Column(
                        children: [
                          const Text(
                            'NEW WORLD',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 3,
                              color: GameColors.accentBright,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'TEST STAGE 01',
                            style: TextStyle(
                              fontSize: 25,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.5,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'EXPERIMENTAL ENVIRONMENT • NEW TRAPS • NEW LEVEL ARCHITECTURE',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 14),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: GameColors.accentBright.withOpacity(.45)),
                              color: GameColors.accent.withOpacity(.08),
                            ),
                            child: const Text(
                              'PLAY PROTOTYPE',
                              style: TextStyle(color: GameColors.accentBright, fontWeight: FontWeight.w900, letterSpacing: 1.2),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              )
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 130),
                sliver: SliverGrid(
                  delegate: SliverChildBuilderDelegate(
                    (_, index) {
                      final stageId = _startStage + index;
                      final plan = TrollStagePlan.fromStageId(stageId);
                      return _StageCard(
                        stageId: (index + 1), // Display 1 to 75
                        difficulty: plan.difficulty,
                        mechanicId: plan.mechanicId,
                        onTap: () => _openStage(stageId),
                      );
                    },
                    childCount: _count,
                  ),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    mainAxisSpacing: 16,
                    crossAxisSpacing: 16,
                    childAspectRatio: 1 / 1.15,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
class _StageCard extends StatelessWidget {
  const _StageCard({required this.stageId, required this.difficulty, required this.mechanicId, required this.onTap});
  final int stageId;
  final int difficulty;
  final int mechanicId;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = switch (difficulty) {
      1 => GameColors.success,
      2 => GameColors.warning,
      _ => GameColors.danger,
    };
    final label = switch (difficulty) {
      1 => 'EASY',
      2 => 'MEDIUM',
      _ => 'HARD',
    };

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(17),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(17),
        child: Ink(
          decoration: BoxDecoration(
            color: GameColors.surfaceGlass,
            borderRadius: BorderRadius.circular(17),
            border: Border.all(color: color.withOpacity(.35)),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(9, 9, 9, 8),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text('MECHANIC ' + mechanicId.toString(), overflow: TextOverflow.ellipsis, style: const TextStyle(color: GameColors.muted, fontSize: 7, fontWeight: FontWeight.w800)),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                      decoration: BoxDecoration(color: color.withOpacity(.09), borderRadius: BorderRadius.circular(7)),
                      child: Text(label, style: TextStyle(color: color, fontSize: 6.5, fontWeight: FontWeight.w900)),
                    ),
                  ],
                ),
                const Spacer(),
                Container(
                  width: 54,
                  height: 54,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: GameColors.backgroundDeep,
                    border: Border.all(color: color.withOpacity(.72), width: 1.4),
                    boxShadow: [BoxShadow(color: color.withOpacity(.10), blurRadius: 14)],
                  ),
                  child: Text(stageId.toString(), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    3,
                    (i) => Icon(
                      i < difficulty ? Icons.star_rounded : Icons.star_border_rounded,
                      color: i < difficulty ? color : GameColors.surfaceStrong,
                      size: 12,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text('TAP TO PLAY', style: TextStyle(color: color, fontSize: 6.5, fontWeight: FontWeight.w900, letterSpacing: .7)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StageIntro extends StatelessWidget {
  const _StageIntro({required this.plan});
  final TrollStagePlan plan;

  @override
  Widget build(BuildContext context) {
    final color = switch (plan.difficulty) {
      1 => GameColors.success,
      2 => GameColors.warning,
      _ => GameColors.danger,
    };
    final label = switch (plan.difficulty) {
      1 => 'EASY',
      2 => 'MEDIUM',
      _ => 'HARD',
    };

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: CosmicPanel(
          glow: true,
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 68,
                height: 68,
                decoration: BoxDecoration(shape: BoxShape.circle, gradient: GameColors.cosmicGradient, boxShadow: GameShadows.primaryGlow),
                child: Center(child: Text((plan.stageId > 100 ? plan.stageId - 100 : plan.stageId).toString(), style: const TextStyle(color: GameColors.backgroundDeep, fontSize: 22, fontWeight: FontWeight.w900))),
              ),
              const SizedBox(height: 11),
              const Text('STAGE READY', style: TextStyle(color: GameColors.accentBright, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 2)),
              const SizedBox(height: 5),
              Text('STAGE ${(plan.stageId > 100 ? plan.stageId - 100 : plan.stageId)}', style: const TextStyle(fontSize: 23, fontWeight: FontWeight.w900)),
              const SizedBox(height: 7),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(color: color.withOpacity(.09), borderRadius: BorderRadius.circular(99), border: Border.all(color: color.withOpacity(.3))),
                child: Text(label, style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 1)),
              ),
              const SizedBox(height: 8),
              Text('MECHANIC ' + plan.mechanicId.toString(), style: const TextStyle(color: GameColors.muted, fontSize: 9, fontWeight: FontWeight.w800)),
              const SizedBox(height: 15),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () => Navigator.of(context).pop(true),
                  icon: const Icon(Icons.play_arrow_rounded),
                  label: const Text('START STAGE'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
