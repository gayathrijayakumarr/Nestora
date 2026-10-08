// Smoke tests for NESTORA.
//
// These replace the default Flutter counter template, which referenced a
// `MyApp` class that this project never had and so failed to compile.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:nestora_mobile/main.dart';

void main() {
  setUp(() {
    // LoginScreen reads SharedPreferences on init; without a mock the
    // platform channel throws and the screen never builds.
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets('app boots, animates and reaches the login screen without '
      'throwing', (WidgetTester tester) async {
    await tester.pumpWidget(const NestoraApp());

    // The landing screen holds a 3s navigation timer plus a per-letter
    // animation chain, so pump past all of them; leaving a timer pending
    // trips the test binding's "timersPending" assertion.
    await tester.pump(const Duration(seconds: 4));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(tester.takeException(), isNull);
    expect(find.byType(MaterialApp), findsOneWidget);
  });

  testWidgets('landing screen hands over to login', (WidgetTester tester) async {
    await tester.pumpWidget(const NestoraApp());
    await tester.pump(const Duration(seconds: 4));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Registered Patient Access'), findsOneWidget);
  });
}