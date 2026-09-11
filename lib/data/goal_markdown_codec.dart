import 'dart:convert';

import '../domain/goal.dart';
import '../domain/life_data.dart';
import '../domain/plan_calculator.dart';

class GoalMarkdownCodec {
  const GoalMarkdownCodec();

  String encode(Goal goal) {
    final plan = goal.plan;
    final activeWeekdays = plan == null
        ? null
        : (plan.activeWeekdays.toList()..sort());
    final metadata = <String, Object?>{
      'id': goal.id,
      'name': goal.name,
      'status': goal.status.name,
      'category': goal.category,
      'icon_id': goal.iconId,
      'is_urgent': goal.isUrgent,
      'urgency_style': goal.urgencyStyle.name,
      'reminder': goal.reminder == null
          ? null
          : <String, Object?>{
              'id': goal.reminder!.id.isEmpty
                  ? '${goal.id}-reminder-main'
                  : goal.reminder!.id,
              'enabled': goal.reminder!.enabled,
              'message': goal.reminder!.message,
              'frequency': goal.reminder!.frequency.name,
              'purpose': goal.reminder!.purpose.name,
              'hour': goal.reminder!.hour,
              'minute': goal.reminder!.minute,
              'weekdays': goal.reminder!.weekdays.toList()..sort(),
              'once_at': goal.reminder!.onceAt?.toIso8601String(),
              'snoozed_until': goal.reminder!.snoozedUntil?.toIso8601String(),
            },
      'created_at': goal.createdAt.toIso8601String(),
      'updated_at': goal.updatedAt.toIso8601String(),
      'completed_amount': goal.completedAmount,
      'total_amount': plan?.totalAmount,
      'unit': plan?.unit,
      'start_date': plan == null ? null : _date(plan.startDate),
      'deadline': plan == null ? null : _date(plan.deadline),
      'active_weekdays': activeWeekdays,
      'whole_units': plan?.wholeUnits,
      'accepted_daily_pace': plan?.acceptedDailyPace,
      'initial_completed_amount': plan?.initialCompletedAmount,
      'started_automatically_at': goal.startedAutomaticallyAt
          ?.toIso8601String(),
      'show_start_notice': goal.showStartNotice,
      'trashed_at': goal.trashedAt?.toIso8601String(),
      'progress_history': goal.progressHistory
          .map(
            (entry) => <String, Object>{
              'recorded_at': entry.recordedAt.toIso8601String(),
              'change': entry.change,
              'completed_after': entry.completedAfter,
              'note': entry.note,
            },
          )
          .toList(),
      'daily_action_completions': goal.dailyActionCompletions
          .map(
            (completion) => <String, Object>{
              'action_date': _date(completion.actionDate),
              'completed_at': completion.completedAt.toIso8601String(),
              'amount': completion.amount,
              'note': completion.note,
              if (completion.record != null)
                'record': completion.record!.toJson(),
            },
          )
          .toList(),
      'steps': goal.steps
          .map(
            (step) => <String, Object?>{
              'id': step.id,
              'title': step.title,
              'details': step.details,
              'created_at': step.createdAt.toIso8601String(),
              'completed_at': step.completedAt?.toIso8601String(),
            },
          )
          .toList(),
      'updates': goal.updates
          .map(
            (update) => <String, Object>{
              'id': update.id,
              'recorded_at': update.recordedAt.toIso8601String(),
              'text': update.text,
              'kind': update.kind.name,
              if (update.editedAt != null)
                'edited_at': update.editedAt!.toIso8601String(),
              if (update.stepId != null) 'step_id': update.stepId!,
              if (update.stepTitle != null) 'step_title': update.stepTitle!,
            },
          )
          .toList(),
    };

    final buffer = StringBuffer('---\n');
    for (final entry in metadata.entries) {
      buffer.writeln('${entry.key}: ${jsonEncode(entry.value)}');
    }
    buffer
      ..writeln('---')
      ..writeln()
      ..writeln('# ${goal.name}')
      ..writeln()
      ..writeln('This goal is stored locally and can be read without the app.')
      ..writeln()
      ..writeln('## Progress history');
    if (goal.progressHistory.isEmpty) {
      buffer.writeln('- No progress recorded yet.');
    } else {
      for (final entry in goal.progressHistory.reversed) {
        final unit = plan?.unit ?? 'units';
        final sign = entry.change >= 0 ? '+' : '';
        buffer.writeln(
          '- ${_date(entry.recordedAt)}: $sign${formatAmount(entry.change)} $unit '
          '(${formatAmount(entry.completedAfter)} completed)'
          '${entry.note.trim().isEmpty ? '' : ' — ${entry.note.trim()}'}',
        );
      }
    }
    buffer
      ..writeln()
      ..writeln('## Daily action notes');
    if (goal.dailyActionCompletions.isEmpty) {
      buffer.writeln('- No daily action notes yet.');
    } else {
      for (final completion in goal.dailyActionCompletions.reversed) {
        buffer.writeln(
          '- ${_date(completion.actionDate)}: '
          '${completion.note.trim().isEmpty ? 'Completed' : completion.note.trim()}',
        );
      }
    }
    buffer
      ..writeln()
      ..writeln('## Small steps');
    if (goal.steps.isEmpty) {
      buffer.writeln('- No small steps yet.');
    } else {
      for (final step in goal.steps) {
        final lines = const LineSplitter().convert(step.title);
        buffer.writeln(
          '- [${step.isCompleted ? 'x' : ' '}] '
          '${lines.isEmpty ? '' : lines.first}',
        );
        for (final line in lines.skip(1)) {
          buffer.writeln('  $line');
        }
        if (step.details.trim().isNotEmpty) {
          buffer.writeln('  Details: ${step.details.trim()}');
        }
      }
    }
    buffer
      ..writeln()
      ..writeln('## Goal updates');
    if (goal.updates.isEmpty) {
      buffer.writeln('- No goal updates yet.');
    } else {
      for (final update in goal.updates.reversed) {
        buffer.writeln(
          '- ${_date(update.recordedAt)}: '
          '${update.stepTitle == null ? '' : '[${update.stepTitle}] '}'
          '${update.text}${update.editedAt == null ? '' : ' (edited)'}',
        );
      }
    }
    return buffer.toString();
  }

