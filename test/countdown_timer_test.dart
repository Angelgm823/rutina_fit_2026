import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:rutina_fit/widgets/countdown_timer.dart';

void main() {
  testWidgets('Countdown timer parses input correctly', (WidgetTester tester) async {
    int? lastEmittedValue;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CountdownTimer(
            total: 0,
            remaining: 0,
            running: false,
            onTotalChanged: (value) => lastEmittedValue = value,
            maxSeconds: 3600,
          ),
        ),
      ),
    );

    final inputField = find.byType(TextField);
    expect(inputField, findsOneWidget);

    // Test 1: Input "30" should be interpreted as 30 seconds
    await tester.enterText(inputField, '30');
    await tester.pumpAndSettle();
    expect(lastEmittedValue, equals(30), reason: '"30" should be 30 seconds');

    // Test 2: Input "30:00" should be interpreted as 30 minutes
    await tester.enterText(inputField, '30:00');
    await tester.pumpAndSettle();
    expect(lastEmittedValue, equals(1800), reason: '"30:00" should be 30 minutes (1800 seconds)');

    // Test 3: Input "1:30" should be interpreted as 1 minute 30 seconds
    await tester.enterText(inputField, '1:30');
    await tester.pumpAndSettle();
    expect(lastEmittedValue, equals(90), reason: '"1:30" should be 1 minute 30 seconds (90 seconds)');

    // Test 4: Input "60" should be interpreted as 60 minutes (not seconds)
    await tester.enterText(inputField, '60');
    await tester.pumpAndSettle();
    expect(lastEmittedValue, equals(3600), reason: '"60" should be 60 minutes (3600 seconds)');

    // Test 5: Input empty should be 0
    await tester.enterText(inputField, '');
    await tester.pumpAndSettle();
    expect(lastEmittedValue, equals(0), reason: 'Empty input should be 0 seconds');

    // Test 6: Input "0:30" should be 30 seconds
    await tester.enterText(inputField, '0:30');
    await tester.pumpAndSettle();
    expect(lastEmittedValue, equals(30), reason: '"0:30" should be 30 seconds');

    // Test 7: Input "59" should be 59 seconds (edge case)
    await tester.enterText(inputField, '59');
    await tester.pumpAndSettle();
    expect(lastEmittedValue, equals(59), reason: '"59" should be 59 seconds');

    // Test 8: Input "60" should be 60 minutes (edge case)
    await tester.enterText(inputField, '60');
    await tester.pumpAndSettle();
    expect(lastEmittedValue, equals(3600), reason: '"60" should be 60 minutes');
  });
}
