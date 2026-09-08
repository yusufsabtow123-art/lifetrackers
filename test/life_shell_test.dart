import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:goal_tracker_poc/app/goal_store.dart';
import 'package:goal_tracker_poc/app/life_store.dart';
import 'package:goal_tracker_poc/data/goal_repository.dart';
import 'package:goal_tracker_poc/data/life_repository.dart';
import 'package:goal_tracker_poc/domain/goal.dart';
import 'package:goal_tracker_poc/domain/life_data.dart';
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
    expect(find.byKey(const Key('calendar-day-timeline')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('mobile calendar adds and edits a timed block without crashing', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final lifeStore = LifeStore(MemoryLifeRepository());

    await tester.pumpWidget(
      GoalApp(
        store: GoalStore(repository: MemoryGoalRepository()),
        lifeStore: lifeStore,
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Calendar').last);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('calendar-add-button')));
    await tester.pumpAndSettle();
    expect(find.text('Add to calendar'), findsWidgets);
    await tester.enterText(
      find.byKey(const Key('calendar-title-field')),
      'Focus block',
    );
    await tester.tap(find.text('Blocked time'));
    await tester.tap(find.byKey(const Key('calendar-color-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(Key('calendar-color-${0xFF45C7BA}')));
    await tester.tap(find.byKey(const Key('calendar-color-done')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('calendar-save-button')));
    await tester.pumpAndSettle();

    expect(lifeStore.calendar.single.title, 'Focus block');
    expect(lifeStore.calendar.single.kind, CalendarEntryKind.blockedTime);
    expect(lifeStore.calendar.single.colorValue, 0xFF45C7BA);
    expect(
      find.byKey(Key('calendar-entry-${lifeStore.calendar.single.id}')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);

    await tester.tap(
      find.byKey(Key('calendar-entry-${lifeStore.calendar.single.id}')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Edit calendar item'), findsOneWidget);
    expect(tester.takeException(), isNull);
    Navigator.of(tester.element(find.text('Edit calendar item'))).pop();
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('simplified goals are one compact action list', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final goals = GoalStore(repository: MemoryGoalRepository());
    await goals.load();
    await goals.createQuick('Find a better job');

    await tester.pumpWidget(
      GoalApp(store: goals, lifeStore: LifeStore(MemoryLifeRepository())),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Goals').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Simplified'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('simplified-goal-list')), findsOneWidget);
    expect(find.text('Find a better job'), findsOneWidget);
    expect(find.text('Add a plan'), findsWidgets);
    expect(find.byKey(const Key('mobile-goal-board')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('dragging near the mobile edge scrolls the goal board', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final goals = GoalStore(repository: MemoryGoalRepository());
    await goals.load();
    await goals.createQuick('Drag me across');

    await tester.pumpWidget(
      GoalApp(store: goals, lifeStore: LifeStore(MemoryLifeRepository())),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Goals').last);
    await tester.pumpAndSettle();

    final board = find.byKey(const Key('mobile-goal-board'));
    final scrollable = find
        .descendant(of: board, matching: find.byType(Scrollable))
        .first;
    final position = tester.state<ScrollableState>(scrollable).position;
    final gesture = await tester.startGesture(
      tester.getCenter(find.text('Drag me across')),
    );
    await tester.pump(const Duration(milliseconds: 650));
    await gesture.moveTo(const Offset(384, 430));
    await tester.pump(const Duration(milliseconds: 500));

    expect(position.pixels, greaterThan(0));
    await gesture.up();
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('daily task count decreases and its name opens editing', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final today = DateTime(2027, 1, 5);
    final goals = GoalStore(
      repository: MemoryGoalRepository(),
      clock: () => today,
    );
    final lifeStore = LifeStore(MemoryLifeRepository(), clock: () => today);
    await lifeStore.load();
    await lifeStore.addTask(
      title: 'Daily editable task',
      dueAt: today,
      repeat: TaskRepeat.daily,
    );

    await tester.pumpWidget(GoalApp(store: goals, lifeStore: lifeStore));
    await tester.pumpAndSettle();
    final task = lifeStore.tasks.single;

    expect(find.byKey(const Key('today-task-count')), findsOneWidget);
    expect(
      tester.widget<Text>(find.byKey(const Key('today-task-count'))).data,
      '1',
    );
    await tester.tap(
      find.descendant(
        of: find.byKey(ValueKey(task.id)),
        matching: find.byIcon(Icons.radio_button_unchecked_rounded),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      tester.widget<Text>(find.byKey(const Key('today-task-count'))).data,
      '0',
    );

    await tester.tap(find.text('Tasks').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Daily editable task'));
    await tester.pumpAndSettle();
    expect(find.text('Edit task'), findsOneWidget);
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('task-title-field')))
          .controller!
          .text,
      'Daily editable task',
    );
    await tester.enterText(
      find.byKey(const Key('task-title-field')),
      'Edited daily task',
    );
    await tester.tap(find.byKey(const Key('task-save-button')));
    await tester.pumpAndSettle();

    expect(lifeStore.tasks.single.title, 'Edited daily task');
    expect(lifeStore.tasks.single.isDoneOn(today), isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('opened goal puts action first and keeps setup out of the way', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final today = DateTime(2027, 1, 5);
    final goals = GoalStore(
      repository: MemoryGoalRepository(),
      clock: () => today,
    );
    await goals.load();
    await goals.createPlanned(
      name: 'Read the Quran',
      amount: 100,
      unit: 'page',
      startDate: today,
      deadline: DateTime(2027, 4, 14),
      wholeUnits: true,
    );

    await tester.pumpWidget(
      GoalApp(store: goals, lifeStore: LifeStore(MemoryLifeRepository())),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Goals').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Simplified'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Read the Quran'));
    await tester.tap(find.text('Read the Quran'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('goal-today-action')), findsOneWidget);
    expect(find.byKey(const Key('goal-schedule-summary')), findsOneWidget);
    expect(find.byKey(const Key('unified-progress-section')), findsOneWidget);
    expect(find.text('Board column'), findsNothing);
    expect(find.text('Organize'), findsNothing);
    expect(find.byKey(const Key('edit-goal-details-button')), findsOneWidget);

    await tester.ensureVisible(
      find.byKey(const Key('edit-goal-details-button')),
    );
    await tester.tap(find.byKey(const Key('edit-goal-details-button')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('goal-status-field')), findsOneWidget);
    expect(find.text('Organize'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('mobile month calendar has no overflow', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
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
    await tester.tap(find.text('Month'));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('calendar-month-view')), findsOneWidget);
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
