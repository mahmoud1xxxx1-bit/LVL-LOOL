import 'package:flutter/material.dart';
import '../../domain/mini_game_contract.dart';
import 'troll_game.dart';
import '../../../../economy_manager.dart';
import 'troll_stage_plan.dart';

class LvlloPlatformerHost extends StatefulWidget {
  const LvlloPlatformerHost({
    super.key,
    required this.config,
    required this.onComplete,
  });

  final MiniGameConfig config;
  final ValueChanged<MiniGameResult> onComplete;

  @override
  State<LvlloPlatformerHost> createState() => _LvlloPlatformerHostState();
}

class _LvlloPlatformerHostState extends State<LvlloPlatformerHost> {
  late DateTime _startTime;

  @override
  void initState() {
    super.initState();
    _startTime = DateTime.now();
  }

  @override
  Widget build(BuildContext context) {
    // The config seed is the existing global stage number. Keep the stage
    // identity exactly as defined by the game design: 1..175.
    final stageId = widget.config.seed;
    if (stageId < 1 || stageId > TrollStagePlan.totalStages) {
      throw StateError('LVL LOOL stage id must be between 1 and 175: $stageId');
    }
    final plan = TrollStagePlan.fromStageId(stageId);

    return TrollGame(
      startRound: plan.localStage,
      maxRounds: 1, // Single stage in host mode
      levelsPerMechanic: plan.levelsPerMechanic,
      mechanicOffset: plan.mechanicOffset,
      stageSeedOverride: stageId,
      onWin: (int score) {
        final duration = DateTime.now().difference(_startTime);
        widget.onComplete(
          MiniGameResult(
            completed: true,
            score: score,
            accuracy: 1.0,
            mistakes: 0,
            duration: duration,
          ),
        );
      },
      onFail: () async {
        await EconomyManager.deductLife();
        final duration = DateTime.now().difference(_startTime);
        widget.onComplete(
          MiniGameResult(
            completed: false,
            score: 0,
            accuracy: 0.0,
            mistakes: 1,
            duration: duration,
          ),
        );
      },
    );
  }
}
