import 'package:flutter_test/flutter_test.dart';
import 'package:goal_tracker_poc/app/goal_store.dart';
import 'package:goal_tracker_poc/data/goal_repository.dart';
import 'package:goal_tracker_poc/domain/goal.dart';

void main() {
  test(
    'step updates, completion, and reopening are distinct actions',
    () async {
      final repository = MemoryGoalRepository();
      final store = GoalStore(
        repository: repository,
        clock: () => DateTime.utc(2026, 8, 20, 10),
      );
      await store.load();
      final goal = await store.createQuick('Make dinner');
      await store.addStep(goal.id, 'Make sauce', details: 'Use the large pot.');
      final step = store.goalById(goal.id)!.steps.single;

      await store.addUpdate(goal.id, 'Bought tomatoes', stepId: step.id);
      var saved = store.goalById(goal.id)!;
      expect(saved.steps.single.isCompleted, isFalse);
      expect(saved.updates.single.kind, GoalUpdateKind.note);
      expect(saved.status, GoalStatus.ideas);

      await store.completeStep(goal.id, step.id, note: 'Sauce is simmering');
      saved = store.goalById(goal.id)!;
      expect(saved.steps.single.isCompleted, isTrue);
      expect(saved.updates.last.kind, GoalUpdateKind.stepCompletion);
      expect(saved.updates.last.text, 'Sauce is simmering');
      expect(saved.status, GoalStatus.ideas);

      await store.reopenStep(goal.id, step.id);
      saved = store.goalById(goal.id)!;
      expect(saved.steps.single.isCompleted, isFalse);
      expect(saved.updates.last.kind, GoalUpdateKind.stepReopened);
      expect(saved.updates.map((update) => update.id).toSet(), hasLength(3));
    },
  );

  test(
    'step edits and reordering preserve stable identities and history',
    () async {
      final repository = MemoryGoalRepository();
      final store = GoalStore(
        repository: repository,
        clock: () => DateTime.utc(2026, 8, 20, 11),
      );
      await store.load();
      final goal = await store.createQuick('Prepare dinner');
      await store.addSteps(goal.id, ['Shop', 'Cook', 'Serve']);
      final original = List<GoalStep>.of(store.goalById(goal.id)!.steps);
      await store.addUpdate(
        goal.id,
        'At the market',
        stepId: original.first.id,
      );

      await store.updateStep(
        goal.id,
        original.first.id,
        title: 'Buy groceries',
        details: 'Tomatoes and onions',
      );
      await store.reorderStep(goal.id, 0, 3);

      final saved = store.goalById(goal.id)!;
      expect(saved.steps.last.id, original.first.id);
      expect(saved.steps.last.title, 'Buy groceries');
      expect(saved.steps.last.details, 'Tomatoes and onions');
      expect(saved.updates.single.stepId, original.first.id);
      expect(saved.updates.single.stepTitle, 'Buy groceries');
    },
  );

  test(
    'updates can be edited, moved, and deleted without new identities',
    () async {
      var tick = 0;
      final repository = MemoryGoalRepository();
      final store = GoalStore(
        repository: repository,
        clock: () =>
            DateTime.utc(2026, 8, 20, 12).add(Duration(microseconds: tick++)),
      );
      await store.load();
      final goal = await store.createQuick('Prepare dinner');
      await store.addSteps(goal.id, ['Shop', 'Cook']);
      final steps = store.goalById(goal.id)!.steps;
      await store.addUpdate(goal.id, 'Started', stepId: steps.first.id);
      final updateId = store.goalById(goal.id)!.updates.single.id;

      await store.editUpdate(goal.id, updateId, 'Shopping started');
      await store.moveUpdate(goal.id, updateId, stepId: steps.last.id);
      var saved = store.goalById(goal.id)!;
      expect(saved.updates.single.id, updateId);
      expect(saved.updates.single.text, 'Shopping started');
      expect(saved.updates.single.stepId, steps.last.id);
      expect(saved.updates.single.editedAt, isNotNull);

      await store.moveUpdate(goal.id, updateId);
      saved = store.goalById(goal.id)!;
      expect(saved.updates.single.id, updateId);
      expect(saved.updates.single.stepId, isNull);

      await store.deleteUpdate(goal.id, updateId);
      expect(store.goalById(goal.id)!.updates, isEmpty);
      await store.undoLastChange();
      expect(store.goalById(goal.id)!.updates.single.id, updateId);
    },
  );
}
