import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:rutina_fit/widgets/countdown_timer.dart';

void main() {
  testWidgets('Countdown timer displays correctly', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CountdownTimer(
            total: 300,
            remaining: 300,
            running: false,
            onTotalChanged: (value) {},
            maxSeconds: 3600,
          ),
        ),
      ),
    );

    // Verify the timer displays the correct time (5 minutes = 300 seconds)
    expect(find.text('5:00'), findsOneWidget);
  });

  testWidgets('Countdown timer shows clock icon to open picker', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CountdownTimer(
            total: 0,
            remaining: 0,
            running: false,
            onTotalChanged: (value) {},
            maxSeconds: 3600,
          ),
        ),
      ),
    );

    // Verify the clock icon exists for opening the time picker
    final clockIcon = find.byIcon(Icons.schedule);
    expect(clockIcon, findsOneWidget);
  });

  testWidgets('Countdown timer formats time correctly', (WidgetTester tester) async {
    // Test various time values
    expect(CountdownTimer.fmt(0), equals('0:00'));
    expect(CountdownTimer.fmt(30), equals('0:30'));
    expect(CountdownTimer.fmt(60), equals('1:00'));
    expect(CountdownTimer.fmt(90), equals('1:30'));
    expect(CountdownTimer.fmt(3600), equals('60:00'));
  });
}
