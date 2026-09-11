import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app/goal_store.dart';
import '../app/life_store.dart';
import '../app/theme_controller.dart';
import '../domain/goal.dart';
import '../platform/goal_notification_payload.dart';
import '../platform/goal_notification_service.dart';
import '../platform/goal_widget_service.dart';
import 'app_theme.dart';
import 'goal_board_screen.dart';
import 'goal_details_sheet.dart';
import 'life_tracker_shell.dart';

class GoalApp extends StatefulWidget {
  const GoalApp({
    super.key,
    required this.store,
    this.settingsController,
    this.notificationService,
    this.widgetService,
    this.lifeStore,
  });

  final GoalStore store;
  final AppSettingsController? settingsController;
  final GoalNotificationService? notificationService;
  final GoalWidgetService? widgetService;
  final LifeStore? lifeStore;

  @override
  State<GoalApp> createState() => _GoalAppState();
}

class _GoalAppState extends State<GoalApp> {
  static const _platform = MethodChannel('life_tracker/files');
  late final AppSettingsController _settings;
  final _navigatorKey = GlobalKey<NavigatorState>();
  final _lifeShellKey = GlobalKey<LifeTrackerShellState>();
  StreamSubscription<NotificationIntent>? _notificationSubscription;
  StreamSubscription<Uri?>? _widgetSubscription;
  Timer? _syncTimer;
  Color? _systemLightAccent;
  Color? _systemDarkAccent;

