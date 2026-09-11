// ignore_for_file: prefer_initializing_formals

import 'package:flutter/foundation.dart';

import '../data/life_repository.dart';
import '../data/app_settings_repository.dart';
import '../domain/life_data.dart';
import '../domain/salah_schedule.dart';

class LifeStore extends ChangeNotifier {
  LifeStore(
    this.repository, {
    DateTime Function()? clock,
    AppSettingsData settings = const AppSettingsData(),
  }) : _clock = clock ?? DateTime.now,
       _settings = settings;

  final LifeRepository repository;
  final DateTime Function() _clock;
  final SalahSchedule _salahSchedule = SalahSchedule();
  AppSettingsData _settings;
  LifeData _data = const LifeData();
  bool isLoading = true;
  String? errorMessage;

  LifeData get data => _data;
  String get storagePath => repository.displayPath;
  String get activeSpaceId => _data.activeSpaceId;
  List<LifeTask> get tasks => List.unmodifiable(_data.tasks);
  List<CalendarEntry> get calendar => List.unmodifiable(_data.calendar);
  List<LifeSpace> get spaces => List.unmodifiable(_data.spaces);
  List<LifeLogEntry> get log => List.unmodifiable(_data.log);

  Future<void> load() async {
    isLoading = true;
    notifyListeners();
    try {
      _data = await repository.load();
      if (_data.spaces.isEmpty) _data = const LifeData();
      errorMessage = null;
    } on Object catch (error) {
      errorMessage = 'Your tasks and calendar could not be opened: $error';
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  List<LifeTask> tasksFor(DateTime day) => _data.tasks
      .where((task) => task.spaceId == activeSpaceId && task.occursOn(day))
      .toList(growable: false);

  List<CalendarEntry> entriesFor(DateTime day) =>
      [
            ..._data.calendar,
            ..._salahSchedule
                .entriesFor(day, _settings)
                .map((entry) => entry.copyWith(spaceId: activeSpaceId)),
          ]
          .where((entry) {
            final generatedSalah = entry.id.startsWith('salah-');
            return entry.spaceId == activeSpaceId &&
                entry.enabled &&
                (generatedSalah ||
                    _data.showBlockedTimes ||
                    entry.kind != CalendarEntryKind.blockedTime) &&
                entry.occursOn(day);
          })
          .toList(growable: false)
        ..sort(
          (a, b) => a.occurrenceStart(day).compareTo(b.occurrenceStart(day)),
        );

  void applySettings(AppSettingsData settings) {
    _settings = settings;
    _salahSchedule.clear();
    notifyListeners();
  }

  Future<void> addTask({
    required String title,
    String notes = '',
    String? goalId,
    DateTime? dueAt,
    TaskRepeat repeat = TaskRepeat.none,
    String location = '',
    String assignee = '',
    List<LifeAttachment> attachments = const [],
    String iconId = 'task',
  }) async {
    final now = _clock();
    final task = LifeTask(
      id: _id('task', now),
      title: title.trim(),
      notes: notes.trim(),
      goalId: goalId,
      dueAt: dueAt,
      repeat: repeat,
      createdAt: now,
      location: location.trim(),
      spaceId: activeSpaceId,
      assignee: assignee.trim(),
      attachments: attachments,
      iconId: iconId,
    );
    _data = _data.copyWith(tasks: [..._data.tasks, task]);
    await _save();
  }

  Future<void> toggleTask(LifeTask task) async {
    if (!task.isCompleted) {
      await completeTaskForDate(task, task.dueAt ?? _clock());
      return;
    }
    await _replaceTask(task.copyWith(clearCompleted: true));
  }

  Future<void> toggleTaskForDate(LifeTask task, DateTime date) async {
    if (task.repeat == TaskRepeat.none) return toggleTask(task);
    final alreadyDone = task.isDoneOn(date);
    if (!alreadyDone) {
      await completeTaskForDate(task, date);
      return;
    }
    final dates = task.completedDates
        .where(
          (item) =>
              item.year != date.year ||
              item.month != date.month ||
              item.day != date.day,
        )
        .toList();
    await _replaceTask(task.copyWith(completedDates: dates));
  }

  Future<void> completeTaskForDate(
    LifeTask task,
    DateTime date, {
    String note = '',
    List<LifeAttachment> attachments = const [],
  }) async {
    final day = DateTime(date.year, date.month, date.day);
    final notes = task.completionNotes
        .where(
          (item) =>
              item.day.year != day.year ||
              item.day.month != day.month ||
              item.day.day != day.day,
        )
        .toList();
    final trimmedNote = note.trim();
    final now = _clock();
    if (trimmedNote.isNotEmpty || attachments.isNotEmpty) {
      final scheduledStart = task.dueAt == null
          ? null
          : DateTime(
              day.year,
              day.month,
              day.day,
              task.dueAt!.hour,
              task.dueAt!.minute,
            );
      notes.add(
        TaskCompletionNote(
          day: day,
          recordedAt: now,
          text: trimmedNote,
          attachments: attachments,
          actualEndAt: now,
          scheduledStartAt: scheduledStart,
          scheduledEndAt: scheduledStart?.add(const Duration(hours: 1)),
          locationName: task.location,
        ),
      );
    }
    final logEntry = LifeLogEntry(
      id: _id('log', now),
      createdAt: now,
      kind: trimmedNote.isEmpty
          ? LifeLogKind.taskCompleted
          : LifeLogKind.progressNote,
      text: trimmedNote,
      attachments: attachments,
      taskId: task.id,
      goalId: task.goalId,
      spaceId: task.spaceId,
    );
    if (task.repeat == TaskRepeat.none) {
      await _replaceTask(
        task.copyWith(completedAt: now, completionNotes: notes),
        logEntry: logEntry,
      );
      return;
    }
    final dates = task.isDoneOn(day)
        ? task.completedDates
        : [...task.completedDates, day];
    await _replaceTask(
      task.copyWith(completedDates: dates, completionNotes: notes),
      logEntry: logEntry,
    );
  }

  Future<void> updateTaskCompletionNote(
    LifeTask task,
    DateTime date,
    String note,
  ) async {
    final day = DateTime(date.year, date.month, date.day);
    final notes = task.completionNotes
        .where(
          (item) =>
              item.day.year != day.year ||
              item.day.month != day.month ||
              item.day.day != day.day,
        )
        .toList();
    if (note.trim().isNotEmpty) {
      notes.add(
        TaskCompletionNote(day: day, recordedAt: _clock(), text: note.trim()),
      );
    }
    final now = _clock();
    await _replaceTask(
      task.copyWith(completionNotes: notes),
      logEntry: note.trim().isEmpty
          ? null
          : LifeLogEntry(
              id: _id('log', now),
              createdAt: now,
              kind: LifeLogKind.progressNote,
              text: note.trim(),
              taskId: task.id,
              goalId: task.goalId,
              spaceId: task.spaceId,
            ),
    );
  }

  Future<void> saveTaskCompletionRecord(
    LifeTask task,
    TaskCompletionNote record,
  ) async {
    final day = DateTime(record.day.year, record.day.month, record.day.day);
    final notes =
        task.completionNotes
            .where(
              (item) =>
                  item.day.year != record.day.year ||
                  item.day.month != record.day.month ||
                  item.day.day != record.day.day,
            )
            .toList()
          ..add(record);
    var updated = task.copyWith(completionNotes: notes);
    if (!task.isDoneOn(day)) {
      if (task.repeat == TaskRepeat.none) {
        updated = updated.copyWith(
          completedAt: record.actualEndAt ?? record.recordedAt,
        );
      } else {
        updated = updated.copyWith(
          completedDates: [...task.completedDates, day],
        );
      }
    }
    await _replaceTask(updated);
  }

  Future<void> addJournalEntry(
    String text, {
    List<LifeAttachment> attachments = const [],
  }) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty && attachments.isEmpty) return;
    final now = _clock();
    _data = _data.copyWith(
      log: [
        ..._data.log,
        LifeLogEntry(
          id: _id('log', now),
          createdAt: now,
          kind: LifeLogKind.journal,
          text: trimmed,
          spaceId: activeSpaceId,
          attachments: attachments,
        ),
      ],
    );
    await _save();
  }

