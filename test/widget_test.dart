import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:goal_tracker_poc/app/goal_store.dart';
import 'package:goal_tracker_poc/app/theme_controller.dart';
import 'package:goal_tracker_poc/data/app_settings_repository.dart';
import 'package:goal_tracker_poc/data/goal_repository.dart';
import 'package:goal_tracker_poc/domain/goal.dart';
import 'package:goal_tracker_poc/ui/goal_app.dart';

void main() {
  testWidgets('quick create only requires a name and persists in Ideas', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repository = MemoryGoalRepository();
    final store = GoalStore(repository: repository);

    await tester.pumpWidget(GoalApp(store: store));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Capture idea'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('goal-name-field')),
      'Learn Arabic',
    );
    await tester.tap(find.byKey(const Key('add-to-ideas-button')));
    await tester.pumpAndSettle();

    expect(find.text('Learn Arabic'), findsOneWidget);
    expect(store.goals.single.status, GoalStatus.ideas);
    expect(store.goals.single.plan, isNull);
    expect((await repository.loadAll()).single.name, 'Learn Arabic');
  });

  testWidgets('urgency is controlled inside the goal and shown on its card', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final store = GoalStore(repository: MemoryGoalRepository());
    await store.load();
    final goal = await store.createQuick('Call the doctor today');

    await tester.pumpWidget(GoalApp(store: store));
    await tester.pumpAndSettle();

    expect(find.byKey(Key('toggle-urgent-${goal.id}')), findsNothing);
    await tester.tap(find.text(goal.name));
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.byKey(const Key('edit-goal-details-button')),
    );
    await tester.tap(find.byKey(const Key('edit-goal-details-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('goal-urgent-switch')));
    await tester.pump(const Duration(milliseconds: 300));

    expect(store.goalById(goal.id)?.isUrgent, isTrue);
    expect(store.goalById(goal.id)?.urgencyStyle, UrgencyStyle.fireRing);
    expect(find.byKey(Key('urgent-card-frame-${goal.id}')), findsOneWidget);

    await tester.tap(find.byKey(const Key('urgency-style-policeSiren')));
    await tester.pump(const Duration(milliseconds: 300));

    expect(store.goalById(goal.id)?.urgencyStyle, UrgencyStyle.policeSiren);
  });

  testWidgets(
    'plan now creates an active goal and demonstrates start actions',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final store = GoalStore(
        repository: MemoryGoalRepository(),
        clock: () => DateTime(2026, 8, 1, 9),
      );

      await tester.pumpWidget(GoalApp(store: store));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Capture idea'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('goal-name-field')),
        'Read 100 pages',
      );
      await tester.tap(find.byKey(const Key('plan-now-button')));
      await tester.pumpAndSettle();

      expect(find.text('Suggested plan'), findsNothing);
      expect(find.text('Active days'), findsNothing);
      final createButton = find.byKey(const Key('create-planned-goal-button'));
      await tester.ensureVisible(createButton);
      await tester.pumpAndSettle();
      await tester.tap(createButton);
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('automatic-start-notice')), findsOneWidget);
      expect(store.goals.single.status, GoalStatus.active);
      await tester.tap(find.byKey(const Key('undo-start-button')));
      await tester.pumpAndSettle();
      expect(store.goals.single.status, GoalStatus.planned);
      expect(find.byKey(const Key('automatic-start-notice')), findsNothing);
    },
  );

  testWidgets('plan accepts a countdown position as starting progress', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final store = GoalStore(
      repository: MemoryGoalRepository(),
      clock: () => DateTime(2026, 8, 1, 9),
    );

    await tester.pumpWidget(GoalApp(store: store));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Capture idea'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('goal-name-field')),
      'Memorize the Quran',
    );
    await tester.tap(find.byKey(const Key('plan-now-button')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('total-amount-field')), '604');
    await tester.tap(find.text('Starting point'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('starting-progress-field')),
      '102',
    );
    final advancedTile = find.ancestor(
      of: find.text('Advanced'),
      matching: find.byType(ListTile),
    );
    await tester.ensureVisible(advancedTile);
    await tester.pumpAndSettle();
    tester.widget<ListTile>(advancedTile).onTap!.call();
    await tester.pumpAndSettle();
    final progressModeSwitch = find.byKey(
      const Key('count-down-progress-switch'),
    );
    expect(
      tester
          .widget<TextField>(
            find.byKey(const Key('total-amount-field'), skipOffstage: false),
          )
          .controller
          ?.text,
      '604',
    );
    expect(tester.widget<SwitchListTile>(progressModeSwitch).value, isFalse);
    tester
        .widget<Switch>(
          find.descendant(
            of: progressModeSwitch,
            matching: find.byType(Switch),
          ),
        )
        .onChanged!
        .call(true);
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('starting-progress-field')))
          .controller
          ?.text,
      '502',
    );
    expect(
      find.textContaining('102 of 604 pages complete · 17%'),
      findsOneWidget,
    );
    expect(find.textContaining('502 pages remaining'), findsOneWidget);

    tester
        .widget<Switch>(
          find.descendant(
            of: progressModeSwitch,
            matching: find.byType(Switch),
          ),
        )
        .onChanged!
        .call(false);
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('starting-progress-field')))
          .controller
          ?.text,
      '102',
    );
    tester
        .widget<Switch>(
          find.descendant(
            of: progressModeSwitch,
            matching: find.byType(Switch),
          ),
        )
        .onChanged!
        .call(true);
    await tester.pumpAndSettle();

    final createButton = find.byKey(const Key('create-planned-goal-button'));
    await tester.ensureVisible(createButton);
    await tester.pumpAndSettle();
    await tester.tap(createButton);
    await tester.pumpAndSettle();

    final goal = store.goals.single;
    expect(goal.completedAmount, 102);
    expect(goal.plan?.initialCompletedAmount, 102);
    expect(goal.progressHistory.single.note, 'Starting progress');
  });

  testWidgets('starting progress mode preserves decimal precision', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final store = GoalStore(repository: MemoryGoalRepository());

    await tester.pumpWidget(GoalApp(store: store));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Capture idea'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('goal-name-field')),
      'Walk five miles',
    );
    await tester.tap(find.byKey(const Key('plan-now-button')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('total-amount-field')), '5');
    await tester.tap(find.text('Starting point'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('starting-progress-field')),
      '1.25',
    );
    final advancedTile = find.ancestor(
      of: find.text('Advanced'),
      matching: find.byType(ListTile),
    );
    await tester.ensureVisible(advancedTile);
    await tester.pumpAndSettle();
    tester.widget<ListTile>(advancedTile).onTap!.call();
    await tester.pumpAndSettle();

    final progressModeSwitch = find.byKey(
      const Key('count-down-progress-switch'),
    );
    tester
        .widget<Switch>(
          find.descendant(
            of: progressModeSwitch,
            matching: find.byType(Switch),
          ),
        )
        .onChanged!
        .call(true);
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('starting-progress-field')))
          .controller
          ?.text,
      '3.75',
    );

    tester
        .widget<Switch>(
          find.descendant(
            of: progressModeSwitch,
            matching: find.byType(Switch),
          ),
        )
        .onChanged!
        .call(false);
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('starting-progress-field')))
          .controller
          ?.text,
      '1.25',
    );

    await tester.ensureVisible(find.text('Outcome'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Outcome'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('total-amount-field')), '0.3');
    await tester.ensureVisible(find.text('Starting point'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Starting point'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('starting-progress-field')),
      '0.1',
    );
    tester
        .widget<Switch>(
          find.descendant(
            of: progressModeSwitch,
            matching: find.byType(Switch),
          ),
        )
        .onChanged!
        .call(true);
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('starting-progress-field')))
          .controller
          ?.text,
      '0.2',
    );
    tester
        .widget<Switch>(
          find.descendant(
            of: progressModeSwitch,
            matching: find.byType(Switch),
          ),
        )
        .onChanged!
        .call(false);
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('starting-progress-field')))
          .controller
          ?.text,
      '0.1',
    );
  });

  testWidgets('small nonzero progress is not displayed as zero percent', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    final store = GoalStore(
      repository: MemoryGoalRepository(),
      clock: () => DateTime(2026, 8, 11, 9),
    );
    await store.load();
    await store.createPlanned(
      name: 'Read the Quran',
      amount: 604,
      unit: 'pages',
      startDate: DateTime(2026, 8, 11),
      deadline: DateTime(2027, 6, 30),
      wholeUnits: true,
      initialCompletedAmount: 2,
    );

    await tester.pumpWidget(GoalApp(store: store));
    await tester.pumpAndSettle();

    expect(find.text('0.3% · 2 of 604 pages'), findsOneWidget);
    expect(find.text('0% · 2 of 604 pages'), findsNothing);

    await tester.tap(find.text('Read the Quran'));
    await tester.pumpAndSettle();

    expect(
      find.descendant(
        of: find.byType(BottomSheet),
        matching: find.text('0.3% · 2 of 604 pages'),
      ),
      findsOneWidget,
    );
    expect(find.text('0% · 2 of 604 pages'), findsNothing);
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('desktop cards drag immediately between columns', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 800));
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    addTearDown(() => tester.binding.setSurfaceSize(null));
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    final store = GoalStore(repository: MemoryGoalRepository());
    await store.load();
    final goal = await store.createQuick('Move me');

    await tester.pumpWidget(GoalApp(store: store));
    await tester.pumpAndSettle();

    final source = find.byKey(Key('goal-drag-${goal.id}'));
    final target = find.byKey(const Key('column-planned'));
    final start = tester.getCenter(source);
    final end = tester.getCenter(target);
    await tester.dragFrom(start, end - start);
    await tester.pumpAndSettle();

    expect(store.goalById(goal.id)?.status, GoalStatus.planned);
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('wide Android boards keep touch-safe long-press dragging', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(900, 700);
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    final store = GoalStore(repository: MemoryGoalRepository());
    await store.load();
    final goal = await store.createQuick('Tablet drag');

    await tester.pumpWidget(GoalApp(store: store));
    await tester.pumpAndSettle();

    final source = find.byKey(Key('goal-drag-${goal.id}'));
    final target = find.byKey(const Key('column-planned'));
    expect(tester.widget(source), isA<LongPressDraggable<String>>());

    final gesture = await tester.startGesture(tester.getCenter(source));
    await tester.pump(kLongPressTimeout + const Duration(milliseconds: 100));
    await gesture.moveTo(tester.getCenter(target));
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();

    expect(store.goalById(goal.id)?.status, GoalStatus.planned);
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('mobile mini board map exposes every visible workflow column', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    final store = GoalStore(repository: MemoryGoalRepository());
    await store.load();
    await store.createQuick('Fresh idea');
    final activeGoal = await store.createQuick('Active work');
    await store.moveGoal(activeGoal.id, GoalStatus.active);
    final settingsRepository = MemoryAppSettingsRepository();
    final settings = AppSettingsController(settingsRepository);
    await settings.load();

    await tester.pumpWidget(
      GoalApp(store: store, settingsController: settings),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('mobile-mini-board-map')), findsOneWidget);
    for (final status in GoalStatus.visibleValues(showAbandoned: false)) {
      expect(find.byKey(Key('mini-map-lane-${status.name}')), findsOneWidget);
    }
    expect(find.byKey(const Key('mini-map-lane-abandoned')), findsNothing);
    expect(find.byKey(const Key('mobile-column-active')), findsOneWidget);
    expect(find.text('Active work'), findsOneWidget);
    expect(find.text('Fresh idea'), findsNothing);

    await tester.tap(find.byKey(const Key('mini-map-lane-ideas')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('full-board-view')), findsOneWidget);
    expect(find.byKey(const Key('full-board-column-ideas')), findsOneWidget);
    await tester.scrollUntilVisible(
      find.byKey(const Key('full-board-column-completed')),
      260,
      scrollable: find
          .descendant(
            of: find.byKey(const Key('full-board-horizontal-scroll')),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    expect(
      find.byKey(const Key('full-board-column-completed')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('open-full-board')), findsNothing);
    await tester.tap(find.byKey(const Key('close-full-board')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('mobile-previous-status')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('mobile-previous-status')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('mobile-column-ideas')), findsOneWidget);
    expect(find.text('Fresh idea'), findsOneWidget);
    expect(
      tester.widget<Text>(find.byKey(const Key('mobile-selected-status'))).data,
      'Ideas',
    );

    await settings.setShowAbandoned(true);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('mini-map-lane-abandoned')), findsOneWidget);
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('mobile long press moves a goal through the mini board map', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    final store = GoalStore(repository: MemoryGoalRepository());
    await store.load();
    final goal = await store.createQuick('Move on mobile');
    await store.moveGoal(goal.id, GoalStatus.active);

    await tester.pumpWidget(GoalApp(store: store));
    await tester.pumpAndSettle();

    final source = find.byKey(Key('goal-drag-${goal.id}'));
    final target = find.byKey(const Key('mini-map-lane-planned'));
    final gesture = await tester.startGesture(tester.getCenter(source));
    await tester.pump(kLongPressTimeout + const Duration(milliseconds: 100));
    await gesture.moveTo(tester.getCenter(target));
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();

    expect(store.goalById(goal.id)?.status, GoalStatus.planned);
    expect(find.byKey(const Key('mobile-column-planned')), findsOneWidget);
    expect(find.text('Move on mobile'), findsOneWidget);
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('compact mobile board scrolls and keeps explanations readable', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 520);
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    final store = GoalStore(repository: MemoryGoalRepository());
    await store.load();
    await store.createQuick('Compact idea one');
    await store.createQuick('Compact idea two');
    await store.createQuick('Compact idea three');

    await tester.pumpWidget(GoalApp(store: store));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('mobile-board-scroll')), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.ensureVisible(find.byKey(const Key('mobile-next-status')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('mobile-next-status')));
    await tester.pumpAndSettle();

    expect(
      tester.widget<Text>(find.byKey(const Key('mobile-selected-status'))).data,
      'Planned',
    );
    expect(find.text(GoalStatus.planned.description), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.byKey(const Key('mobile-previous-status')));
    await tester.pumpAndSettle();
    expect(
      tester.widget<Text>(find.byKey(const Key('mobile-selected-status'))).data,
      'Ideas',
    );
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('pinned mini board moves a goal after scrolling', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 700);
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    final store = GoalStore(repository: MemoryGoalRepository());
    await store.load();
    Goal? deepGoal;
    for (var index = 0; index < 8; index++) {
      final goal = await store.createQuick('Active goal ${index + 1}');
      await store.moveGoal(goal.id, GoalStatus.active);
      deepGoal = goal;
    }

    await tester.pumpWidget(GoalApp(store: store));
    await tester.pumpAndSettle();

    final source = find.byKey(Key('goal-drag-${deepGoal!.id}'));
    await tester.scrollUntilVisible(
      source,
      220,
      scrollable: find.descendant(
        of: find.byKey(const Key('mobile-board-scroll')),
        matching: find.byType(Scrollable),
      ),
    );
    await tester.pumpAndSettle();

    final map = find.byKey(const Key('mobile-mini-board-map'));
    final target = find.byKey(const Key('mini-map-lane-planned'));
    expect(map, findsOneWidget);
    expect(target, findsOneWidget);

    final gesture = await tester.startGesture(tester.getCenter(source));
    await tester.pump(kLongPressTimeout + const Duration(milliseconds: 100));
    await gesture.moveTo(tester.getCenter(target));
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();

    expect(store.goalById(deepGoal.id)?.status, GoalStatus.planned);
    expect(find.byKey(const Key('mobile-column-planned')), findsOneWidget);
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('Trash is separate, recoverable, and supports permanent delete', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final store = GoalStore(repository: MemoryGoalRepository());
    await store.load();
    final restore = await store.createQuick('Restore me');
    final remove = await store.createQuick('Remove forever');
    await store.trashGoal(restore.id);
    await store.trashGoal(remove.id);

    await tester.pumpWidget(GoalApp(store: store));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Trash'));
    await tester.pumpAndSettle();

    expect(find.text('Restore me'), findsOneWidget);
    expect(find.text('Remove forever'), findsOneWidget);

    await tester.tap(find.byKey(Key('restore-goal-${restore.id}')));
    await tester.pumpAndSettle();
    expect(find.text('Restore me'), findsNothing);
    expect(store.goalById(restore.id)?.isTrashed, isFalse);

    await tester.tap(find.byKey(Key('delete-forever-${remove.id}')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('confirm-delete-forever')), findsOneWidget);
    await tester.tap(find.byKey(const Key('confirm-delete-forever')));
    await tester.pumpAndSettle();
    expect(store.goalById(remove.id), isNull);
  });

  testWidgets('appearance menu changes between light and dark mode', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final settings = MemoryAppSettingsRepository();
    final themes = AppSettingsController(settings);
    await themes.load();

    await tester.pumpWidget(
      GoalApp(
        store: GoalStore(repository: MemoryGoalRepository()),
        settingsController: themes,
      ),
    );
    await tester.pumpAndSettle();
    expect(
      Theme.of(tester.element(find.byType(Scaffold))).brightness,
      Brightness.dark,
    );

    await tester.tap(find.byKey(const Key('appearance-menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('appearance-light')));
    await tester.pumpAndSettle();

    expect(themes.appearance, AppAppearance.light);
    expect(settings.settings.appearance, 'light');
    expect(
      Theme.of(tester.element(find.byType(Scaffold))).brightness,
      Brightness.light,
    );
  });
  testWidgets('Abandoned is hidden until enabled in Settings', (tester) async {
    await tester.binding.setSurfaceSize(const Size(2200, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repository = MemoryGoalRepository();
    final store = GoalStore(repository: repository);
    await store.load();
    final goal = await store.createQuick('Stopped goal');
    await store.moveGoal(goal.id, GoalStatus.abandoned);
    final settingsRepository = MemoryAppSettingsRepository();
    final settings = AppSettingsController(settingsRepository);
    await settings.load();

    await tester.pumpWidget(
      GoalApp(store: store, settingsController: settings),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('column-paused')), findsOneWidget);
    expect(find.text('Blocked'), findsNothing);
    expect(find.byKey(const Key('column-abandoned')), findsNothing);
    expect(store.goalById(goal.id)?.status, GoalStatus.abandoned);

    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Board and categories'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('show-abandoned-switch')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('show-abandoned-switch')));
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.text('All goals'));
    await tester.pumpAndSettle();

    expect(settings.showAbandoned, isTrue);
    expect(settingsRepository.settings.showAbandoned, isTrue);
    expect(find.byKey(const Key('column-abandoned')), findsOneWidget);
    expect(store.goalById(goal.id)?.status, GoalStatus.abandoned);

    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Board and categories'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('show-abandoned-switch')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('show-abandoned-switch')));
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.text('All goals'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('column-abandoned')), findsNothing);
    expect(store.goalById(goal.id)?.status, GoalStatus.abandoned);
  });

  testWidgets('Settings saves accent color and progress format', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repository = MemoryAppSettingsRepository();
    final settings = AppSettingsController(repository);
    await settings.load();

    await tester.pumpWidget(
      GoalApp(
        store: GoalStore(repository: MemoryGoalRepository()),
        settingsController: settings,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Appearance'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('accent-rose')));
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Board and categories'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('progress-format-amount')));
    await tester.pumpAndSettle();

    expect(settings.accentColor, AppAccentColor.rose);
    expect(settings.progressFormat, AppProgressFormat.amount);
    expect(repository.settings.accentColor, 'rose');
    expect(repository.settings.progressFormat, 'amount');
  });

  testWidgets('mobile Settings is a usable page with honest storage wording', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    final repository = MemoryAppSettingsRepository();
    final settings = AppSettingsController(repository);
    await settings.load();

    await tester.pumpWidget(
      GoalApp(
        store: GoalStore(repository: MemoryGoalRepository()),
        settingsController: settings,
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('settings-button')));
    await tester.pumpAndSettle();

    expect(find.text('Settings'), findsWidgets);
    expect(find.text('Appearance'), findsOneWidget);
    await tester.tap(find.text('Appearance'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('accent-ocean')));
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Board and categories'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('progress-format-both')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('progress-format-percentage')));
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Local data'));
    await tester.tap(find.text('Local data'));
    await tester.pumpAndSettle();

    expect(settings.accentColor, AppAccentColor.ocean);
    expect(settings.progressFormat, AppProgressFormat.percentage);
    expect(find.byKey(const Key('open-local-folder-setting')), findsOneWidget);
    expect(find.textContaining('Markdown'), findsWidgets);
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('opened goal has one progress area and direct checklist', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repository = MemoryGoalRepository();
    final store = GoalStore(repository: repository);
    await store.load();
    final goal = await store.createPlanned(
      name: 'Make lasagna',
      amount: 10,
      unit: 'servings',
      startDate: DateTime(2026, 8, 25),
      deadline: DateTime(2026, 9, 1),
      wholeUnits: true,
    );
    await store.addStep(goal.id, 'Make sauce');
    final step = store.goalById(goal.id)!.steps.single;

    await tester.pumpWidget(GoalApp(store: store));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Make lasagna'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('unified-progress-section')), findsOneWidget);
    expect(find.byKey(const Key('log-amount-progress-button')), findsOneWidget);
    expect(find.text('Goal updates'), findsNothing);
    expect(find.text('Update the whole goal'), findsNothing);
    expect(find.text('Today’s action'), findsNothing);

    final stepToggle = find.byKey(Key('step-toggle-${step.id}'));
    await tester.ensureVisible(stepToggle);
    await tester.pumpAndSettle();
    await tester.tap(stepToggle);
    await tester.pumpAndSettle();

    expect(store.goalById(goal.id)!.steps.single.isCompleted, isTrue);
    expect(
      store.goalById(goal.id)!.updates.single.kind,
      GoalUpdateKind.stepCompletion,
    );

    await tester.ensureVisible(
      find.byKey(const Key('log-amount-progress-button')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('log-amount-progress-button')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('completed-amount-field')),
      '3',
    );
    await tester.tap(find.byKey(const Key('save-progress-button')));
    await tester.pumpAndSettle();

    final saved = store.goalById(goal.id)!;
    expect(saved.steps.single.title, 'Make sauce');
    expect(saved.steps.single.isCompleted, isTrue);
    expect(saved.completedAmount, 3);
  });
}
