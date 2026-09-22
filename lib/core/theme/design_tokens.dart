export 'dart:ui' show FontFeature;

import 'package:flutter/material.dart';

class GameColors {
  const GameColors._();

  // Cosmic Flow: deep-space surfaces with controlled cyan/violet energy.
  // High-saturation colors are reserved for calls to action, ranks and rewards
  // so long sessions stay comfortable instead of visually exhausting.
  static const background = Color(0xFF050A18);
  static const backgroundDeep = Color(0xFF020612);
  static const surface = Color(0xFF0B1530);
  static const surfaceRaised = Color(0xFF102044);
  static const surfaceStrong = Color(0xFF1A3158);
  static const surfaceGlass = Color(0xCC0D1A36);

  static const accent = Color(0xFF19DCE8);
  static const accentBright = Color(0xFF52F2F2);
  static const accentSoft = Color(0xFF123B52);
  static const violet = Color(0xFF7957F5);
  static const violetSoft = Color(0xFF2A1F5C);
  static const cosmicPink = Color(0xFFD454E8);

  static const success = Color(0xFF4DDA9A);
  static const danger = Color(0xFFFF667E);
  static const warning = Color(0xFFFFB85A);
  static const rewardGold = Color(0xFFFFCD68);
  static const muted = Color(0xFF8293B2);
  static const textStrong = Color(0xFFF5F7FF);
  static const textSoft = Color(0xFFC4CEE0);

  static const rankBronze = Color(0xFFC38354);
  static const rankSilver = Color(0xFFBCC8D6);
  static const rankGold = Color(0xFFFFCC5C);
  static const rankPlatinum = Color(0xFF61D5D0);
  static const rankDiamond = Color(0xFF6AA8FF);
  static const rankMaster = Color(0xFFC37BFF);
  static const rankGrandmaster = Color(0xFFFF667E);
  static const rankLegend = Color(0xFFFFD86B);

  static const rarityCommon = Color(0xFFB8C2D0);
  static const rarityRare = Color(0xFF5EA8FF);
  static const rarityEpic = Color(0xFFB46CFF);
  static const rarityLegendary = Color(0xFFFFC857);
  static const rarityMythic = Color(0xFFFF718F);

  static const cosmicGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF16D9E6), Color(0xFF6D5AF4), Color(0xFFC84FE0)],
  );

  static const cosmicBackgroundGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFF08132B), Color(0xFF050A18), Color(0xFF020612)],
  );
}

class GameSpacing {
  const GameSpacing._();

  static const double xs = 6;
  static const double sm = 10;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
  static const double xxl = 44;
}

class GameRadii {
  const GameRadii._();

  static const double button = 16;
  static const double card = 18;
  static const double panel = 24;
  static const double pill = 999;
}

class GameDurations {
  const GameDurations._();

  static const fast = Duration(milliseconds: 100);
  static const normal = Duration(milliseconds: 190);
  static const reveal = Duration(milliseconds: 650);
  static const rankUp = Duration(milliseconds: 1050);
}

class GameShadows {
  const GameShadows._();

  static const card = <BoxShadow>[
    BoxShadow(
      color: Color(0x2600CFE0),
      blurRadius: 18,
      offset: Offset(0, 7),
    ),
  ];

  static const primaryGlow = <BoxShadow>[
    BoxShadow(color: Color(0x4D19DCE8), blurRadius: 22),
    BoxShadow(color: Color(0x267957F5), blurRadius: 34),
  ];
}
