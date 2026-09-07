import '../data/app_settings_repository.dart';
import '../domain/goal.dart';
import 'goal_notification_payload.dart';

enum GoalNotificationRepeat { none, daily, weekly }

class GoalNotificationSchedule {
  const GoalNotificationSchedule({
    required this.id,
    required this.title,
    required this.body,
    required this.when,
    required this.payload,
    this.repeat = GoalNotificationRepeat.none,
  });

  final int id;
  final String title;
  final String body;
  final DateTime when;
  final GoalNotificationPayload payload;
  final GoalNotificationRepeat repeat;
}

List<GoalNotificationSchedule> buildGoalNotificationSchedule({
  required Iterable<Goal> goals,
  required AppSettingsData settings,
  required DateTime now,
}) {
  if (!settings.notificationsEnabled) return const [];

  final activeGoals = goals
      .where(
        (goal) =>
            !goal.isTrashed &&
            goal.status != GoalStatus.completed &&
            goal.status != GoalStatus.abandoned,
      )
      .toList(growable: false);
  final result = <GoalNotificationSchedule>[];

  if (settings.automaticStarts) {
    for (final goal in activeGoals.where((goal) => goal.showStartNotice)) {
      final plan = goal.plan;
      if (plan == null) continue;
      final when = _outsideQuietHours(
        now.add(const Duration(seconds: 5)),
        settings,
      );
      result.add(
        _schedule(
          key: 'automatic-start/${goal.id}/${_dateKey(plan.startDate)}',
          title: '${goal.name} starts today',
          body:
              'Begin today’s action, choose a later start, or undo the start.',
          when: when,
          payload: GoalNotificationPayload(
            type: GoalNotificationType.automaticStart,
            occurrenceId: 'automatic-start-${_dateKey(plan.startDate)}',
            goalId: goal.id,
          ),
        ),
      );
    }
  }

  for (final goal in activeGoals) {
    final reminder = goal.reminder;
    if (reminder?.enabled != true) continue;
    result.addAll(_goalSchedules(goal, reminder!, settings, now));
  }

  if (settings.endOfDayReview) {
    final when = _nextDailyOccurrence(
      now: now,
      hour: settings.endOfDayHour,
      minute: settings.endOfDayMinute,
      notBefore: now,
      settings: settings,
    );
    final unfinished = activeGoals
        .where((goal) => goal.completionFor(now) == null)
        .map((goal) => goal.name)
        .take(3)
        .toList(growable: false);
    final body = unfinished.isEmpty
        ? 'All tracked actions are up to date.'
        : 'Still open: ${unfinished.join(', ')}.';
    result.add(
      _schedule(
        key: 'end-of-day/${when.hour}:${when.minute}/$body',
        title: 'End-of-day review',
        body: body,
        when: when,
        repeat: GoalNotificationRepeat.daily,
        payload: const GoalNotificationPayload(
          type: GoalNotificationType.endOfDayReview,
          occurrenceId: 'end-of-day-daily',
        ),
      ),
    );
  }

  return List.unmodifiable(result);
}

List<GoalNotificationSchedule> _goalSchedules(
  Goal goal,
  GoalReminder reminder,
  AppSettingsData settings,
  DateTime now,
) {
  final type = reminder.purpose == ReminderPurpose.dailyAction
      ? GoalNotificationType.dailyActionReminder
      : GoalNotificationType.goalCompletionCheckIn;
  final notBefore = reminder.snoozedUntil?.isAfter(now) == true
      ? reminder.snoozedUntil!
      : now;
  final result = <GoalNotificationSchedule>[];

  void add({
    required String slot,
    required DateTime when,
    GoalNotificationRepeat repeat = GoalNotificationRepeat.none,
  }) {
    final payload = GoalNotificationPayload(
      type: type,
      occurrenceId: '${reminder.id}:$slot',
      goalId: goal.id,
      reminderId: reminder.id,
    );
    result.add(
      _schedule(
        key:
            '${type.name}/${goal.id}/${reminder.id}/$slot/'
            '${when.weekday}/${when.hour}:${when.minute}/${reminder.message}',
        title: goal.name,
        body: reminder.message,
        when: when,
        repeat: repeat,
        payload: payload,
      ),
    );
  }

  final snoozed = reminder.snoozedUntil;
  if (snoozed != null && snoozed.isAfter(now)) {
    add(
      slot: 'snooze-${_dateKey(snoozed)}',
      when: _outsideQuietHours(snoozed, settings),
    );
  }

  if (reminder.frequency == ReminderFrequency.once) {
    final once = reminder.onceAt;
    if (once != null && once.isAfter(notBefore)) {
      final adjusted = _outsideQuietHours(once, settings);
      if (!result.any((item) => item.when == adjusted)) {
        add(slot: 'once-${_dateKey(once)}', when: adjusted);
      }
    }
    return result;
  }

  if (reminder.frequency == ReminderFrequency.daily) {
    add(
      slot: 'daily',
      when: _nextDailyOccurrence(
        now: now,
        hour: reminder.hour,
        minute: reminder.minute,
        notBefore: notBefore,
        settings: settings,
      ),
      repeat: GoalNotificationRepeat.daily,
    );
    return result;
  }

  final weekdays = switch (reminder.frequency) {
    ReminderFrequency.weekdays => const {1, 2, 3, 4, 5},
    ReminderFrequency.weekly ||
    ReminderFrequency.customDays => reminder.weekdays,
    ReminderFrequency.daily || ReminderFrequency.once => const <int>{},
  };
  for (final weekday in weekdays.toList()..sort()) {
    add(
      slot: 'weekday-$weekday',
      when: _nextWeeklyOccurrence(
        now: now,
        weekday: weekday,
        hour: reminder.hour,
        minute: reminder.minute,
        notBefore: notBefore,
        settings: settings,
      ),
      repeat: GoalNotificationRepeat.weekly,
    );
  }
  return result;
}

