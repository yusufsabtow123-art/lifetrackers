import 'dart:math' as math;

enum TaskRepeat {
  none('Does not repeat'),
  daily('Every day'),
  weekdays('Weekdays'),
  weekly('Every week');

  const TaskRepeat(this.label);
  final String label;

  static TaskRepeat parse(String? value) => TaskRepeat.values.firstWhere(
    (item) => item.name == value,
    orElse: () => TaskRepeat.none,
  );
}

class LifeTask {
  const LifeTask({
    required this.id,
    required this.title,
    required this.createdAt,
    this.notes = '',
    this.goalId,
    this.dueAt,
    this.repeat = TaskRepeat.none,
    this.completedAt,
    this.completedDates = const [],
    this.completionNotes = const [],
    this.location = '',
    this.spaceId = LifeSpace.personalId,
    this.assignee = '',
  });

  final String id;
  final String title;
  final String notes;
  final String? goalId;
  final DateTime? dueAt;
  final TaskRepeat repeat;
  final DateTime? completedAt;
  final List<DateTime> completedDates;
  final List<TaskCompletionNote> completionNotes;
  final DateTime createdAt;
  final String location;
  final String spaceId;
  final String assignee;

  bool get isCompleted => completedAt != null;

  bool isDoneOn(DateTime day) => repeat == TaskRepeat.none
      ? isCompleted
      : completedDates.any((date) => _sameDate(date, day));

  TaskCompletionNote? completionNoteFor(DateTime day) {
    for (final note in completionNotes.reversed) {
      if (_sameDate(note.day, day)) return note;
    }
    return null;
  }

  bool occursOn(DateTime day) {
    final due = dueAt;
    if (due == null) return false;
    final date = DateTime(day.year, day.month, day.day);
    final start = DateTime(due.year, due.month, due.day);
    if (date.isBefore(start)) return false;
    return switch (repeat) {
      TaskRepeat.none => _sameDate(date, start),
      TaskRepeat.daily => true,
      TaskRepeat.weekdays => date.weekday <= DateTime.friday,
      TaskRepeat.weekly => date.weekday == start.weekday,
    };
  }

  LifeTask copyWith({
    String? title,
    String? notes,
    String? goalId,
    bool clearGoal = false,
    DateTime? dueAt,
    bool clearDue = false,
    TaskRepeat? repeat,
    DateTime? completedAt,
    bool clearCompleted = false,
    List<DateTime>? completedDates,
    List<TaskCompletionNote>? completionNotes,
    String? location,
    String? spaceId,
    String? assignee,
  }) => LifeTask(
    id: id,
    title: title ?? this.title,
    notes: notes ?? this.notes,
    goalId: clearGoal ? null : goalId ?? this.goalId,
    dueAt: clearDue ? null : dueAt ?? this.dueAt,
    repeat: repeat ?? this.repeat,
    completedAt: clearCompleted ? null : completedAt ?? this.completedAt,
    completedDates: completedDates ?? this.completedDates,
    completionNotes: completionNotes ?? this.completionNotes,
    createdAt: createdAt,
    location: location ?? this.location,
    spaceId: spaceId ?? this.spaceId,
    assignee: assignee ?? this.assignee,
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'title': title,
    'notes': notes,
    'goalId': goalId,
    'dueAt': dueAt?.toIso8601String(),
    'repeat': repeat.name,
    'completedAt': completedAt?.toIso8601String(),
    'completedDates': completedDates
        .map((date) => date.toIso8601String())
        .toList(),
    'completionNotes': completionNotes.map((note) => note.toJson()).toList(),
    'createdAt': createdAt.toIso8601String(),
    'location': location,
    'spaceId': spaceId,
    'assignee': assignee,
  };

