import 'package:flutter_test/flutter_test.dart';
import 'package:lvllo/features/lvllo_platformer/troll_engine.dart';
import 'package:lvllo/features/lvllo_platformer/troll_stage_plan.dart';

void main() {
  test('all 175 stage plans are valid and deterministic', () {
    final seen = <int>{};
    for (var stageId = 1; stageId <= TrollStagePlan.totalStages; stageId++) {
      final plan = TrollStagePlan.fromStageId(stageId);
      expect(plan.stageId, stageId);
      expect(plan.season, inInclusiveRange(1, 6));
      expect(plan.localStage, inInclusiveRange(1, plan.levelsPerMechanic));
      expect(plan.difficulty, inInclusiveRange(1, 3));
      expect(seen.add(plan.mechanicId), isTrue,
          reason: 'mechanic id should be encountered across the 175-stage plan');
      final engine = TrollEngine(
        round: plan.localStage,
        maxRounds: 1,
        levelsPerMechanic: plan.levelsPerMechanic,
        mechanicOffset: plan.mechanicOffset,
        stageSeedOverride: stageId,
      );
      expect(engine.stageSeed, stageId);
      expect(engine.entities, isNotEmpty, reason: 'stage $stageId has no entities');
      engine.update(1 / 60);
      expect(engine.isDead, isFalse);
      expect(engine.roundWon, isFalse);
    }
    expect(seen.length, 25);
  });

  test('season boundaries are preserved', () {
    expect(TrollStagePlan.fromStageId(1).season, 1);
    expect(TrollStagePlan.fromStageId(20).season, 1);
    expect(TrollStagePlan.fromStageId(21).season, 2);
    expect(TrollStagePlan.fromStageId(100).season, 5);
    expect(TrollStagePlan.fromStageId(101).season, 6);
    expect(TrollStagePlan.fromStageId(175).season, 6);
    expect(TrollStagePlan.fromStageId(101).localStage, 1);
    expect(TrollStagePlan.fromStageId(160).mechanicId, 20);
    expect(TrollStagePlan.fromStageId(161).mechanicId, 21);
    expect(TrollStagePlan.fromStageId(175).mechanicId, 25);
  });
}
