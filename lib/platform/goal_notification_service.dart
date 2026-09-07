import 'dart:async';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as timezone_data;
import 'package:timezone/timezone.dart' as timezone;

import '../app/goal_store.dart';
import '../data/app_settings_repository.dart';
import '../data/goal_repository.dart';
import '../domain/goal.dart';
import 'goal_notification_payload.dart';
import 'goal_notification_reconciler.dart';
import 'goal_notification_schedule.dart';

const _testNotificationId = 1999999000;
const _scheduledTestNotificationId = 1999999001;

@pragma('vm:entry-point')
Future<void> notificationTapBackground(NotificationResponse response) async {
  final payload = GoalNotificationPayload.tryDecode(response.payload);
  final goalId = payload?.goalId;
  if (payload == null || goalId == null) return;

  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();
  final repository = await MarkdownGoalRepository.createDefault();
  final store = GoalStore(repository: repository);
  await store.load();
  await _applyBackgroundAction(
    store,
    payload,
    response.actionId ?? GoalNotificationActions.open,
  );
}

Future<void> _applyBackgroundAction(
  GoalStore store,
  GoalNotificationPayload payload,
  String action,
) async {
  final goalId = payload.goalId;
  if (goalId == null) return;
  final occurrenceId = notificationActionOccurrenceId(payload, DateTime.now());

  switch ((payload.type, action)) {
    case (
      GoalNotificationType.dailyActionReminder,
      GoalNotificationActions.done,
    ):
      await store.completeTodayAction(goalId);
    case (
      GoalNotificationType.dailyActionReminder,
      GoalNotificationActions.notDone,
    ):
      await store.recordMissedReminder(goalId, occurrenceId: occurrenceId);
    case (
      GoalNotificationType.goalCompletionCheckIn,
      GoalNotificationActions.done,
    ):
      await store.moveGoal(goalId, GoalStatus.completed);
    case (
      GoalNotificationType.goalCompletionCheckIn,
      GoalNotificationActions.notYet,
    ):
      return;
    case (
      GoalNotificationType.automaticStart,
      GoalNotificationActions.beginToday,
    ):
      await store.beginToday(goalId);
    case (
      GoalNotificationType.automaticStart,
      GoalNotificationActions.undoStart,
    ):
      await store.undoAutomaticStart(goalId);
    default:
      return;
  }
}

class NotificationIntent {
  const NotificationIntent({required this.payload, required this.action});

  final GoalNotificationPayload payload;
  final String action;

  String? get goalId => payload.goalId;

  String occurrenceIdAt(DateTime handledAt) =>
      notificationActionOccurrenceId(payload, handledAt);
}

class NotificationStatus {
  const NotificationStatus({
    required this.available,
    required this.allowed,
    required this.exactTimingAvailable,
    required this.pendingCount,
    this.message,
  });

  final bool available;
  final bool allowed;
  final bool exactTimingAvailable;
  final int pendingCount;
  final String? message;
}

class GoalNotificationService implements GoalNotificationAdapter {
  GoalNotificationService();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  final StreamController<NotificationIntent> _intents =
      StreamController<NotificationIntent>.broadcast();
  bool _initialized = false;
  bool _permissionsRequested = false;
  NotificationIntent? _initialIntent;
  Future<void> _syncTail = Future.value();
  AndroidScheduleMode _androidScheduleMode =
      AndroidScheduleMode.inexactAllowWhileIdle;
  final GoalNotificationReconciler _reconciler =
      const GoalNotificationReconciler();
  Set<int> _knownDesiredIds = const {};
  bool _completedInitialSync = false;

  Stream<NotificationIntent> get intents => _intents.stream;

  NotificationIntent? takeInitialIntent() {
    final intent = _initialIntent;
    _initialIntent = null;
    return intent;
  }

