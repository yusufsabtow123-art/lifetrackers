import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:goal_tracker_poc/app/goal_store.dart';
import 'package:goal_tracker_poc/app/life_store.dart';
import 'package:goal_tracker_poc/app/theme_controller.dart';
import 'package:goal_tracker_poc/data/app_settings_repository.dart';
import 'package:goal_tracker_poc/data/goal_repository.dart';
import 'package:goal_tracker_poc/data/life_repository.dart';
import 'package:goal_tracker_poc/domain/goal.dart';
import 'package:goal_tracker_poc/domain/life_data.dart';
import 'package:goal_tracker_poc/ui/goal_app.dart';

void main() {
  testWidgets('enabling Salah makes prayer blocks visible in Calendar', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final goals = GoalStore(repository: MemoryGoalRepository());
    await goals.load();
    await goals.createQuick('Keep the real shell loaded');
    final lifeStore = LifeStore(
      MemoryLifeRepository(const LifeData(showBlockedTimes: false)),
      clock: () => DateTime(2026, 9, 10, 12),
    );
    await lifeStore.load();
    final settings = AppSettingsController(MemoryAppSettingsRepository());
    await settings.load();

    await tester.pumpWidget(
      GoalApp(store: goals, lifeStore: lifeStore, settingsController: settings),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('More').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Calendar'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('salah-calendar-enabled')));
    await tester.pumpAndSettle();

    expect(settings.salahEnabled, isTrue);
    expect(lifeStore.data.showBlockedTimes, isTrue);
    expect(lifeStore.entriesFor(DateTime(2026, 9, 10)), hasLength(5));
    expect(tester.takeException(), isNull);
  });

  testWidgets('Today check circle completes once without forcing a note', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final goals = GoalStore(repository: MemoryGoalRepository());
    await goals.load();
    await goals.createQuick('Unplanned goal');
    final tasks = LifeStore(MemoryLifeRepository());
    await tasks.load();
    await tasks.addTask(title: 'Daily task', dueAt: goals.today);

    await tester.pumpWidget(GoalApp(store: goals, lifeStore: tasks));
    await tester.pumpAndSettle();

    expect(find.text('Daily task'), findsWidgets);
    expect(find.text('How did you do it?'), findsNothing);
    await tester.tap(find.byTooltip('Complete'));
    await tester.pumpAndSettle();

    expect(tasks.tasks.single.isDoneOn(goals.today), isTrue);
    expect(find.text('How did you do it?'), findsNothing);
    expect(find.byKey(const ValueKey('complete')), findsOneWidget);
    expect(find.text('Daily task'), findsNothing);
  });

  testWidgets('Today task arrow opens completion while its name still edits', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final today = DateTime(2026, 9, 10, 18, 7);
    final goals = GoalStore(
      repository: MemoryGoalRepository(),
      clock: () => today,
    );
    await goals.load();
    final tasks = LifeStore(MemoryLifeRepository(), clock: () => today);
    await tasks.load();
    await tasks.addTask(title: 'Call Ahmed', dueAt: today);

    await tester.pumpWidget(GoalApp(store: goals, lifeStore: tasks));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Completion details'));
    await tester.pumpAndSettle();

    expect(find.text('Completion record'), findsOneWidget);
    expect(find.text('Call Ahmed'), findsOneWidget);
    expect(find.text('Edit task'), findsNothing);
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Call Ahmed'));
    await tester.pumpAndSettle();
    expect(find.text('Edit task'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Today goal arrow opens the approved completion record', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final today = DateTime(2026, 9, 10, 18, 7);
    final goals = GoalStore(
      repository: MemoryGoalRepository(),
      clock: () => today,
    );
    await goals.load();
    await goals.createPlanned(
      name: 'Memorize the Quran',
      amount: 10,
      unit: 'pages',
      startDate: today,
      deadline: DateTime(2026, 9, 19),
      wholeUnits: true,
    );
    final lifeStore = LifeStore(MemoryLifeRepository(), clock: () => today);
    await lifeStore.load();

    await tester.pumpWidget(GoalApp(store: goals, lifeStore: lifeStore));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Open'));
    await tester.pumpAndSettle();

    expect(find.text('Completion record'), findsOneWidget);
    expect(find.text('Progress & plan'), findsNothing);
    expect(find.text('Save completion'), findsOneWidget);
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Complete'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Completed'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Completion details'));
    await tester.pumpAndSettle();

    expect(find.text('Completion record'), findsOneWidget);
    expect(find.text('Outcome'), findsOneWidget);
    expect(find.text('Notes'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('editing an undated task preserves its unscheduled state', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final tasks = LifeStore(MemoryLifeRepository());
    await tasks.load();
    await tasks.addTask(title: 'Undated task');
    await tester.pumpWidget(
      GoalApp(
        store: GoalStore(repository: MemoryGoalRepository()),
        lifeStore: tasks,
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tasks').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('All'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Task actions'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Edit task'));
    await tester.pumpAndSettle();
    expect(find.text('No date'), findsOneWidget);
    await tester.enterText(
      find.byKey(const Key('task-title-field')),
      'Still undated',
    );
    await tester.scrollUntilVisible(
      find.byKey(const Key('task-save-button')),
      260,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('task-save-button')));
    await tester.pumpAndSettle();
    expect(tasks.tasks.single.title, 'Still undated');
    expect(tasks.tasks.single.dueAt, isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('compact Android screens keep all four pages usable', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 740);
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
    for (final page in ['Goals', 'Tasks', 'Calendar', 'More']) {
      await tester.tap(find.text(page).last);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: page);
    }
  });

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
    expect(find.byKey(const Key('today-inline-quick-add')), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Goals').last);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('simplified-new-goal-button')), findsOneWidget);
    expect(find.byKey(const Key('simplified-goal-list')), findsOneWidget);
    expect(find.text('Memorize the Quran'), findsWidgets);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Calendar').last);
    await tester.pumpAndSettle();
    expect(find.byTooltip('Schedule'), findsOneWidget);
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

    await tester.tap(find.byKey(const Key('calendar-floating-add-button')));
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

  testWidgets('holding and dragging on the timeline creates a time range', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final goals = GoalStore(repository: MemoryGoalRepository());
    final lifeStore = LifeStore(MemoryLifeRepository());

    await tester.pumpWidget(GoalApp(store: goals, lifeStore: lifeStore));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Calendar').last);
    await tester.pumpAndSettle();

    final date = goals.today;
    final timeline = find.byKey(
      ValueKey('calendar-timeline-${date.year}-${date.month}-${date.day}'),
    );
    expect(timeline, findsOneWidget);
    final start = tester.getCenter(timeline);
    final gesture = await tester.startGesture(start);
    await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
    await gesture.moveBy(const Offset(0, 54));
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();

    expect(find.text('Add to calendar'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('simplified goals match the grouped text-first design', (
    tester,
  ) async {
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
    await tester.tap(find.text('Board'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Simplified'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('simplified-goal-list')), findsOneWidget);
    expect(find.text('Find a better job'), findsOneWidget);
    expect(find.text('Ideas'), findsOneWidget);
    expect(find.text('In progress'), findsOneWidget);
    expect(find.text('Paused'), findsOneWidget);
    expect(find.text('Finished'), findsOneWidget);
    expect(find.byKey(const Key('simplified-new-goal-button')), findsOneWidget);
    expect(find.text('Move what matters forward.'), findsOneWidget);
    expect(find.text('Add a plan'), findsNothing);
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
    await tester.tap(find.text('Board'));
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

    expect(find.text('Daily editable task'), findsOneWidget);
    await tester.tap(
      find.descendant(
        of: find.byKey(ValueKey(task.id)),
        matching: find.byIcon(Icons.circle_outlined),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: find.byKey(ValueKey(task.id)),
        matching: find.byIcon(Icons.circle_outlined),
      ),
      findsNothing,
    );
    expect(find.text('Completed'), findsOneWidget);

    await tester.tap(find.text('Tasks').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Task actions'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Edit task'));
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
    await tester.scrollUntilVisible(
      find.byKey(const Key('task-save-button')),
      260,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.pumpAndSettle();
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
    expect(find.text('Progress & plan'), findsOneWidget);
    expect(find.text('Board column'), findsNothing);
    expect(find.text('Organize'), findsNothing);
    expect(find.byKey(const Key('edit-goal-details-button')), findsNothing);
    await tester.ensureVisible(find.text('Details'));
    await tester.tap(find.text('Details'));
    await tester.pumpAndSettle();

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
    await tester.tap(find.byTooltip('Month'));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('calendar-month-view')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('wide calendar fills its panel without layout errors', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
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

    expect(find.text('Blocked times'), findsOneWidget);
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
    await tester.tap(find.text('Board'));
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
