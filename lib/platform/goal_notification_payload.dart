import 'dart:convert';

enum GoalNotificationType {
  dailyActionReminder,
  goalCompletionCheckIn,
  automaticStart,
  endOfDayReview,
  test;

  static GoalNotificationType? tryParse(String? value) {
    for (final type in GoalNotificationType.values) {
      if (type.name == value) return type;
    }
    return null;
  }
}

abstract final class GoalNotificationActions {
  static const open = 'open';
  static const done = 'done';
  static const notDone = 'not_done';
  static const notYet = 'not_yet';
  static const delay = 'delay';
  static const beginToday = 'begin_today';
  static const undoStart = 'undo_start';
}

class GoalNotificationPayload {
  const GoalNotificationPayload({
    required this.type,
    required this.occurrenceId,
    this.goalId,
    this.reminderId,
  });

  static const _prefix = 'goal-tracker-notification-v1:';

  final GoalNotificationType type;
  final String occurrenceId;
  final String? goalId;
  final String? reminderId;

  String encode() =>
      '$_prefix${jsonEncode(<String, Object?>{'type': type.name, 'occurrence_id': occurrenceId, 'goal_id': goalId, 'reminder_id': reminderId})}';

  static GoalNotificationPayload? tryDecode(String? encoded) {
    if (encoded == null || !encoded.startsWith(_prefix)) return null;
    try {
      final value = jsonDecode(encoded.substring(_prefix.length));
      if (value is! Map) return null;
      final typeValue = value['type'];
      final occurrenceValue = value['occurrence_id'];
      final goalValue = value['goal_id'];
      final reminderValue = value['reminder_id'];
      if (typeValue is! String || occurrenceValue is! String) return null;
      if (goalValue != null && goalValue is! String) return null;
      if (reminderValue != null && reminderValue is! String) return null;
      final type = GoalNotificationType.tryParse(typeValue);
      final occurrenceId = occurrenceValue;
      if (type == null || occurrenceId.isEmpty) {
        return null;
      }
      return GoalNotificationPayload(
        type: type,
        occurrenceId: occurrenceId,
        goalId: goalValue as String?,
        reminderId: reminderValue as String?,
      );
    } on FormatException {
      return null;
    }
  }
}

int stableNotificationId(String key) {
  var hash = 0x811c9dc5;
  for (final code in key.codeUnits) {
    hash ^= code;
    hash = (hash * 0x01000193) & 0x7fffffff;
  }
  return hash == 0 ? 1 : hash;
}
