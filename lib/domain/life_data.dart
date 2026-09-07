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
  final DateTime createdAt;
  final String location;
  final String spaceId;
  final String assignee;

  bool get isCompleted => completedAt != null;

  bool isDoneOn(DateTime day) => repeat == TaskRepeat.none
      ? isCompleted
      : completedDates.any((date) => _sameDate(date, day));

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
    createdAt: _date(json['createdAt']) ?? DateTime.now(),
    location: json['location'] as String? ?? '',
    spaceId: json['spaceId'] as String? ?? LifeSpace.personalId,
    assignee: json['assignee'] as String? ?? '',
  );
}

enum CalendarEntryKind { event, blockedTime }

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
  });

  final String id;
  final String title;
  final DateTime start;
  final DateTime end;
  final CalendarEntryKind kind;
  final String location;
  final bool enabled;
  final String spaceId;

  bool occursOn(DateTime day) {
    final dayStart = DateTime(day.year, day.month, day.day);
    final dayEnd = dayStart.add(const Duration(days: 1));
    return start.isBefore(dayEnd) && end.isAfter(dayStart);
  }

  Map<String, Object?> toJson() => {
    'id': id,
    'title': title,
    'start': start.toIso8601String(),
    'end': end.toIso8601String(),
    'kind': kind.name,
    'location': location,
    'enabled': enabled,
    'spaceId': spaceId,
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
  );
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
    'version': 1,
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
