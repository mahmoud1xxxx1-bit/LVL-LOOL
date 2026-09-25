import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:lvllo/store_screen.dart';
import 'package:lvllo/features/lvllo_platformer/lvllo_lobby_screen.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('store renders economy controls', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: StoreScreen()));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('STORE'), findsOneWidget);
    expect(find.textContaining('/10'), findsOneWidget);
  });
}
