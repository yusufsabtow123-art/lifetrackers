import 'package:flutter_test/flutter_test.dart';
import 'package:goal_tracker_poc/platform/goal_notification_payload.dart';

void main() {
  test('versioned notification payload round-trips routing identity', () {
    const payload = GoalNotificationPayload(
      type: GoalNotificationType.dailyActionReminder,
      occurrenceId: 'reminder-1-2026-08-25',
      goalId: 'goal-1',
      reminderId: 'reminder-1',
    );

    final decoded = GoalNotificationPayload.tryDecode(payload.encode());

    expect(decoded?.type, GoalNotificationType.dailyActionReminder);
    expect(decoded?.occurrenceId, 'reminder-1-2026-08-25');
    expect(decoded?.goalId, 'goal-1');
    expect(decoded?.reminderId, 'reminder-1');
  });

  test('invalid and legacy payloads fail closed', () {
    expect(GoalNotificationPayload.tryDecode(null), isNull);
    expect(GoalNotificationPayload.tryDecode('goal:legacy'), isNull);
    expect(
      GoalNotificationPayload.tryDecode('goal-tracker-notification-v1:{}'),
      isNull,
    );
    expect(
      GoalNotificationPayload.tryDecode(
        'goal-tracker-notification-v1:{"type":7,"occurrence_id":true}',
      ),
      isNull,
    );
  });

  test('notification identifiers are stable, positive, and key-specific', () {
    final first = stableNotificationId('goal-1/reminder-1/monday');

    expect(first, greaterThan(0));
    expect(first, stableNotificationId('goal-1/reminder-1/monday'));
    expect(first, isNot(stableNotificationId('goal-1/reminder-1/tuesday')));
  });
}
