import 'package:flutter_test/flutter_test.dart';
import 'package:goal_tracker_poc/data/app_settings_repository.dart';
import 'package:goal_tracker_poc/domain/goal.dart';
import 'package:goal_tracker_poc/platform/goal_notification_payload.dart';
import 'package:goal_tracker_poc/platform/goal_notification_schedule.dart';

void main() {
  final now = DateTime(2026, 8, 25, 12);

  Goal goalWith(GoalReminder reminder) => Goal(
    id: 'goal-1',
    name: 'Finish the course',
    status: GoalStatus.active,
    createdAt: now,
    updatedAt: now,
    reminder: reminder,
  );

  test('daily reminders use one native daily repeating schedule', () {
    final schedules = buildGoalNotificationSchedule(
      goals: [
        goalWith(
          const GoalReminder(
            id: 'reminder-1',
            message: 'Do the next lesson',
            frequency: ReminderFrequency.daily,
            hour: 18,
            minute: 30,
          ),
        ),
      ],
      settings: const AppSettingsData(quietHoursEnabled: false),
      now: now,
    );

    expect(schedules, hasLength(1));
    expect(schedules.single.repeat, GoalNotificationRepeat.daily);
    expect(schedules.single.when, DateTime(2026, 8, 25, 18, 30));
    expect(
      schedules.single.payload.type,
      GoalNotificationType.dailyActionReminder,
    );
  });

  test('custom weekdays use stable weekly schedules', () {
    final reminder = GoalReminder(
      id: 'reminder-2',
      message: 'Check the result',
      frequency: ReminderFrequency.customDays,
      hour: 9,
      minute: 15,
      purpose: ReminderPurpose.goalCompletion,
      weekdays: const {1, 3, 5},
    );
    final first = buildGoalNotificationSchedule(
      goals: [goalWith(reminder)],
      settings: const AppSettingsData(quietHoursEnabled: false),
      now: now,
    );
    final second = buildGoalNotificationSchedule(
      goals: [goalWith(reminder)],
      settings: const AppSettingsData(quietHoursEnabled: false),
      now: now,
    );

    expect(first, hasLength(3));
    expect(
      first.map((item) => item.repeat),
      everyElement(GoalNotificationRepeat.weekly),
    );
    expect(first.map((item) => item.id), second.map((item) => item.id));
    expect(
      first.map((item) => item.payload.type),
      everyElement(GoalNotificationType.goalCompletionCheckIn),
    );
  });

  test('quiet hours move a reminder to the configured quiet-hours end', () {
    final schedules = buildGoalNotificationSchedule(
      goals: [
        goalWith(
          const GoalReminder(
            id: 'reminder-3',
            message: 'Late reminder',
            frequency: ReminderFrequency.daily,
            hour: 23,
            minute: 0,
          ),
        ),
      ],
      settings: const AppSettingsData(
        quietHoursEnabled: true,
        quietStartHour: 22,
        quietEndHour: 7,
      ),
      now: now,
    );

    expect(schedules.single.when, DateTime(2026, 8, 26, 7));
  });

  test('disabled, completed, and trashed goals are not scheduled', () {
    const reminder = GoalReminder(
      id: 'reminder-4',
      enabled: false,
      message: 'Hidden',
      frequency: ReminderFrequency.daily,
      hour: 18,
      minute: 0,
    );
    final completed = goalWith(reminder).copyWith(status: GoalStatus.completed);
    final trashed = goalWith(reminder).copyWith(trashedAt: now);

    expect(
      buildGoalNotificationSchedule(
        goals: [goalWith(reminder), completed, trashed],
        settings: const AppSettingsData(),
        now: now,
      ),
      isEmpty,
    );
  });

  test('automatic starts create one interactive start notice', () {
    final goal = Goal(
      id: 'starting-goal',
      name: 'Read the book',
      status: GoalStatus.active,
      createdAt: now,
      updatedAt: now,
      showStartNotice: true,
      plan: GoalPlan(
        totalAmount: 100,
        unit: 'page',
        startDate: DateTime(2026, 8, 25),
        deadline: DateTime(2026, 9, 25),
        activeWeekdays: const {1, 2, 3, 4, 5, 6, 7},
        wholeUnits: true,
        acceptedDailyPace: 4,
      ),
    );

    final schedules = buildGoalNotificationSchedule(
      goals: [goal],
      settings: const AppSettingsData(quietHoursEnabled: false),
      now: now,
    );

    expect(schedules, hasLength(1));
    expect(schedules.single.repeat, GoalNotificationRepeat.none);
    expect(schedules.single.payload.type, GoalNotificationType.automaticStart);
    expect(schedules.single.payload.goalId, goal.id);
  });

  test('action occurrence identities are idempotent for the same minute', () {
    const payload = GoalNotificationPayload(
      type: GoalNotificationType.dailyActionReminder,
      occurrenceId: 'reminder-1:daily',
      goalId: 'goal-1',
    );

    expect(
      notificationActionOccurrenceId(payload, DateTime(2026, 8, 25, 18, 3)),
      notificationActionOccurrenceId(payload, DateTime(2026, 8, 25, 18, 3, 45)),
    );
  });

  test('Windows recurrence expands to bounded stable one-time schedules', () {
    final recurring = GoalNotificationSchedule(
      id: 44,
      title: 'Daily action',
      body: 'Do it',
      when: DateTime(2026, 8, 25, 18),
      payload: const GoalNotificationPayload(
        type: GoalNotificationType.dailyActionReminder,
        occurrenceId: 'reminder-1:daily',
        goalId: 'goal-1',
      ),
      repeat: GoalNotificationRepeat.daily,
    );

    final first = expandWindowsNotificationSchedules([
      recurring,
    ], dailyOccurrences: 3);
    final second = expandWindowsNotificationSchedules([
      recurring,
    ], dailyOccurrences: 3);

    expect(first, hasLength(3));
    expect(
      first.map((item) => item.repeat),
      everyElement(GoalNotificationRepeat.none),
    );
    expect(first.map((item) => item.when), [
      DateTime(2026, 8, 25, 18),
      DateTime(2026, 8, 26, 18),
      DateTime(2026, 8, 27, 18),
    ]);
    expect(first.map((item) => item.id), second.map((item) => item.id));
  });
}