  factory LifeTask.fromJson(Map<String, Object?> json) => LifeTask(
    id: json['id'] as String,
    title: json['title'] as String,
    notes: json['notes'] as String? ?? '',
    goalId: json['goalId'] as String?,
    dueAt: _date(json['dueAt']),
    repeat: TaskRepeat.parse(json['repeat'] as String?),
    completedAt: _date(json['completedAt']),
    completedDates: (json['completedDates'] as List<Object?>? ?? const [])
        .map(_date)
        .whereType<DateTime>()
        .toList(),
    completionNotes: (json['completionNotes'] as List<Object?>? ?? const [])
        .whereType<Map>()
        .map(
          (item) =>
              TaskCompletionNote.fromJson(Map<String, Object?>.from(item)),
        )
        .toList(),
    createdAt: _date(json['createdAt']) ?? DateTime.now(),
    location: json['location'] as String? ?? '',
    spaceId: json['spaceId'] as String? ?? LifeSpace.personalId,
    assignee: json['assignee'] as String? ?? '',
  );
}

class TaskCompletionNote {
  const TaskCompletionNote({
    required this.day,
    required this.recordedAt,
    required this.text,
  });

  final DateTime day;
  final DateTime recordedAt;
  final String text;

  Map<String, Object?> toJson() => {
    'day': day.toIso8601String(),
    'recordedAt': recordedAt.toIso8601String(),
    'text': text,
  };

  factory TaskCompletionNote.fromJson(Map<String, Object?> json) =>
      TaskCompletionNote(
        day: _date(json['day']) ?? DateTime.now(),
        recordedAt: _date(json['recordedAt']) ?? DateTime.now(),
        text: json['text'] as String? ?? '',
      );
}

enum CalendarEntryKind { event, blockedTime }

enum CalendarRepeat {
  none('Does not repeat'),
  daily('Every day'),
  weekdays('Weekdays'),
  weekly('Every week'),
  monthly('Every month'),
  yearly('Every year');

  const CalendarRepeat(this.label);
  final String label;

  static CalendarRepeat parse(String? value) =>
      CalendarRepeat.values.firstWhere(
        (item) => item.name == value,
        orElse: () => CalendarRepeat.none,
      );
}

class CalendarEntry {
  const CalendarEntry({
    required this.id,
    required this.title,
    required this.start,
    required this.end,
    required this.kind,
    this.location = '',
    this.enabled = true,
    this.spaceId = LifeSpace.personalId,
    this.repeat = CalendarRepeat.none,
    this.repeatInterval = 1,
    this.repeatWeekdays = const <int>{},
    this.repeatUntil,
    this.colorValue,
  });

  final String id;
  final String title;
  final DateTime start;
  final DateTime end;
  final CalendarEntryKind kind;
  final String location;
  final bool enabled;
  final String spaceId;
  final CalendarRepeat repeat;
  final int repeatInterval;
  final Set<int> repeatWeekdays;
  final DateTime? repeatUntil;
  final int? colorValue;

  bool occursOn(DateTime day) {
    if (repeat != CalendarRepeat.none) {
      final occurrenceDay = DateTime(day.year, day.month, day.day);
      final firstDay = DateTime(start.year, start.month, start.day);
      if (occurrenceDay.isBefore(firstDay)) return false;
      if (_repeatMatches(occurrenceDay, firstDay)) return true;
      final previousDay = occurrenceDay.subtract(const Duration(days: 1));
      if (previousDay.isBefore(firstDay) ||
          !_repeatMatches(previousDay, firstDay)) {
        return false;
      }
      final previousStart = DateTime(
        previousDay.year,
        previousDay.month,
        previousDay.day,
        start.hour,
        start.minute,
        start.second,
      );
      return previousStart.add(end.difference(start)).isAfter(occurrenceDay);
    }
    final dayStart = DateTime(day.year, day.month, day.day);
    final dayEnd = dayStart.add(const Duration(days: 1));
    return start.isBefore(dayEnd) && end.isAfter(dayStart);
  }

