import 'goal_notification_schedule.dart';

class PendingGoalNotification {
  const PendingGoalNotification({
    required this.id,
    required this.payload,
    required this.managed,
  });

  final int id;
  final String? payload;
  final bool managed;
}

abstract interface class GoalNotificationAdapter {
  Future<List<PendingGoalNotification>> pendingGoalNotifications();

  Future<void> cancelGoalNotification(int id);

  Future<void> scheduleGoalNotification(GoalNotificationSchedule schedule);
}

class GoalNotificationReconciler {
  const GoalNotificationReconciler();

  Future<void> reconcile({
    required GoalNotificationAdapter adapter,
    required Iterable<GoalNotificationSchedule> desiredSchedules,
  }) async {
    final desired = {
      for (final schedule in desiredSchedules) schedule.id: schedule,
    };
    final pending = await adapter.pendingGoalNotifications();
    final pendingById = {for (final item in pending) item.id: item};

    for (final request in pending.where((item) => item.managed)) {
      final wanted = desired[request.id];
      if (wanted == null || request.payload != wanted.payload.encode()) {
        await adapter.cancelGoalNotification(request.id);
        pendingById.remove(request.id);
      }
    }

    for (final schedule in desired.values) {
      final existing = pendingById[schedule.id];
      if (existing?.payload == schedule.payload.encode()) continue;
      await adapter.scheduleGoalNotification(schedule);
    }
  }
}
