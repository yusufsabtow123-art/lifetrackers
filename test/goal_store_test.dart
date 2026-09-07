import 'package:flutter_test/flutter_test.dart';
import 'package:goal_tracker_poc/app/goal_store.dart';
import 'package:goal_tracker_poc/data/goal_repository.dart';
import 'package:goal_tracker_poc/domain/goal.dart';

void main() {
  test(
    'due planned goals activate on reload and expose the in-app notice',
    () async {
      final planned = Goal(
        id: 'planned',
        name: 'Read 10 pages',
        status: GoalStatus.planned,
        createdAt: DateTime(2026, 7, 1),
        updatedAt: DateTime(2026, 7, 1),
        plan: GoalPlan(
          totalAmount: 10,
          unit: 'pages',
          startDate: DateTime(2026, 8, 1),
          deadline: DateTime(2026, 8, 10),
          activeWeekdays: const {1, 2, 3, 4, 5, 6, 7},
          wholeUnits: true,
          acceptedDailyPace: 1,
        ),
      );
      final repository = MemoryGoalRepository([planned]);
      final store = GoalStore(
        repository: repository,
        clock: () => DateTime(2026, 8, 1, 8),
      );

      await store.load();

      expect(store.goals.single.status, GoalStatus.active);
      expect(store.pendingStartNotice?.id, 'planned');
      expect((await repository.loadAll()).single.status, GoalStatus.active);
    },
  );

  test('manual progress is dated and never moves the board silently', () async {
    final repository = MemoryGoalRepository();
    final store = GoalStore(
      repository: repository,
      clock: () => DateTime(2026, 8, 1, 8),
    );
    await store.load();
    final goal = await store.createPlanned(
      name: 'Read',
      amount: 10,
      unit: 'pages',
      startDate: DateTime(2026, 8, 1),
      deadline: DateTime(2026, 8, 10),
      wholeUnits: true,
    );

    await store.recordProgress(goal.id, 10);

    final saved = (await repository.loadAll()).single;
    expect(saved.completedAmount, 10);
    expect(saved.status, GoalStatus.active);
    expect(saved.progressHistory.single.change, 10);

    await expectLater(store.recordProgress(goal.id, 11), throwsArgumentError);
  });

  test('starting progress is saved and daily work uses what remains', () async {
    final repository = MemoryGoalRepository();
    final store = GoalStore(
      repository: repository,
      clock: () => DateTime(2026, 8, 1, 8),
    );
    await store.load();

    final goal = await store.createPlanned(
      name: 'Memorize the Quran',
      amount: 604,
      unit: 'pages',
      startDate: DateTime(2026, 8, 1),
      deadline: DateTime(2026, 8, 10),
      wholeUnits: true,
      initialCompletedAmount: 102,
    );

    final saved = (await repository.loadAll()).single;
    expect(saved.completedAmount, 102);
    expect(saved.progress, closeTo(102 / 604, 0.0001));
    expect(saved.plan?.initialCompletedAmount, 102);
    expect(saved.plan?.acceptedDailyPace, closeTo(50.2, 0.0001));
    expect(saved.progressHistory.single.note, 'Starting progress');
    expect(store.calculator.actionForDate(goal, store.today), 51);
  });

  test('today action saves its note, toggles off, and supports undo', () async {
    final repository = MemoryGoalRepository();
    final store = GoalStore(
      repository: repository,
      clock: () => DateTime(2026, 8, 1, 8),
    );
    await store.load();
    final goal = await store.createPlanned(
      name: 'Read',
      amount: 10,
      unit: 'pages',
      startDate: DateTime(2026, 8, 1),
      deadline: DateTime(2026, 8, 10),
      wholeUnits: true,
    );

    await store.completeTodayAction(goal.id, note: 'Read the introduction.');

    var saved = (await repository.loadAll()).single;
    expect(saved.dailyActionCompletions.single.note, 'Read the introduction.');
    expect(saved.progressHistory.single.note, 'Read the introduction.');

    await store.undoTodayAction(goal.id);
    saved = (await repository.loadAll()).single;
    expect(saved.dailyActionCompletions, isEmpty);

    await store.undoLastChange();
    saved = (await repository.loadAll()).single;
    expect(saved.dailyActionCompletions.single.note, 'Read the introduction.');
  });

  test(
    'inline steps and text updates save independently without moving the goal',
    () async {
      final repository = MemoryGoalRepository();
      final store = GoalStore(
        repository: repository,
        clock: () => DateTime(2026, 8, 11, 10),
      );
      await store.load();
      final goal = await store.createQuick('Make lasagna');
      await store.moveGoal(goal.id, GoalStatus.active);

      await store.addStep(goal.id, 'Make sauce');
      final step = store.goalById(goal.id)!.steps.single;
      await store.addUpdate(goal.id, 'Got tomatoes', stepId: step.id);

      var saved = (await repository.loadAll()).single;
      expect(saved.status, GoalStatus.active);
      expect(saved.steps.single.isCompleted, isFalse);
      expect(saved.updates.single.text, 'Got tomatoes');
      expect(saved.updates.single.stepId, step.id);
      expect(saved.updates.single.stepTitle, 'Make sauce');
      expect(saved.progress, 0);

      await store.toggleStep(goal.id, step.id);
      saved = (await repository.loadAll()).single;
      expect(saved.steps.single.isCompleted, isTrue);
      expect(saved.progress, 1);
      expect(saved.status, GoalStatus.active);

      await store.toggleStep(goal.id, step.id);
      expect(store.goalById(goal.id)!.steps.single.isCompleted, isFalse);
    },
  );

  test(
    'inline steps do not replace amount progress on an amount goal',
    () async {
      final repository = MemoryGoalRepository();
      final store = GoalStore(
        repository: repository,
        clock: () => DateTime(2026, 8, 11, 10),
      );
      await store.load();
      final goal = await store.createPlanned(
        name: 'Finish the Quran',
        amount: 604,
        unit: 'pages',
        startDate: DateTime(2026, 8, 11),
        deadline: DateTime(2027, 8, 11),
        wholeUnits: true,
        initialCompletedAmount: 2,
      );

      await store.addStep(goal.id, 'Review the current surah');
      final step = store.goalById(goal.id)!.steps.single;
      await store.addUpdate(goal.id, 'Reviewed one ayah', stepId: step.id);

      final saved = (await repository.loadAll()).single;
      expect(saved.completedAmount, 2);
      expect(saved.progress, closeTo(2 / 604, 0.000001));
      expect(saved.steps.single.isCompleted, isFalse);
      expect(saved.status, GoalStatus.active);
    },
  );

  test('steps receive unique IDs even when the clock does not move', () async {
    final repository = MemoryGoalRepository();
    final store = GoalStore(
      repository: repository,
      clock: () => DateTime(2026, 8, 11, 10),
    );
    await store.load();
    final goal = await store.createQuick('Make lasagna');

    await store.addStep(goal.id, 'Make sauce');
    await store.addStep(goal.id, 'Layer noodles');

    final steps = store.goalById(goal.id)!.steps;
    expect(steps.map((step) => step.id).toSet(), hasLength(2));
    await store.removeStep(goal.id, steps.first.id);
    expect(store.goalById(goal.id)!.steps.single.title, 'Layer noodles');
  });

  test('trash preserves goal data, restores it, and supports undo', () async {
    final repository = MemoryGoalRepository();
    final store = GoalStore(
      repository: repository,
      clock: () => DateTime(2026, 8, 5, 12),
    );
    await store.load();
    final goal = await store.createPlanned(
      name: 'Keep my plan',
      amount: 12,
      unit: 'pages',
      startDate: DateTime(2026, 8, 6),
      deadline: DateTime(2026, 8, 20),
      wholeUnits: true,
    );

    await store.trashGoal(goal.id);

    final trashed = store.goalById(goal.id)!;
    expect(trashed.isTrashed, isTrue);
    expect(trashed.status, GoalStatus.planned);
    expect(trashed.plan?.totalAmount, 12);
    expect(store.goalsFor(GoalStatus.planned), isEmpty);
    expect(store.trashedGoals.single.id, goal.id);

    await store.undoLastChange();
    expect(store.goalById(goal.id)?.isTrashed, isFalse);
    expect(store.goalsFor(GoalStatus.planned).single.id, goal.id);

    await store.trashGoal(goal.id);
    await store.restoreGoal(goal.id);
    expect(store.goalById(goal.id)?.isTrashed, isFalse);
    expect(store.goalById(goal.id)?.plan?.unit, 'pages');
  });

  test('delete forever removes only an already trashed goal', () async {
    final repository = MemoryGoalRepository();
    final store = GoalStore(repository: repository);
    await store.load();
    final keep = await store.createQuick('Keep');
    final remove = await store.createQuick('Remove');

    await store.deleteForever(keep.id);
    expect(store.goalById(keep.id), isNotNull);

    await store.trashGoal(remove.id);
    await store.deleteForever(remove.id);

    expect(store.goalById(remove.id), isNull);
    expect(
      (await repository.loadAll()).map((goal) => goal.id),
      contains(keep.id),
    );
  });
}
