import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:goal_tracker_poc/app/goal_store.dart';
import 'package:goal_tracker_poc/app/life_store.dart';
import 'package:goal_tracker_poc/data/goal_repository.dart';
import 'package:goal_tracker_poc/data/life_repository.dart';
import 'package:goal_tracker_poc/domain/goal.dart';
import 'package:goal_tracker_poc/ui/goal_app.dart';

void main() {
  testWidgets('mobile shell keeps the approved goal board and new pages', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      GoalApp(
        store: GoalStore(repository: MemoryGoalRepository()),
        lifeStore: LifeStore(MemoryLifeRepository()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Today'), findsWidgets);
    expect(find.text('Daily actions'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Goals').last);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('new-goal-button')), findsOneWidget);
    expect(find.byKey(const Key('mobile-goal-board')), findsOneWidget);
    expect(find.text('Memorize the Quran'), findsWidgets);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Calendar').last);
    await tester.pumpAndSettle();
    expect(find.text('Blocked times are shown'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('wide calendar fills its panel without layout errors', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      GoalApp(
        store: GoalStore(repository: MemoryGoalRepository()),
        lifeStore: LifeStore(MemoryLifeRepository()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Calendar').last);
    await tester.pumpAndSettle();

    expect(find.text('Blocked times are shown'), findsOneWidget);
    expect(find.byIcon(Icons.playlist_add_rounded), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('approved board moves goals between columns', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final goals = GoalStore(repository: MemoryGoalRepository());
    await goals.load();
    final goal = await goals.createQuick('Move this goal');

    await tester.pumpWidget(
      GoalApp(store: goals, lifeStore: LifeStore(MemoryLifeRepository())),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Goals').first);
    await tester.pumpAndSettle();

    final source = tester.getCenter(find.text('Move this goal'));
    final target = tester.getCenter(
      find.byKey(const Key('life-goal-column-active')),
    );
    final gesture = await tester.startGesture(source);
    await tester.pump(const Duration(milliseconds: 650));
    await gesture.moveTo(target);
    await tester.pump(const Duration(milliseconds: 200));
    await gesture.up();
    await tester.pumpAndSettle();

    expect(goals.goalById(goal.id)?.status, GoalStatus.active);
    expect(tester.takeException(), isNull);
  });
}