  Future<void> initialize() async {
    if (_initialized) return;
    timezone_data.initializeTimeZones();
    try {
      final current = await FlutterTimezone.getLocalTimezone();
      timezone.setLocalLocation(timezone.getLocation(current.identifier));
    } on Object {
      // UTC is a safe fallback if the operating system returns an unknown zone.
    }

    const initialization = InitializationSettings(
      android: AndroidInitializationSettings('ic_stat_goal_tracker'),
      windows: WindowsInitializationSettings(
        appName: 'Goal Tracker',
        appUserModelId: 'LocalFirst.GoalTracker',
        guid: '8a91dcba-e5d8-42a3-aefb-6c6ae2bb5998',
      ),
    );
    await _plugin.initialize(
      settings: initialization,
      onDidReceiveNotificationResponse: _handleResponse,
      onDidReceiveBackgroundNotificationResponse: notificationTapBackground,
    );
    await _refreshScheduleMode();

    final launch = await _plugin.getNotificationAppLaunchDetails();
    final response = launch?.notificationResponse;
    final payload = GoalNotificationPayload.tryDecode(response?.payload);
    if (launch?.didNotificationLaunchApp == true && payload != null) {
      _initialIntent = NotificationIntent(
        payload: payload,
        action: response?.actionId ?? GoalNotificationActions.open,
      );
    }
    _initialized = true;
  }

  Future<void> _refreshScheduleMode() async {
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    try {
      final exact = await android?.canScheduleExactNotifications();
      _androidScheduleMode = exact == true
          ? AndroidScheduleMode.exactAllowWhileIdle
          : AndroidScheduleMode.inexactAllowWhileIdle;
    } on Object {
      _androidScheduleMode = AndroidScheduleMode.inexactAllowWhileIdle;
    }
  }

  void _handleResponse(NotificationResponse response) {
    final payload = GoalNotificationPayload.tryDecode(response.payload);
    if (payload == null) return;
    _intents.add(
      NotificationIntent(
        payload: payload,
        action: response.actionId ?? GoalNotificationActions.open,
      ),
    );
  }

  Future<bool> requestPermissions({bool force = false}) async {
    await initialize();
    if (_permissionsRequested && !force) {
      return (await notificationStatus()).allowed;
    }
    _permissionsRequested = true;
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    final result = await android?.requestNotificationsPermission();
    return result ?? true;
  }

  Future<NotificationStatus> notificationStatus() async {
    try {
      await initialize();
      final android = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      final allowed = await android?.areNotificationsEnabled() ?? true;
      final exact = await android?.canScheduleExactNotifications() ?? true;
      final pending = await _plugin.pendingNotificationRequests();
      return NotificationStatus(
        available: true,
        allowed: allowed,
        exactTimingAvailable: exact,
        pendingCount: pending.where(_isOwnedRequest).length,
        message: allowed
            ? null
            : 'Notifications are blocked in the device settings.',
      );
    } on Object catch (error) {
      return NotificationStatus(
        available: false,
        allowed: false,
        exactTimingAvailable: false,
        pendingCount: 0,
        message: 'Notifications are unavailable: $error',
      );
    }
  }

  Future<bool> openNotificationSettings() async {
    await initialize();
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    return await android?.openAppNotificationSettings() ?? false;
  }

  Future<void> sendTestNotification() async {
    await initialize();
    final allowed = await requestPermissions(force: true);
    if (!allowed) {
      throw StateError('Notifications are blocked in the device settings.');
    }
    const payload = GoalNotificationPayload(
      type: GoalNotificationType.test,
      occurrenceId: 'immediate-test',
    );
    await _plugin.show(
      id: _testNotificationId,
      title: 'Goal Tracker test',
      body: 'Notifications, sound, and vibration are working.',
      notificationDetails: _details(GoalNotificationType.test),
      payload: payload.encode(),
    );
  }

