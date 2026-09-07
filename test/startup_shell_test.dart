import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:goal_tracker_poc/ui/goal_tracker_startup_app.dart';

void main() {
  testWidgets('shows a shell immediately and retries bootstrap failures', (
    tester,
  ) async {
    var attempts = 0;

    await tester.pumpWidget(
      GoalTrackerStartupApp(
        bootstrap: () async {
          attempts += 1;
          throw StateError('temporary bootstrap failure');
        },
      ),
    );

    expect(find.byKey(const Key('startup-loading')), findsOneWidget);
    await tester.pump();
    expect(find.byKey(const Key('startup-error')), findsOneWidget);
    expect(attempts, 1);

    await tester.tap(find.byKey(const Key('startup-retry')));
    await tester.pump();
    expect(attempts, 2);
    await tester.pump();
    expect(find.byKey(const Key('startup-error')), findsOneWidget);
  });
}
