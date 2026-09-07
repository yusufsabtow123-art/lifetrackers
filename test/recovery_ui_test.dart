import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:goal_tracker_poc/app/goal_store.dart';
import 'package:goal_tracker_poc/app/theme_controller.dart';
import 'package:goal_tracker_poc/data/app_settings_repository.dart';
import 'package:goal_tracker_poc/data/goal_repository.dart';
import 'package:goal_tracker_poc/domain/goal.dart';
import 'package:goal_tracker_poc/ui/goal_app.dart';

void main() {
  testWidgets(
    'a board column can be hidden and restored without moving goals',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1400, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final store = GoalStore(repository: MemoryGoalRepository());
      await store.load();
      final goal = await store.createQuick('Paused goal');
      await store.moveGoal(goal.id, GoalStatus.paused);
      final settings = AppSettingsController(MemoryAppSettingsRepository());
      await settings.load();

      await tester.pumpWidget(
        GoalApp(store: store, settingsController: settings),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('hide-column-paused')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('column-paused')), findsNothing);
      expect(store.goalById(goal.id)?.status, GoalStatus.paused);
      expect(find.byKey(const Key('hidden-columns-control')), findsOneWidget);

      await tester.tap(find.byKey(const Key('hidden-columns-control')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Restore Paused'));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('column-paused')), findsOneWidget);
      expect(store.goalById(goal.id)?.status, GoalStatus.paused);
    },
  );

  testWidgets('batch step entry previews and saves every entered item', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final store = GoalStore(repository: MemoryGoalRepository());
    await store.load();
    final goal = await store.createQuick('Cook rice');

    await tester.pumpWidget(GoalApp(store: store));
    await tester.pumpAndSettle();
    await tester.tap(find.text(goal.name));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('goal-detail-view-toggle')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('add-many-steps-button')));
    await tester.tap(find.byKey(const Key('add-many-steps-button')));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('batch-steps-field')),
      'Get pot + Add water + Cook = Rice ready',
    );
    await tester.pumpAndSettle();
    expect(find.text('Final result'), findsOneWidget);
    await tester.tap(find.byKey(const Key('confirm-add-many-steps')));
    await tester.pumpAndSettle();

    expect(store.goalById(goal.id)?.steps.map((step) => step.title), [
      'Get pot',
      'Add water',
      'Cook',
      'Rice ready',
    ]);
  });

  testWidgets('whole-goal progress keeps its column unless confirmed', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final store = GoalStore(repository: MemoryGoalRepository());
    await store.load();
    final goal = await store.createPlanned(
      name: 'Read a book',
      amount: 100,
      unit: 'page',
      startDate: DateTime.now(),
      deadline: DateTime.now().add(const Duration(days: 30)),
      wholeUnits: true,
    );

    await tester.pumpWidget(GoalApp(store: store));
    await tester.pumpAndSettle();
    await tester.tap(find.text(goal.name));
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.byKey(const Key('log-amount-progress-button')),
    );
    await tester.tap(find.byKey(const Key('log-amount-progress-button')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('completed-amount-field')));
    await tester.enterText(
      find.byKey(const Key('completed-amount-field')),
      '100',
    );
    await tester.enterText(
      find.byKey(const Key('progress-note-field')),
      'Finished the final chapter',
    );
    await tester.ensureVisible(find.byKey(const Key('save-progress-button')));
    await tester.tap(find.byKey(const Key('save-progress-button')));
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Move this goal to Completed?'), findsOneWidget);
    await tester.tap(find.text('Keep it here'));
    await tester.pumpAndSettle();

    final saved = store.goalById(goal.id)!;
    expect(saved.completedAmount, 100);
    expect(saved.status, isNot(GoalStatus.completed));
    expect(saved.progressHistory.single.note, 'Finished the final chapter');
  });
}