  Future<void> scheduleTestNotification({
    Duration delay = const Duration(minutes: 1),
  }) async {
    await initialize();
    final allowed = await requestPermissions(force: true);
    if (!allowed) {
      throw StateError('Notifications are blocked in the device settings.');
    }
    final when = DateTime.now().add(delay);
    final payload = GoalNotificationPayload(
      type: GoalNotificationType.test,
      occurrenceId: 'scheduled-test-${when.millisecondsSinceEpoch}',
    );
    await _plugin.cancel(id: _scheduledTestNotificationId);
    await _zonedSchedule(
      GoalNotificationSchedule(
        id: _scheduledTestNotificationId,
        title: 'Scheduled Goal Tracker test',
        body: 'Background reminder delivery is working.',
        when: when,
        payload: payload,
      ),
    );
  }

  Future<void> sync(Iterable<Goal> goals, AppSettingsData settings) {
    final snapshot = goals.toList(growable: false);
    final current = _syncTail.then(
      (_) => _syncNow(snapshot, settings),
      onError: (_) => _syncNow(snapshot, settings),
    );
    _syncTail = current.catchError((Object _) {});
    return current;
  }

  Future<void> _syncNow(List<Goal> goals, AppSettingsData settings) async {
    await initialize();
    final plannedSchedules = buildGoalNotificationSchedule(
      goals: goals,
      settings: settings,
      now: DateTime.now(),
    );
    final schedules = defaultTargetPlatform == TargetPlatform.windows
        ? expandWindowsNotificationSchedules(plannedSchedules)
        : plannedSchedules;
    final desiredIds = schedules.map((item) => item.id).toSet();
    if (schedules.isNotEmpty) {
      var allowed = (await notificationStatus()).allowed;
      final newlyAdded = desiredIds.difference(_knownDesiredIds);
      if (!allowed && _completedInitialSync && newlyAdded.isNotEmpty) {
        allowed = await requestPermissions(force: true);
      }
      _knownDesiredIds = desiredIds;
      _completedInitialSync = true;
      if (!allowed) return;
    } else {
      _knownDesiredIds = desiredIds;
      _completedInitialSync = true;
    }

    await _reconciler.reconcile(adapter: this, desiredSchedules: schedules);
  }

  bool _isOwnedRequest(PendingNotificationRequest request) {
    final payload = request.payload;
    return GoalNotificationPayload.tryDecode(payload) != null ||
        payload == 'review' ||
        payload?.startsWith('goal:') == true;
  }

  bool _isManagedRequest(PendingNotificationRequest request) {
    final typed = GoalNotificationPayload.tryDecode(request.payload);
    if (typed != null) return typed.type != GoalNotificationType.test;
    return request.payload == 'review' ||
        request.payload?.startsWith('goal:') == true;
  }

  @override
  Future<List<PendingGoalNotification>> pendingGoalNotifications() async {
    final pending = await _plugin.pendingNotificationRequests();
    return pending
        .map(
          (request) => PendingGoalNotification(
            id: request.id,
            payload: request.payload,
            managed: _isManagedRequest(request),
          ),
        )
        .toList(growable: false);
  }

  @override
  Future<void> cancelGoalNotification(int id) => _plugin.cancel(id: id);

  @override
  Future<void> scheduleGoalNotification(GoalNotificationSchedule schedule) =>
      _zonedSchedule(schedule);

  Future<void> _zonedSchedule(GoalNotificationSchedule schedule) async {
    final matchComponents = switch (schedule.repeat) {
      GoalNotificationRepeat.none => null,
      GoalNotificationRepeat.daily => DateTimeComponents.time,
      GoalNotificationRepeat.weekly => DateTimeComponents.dayOfWeekAndTime,
    };
    Future<void> submit(AndroidScheduleMode mode) => _plugin.zonedSchedule(
      id: schedule.id,
      title: schedule.title,
      body: schedule.body,
      scheduledDate: timezone.TZDateTime.from(schedule.when, timezone.local),
      notificationDetails: _details(schedule.payload.type),
      androidScheduleMode: mode,
      payload: schedule.payload.encode(),
      matchDateTimeComponents: matchComponents,
    );

    try {
      await submit(_androidScheduleMode);
    } on Object {
      if (_androidScheduleMode == AndroidScheduleMode.inexactAllowWhileIdle) {
        rethrow;
      }
      _androidScheduleMode = AndroidScheduleMode.inexactAllowWhileIdle;
      await submit(_androidScheduleMode);
    }
  }