  DateTime occurrenceStart(DateTime day) {
    if (repeat == CalendarRepeat.none) return start;
    final occurrenceDay = DateTime(day.year, day.month, day.day);
    final firstDay = DateTime(start.year, start.month, start.day);
    final selectedDay = _repeatMatches(occurrenceDay, firstDay)
        ? occurrenceDay
        : occurrenceDay.subtract(const Duration(days: 1));
    return DateTime(
      selectedDay.year,
      selectedDay.month,
      selectedDay.day,
      start.hour,
      start.minute,
      start.second,
    );
  }

  DateTime occurrenceEnd(DateTime day) {
    if (repeat == CalendarRepeat.none) return end;
    return occurrenceStart(day).add(end.difference(start));
  }

  CalendarEntry copyWith({
    String? title,
    DateTime? start,
    DateTime? end,
    CalendarEntryKind? kind,
    String? location,
    bool? enabled,
    String? spaceId,
    CalendarRepeat? repeat,
    int? repeatInterval,
    Set<int>? repeatWeekdays,
    DateTime? repeatUntil,
    bool clearRepeatUntil = false,
    int? colorValue,
    bool clearColor = false,
  }) => CalendarEntry(
    id: id,
    title: title ?? this.title,
    start: start ?? this.start,
    end: end ?? this.end,
    kind: kind ?? this.kind,
    location: location ?? this.location,
    enabled: enabled ?? this.enabled,
    spaceId: spaceId ?? this.spaceId,
    repeat: repeat ?? this.repeat,
    repeatInterval: repeatInterval ?? this.repeatInterval,
    repeatWeekdays: repeatWeekdays ?? this.repeatWeekdays,
    repeatUntil: clearRepeatUntil ? null : repeatUntil ?? this.repeatUntil,
    colorValue: clearColor ? null : colorValue ?? this.colorValue,
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'title': title,
    'start': start.toIso8601String(),
    'end': end.toIso8601String(),
    'kind': kind.name,
    'location': location,
    'enabled': enabled,
    'spaceId': spaceId,
    'repeat': repeat.name,
    'repeatInterval': repeatInterval,
    'repeatWeekdays': repeatWeekdays.toList()..sort(),
    'repeatUntil': repeatUntil?.toIso8601String(),
    'colorValue': colorValue,
  };

  factory CalendarEntry.fromJson(Map<String, Object?> json) => CalendarEntry(
    id: json['id'] as String,
    title: json['title'] as String,
    start: _date(json['start']) ?? DateTime.now(),
    end: _date(json['end']) ?? DateTime.now().add(const Duration(hours: 1)),
    kind: CalendarEntryKind.values.firstWhere(
      (item) => item.name == json['kind'],
      orElse: () => CalendarEntryKind.event,
    ),
    location: json['location'] as String? ?? '',
    enabled: json['enabled'] as bool? ?? true,
    spaceId: json['spaceId'] as String? ?? LifeSpace.personalId,
    repeat: CalendarRepeat.parse(json['repeat'] as String?),
    repeatInterval: math.max(1, (json['repeatInterval'] as num?)?.toInt() ?? 1),
    repeatWeekdays:
        (json['repeatWeekdays'] as List<Object?>? ?? const <Object?>[])
            .whereType<num>()
            .map((value) => value.toInt())
            .where(
              (value) => value >= DateTime.monday && value <= DateTime.sunday,
            )
            .toSet(),
    repeatUntil: _date(json['repeatUntil']),
    colorValue: (json['colorValue'] as num?)?.toInt(),
  );