GoalNotificationSchedule _schedule({
  required String key,
  required String title,
  required String body,
  required DateTime when,
  required GoalNotificationPayload payload,
  GoalNotificationRepeat repeat = GoalNotificationRepeat.none,
}) => GoalNotificationSchedule(
  id: stableNotificationId('goal-tracker-v0.11/$key'),
  title: title,
  body: body,
  when: when,
  payload: payload,
  repeat: repeat,
);

DateTime _nextDailyOccurrence({
  required DateTime now,
  required int hour,
  required int minute,
  required DateTime notBefore,
  required AppSettingsData settings,
}) {
  var candidate = DateTime(now.year, now.month, now.day, hour, minute);
  while (!candidate.isAfter(notBefore)) {
    candidate = candidate.add(const Duration(days: 1));
  }
  return _outsideQuietHours(candidate, settings);
}

DateTime _nextWeeklyOccurrence({
  required DateTime now,
  required int weekday,
  required int hour,
  required int minute,
  required DateTime notBefore,
  required AppSettingsData settings,
}) {
  var daysAhead = (weekday - now.weekday) % 7;
  var candidate = DateTime(
    now.year,
    now.month,
    now.day + daysAhead,
    hour,
    minute,
  );
  while (!candidate.isAfter(notBefore)) {
    candidate = candidate.add(const Duration(days: 7));
  }
  return _outsideQuietHours(candidate, settings);
}

DateTime _outsideQuietHours(DateTime value, AppSettingsData settings) {
  if (!settings.quietHoursEnabled) return value;
  final minute = value.hour * 60 + value.minute;
  final start = settings.quietStartHour * 60 + settings.quietStartMinute;
  final end = settings.quietEndHour * 60 + settings.quietEndMinute;
  final inside = start <= end
      ? minute >= start && minute < end
      : minute >= start || minute < end;
  if (!inside) return value;
  final nextDay = start > end && minute >= start;
  final date = nextDay ? value.add(const Duration(days: 1)) : value;
  return DateTime(
    date.year,
    date.month,
    date.day,
    settings.quietEndHour,
    settings.quietEndMinute,
  );
}

String notificationActionOccurrenceId(
  GoalNotificationPayload payload,
  DateTime handledAt,
) => '${payload.occurrenceId}:${_dateKey(handledAt)}';

/// Windows does not support calendar recurrence. Keep a bounded rolling set of
/// one-time notifications that is refreshed whenever the app opens or data
/// changes.
List<GoalNotificationSchedule> expandWindowsNotificationSchedules(
  Iterable<GoalNotificationSchedule> schedules, {
  int dailyOccurrences = 21,
  int weeklyOccurrences = 8,
}) {
  final expanded = <GoalNotificationSchedule>[];
  for (final schedule in schedules) {
    final count = switch (schedule.repeat) {
      GoalNotificationRepeat.none => 1,
      GoalNotificationRepeat.daily => dailyOccurrences,
      GoalNotificationRepeat.weekly => weeklyOccurrences,
    };
    final interval = switch (schedule.repeat) {
      GoalNotificationRepeat.none => Duration.zero,
      GoalNotificationRepeat.daily => const Duration(days: 1),
      GoalNotificationRepeat.weekly => const Duration(days: 7),
    };
    for (var index = 0; index < count; index++) {
      final when = schedule.when.add(interval * index);
      if (schedule.repeat == GoalNotificationRepeat.none) {
        expanded.add(schedule);
        continue;
      }
      final occurrence = _dateKey(when);
      expanded.add(
        GoalNotificationSchedule(
          id: stableNotificationId(
            'goal-tracker-windows/${schedule.id}/$occurrence',
          ),
          title: schedule.title,
          body: schedule.body,
          when: when,
          payload: GoalNotificationPayload(
            type: schedule.payload.type,
            occurrenceId: '${schedule.payload.occurrenceId}:$occurrence',
            goalId: schedule.payload.goalId,
            reminderId: schedule.payload.reminderId,
          ),
        ),
      );
    }
  }
  return List.unmodifiable(expanded);
}

String _dateKey(DateTime value) =>
    '${value.year.toString().padLeft(4, '0')}-'
    '${value.month.toString().padLeft(2, '0')}-'
    '${value.day.toString().padLeft(2, '0')}-'
    '${value.hour.toString().padLeft(2, '0')}'
    '${value.minute.toString().padLeft(2, '0')}';
