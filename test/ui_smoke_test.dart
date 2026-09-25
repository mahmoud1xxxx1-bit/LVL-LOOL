import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:lvllo/store_screen.dart';
import 'package:lvllo/features/lvllo_platformer/lvllo_lobby_screen.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('LVL LOOL lobby renders', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: LvlloLobbyScreen()));
    await tester.pumpAndSettle();
    expect(find.text('HOME'), findsWidgets);
    expect(find.text('WORLDS'), findsWidgets);
  });

  testWidgets('store renders economy controls', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: StoreScreen()));
    await tester.pumpAndSettle();
    expect(find.text('STORE'), findsOneWidget);
    expect(find.textContaining('/10'), findsOneWidget);
  });

  testWidgets('settings page is reachable from the lobby', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: LvlloLobbyScreen()));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.settings_rounded).first);
    await tester.pumpAndSettle();
    expect(find.text('SETTINGS'), findsWidgets);
    expect(find.text('Haptic feedback'), findsOneWidget);
    expect(find.text('Sound effects'), findsOneWidget);
  });
}