  Future<void> updateTask(LifeTask task) => _replaceTask(task);

  Future<void> deleteTask(LifeTask task) async {
    _data = _data.copyWith(
      tasks: _data.tasks.where((item) => item.id != task.id).toList(),
    );
    await _save();
  }

  Future<void> _replaceTask(LifeTask task, {LifeLogEntry? logEntry}) async {
    _data = _data.copyWith(
      tasks: _data.tasks
          .map((item) => item.id == task.id ? task : item)
          .toList(),
      log: logEntry == null ? _data.log : [..._data.log, logEntry],
    );
    await _save();
  }

  Future<void> addCalendarEntry({
    required String title,
    required DateTime start,
    required DateTime end,
    required CalendarEntryKind kind,
    String location = '',
    CalendarRepeat repeat = CalendarRepeat.none,
    int repeatInterval = 1,
    Set<int> repeatWeekdays = const <int>{},
    DateTime? repeatUntil,
    int? colorValue,
    String iconId = 'calendar',
  }) async {
    final entry = CalendarEntry(
      id: _id('calendar', _clock()),
      title: title.trim(),
      start: start,
      end: end,
      kind: kind,
      location: location.trim(),
      spaceId: activeSpaceId,
      repeat: repeat,
      repeatInterval: repeatInterval,
      repeatWeekdays: repeatWeekdays,
      repeatUntil: repeatUntil,
      colorValue: colorValue,
      iconId: iconId,
    );
    _data = _data.copyWith(calendar: [..._data.calendar, entry]);
    await _save();
  }