  Goal decode(String markdown) {
    final lines = const LineSplitter().convert(markdown);
    if (lines.isEmpty || lines.first.trim() != '---') {
      throw const FormatException('Goal file has no metadata header.');
    }
    final metadata = <String, Object?>{};
    var foundEnd = false;
    for (var index = 1; index < lines.length; index++) {
      final line = lines[index];
      if (line.trim() == '---') {
        foundEnd = true;
        break;
      }
      final separator = line.indexOf(':');
      if (separator <= 0) continue;
      final key = line.substring(0, separator).trim();
      final value = line.substring(separator + 1).trim();
      metadata[key] = jsonDecode(value);
    }
    if (!foundEnd) throw const FormatException('Goal metadata is not closed.');

    final goalId = _requiredString(metadata, 'id');
    final goalName = _requiredString(metadata, 'name');
    final createdAt = _requiredDateTime(metadata, 'created_at');
    final updatedAt = _dateTimeOrNull(metadata['updated_at']) ?? createdAt;

    final totalAmount = _doubleOrNull(metadata['total_amount']);
    final unit = metadata['unit'] as String?;
    final start = _dateOrNull(metadata['start_date']);
    final deadline = _dateOrNull(metadata['deadline']);
    final weekdays = (metadata['active_weekdays'] as List<Object?>?)
        ?.whereType<num>()
        .map((value) => value.toInt())
        .toSet();
    GoalPlan? plan;
    if (totalAmount != null &&
        unit != null &&
        start != null &&
        deadline != null) {
      plan = GoalPlan(
        totalAmount: totalAmount,
        unit: unit,
        startDate: start,
        deadline: deadline,
        activeWeekdays: weekdays == null || weekdays.isEmpty
            ? {1, 2, 3, 4, 5, 6, 7}
            : weekdays,
        wholeUnits: metadata['whole_units'] as bool? ?? true,
        acceptedDailyPace: _doubleOrNull(metadata['accepted_daily_pace']) ?? 0,
        initialCompletedAmount:
            _doubleOrNull(metadata['initial_completed_amount']) ?? 0,
      );
    }

    GoalReminder? reminder;
    if (metadata['reminder'] case final Map<String, Object?> value) {
      final storedReminderId = value['id'] as String?;
      reminder = GoalReminder(
        id: storedReminderId?.trim().isNotEmpty == true
            ? storedReminderId!.trim()
            : '$goalId-reminder-main',
        enabled: value['enabled'] as bool? ?? true,
        message: value['message'] as String? ?? '',
        frequency: ReminderFrequency.parse(value['frequency'] as String?),
        purpose: ReminderPurpose.parse(
          value['purpose'] as String?,
          fallback: plan == null
              ? ReminderPurpose.goalCompletion
              : ReminderPurpose.dailyAction,
        ),
        hour: (value['hour'] as num?)?.toInt() ?? 18,
        minute: (value['minute'] as num?)?.toInt() ?? 0,
        weekdays:
            (value['weekdays'] as List<Object?>? ?? const [1, 2, 3, 4, 5, 6, 7])
                .whereType<num>()
                .map((day) => day.toInt())
                .toSet(),
        onceAt: _dateTimeOrNull(value['once_at']),
        snoozedUntil: _dateTimeOrNull(value['snoozed_until']),
      );
    }

    final history = (metadata['progress_history'] as List<Object?>? ?? const [])
        .whereType<Map<String, Object?>>()
        .map(
          (entry) => ProgressEntry(
            recordedAt: DateTime.parse(entry['recorded_at']! as String),
            change: _doubleOrNull(entry['change']) ?? 0,
            completedAfter: _doubleOrNull(entry['completed_after']) ?? 0,
            note: entry['note'] as String? ?? '',
          ),
        )
        .toList();

    final dailyActionCompletions =
        (metadata['daily_action_completions'] as List<Object?>? ?? const [])
            .whereType<Map<String, Object?>>()
            .map(
              (entry) => DailyActionCompletion(
                actionDate:
                    _dateOrNull(entry['action_date']) ??
                    DateTime.parse(entry['completed_at']! as String),
                completedAt: DateTime.parse(entry['completed_at']! as String),
                amount: _doubleOrNull(entry['amount']) ?? 0,
                note: entry['note'] as String? ?? '',
                record: entry['record'] is Map
                    ? TaskCompletionNote.fromJson(
                        Map<String, Object?>.from(entry['record']! as Map),
                      )
                    : null,
              ),
            )
            .toList();

    final steps = <GoalStep>[];
    final storedSteps = (metadata['steps'] as List<Object?>? ?? const [])
        .whereType<Map<String, Object?>>()
        .toList(growable: false);
    for (var index = 0; index < storedSteps.length; index++) {
      final entry = storedSteps[index];
      final title = entry['title'] as String?;
      if (title == null || title.trim().isEmpty) continue;
      final stepCreatedAt =
          _dateTimeOrNull(entry['created_at']) ??
          createdAt.add(Duration(microseconds: index));
      final storedId = entry['id'] as String?;
      steps.add(
        GoalStep(
          id: storedId?.trim().isNotEmpty == true
              ? storedId!.trim()
              : _legacyId('step', [goalId, index, stepCreatedAt, title]),
          title: title,
          details: entry['details'] as String? ?? '',
          createdAt: stepCreatedAt,
          completedAt: _dateTimeOrNull(entry['completed_at']),
        ),
      );
    }

    final updates = <GoalUpdate>[];
    final storedUpdates = (metadata['updates'] as List<Object?>? ?? const [])
        .whereType<Map<String, Object?>>()
        .toList(growable: false);
    for (var index = 0; index < storedUpdates.length; index++) {
      final entry = storedUpdates[index];
      final text = entry['text'] as String?;
      if (text == null || text.trim().isEmpty) continue;
      final recordedAt =
          _dateTimeOrNull(entry['recorded_at']) ??
          updatedAt.add(Duration(microseconds: index));
      final storedId = entry['id'] as String?;
      updates.add(
        GoalUpdate(
          id: storedId?.trim().isNotEmpty == true
              ? storedId!.trim()
              : _legacyId('update', [
                  goalId,
                  index,
                  recordedAt,
                  entry['step_id'],
                  text,
                ]),
          recordedAt: recordedAt,
          text: text,
          stepId: entry['step_id'] as String?,
          stepTitle: entry['step_title'] as String?,
          kind: GoalUpdateKind.parse(entry['kind'] as String?),
          editedAt: _dateTimeOrNull(entry['edited_at']),
        ),
      );
    }

    return Goal(
      id: goalId,
      name: goalName,
      status: GoalStatus.parse(metadata['status'] as String? ?? 'ideas'),
      createdAt: createdAt,
      category: (metadata['category'] as String?)?.trim().isNotEmpty == true
          ? (metadata['category']! as String).trim()
          : GoalCategories.other,
      iconId: metadata['icon_id'] as String? ?? 'goal',
      isUrgent: metadata['is_urgent'] as bool? ?? false,
      urgencyStyle: UrgencyStyle.parse(metadata['urgency_style'] as String?),
      reminder: reminder,
      updatedAt: updatedAt,
      plan: plan,
      completedAmount: _doubleOrNull(metadata['completed_amount']) ?? 0,
      progressHistory: history,
      dailyActionCompletions: dailyActionCompletions,
      steps: steps,
      updates: updates,
      startedAutomaticallyAt: _dateTimeOrNull(
        metadata['started_automatically_at'],
      ),
      showStartNotice: metadata['show_start_notice'] as bool? ?? false,
      trashedAt: _dateTimeOrNull(metadata['trashed_at']),
    );
  }

  static String _date(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-'
      '${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';

  static DateTime? _dateOrNull(Object? value) =>
      value is String && value.isNotEmpty ? DateTime.tryParse(value) : null;

  static DateTime? _dateTimeOrNull(Object? value) =>
      value is String && value.isNotEmpty ? DateTime.tryParse(value) : null;

  static double? _doubleOrNull(Object? value) =>
      value is num ? value.toDouble() : null;

  static String _requiredString(Map<String, Object?> metadata, String key) {
    final value = metadata[key];
    if (value is String && value.trim().isNotEmpty) return value.trim();
    throw FormatException('Goal metadata is missing $key.');
  }

  static DateTime _requiredDateTime(Map<String, Object?> metadata, String key) {
    final value = _dateTimeOrNull(metadata[key]);
    if (value != null) return value;
    throw FormatException('Goal metadata has an invalid $key.');
  }

  static String _legacyId(String namespace, Iterable<Object?> parts) {
    var hash = 0x811c9dc5;
    for (final code in parts.join('\u001f').codeUnits) {
      hash ^= code;
      hash = (hash * 0x01000193) & 0xffffffff;
    }
    return '$namespace-${hash.toRadixString(16).padLeft(8, '0')}';
  }
}