  @override
  void initState() {
    super.initState();
    _settings = widget.settingsController ?? AppSettingsController.memory();
    widget.store.addListener(_queueExternalSync);
    widget.lifeStore?.addListener(_queueExternalSync);
    _settings.addListener(_queueExternalSync);
    _settings.addListener(_applyLifeSettings);
    widget.store.automaticStartsEnabled = _settings.automaticStarts;
    final notifications = widget.notificationService;
    if (notifications != null) {
      _notificationSubscription = notifications.intents.listen(
        _handleNotificationIntent,
      );
    }
    _widgetSubscription = widget.widgetService?.clicks.listen(_handleWidgetUri);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_load());
    });
    unawaited(_loadSystemThemeColors());
  }

  Future<void> _loadSystemThemeColors() async {
    try {
      final colors = await _platform.invokeMapMethod<String, int>(
        'systemThemeColors',
      );
      if (!mounted || colors == null) return;
      setState(() {
        final light = colors['light'];
        final dark = colors['dark'];
        _systemLightAccent = light == null ? null : Color(light);
        _systemDarkAccent = dark == null ? null : Color(dark);
      });
    } on PlatformException {
      // Android versions before dynamic color support keep the approved palette.
    } on MissingPluginException {
      // Non-Android test and desktop hosts keep the approved palette.
    }
  }

  void _applyLifeSettings() => widget.lifeStore?.applySettings(_settings.data);

  Future<void> _load() async {
    await widget.store.load();
    if (widget.lifeStore != null && widget.store.goals.isEmpty) {
      await _addFirstRunGoals();
    }
    await widget.lifeStore?.load();
    await _initializeExternalSurfaces();
    await _syncExternalSurfaces();
    Uri? widgetUri;
    try {
      widgetUri = await widget.widgetService?.initialUri();
    } on Object {
      // Widgets are optional. Their native bridge must never hide the board.
    }
    if (widgetUri != null) _handleWidgetUri(widgetUri);
    final initial = widget.notificationService?.takeInitialIntent();
    if (initial != null) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _handleNotificationIntent(initial),
      );
    }
  }

  Future<void> _addFirstRunGoals() async {
    final quran = await widget.store.createPlanned(
      name: 'Memorize the Quran',
      amount: 604,
      unit: 'pages',
      startDate: widget.store.today,
      deadline: DateTime(2027, 12, 31),
      wholeUnits: true,
      initialCompletedAmount: 103,
    );
    await widget.store.setCategory(quran.id, 'Faith');
    await widget.store.addUpdate(
      quran.id,
      'Surah An-Nas through Surah Al-Ahqaf is memorized. About 501 pages remain in the standard 604-page Madinah mushaf.',
    );

    final business = await widget.store.createQuick(
      'Build the business to about USD 5,000 per month',
    );
    await widget.store.setCategory(business.id, 'Finances');
    await widget.store.addUpdate(
      business.id,
      'Current progress: 1 client. At about USD 299 per client, the target is about 17 clients total.',
    );

    final curriculum = await widget.store.createQuick(
      'Finish the duksi curriculum for three groups',
    );
    await widget.store.setCategory(curriculum.id, 'Faith');
    await widget.store.addSteps(curriculum.id, const [
      'Finish the first group curriculum',
      'Finish the second group curriculum',
      'Finish the third group curriculum',
    ]);

    final students = await widget.store.createQuick(
      'Bring 10 people to the duksi',
    );
    await widget.store.setCategory(students.id, 'Faith');

    final college = await widget.store.createQuick(
      'Finish the WGU computer science degree',
    );
    await widget.store.setCategory(college.id, 'Mind');
    await widget.store.addUpdate(
      college.id,
      'First create a careful transfer-course and fastest-finish plan before adding course tasks.',
    );

    final islamicStudies = await widget.store.createQuick(
      'Learn and memorize Nasikh and Mansukh',
    );
    await widget.store.setCategory(islamicStudies.id, 'Faith');
  }

  Future<void> _initializeExternalSurfaces() async {
    try {
      await widget.notificationService?.initialize();
    } on Object {
      // Notifications are optional. Keep the local board usable if unavailable.
    }
    try {
      await widget.widgetService?.initialize();
    } on Object {
      // Home-screen widgets are optional and must not block app startup.
    }
  }

  void _queueExternalSync() {
    _syncTimer?.cancel();
    _syncTimer = Timer(
      const Duration(milliseconds: 450),
      _syncExternalSurfaces,
    );
  }

  Future<void> _syncExternalSurfaces() async {
    try {
      await widget.widgetService?.sync(
        widget.store.goals,
        widget.store,
        widget.lifeStore,
        _settings,
      );
    } on Object {
      // Keep board edits working even when the optional widget bridge fails.
    }
    try {
      await widget.notificationService?.sync(
        widget.store.goals,
        _settings.data,
      );
    } on Object {
      // Keep board edits working even when notifications are unavailable.
    }
  }

  void _handleWidgetUri(Uri? uri) {
    if (uri?.scheme != 'goaltracker') return;
    if (uri?.host == 'today') {
      _lifeShellKey.currentState?.openToday();
      return;
    }
    if (uri?.host == 'calendar') {
      _lifeShellKey.currentState?.openCalendar();
      return;
    }
    final goalId = uri?.queryParameters['id'];
    final context = _navigatorKey.currentContext;
    if (goalId == null || context == null || !context.mounted) return;
    if (uri?.host == 'task') {
      final lifeStore = widget.lifeStore;
      if (lifeStore == null) return;
      final task = lifeStore.tasks
          .where((item) => item.id == goalId)
          .firstOrNull;
      if (task != null) {
        showTaskEditor(context, lifeStore, widget.store, task: task);
      }
      return;
    }
    if (uri?.host != 'goal') return;
    showGoalDetailsSheet(
      context,
      widget.store,
      goalId,
      showAbandoned: _settings.showAbandoned,
      progressFormat: _settings.progressFormat,
      settings: _settings,
    );
  }

  Future<void> _handleNotificationIntent(NotificationIntent intent) async {
    if (intent.payload.type == GoalNotificationType.endOfDayReview) {
      final context = _navigatorKey.currentContext;
      if (context != null && context.mounted) {
        await _showEndOfDayReview(context);
      }
      return;
    }
    final goalId = intent.goalId;
    if (goalId == null) return;
    final goal = widget.store.goalById(goalId);
    if (goal == null) return;
    final occurrenceId = intent.occurrenceIdAt(DateTime.now());
    switch ((intent.payload.type, intent.action)) {
      case (
        GoalNotificationType.dailyActionReminder,
        GoalNotificationActions.done,
      ):
        await widget.store.completeTodayAction(goal.id);
        return;
      case (
        GoalNotificationType.dailyActionReminder,
        GoalNotificationActions.notDone,
      ):
        await widget.store.recordMissedReminder(
          goal.id,
          occurrenceId: occurrenceId,
        );
        return;
      case (
        GoalNotificationType.goalCompletionCheckIn,
        GoalNotificationActions.done,
      ):
        await widget.store.moveGoal(goal.id, GoalStatus.completed);
        return;
      case (
        GoalNotificationType.goalCompletionCheckIn,
        GoalNotificationActions.notYet,
      ):
        final context = _navigatorKey.currentContext;
        if (context != null && context.mounted) {
          await _showDelayChoices(context, goal.id);
        }
        return;
      case (
        GoalNotificationType.automaticStart,
        GoalNotificationActions.beginToday,
      ):
        await widget.store.beginToday(goal.id);
        final context = _navigatorKey.currentContext;
        if (context != null && context.mounted) {
          await showGoalDetailsSheet(
            context,
            widget.store,
            goal.id,
            showAbandoned: _settings.showAbandoned,
            progressFormat: _settings.progressFormat,
            settings: _settings,
          );
        }
        return;
      case (
        GoalNotificationType.automaticStart,
        GoalNotificationActions.undoStart,
      ):
        await widget.store.undoAutomaticStart(goal.id);
        return;
    }
    final context = _navigatorKey.currentContext;
    if (context == null || !context.mounted) return;
    if (intent.action == GoalNotificationActions.delay) {
      if (intent.payload.type == GoalNotificationType.automaticStart) {
        await _showStartDelayChoices(context, goal.id);
      } else {
        await _showDelayChoices(context, goal.id);
      }
      return;
    }
    await showGoalDetailsSheet(
      context,
      widget.store,
      goal.id,
      showAbandoned: _settings.showAbandoned,
      progressFormat: _settings.progressFormat,
      settings: _settings,
    );
  }

  Future<void> _showDelayChoices(BuildContext context, String goalId) async {
    final now = DateTime.now();
    final choice = await showModalBottomSheet<DateTime>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'When should I remind you again?',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              ListTile(
                leading: const Icon(Icons.timer_outlined),
                title: const Text('In 30 minutes'),
                onTap: () => Navigator.pop(
                  context,
                  now.add(const Duration(minutes: 30)),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.schedule_outlined),
                title: const Text('In 1 hour'),
                onTap: () =>
                    Navigator.pop(context, now.add(const Duration(hours: 1))),
              ),
              ListTile(
                leading: const Icon(Icons.wb_sunny_outlined),
                title: const Text('Tomorrow at the same time'),
                onTap: () =>
                    Navigator.pop(context, now.add(const Duration(days: 1))),
              ),
              ListTile(
                leading: const Icon(Icons.edit_calendar_outlined),
                title: const Text('Choose a time'),
                onTap: () async {
                  final time = await showTimePicker(
                    context: context,
                    initialTime: TimeOfDay.fromDateTime(
                      now.add(const Duration(hours: 1)),
                    ),
                  );
                  if (time == null || !context.mounted) return;
                  var selected = DateTime(
                    now.year,
                    now.month,
                    now.day,
                    time.hour,
                    time.minute,
                  );
                  if (!selected.isAfter(now)) {
                    selected = selected.add(const Duration(days: 1));
                  }
                  if (context.mounted) Navigator.pop(context, selected);
                },
              ),
            ],
          ),
        ),
      ),
    );
    if (choice != null) await widget.store.snoozeReminder(goalId, choice);
  }

  Future<void> _showStartDelayChoices(
    BuildContext context,
    String goalId,
  ) async {
    final now = DateTime.now();
    final choice = await showModalBottomSheet<DateTime>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text('Start tomorrow'),
              onTap: () =>
                  Navigator.pop(context, now.add(const Duration(days: 1))),
            ),
            ListTile(
              title: const Text('Start next week'),
              onTap: () =>
                  Navigator.pop(context, now.add(const Duration(days: 7))),
            ),
            ListTile(
              title: const Text('Choose a date'),
              onTap: () async {
                final date = await showDatePicker(
                  context: context,
                  firstDate: now.add(const Duration(days: 1)),
                  lastDate: DateTime(now.year + 10),
                );
                if (date != null && context.mounted) {
                  Navigator.pop(context, date);
                }
              },
            ),
          ],
        ),
      ),
    );
    if (choice != null) await widget.store.delayStart(goalId, choice);
  }

  Future<void> _showEndOfDayReview(BuildContext context) async {
    final goals = widget.store.goals
        .where(
          (goal) =>
              !goal.isTrashed &&
              goal.status != GoalStatus.completed &&
              goal.status != GoalStatus.abandoned &&
              goal.completionFor(widget.store.today) == null,
        )
        .toList(growable: false);
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height * .68,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'End-of-day review',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  if (goals.isEmpty)
                    const ListTile(
                      leading: Icon(Icons.check_circle_outline_rounded),
                      title: Text('All tracked actions are up to date.'),
                    )
                  else
                    for (final goal in goals)
                      ListTile(
                        leading: const Icon(
                          Icons.radio_button_unchecked_rounded,
                        ),
                        title: Text(goal.name),
                        subtitle: Text(
                          goal.status == GoalStatus.ideas
                              ? 'To Do'
                              : goal.status.label,
                        ),
                        onTap: () {
                          Navigator.pop(context);
                          final appContext = _navigatorKey.currentContext;
                          if (appContext != null && appContext.mounted) {
                            showGoalDetailsSheet(
                              appContext,
                              widget.store,
                              goal.id,
                              showAbandoned: _settings.showAbandoned,
                              progressFormat: _settings.progressFormat,
                              settings: _settings,
                            );
                          }
                        },
                      ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _syncTimer?.cancel();
    _notificationSubscription?.cancel();
    _widgetSubscription?.cancel();
    widget.store.removeListener(_queueExternalSync);
    widget.lifeStore?.removeListener(_queueExternalSync);
    _settings.removeListener(_queueExternalSync);
    _settings.removeListener(_applyLifeSettings);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _settings,
      builder: (context, _) {
        final useSystem = _settings.useSystemThemeColors;
        return MaterialApp(
          navigatorKey: _navigatorKey,
          debugShowCheckedModeBanner: false,
          title: 'Life Tracker',
          theme: buildAppTheme(
            accentColor: useSystem
                ? _systemLightAccent ?? AppColors.coral
                : AppColors.coral,
          ),
          darkTheme: buildAppTheme(
            brightness: Brightness.dark,
            accentColor: useSystem
                ? _systemDarkAccent ?? AppColors.coral
                : AppColors.coral,
          ),
          themeMode: _settings.themeMode,
          home: widget.lifeStore == null
              ? GoalBoardScreen(
                  store: widget.store,
                  settings: _settings,
                  notificationService: widget.notificationService,
                )
              : LifeTrackerShell(
                  key: _lifeShellKey,
                  goalStore: widget.store,
                  lifeStore: widget.lifeStore!,
                  settings: _settings,
                  notificationService: widget.notificationService,
                ),
        );
      },
    );
  }
}
