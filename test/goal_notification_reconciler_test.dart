import 'package:flutter_test/flutter_test.dart';
import 'package:goal_tracker_poc/platform/goal_notification_payload.dart';
import 'package:goal_tracker_poc/platform/goal_notification_reconciler.dart';
import 'package:goal_tracker_poc/platform/goal_notification_schedule.dart';

void main() {
  const reconciler = GoalNotificationReconciler();

  test(
    'reconciliation preserves unrelated and unchanged notifications',
    () async {
      final desired = _schedule(12, 'same');
      final fake = _FakeAdapter([
        PendingGoalNotification(
          id: 12,
          payload: desired.payload.encode(),
          managed: true,
        ),
        const PendingGoalNotification(
          id: 99,
          payload: 'another-app',
          managed: false,
        ),
      ]);

      await reconciler.reconcile(adapter: fake, desiredSchedules: [desired]);

      expect(fake.cancelled, isEmpty);
      expect(fake.scheduled, isEmpty);
    },
  );

  test(
    'reconciliation replaces changed and removes stale owned schedules',
    () async {
      final desired = _schedule(12, 'new');
      final fake = _FakeAdapter(const [
        PendingGoalNotification(id: 12, payload: 'old', managed: true),
        PendingGoalNotification(id: 13, payload: 'stale', managed: true),
        PendingGoalNotification(id: 99, payload: 'unrelated', managed: false),
      ]);

      await reconciler.reconcile(adapter: fake, desiredSchedules: [desired]);

      expect(fake.cancelled, [12, 13]);
      expect(fake.scheduled.map((item) => item.id), [12]);
    },
  );

  test('schedule failures remain visible to the caller', () async {
    final fake = _FakeAdapter(const [])..failSchedule = true;

    await expectLater(
      reconciler.reconcile(
        adapter: fake,
        desiredSchedules: [_schedule(12, 'new')],
      ),
      throwsStateError,
    );
  });
}

GoalNotificationSchedule _schedule(int id, String occurrence) =>
    GoalNotificationSchedule(
      id: id,
      title: 'Goal',
      body: 'Reminder',
      when: DateTime(2026, 8, 25, 18),
      payload: GoalNotificationPayload(
        type: GoalNotificationType.dailyActionReminder,
        occurrenceId: occurrence,
        goalId: 'goal-1',
      ),
    );

class _FakeAdapter implements GoalNotificationAdapter {
  _FakeAdapter(this.pending);

  final List<PendingGoalNotification> pending;
  final List<int> cancelled = [];
  final List<GoalNotificationSchedule> scheduled = [];
  bool failSchedule = false;

  @override
  Future<void> cancelGoalNotification(int id) async => cancelled.add(id);

  @override
  Future<List<PendingGoalNotification>> pendingGoalNotifications() async =>
      pending;

  @override
  Future<void> scheduleGoalNotification(
    GoalNotificationSchedule schedule,
  ) async {
    if (failSchedule) throw StateError('native scheduling unavailable');
    scheduled.add(schedule);
  }
}