  Future<void> updateCalendarEntry(CalendarEntry entry) async {
    _data = _data.copyWith(
      calendar: _data.calendar
          .map((item) => item.id == entry.id ? entry : item)
          .toList(),
    );
    await _save();
  }

  Future<int> importBlockedSchedule(String text) async {
    final imported = <CalendarEntry>[];
    final signatures = _data.calendar
        .where((entry) => entry.spaceId == activeSpaceId)
        .map(_calendarSignature)
        .toSet();
    for (final rawLine in text.split(RegExp(r'[\r\n]+'))) {
      final line = rawLine.trim();
      if (line.isEmpty) continue;
      final advanced = line.contains('\t');
      final parts = advanced ? line.split('\t') : line.split(',');
      if (parts.length < 4) continue;
      final date = _parseDate(parts[0].trim());
      final startTime = _parseTime(parts[1].trim());
      final endTime = _parseTime(parts[2].trim());
      if (date == null || startTime == null || endTime == null) continue;
      final start = DateTime(
        date.year,
        date.month,
        date.day,
        startTime.$1,
        startTime.$2,
      );
      var end = DateTime(
        date.year,
        date.month,
        date.day,
        endTime.$1,
        endTime.$2,
      );
      if (!end.isAfter(start)) end = end.add(const Duration(days: 1));
      final entry = CalendarEntry(
        id: '${_id('calendar', _clock())}-${imported.length}',
        title: advanced ? parts[3].trim() : parts.sublist(3).join(',').trim(),
        start: start,
        end: end,
        kind: advanced && parts.length > 7
            ? _parseCalendarKind(parts[7])
            : CalendarEntryKind.blockedTime,
        location: advanced && parts.length > 4 ? parts[4].trim() : '',
        spaceId: activeSpaceId,
        repeat: advanced && parts.length > 6
            ? CalendarRepeat.parse(parts[6].trim().toLowerCase())
            : CalendarRepeat.none,
        colorValue: advanced && parts.length > 5
            ? _parseCalendarColor(parts[5])
            : null,
      );
      final signature = _calendarSignature(entry);
      if (!signatures.add(signature)) continue;
      imported.add(entry);
    }
    if (imported.isEmpty) return 0;
    _data = _data.copyWith(calendar: [..._data.calendar, ...imported]);
    await _save();
    return imported.length;
  }

  String _calendarSignature(CalendarEntry entry) => [
    entry.spaceId,
    entry.title.trim().toLowerCase(),
    entry.start.toIso8601String(),
    entry.end.toIso8601String(),
    entry.kind.name,
    entry.repeat.name,
  ].join('|');

  CalendarEntryKind _parseCalendarKind(String value) =>
      value.trim().toLowerCase() == 'event'
      ? CalendarEntryKind.event
      : CalendarEntryKind.blockedTime;

