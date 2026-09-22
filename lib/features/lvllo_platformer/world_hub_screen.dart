import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/cosmic_background.dart';
import '../../core/theme/design_tokens.dart';
import '../../core/theme/lvllo_brand.dart';
import 'troll_game.dart';
import '../../economy_manager.dart';
import '../../services/life_recovery_dialog.dart';
import 'troll_stage_plan.dart';

class LvlloPlatformerHubScreen extends StatefulWidget {
  const LvlloPlatformerHubScreen({super.key, this.inline = false});
  final bool inline;

  @override
  State<LvlloPlatformerHubScreen> createState() => _LvlloPlatformerHubScreenState();
}

class _LvlloPlatformerHubScreenState extends State<LvlloPlatformerHubScreen> {
  int _season = 6;

  int get _startStage => _season == 6 ? 101 : ((_season - 1) * 20) + 1;
  int get _count => _season == 6 ? 75 : 20;

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
    if ((economy['lives'] as int? ?? 0) <= 0) {
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
          startRound: plan.localStage,
          maxRounds: 1,
          levelsPerMechanic: plan.levelsPerMechanic,
          mechanicOffset: plan.mechanicOffset,
          onWin: (_) => Navigator.of(context).pop(),
          onFail: () async {
            await EconomyManager.deductLife();
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
    final seasonSix = _season == 6;
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
                  title: const Text('WORLDS', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.6)),
                ),
              SliverPadding(
                padding: EdgeInsets.fromLTRB(16, widget.inline ? 14 : 6, 16, 8),
                sliver: SliverToBoxAdapter(child: _topHeader()),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                sliver: SliverToBoxAdapter(child: _seasonTabs()),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                sliver: SliverToBoxAdapter(child: _selectedSeasonHeader(seasonSix)),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 130),
                sliver: SliverGrid(
                  delegate: SliverChildBuilderDelegate(
                    (_, index) {
                      final stageId = _startStage + index;
                      final plan = TrollStagePlan.fromStageId(stageId);
                      return _StageCard(
                        stageId: stageId,
                        difficulty: plan.difficulty,
                        mechanicId: plan.mechanicId,
                        onTap: () => _openStage(stageId),
                      );
                    },
                    childCount: _count,
                  ),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: MediaQuery.sizeOf(context).width >= 430 ? 3 : 2,
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    childAspectRatio: .92,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _topHeader() {
    return CosmicPanel(
      glow: true,
      padding: const EdgeInsets.fromLTRB(16, 15, 16, 15),
      child: Row(
        children: [
          const LvlloBrandMark(size: 54),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('WORLDS / SEASONS', style: TextStyle(color: GameColors.accentBright, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 1.7)),
                SizedBox(height: 4),
                Text('CHOOSE YOUR WORLD', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
                SizedBox(height: 3),
                Text('6 seasons • 175 stages', style: TextStyle(color: GameColors.muted, fontSize: 9)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _seasonTabs() {
    return SizedBox(
      height: 74,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: 6,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, index) {
          final season = index + 1;
          final count = season == 6 ? 75 : 20;
          final selected = season == _season;
          return GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              setState(() => _season = season);
            },
            child: AnimatedContainer(
              duration: GameDurations.normal,
              width: 108,
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
              decoration: BoxDecoration(
                color: selected ? GameColors.surfaceRaised : GameColors.surfaceGlass,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: selected ? GameColors.accentBright.withOpacity(.75) : GameColors.surfaceStrong,
                  width: selected ? 1.4 : 1,
                ),
                boxShadow: selected ? GameShadows.primaryGlow : null,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        season == 6 ? Icons.auto_awesome_rounded : Icons.public_rounded,
                        color: selected ? GameColors.accentBright : GameColors.muted,
                        size: 17,
                      ),
                      const Spacer(),
                      if (selected) const Icon(Icons.check_rounded, color: GameColors.accentBright, size: 14),
                    ],
                  ),
                  const Spacer(),
                  Text('SEASON $season', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 2),
                  Text('$count STAGES', style: const TextStyle(color: GameColors.muted, fontSize: 8, fontWeight: FontWeight.w800)),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _selectedSeasonHeader(bool seasonSix) {
    final range = _startStage.toString() + '–' + (_startStage + _count - 1).toString();
    return CosmicPanel(
      padding: const EdgeInsets.all(15),
      child: Row(
        children: [
          Container(
            width: 66,
            height: 66,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(17),
              gradient: seasonSix ? GameColors.cosmicGradient : null,
              color: seasonSix ? null : GameColors.surfaceRaised,
            ),
            child: Icon(
              seasonSix ? Icons.auto_awesome_rounded : Icons.public_rounded,
              color: seasonSix ? GameColors.backgroundDeep : GameColors.accentBright,
              size: 30,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('SEASON ' + _season.toString(), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                const SizedBox(height: 3),
                Text(
                  _season == 6 ? '75 stages • 101–175' : '20 stages • ' + range,
                  style: const TextStyle(color: GameColors.muted, fontSize: 9, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 9),
                Row(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(99),
                        child: const LinearProgressIndicator(
                          minHeight: 5,
                          value: 0,
                          backgroundColor: GameColors.surfaceStrong,
                          valueColor: AlwaysStoppedAnimation(GameColors.accent),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(range, style: const TextStyle(color: GameColors.accentBright, fontSize: 9, fontWeight: FontWeight.w900)),
                  ],
                ),
              ],
            ),
          ),
        ],
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
                child: Center(child: Text(plan.stageId.toString(), style: const TextStyle(color: GameColors.backgroundDeep, fontSize: 22, fontWeight: FontWeight.w900))),
              ),
              const SizedBox(height: 11),
              const Text('STAGE READY', style: TextStyle(color: GameColors.accentBright, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 2)),
              const SizedBox(height: 5),
              Text('STAGE ' + plan.stageId.toString(), style: const TextStyle(fontSize: 23, fontWeight: FontWeight.w900)),
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