  bool _repeatMatches(DateTime day, DateTime firstDay) {
    if (day.isBefore(firstDay)) return false;
    final until = repeatUntil == null
        ? null
        : DateTime(repeatUntil!.year, repeatUntil!.month, repeatUntil!.day);
    if (until != null && day.isAfter(until)) return false;
    final interval = math.max(1, repeatInterval);
    final daysApart = day.difference(firstDay).inDays;
    return switch (repeat) {
      CalendarRepeat.none => false,
      CalendarRepeat.daily => daysApart % interval == 0,
      CalendarRepeat.weekdays => day.weekday <= DateTime.friday,
      CalendarRepeat.weekly =>
        (daysApart ~/ 7) % interval == 0 &&
            (repeatWeekdays.isEmpty
                ? day.weekday == firstDay.weekday
                : repeatWeekdays.contains(day.weekday)),
      CalendarRepeat.monthly =>
        day.day == firstDay.day &&
            ((day.year - firstDay.year) * 12 + day.month - firstDay.month) %
                    interval ==
                0,
      CalendarRepeat.yearly =>
        day.month == firstDay.month &&
            day.day == firstDay.day &&
            (day.year - firstDay.year) % interval == 0,
    };
  }
}

enum SpaceRole {
  owner('Owner'),
  manager('Manager'),
  member('Member');

  const SpaceRole(this.label);
  final String label;
}

class SpaceMember {
  const SpaceMember({required this.name, required this.role});
  final String name;
  final SpaceRole role;

  Map<String, Object?> toJson() => {'name': name, 'role': role.name};

  factory SpaceMember.fromJson(Map<String, Object?> json) => SpaceMember(
    name: json['name'] as String? ?? '',
    role: SpaceRole.values.firstWhere(
      (role) => role.name == json['role'],
      orElse: () => SpaceRole.member,
    ),
  );
}

class LifeSpace {
  const LifeSpace({
    required this.id,
    required this.name,
    required this.isShared,
    this.members = const [],
  });

  static const personalId = 'personal';
  static const sharedId = 'shared';

  final String id;
  final String name;
  final bool isShared;
  final List<SpaceMember> members;

  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'isShared': isShared,
    'members': members.map((member) => member.toJson()).toList(),
  };

  factory LifeSpace.fromJson(Map<String, Object?> json) => LifeSpace(
    id: json['id'] as String,
    name: json['name'] as String,
    isShared: json['isShared'] as bool? ?? false,
    members: (json['members'] as List<Object?>? ?? const [])
        .whereType<Map<String, Object?>>()
        .map(SpaceMember.fromJson)
        .toList(),
  );
}

class LifeData {
  const LifeData({
    this.tasks = const [],
    this.calendar = const [],
    this.spaces = const [
      LifeSpace(id: LifeSpace.personalId, name: 'Personal', isShared: false),
    ],
    this.activeSpaceId = LifeSpace.personalId,
    this.showBlockedTimes = true,
  });

  final List<LifeTask> tasks;
  final List<CalendarEntry> calendar;
  final List<LifeSpace> spaces;
  final String activeSpaceId;
  final bool showBlockedTimes;

  Map<String, Object?> toJson() => {
    'version': 2,
    'activeSpaceId': activeSpaceId,
    'showBlockedTimes': showBlockedTimes,
    'tasks': tasks.map((task) => task.toJson()).toList(),
    'calendar': calendar.map((entry) => entry.toJson()).toList(),
    'spaces': spaces.map((space) => space.toJson()).toList(),
  };

  factory LifeData.fromJson(Map<String, Object?> json) => LifeData(
    activeSpaceId: json['activeSpaceId'] as String? ?? LifeSpace.personalId,
    showBlockedTimes: json['showBlockedTimes'] as bool? ?? true,
    tasks: (json['tasks'] as List<Object?>? ?? const [])
        .whereType<Map<String, Object?>>()
        .map(LifeTask.fromJson)
        .toList(),
    calendar: (json['calendar'] as List<Object?>? ?? const [])
        .whereType<Map<String, Object?>>()
        .map(CalendarEntry.fromJson)
        .toList(),
    spaces: (json['spaces'] as List<Object?>? ?? const [])
        .whereType<Map<String, Object?>>()
        .map(LifeSpace.fromJson)
        .toList(),
  );
}

DateTime? _date(Object? value) =>
    value is String ? DateTime.tryParse(value) : null;

bool _sameDate(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;