  int? _parseCalendarColor(String value) {
    const named = <String, int>{
      'green': 0xFF70C982,
      'cyan': 0xFF45C7BA,
      'blue': 0xFF4FA3E3,
      'red': 0xFFE05D62,
      'yellow': 0xFFF1C94A,
      'coral': 0xFFD16A61,
      'gray': 0xFF89909B,
      'grey': 0xFF89909B,
      'purple': 0xFF9B66D9,
    };
    final normalized = value.trim().toLowerCase();
    if (normalized.isEmpty) return null;
    final preset = named[normalized];
    if (preset != null) return preset;
    final hex = normalized.replaceFirst('#', '').replaceFirst('0x', '');
    if (!RegExp(r'^[0-9a-f]{6}([0-9a-f]{2})?$').hasMatch(hex)) return null;
    final parsed = int.tryParse(hex, radix: 16);
    if (parsed == null) return null;
    return hex.length == 6 ? 0xFF000000 | parsed : parsed;
  }

  Future<void> deleteCalendarEntry(CalendarEntry entry) async {
    _data = _data.copyWith(
      calendar: _data.calendar.where((item) => item.id != entry.id).toList(),
    );
    await _save();
  }

  Future<void> setShowBlockedTimes(bool value) async {
    _data = _data.copyWith(showBlockedTimes: value);
    await _save();
  }

  Future<void> selectSpace(String id) async {
    if (!_data.spaces.any((space) => space.id == id)) return;
    _data = _data.copyWith(activeSpaceId: id);
    await _save();
  }

  Future<void> createSharedSpace(String name) async {
    if (_data.spaces.any((space) => space.isShared)) return;
    final shared = LifeSpace(
      id: LifeSpace.sharedId,
      name: name.trim().isEmpty ? 'Shared Space' : name.trim(),
      isShared: true,
      members: const [SpaceMember(name: 'You', role: SpaceRole.owner)],
    );
    _data = _data.copyWith(
      spaces: [..._data.spaces, shared],
      activeSpaceId: shared.id,
    );
    await _save();
  }

  Future<void> addMember(String name, SpaceRole role) async {
    final spaces = _data.spaces.map((space) {
      if (space.id != activeSpaceId || !space.isShared) return space;
      return LifeSpace(
        id: space.id,
        name: space.name,
        isShared: true,
        members: [
          ...space.members,
          SpaceMember(name: name.trim(), role: role),
        ],
      );
    }).toList();
    _data = _data.copyWith(spaces: spaces);
    await _save();
  }

  Future<void> setProfileImage(String? path) async {
    _data = _data.copyWith(
      spaces: _data.spaces
          .map(
            (space) => space.id == activeSpaceId
                ? space.copyWith(
                    profileImagePath: path,
                    clearProfileImage: path == null || path.isEmpty,
                  )
                : space,
          )
          .toList(),
    );
    await _save();
  }

  Future<void> _save() async {
    notifyListeners();
    try {
      await repository.save(_data);
      errorMessage = null;
    } on Object catch (error) {
      errorMessage = 'That change could not be saved: $error';
      notifyListeners();
    }
  }

  String _id(String prefix, DateTime now) =>
      '$prefix-${now.microsecondsSinceEpoch.toRadixString(36)}';

  DateTime? _parseDate(String value) {
    final iso = DateTime.tryParse(value);
    if (iso != null) return iso;
    final parts = value.split('/').map(int.tryParse).toList();
    if (parts.length != 3 || parts.any((item) => item == null)) return null;
    final year = parts[2]! < 100 ? 2000 + parts[2]! : parts[2]!;
    return DateTime(year, parts[0]!, parts[1]!);
  }

  (int, int)? _parseTime(String value) {
    final match = RegExp(
      r'^(\d{1,2}):(\d{2})\s*(AM|PM)?$',
    ).firstMatch(value.trim().toUpperCase());
    if (match == null) return null;
    var hour = int.parse(match.group(1)!);
    final minute = int.parse(match.group(2)!);
    final suffix = match.group(3);
    if (minute > 59 || hour > 23) return null;
    if (suffix != null) {
      if (hour < 1 || hour > 12) return null;
      if (suffix == 'AM' && hour == 12) hour = 0;
      if (suffix == 'PM' && hour != 12) hour += 12;
    }
    return (hour, minute);
  }
}
