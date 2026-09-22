import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:lvllo/store_screen.dart';
import 'package:lvllo/features/lvllo_platformer/lvllo_lobby_screen.dart';
import 'package:lvllo/features/lvllo_platformer/world_hub_screen.dart';

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
    expect(find.text('SEASON 1'), findsWidgets);
    expect(find.textContaining('1–20'), findsWidgets);
    expect(find.text('SEASON 6'), findsWidgets);

  });

  testWidgets('store renders economy controls', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: StoreScreen()));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('STORE'), findsOneWidget);
    expect(find.textContaining('/10'), findsOneWidget);
  });

  testWidgets('settings page is reachable from the lobby', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: LvlloLobbyScreen()));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.byIcon(Icons.settings_rounded).first);
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('SETTINGS'), findsWidgets);
    expect(find.text('Haptic feedback'), findsOneWidget);
    expect(find.text('Sound effects'), findsOneWidget);
  });
}
