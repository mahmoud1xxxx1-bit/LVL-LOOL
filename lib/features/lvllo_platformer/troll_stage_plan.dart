/// Immutable mapping for the game's 175-stage architecture.
///
/// This class only maps an existing global stage number to its structural
/// metadata. It does not create, rename, reorder, or renumber stages.
///
/// Season 6 deliberately reuses the exact 20 mechanics from Seasons 1-5
/// first (3 stages each: Easy/Medium/Hard), followed by five distinct new
/// mechanics (3 stages each).
class TrollStagePlan {
  static const int totalStages = 175;
  static const int mainSeasonCount = 5;
  static const int mainSeasonStages = 20;
  static const int season6Stages = 75;

  /// Season 6 mechanic IDs by group, in canonical design order.
  ///
  /// 101-160 -> mechanics 1-20 (the 20 established ideas)
  /// 161-175 -> mechanics 21-25 (five Season 6-only ideas)
  static const List<int> season6MechanicIds = <int>[
    1, 2, 3, 4, 5,
    6, 7, 8, 9, 10,
    11, 12, 13, 14, 15,
    16, 17, 18, 19, 20,
    21, 22, 23, 24, 25,
  ];

  final int stageId;
  final int season;
  final int localStage;
  final int levelsPerMechanic;
  final int mechanicOffset;
  final int mechanicId;
  final int difficulty;

  const TrollStagePlan._({
    required this.stageId,
    required this.season,
    required this.localStage,
    required this.levelsPerMechanic,
    required this.mechanicOffset,
    required this.mechanicId,
    required this.difficulty,
  });

  factory TrollStagePlan.fromStageId(int stageId) {
    if (stageId < 1 || stageId > totalStages) {
      throw ArgumentError.value(
        stageId,
        'stageId',
        'Must be between 1 and 175.',
      );
    }

    if (stageId <= 100) {
      final season = ((stageId - 1) ~/ mainSeasonStages) + 1;
      final localStage = ((stageId - 1) % mainSeasonStages) + 1;
      final mechanicOffset = (season - 1) * 4;
      final mechanicId = ((localStage - 1) ~/ 5) + 1 + mechanicOffset;
      final localMechanicStage = ((localStage - 1) % 5) + 1;
      final difficulty =
          localMechanicStage <= 2 ? 1 : localMechanicStage <= 4 ? 2 : 3;

      return TrollStagePlan._(
        stageId: stageId,
        season: season,
        localStage: localStage,
        levelsPerMechanic: 5,
        mechanicOffset: mechanicOffset,
        mechanicId: mechanicId,
        difficulty: difficulty,
      );
    }

    final localStage = stageId - 100;
    final groupIndex = (localStage - 1) ~/ 3;
    final mechanicId = season6MechanicIds[groupIndex];
    final mechanicOffset = mechanicId - 1;
    final difficulty = ((localStage - 1) % 3) + 1;

    return TrollStagePlan._(
      stageId: stageId,
      season: 6,
      localStage: ((localStage - 1) % 3) + 1,
      levelsPerMechanic: 3,
      mechanicOffset: mechanicOffset,
      mechanicId: mechanicId,
      difficulty: difficulty,
    );
  }
}
