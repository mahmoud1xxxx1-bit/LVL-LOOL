import 'package:flutter/material.dart';

// Unified visual language: geometry stays consistent; each season changes only its atmosphere and accents.
class LvlloSeasonVisualTheme {
  const LvlloSeasonVisualTheme({
    required this.season,
    required this.name,
    required this.accent,
    required this.accentBright,
    required this.accentDark,
    required this.backgroundTop,
    required this.backgroundBottom,
    required this.mountainBack,
    required this.mountainFront,
    required this.platform,
    required this.platformTop,
    required this.platformEdge,
    required this.danger,
    required this.portal,
  });

  final int season;
  final String name;
  final Color accent;
  final Color accentBright;
  final Color accentDark;
  final Color backgroundTop;
  final Color backgroundBottom;
  final Color mountainBack;
  final Color mountainFront;
  final Color platform;
  final Color platformTop;
  final Color platformEdge;
  final Color danger;
  final Color portal;

  static LvlloSeasonVisualTheme forStage(int stageId) {
    final season = stageId >= 101
        ? 6
        : ((stageId - 1) ~/ 20 + 1).clamp(1, 5);
    return forSeason(season);
  }

  static LvlloSeasonVisualTheme forSeason(int season) {
    switch (season) {
      case 2:
        return const LvlloSeasonVisualTheme(
          season: 2,
          name: 'INFERNO',
          accent: Color(0xFFFF5A36),
          accentBright: Color(0xFFFFA24A),
          accentDark: Color(0xFFB72D24),
          backgroundTop: Color(0xFF170A12),
          backgroundBottom: Color(0xFF050308),
          mountainBack: Color(0xFF35131A),
          mountainFront: Color(0xFF190B10),
          platform: Color(0xFF2A1720),
          platformTop: Color(0xFFFF5A36),
          platformEdge: Color(0xFF6F2830),
          danger: Color(0xFFFF6B3D),
          portal: Color(0xFFFF8A3D),
        );
      case 3:
        return const LvlloSeasonVisualTheme(
          season: 3,
          name: 'WILDS',
          accent: Color(0xFF55D98B),
          accentBright: Color(0xFF9BFFB8),
          accentDark: Color(0xFF207653),
          backgroundTop: Color(0xFF071916),
          backgroundBottom: Color(0xFF030A09),
          mountainBack: Color(0xFF123C31),
          mountainFront: Color(0xFF081F1A),
          platform: Color(0xFF17352D),
          platformTop: Color(0xFF55D98B),
          platformEdge: Color(0xFF2B7157),
          danger: Color(0xFFB7FF75),
          portal: Color(0xFF55E69A),
        );
      case 4:
        return const LvlloSeasonVisualTheme(
          season: 4,
          name: 'CIRCUIT',
          accent: Color(0xFF9A65FF),
          accentBright: Color(0xFFD0A2FF),
          accentDark: Color(0xFF5530B5),
          backgroundTop: Color(0xFF100A20),
          backgroundBottom: Color(0xFF05030C),
          mountainBack: Color(0xFF26134B),
          mountainFront: Color(0xFF100820),
          platform: Color(0xFF21183B),
          platformTop: Color(0xFF9A65FF),
          platformEdge: Color(0xFF563A91),
          danger: Color(0xFFFF5AD9),
          portal: Color(0xFFB36CFF),
        );
      case 5:
        return const LvlloSeasonVisualTheme(
          season: 5,
          name: 'FROZEN',
          accent: Color(0xFF69D8FF),
          accentBright: Color(0xFFC6F4FF),
          accentDark: Color(0xFF287CA6),
          backgroundTop: Color(0xFF081827),
          backgroundBottom: Color(0xFF030811),
          mountainBack: Color(0xFF123553),
          mountainFront: Color(0xFF091D31),
          platform: Color(0xFF173149),
          platformTop: Color(0xFF69D8FF),
          platformEdge: Color(0xFF3A7292),
          danger: Color(0xFFBCEBFF),
          portal: Color(0xFF78E8FF),
        );
      case 6:
        return const LvlloSeasonVisualTheme(
          season: 6,
          name: 'RIFT',
          accent: Color(0xFFB45CFF),
          accentBright: Color(0xFFE0A4FF),
          accentDark: Color(0xFF5D2D9D),
          backgroundTop: Color(0xFF10081D),
          backgroundBottom: Color(0xFF04020A),
          mountainBack: Color(0xFF24113E),
          mountainFront: Color(0xFF0F071C),
          platform: Color(0xFF211633),
          platformTop: Color(0xFFB45CFF),
          platformEdge: Color(0xFF5C397F),
          danger: Color(0xFFFF63D8),
          portal: Color(0xFFCF72FF),
        );
      default:
        return const LvlloSeasonVisualTheme(
          season: 1,
          name: 'COSMIC',
          accent: Color(0xFF19C8FF),
          accentBright: Color(0xFF7DEBFF),
          accentDark: Color(0xFF1469A4),
          backgroundTop: Color(0xFF07152A),
          backgroundBottom: Color(0xFF030711),
          mountainBack: Color(0xFF102A4A),
          mountainFront: Color(0xFF08162B),
          platform: Color(0xFF142B43),
          platformTop: Color(0xFF19C8FF),
          platformEdge: Color(0xFF286B91),
          danger: Color(0xFFFF557A),
          portal: Color(0xFF5CE5FF),
        );
    }
  }
}
