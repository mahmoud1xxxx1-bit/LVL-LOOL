import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:lvllo/store_screen.dart';
import 'package:lvllo/features/lvllo_platformer/lvllo_lobby_screen.dart';
import 'package:lvllo/features/lvllo_platformer/world_hub_screen.dart';
import 'package:lvllo/core/settings/game_settings_controller.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('LVL LOOL lobby renders', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: LvlloLobbyScreen()));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('LVL LOOL'), findsWidgets);
    expect(find.textContaining('175 STAGES'), findsOneWidget);
  });

  testWidgets('world hub renders six seasons and stage one', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: LvlloPlatformerHubScreen()));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('SEASON 6'), findsWidgets);
    expect(find.text('STAGE 101'), findsOneWidget);
  });

  testWidgets('store renders economy controls', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: StoreScreen()));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('STORE'), findsOneWidget);
    expect(find.textContaining('/10'), findsOneWidget);
  });

  test('settings persist and clamp values', () async {
    final settings = GameSettingsController.instance;
    await settings.setMusicVolume(2);
    await settings.setSfxVolume(-1);
    await settings.setMusicMuted(true);
    await settings.setSfxMuted(true);
    await settings.setHapticsEnabled(false);

    expect(settings.musicVolume, 1);
    expect(settings.sfxVolume, 0);
    expect(settings.effectiveMusicVolume, 0);
    expect(settings.effectiveSfxVolume, 0);
    expect(settings.hapticsEnabled, false);
  });
}
