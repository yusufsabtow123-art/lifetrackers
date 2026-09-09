import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:goal_tracker_poc/app/goal_store.dart';
import 'package:goal_tracker_poc/app/life_store.dart';
import 'package:goal_tracker_poc/data/goal_repository.dart';
import 'package:goal_tracker_poc/data/life_repository.dart';
import 'package:goal_tracker_poc/ui/goal_app.dart';

void main() {
  for (final size in [const Size(1280, 800), const Size(1024, 768)]) {
    testWidgets('Windows navigation fits ${size.width.toInt()}px', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        GoalApp(
          store: GoalStore(repository: MemoryGoalRepository()),
          lifeStore: LifeStore(MemoryLifeRepository()),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'Today');
      for (final page in ['Goals', 'Tasks', 'Calendar', 'AI', 'Settings']) {
        await tester.tap(find.text(page).first);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: page);
      }
    });
  }
}
