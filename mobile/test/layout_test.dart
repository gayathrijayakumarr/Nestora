// Layout regression tests.
//
// The reported symptoms were "black pages" and "overflow errors" when
// tapping the Home dashboard Quick Actions. Both come from unbounded Rows
// and fixed heights, so these tests render every screen at the smallest
// supported width and at a large accessibility text scale, where any
// RenderFlex overflow is recorded as a test failure.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:nestora_mobile/screens/reminders_screen.dart';
import 'package:nestora_mobile/screens/nutrition_screen.dart';
import 'package:nestora_mobile/screens/symptoms_screen.dart';
import 'package:nestora_mobile/screens/vitals_screen.dart';
import 'package:nestora_mobile/screens/home_screen.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  Future<void> pumpScreen(
    WidgetTester tester,
    Widget screen, {
    Size size = const Size(320, 640),
    double textScale = 1.0,
  }) async {
    tester.view
      ..physicalSize = size
      ..devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MediaQuery(
        data: MediaQueryData(size: size, textScaler: TextScaler.linear(textScale)),
        child: MaterialApp(home: screen),
      ),
    );
    // Let the API fallbacks resolve, then settle.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
  }

  final screens = <String, Widget>{
    'VitalsScreen': const VitalsScreen(),
    'NutritionScreen': const NutritionScreen(),
    'RemindersScreen': const RemindersScreen(),
    'SymptomsScreen': const SymptomsScreen(),
  };

  for (final entry in screens.entries) {
    testWidgets('${entry.key} lays out on a 320x640 screen',
        (WidgetTester tester) async {
      await pumpScreen(tester, entry.value);
      expect(tester.takeException(), isNull);
    });

    testWidgets('${entry.key} lays out at 1.5x text scale',
        (WidgetTester tester) async {
      await pumpScreen(tester, entry.value, size: const Size(360, 800), textScale: 1.5);
      expect(tester.takeException(), isNull);
    });

    testWidgets('${entry.key} lays out at 2x text scale',
        (WidgetTester tester) async {
      await pumpScreen(tester, entry.value, size: const Size(360, 800), textScale: 2.0);
      expect(tester.takeException(), isNull);
    });

  }

  // 1.5x is the supported ceiling for text scaling. 2x (twice Android's
  // largest accessibility step) still overflows a few fixed-width clusters
  // in the dashboard and nutrition header; those are recorded rather than
  // papered over with a wider test threshold.
  //
  // The Home dashboard is where the Quick Actions live, so it is also where
  // the overflows that produced the yellow stripes were seen.
  testWidgets('HomeScreen lays out on a 320x640 screen',
      (WidgetTester tester) async {
    await pumpScreen(tester, const HomeScreen());
    expect(tester.takeException(), isNull);
  });

  testWidgets('HomeScreen lays out at 1.5x text scale',
      (WidgetTester tester) async {
    await pumpScreen(tester, const HomeScreen(),
        size: const Size(360, 800), textScale: 1.5);
    expect(tester.takeException(), isNull);
  });

  testWidgets('HomeScreen lays out at 2x text scale',
      (WidgetTester tester) async {
    await pumpScreen(tester, const HomeScreen(),
        size: const Size(360, 800), textScale: 2.0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('quick action screens expose a back button when pushed',
      (WidgetTester tester) async {
    // A Quick Action pushes the screen as a route. Without a Scaffold the
    // pushed page has no AppBar and therefore no way back, which is what
    // made the page look like it had gone black.
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const VitalsScreen()),
                ),
                child: const Text('Vitals History'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Vitals History'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.byType(BackButton), findsOneWidget);
  });
}