  NotificationDetails _details(GoalNotificationType type) {
    final List<AndroidNotificationAction>? androidActions = switch (type) {
      GoalNotificationType.dailyActionReminder => const [
        AndroidNotificationAction(
          GoalNotificationActions.done,
          'Done',
          showsUserInterface: false,
          semanticAction: SemanticAction.markAsRead,
        ),
        AndroidNotificationAction(
          GoalNotificationActions.notDone,
          'Not done',
          showsUserInterface: false,
        ),
        AndroidNotificationAction(
          GoalNotificationActions.delay,
          'Delay',
          showsUserInterface: true,
        ),
      ],
      GoalNotificationType.goalCompletionCheckIn => const [
        AndroidNotificationAction(
          GoalNotificationActions.done,
          'Done',
          showsUserInterface: false,
          semanticAction: SemanticAction.markAsRead,
        ),
        AndroidNotificationAction(
          GoalNotificationActions.notYet,
          'Not yet',
          showsUserInterface: true,
        ),
      ],
      GoalNotificationType.automaticStart => const [
        AndroidNotificationAction(
          GoalNotificationActions.beginToday,
          'Begin today’s action',
          showsUserInterface: true,
        ),
        AndroidNotificationAction(
          GoalNotificationActions.delay,
          'Delay',
          showsUserInterface: true,
        ),
        AndroidNotificationAction(
          GoalNotificationActions.undoStart,
          'Undo',
          showsUserInterface: false,
        ),
      ],
      GoalNotificationType.endOfDayReview || GoalNotificationType.test => null,
    };
    final List<WindowsAction> windowsActions = switch (type) {
      GoalNotificationType.dailyActionReminder => const [
        WindowsAction(
          content: 'Done',
          arguments: GoalNotificationActions.done,
          buttonStyle: WindowsButtonStyle.success,
        ),
        WindowsAction(
          content: 'Not done',
          arguments: GoalNotificationActions.notDone,
        ),
        WindowsAction(
          content: 'Delay',
          arguments: GoalNotificationActions.delay,
        ),
      ],
      GoalNotificationType.goalCompletionCheckIn => const [
        WindowsAction(
          content: 'Done',
          arguments: GoalNotificationActions.done,
          buttonStyle: WindowsButtonStyle.success,
        ),
        WindowsAction(
          content: 'Not yet',
          arguments: GoalNotificationActions.notYet,
        ),
      ],
      GoalNotificationType.automaticStart => const [
        WindowsAction(
          content: 'Begin today’s action',
          arguments: GoalNotificationActions.beginToday,
          buttonStyle: WindowsButtonStyle.success,
        ),
        WindowsAction(
          content: 'Delay',
          arguments: GoalNotificationActions.delay,
        ),
        WindowsAction(
          content: 'Undo',
          arguments: GoalNotificationActions.undoStart,
        ),
      ],
      GoalNotificationType.endOfDayReview ||
      GoalNotificationType.test => const [],
    };

    return NotificationDetails(
      android: AndroidNotificationDetails(
        type == GoalNotificationType.endOfDayReview
            ? 'goal_review_v2'
            : 'goal_reminders_v2',
        type == GoalNotificationType.endOfDayReview
            ? 'End-of-day review'
            : 'Goal reminders',
        channelDescription: type == GoalNotificationType.endOfDayReview
            ? 'Optional daily review of unfinished actions.'
            : 'Goal reminders and check-ins with quick actions.',
        icon: 'ic_stat_goal_tracker',
        importance: Importance.high,
        priority: Priority.high,
        category: AndroidNotificationCategory.reminder,
        playSound: true,
        enableVibration: true,
        visibility: NotificationVisibility.private,
        actions: androidActions,
      ),
      windows: WindowsNotificationDetails(actions: windowsActions),
    );
  }

  Future<void> dispose() async {
    await _intents.close();
  }
}
