import 'package:flutter/foundation.dart';

import '../data/life_repository.dart';
import '../domain/life_data.dart';

class LifeStore extends ChangeNotifier {
  LifeStore(this.repository, {DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  final LifeRepository repository;
  final DateTime Function() _clock;
  LifeData _data = const LifeData();
  bool isLoading = true;
  String? errorMessage;

  LifeData get data => _data;
  String get storagePath => repository.displayPath;
  String get activeSpaceId => _data.activeSpaceId;
  List<LifeTask> get tasks => List.unmodifiable(_data.tasks);
  List<CalendarEntry> get calendar => List.unmodifiable(_data.calendar);
  List<LifeSpace> get spaces => List.unmodifiable(_data.spaces);

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
      _data.calendar
          .where(
            (entry) =>
                entry.spaceId == activeSpaceId &&
                entry.enabled &&
                (_data.showBlockedTimes ||
                    entry.kind != CalendarEntryKind.blockedTime) &&
                entry.occursOn(day),
          )
          .toList(growable: false)
        ..sort((a, b) => a.start.compareTo(b.start));

  Future<void> addTask({
    required String title,
    String notes = '',
    String? goalId,
    DateTime? dueAt,
    TaskRepeat repeat = TaskRepeat.none,
    String location = '',
    String assignee = '',
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
    );
    _data = LifeData(
      tasks: [..._data.tasks, task],
      calendar: _data.calendar,
      spaces: _data.spaces,
      activeSpaceId: activeSpaceId,
      showBlockedTimes: _data.showBlockedTimes,
    );
    await _save();
  }

  Future<void> toggleTask(LifeTask task) async {
    final replacement = task.isCompleted
        ? task.copyWith(clearCompleted: true)
        : task.copyWith(completedAt: _clock());
    await _replaceTask(replacement);
  }

  Future<void> toggleTaskForDate(LifeTask task, DateTime date) async {
    if (task.repeat == TaskRepeat.none) return toggleTask(task);
    final alreadyDone = task.isDoneOn(date);
    final dates = alreadyDone
        ? task.completedDates
              .where(
                (item) =>
                    item.year != date.year ||
                    item.month != date.month ||
                    item.day != date.day,
              )
              .toList()
        : [...task.completedDates, DateTime(date.year, date.month, date.day)];
    await _replaceTask(task.copyWith(completedDates: dates));
  }

  Future<void> deleteTask(LifeTask task) async {
    _data = LifeData(
      tasks: _data.tasks.where((item) => item.id != task.id).toList(),
      calendar: _data.calendar,
      spaces: _data.spaces,
      activeSpaceId: activeSpaceId,
      showBlockedTimes: _data.showBlockedTimes,
    );
    await _save();
  }

  Future<void> _replaceTask(LifeTask task) async {
    _data = LifeData(
      tasks: _data.tasks
          .map((item) => item.id == task.id ? task : item)
          .toList(),
      calendar: _data.calendar,
      spaces: _data.spaces,
      activeSpaceId: activeSpaceId,
      showBlockedTimes: _data.showBlockedTimes,
    );
    await _save();
  }

  Future<void> addCalendarEntry({
    required String title,
    required DateTime start,
    required DateTime end,
    required CalendarEntryKind kind,
    String location = '',
  }) async {
    final entry = CalendarEntry(
      id: _id('calendar', _clock()),
      title: title.trim(),
      start: start,
      end: end,
      kind: kind,
      location: location.trim(),
      spaceId: activeSpaceId,
    );
    _data = LifeData(
      tasks: _data.tasks,
      calendar: [..._data.calendar, entry],
      spaces: _data.spaces,
      activeSpaceId: activeSpaceId,
      showBlockedTimes: _data.showBlockedTimes,
    );
    await _save();
  }

  Future<int> importBlockedSchedule(String text) async {
    final imported = <CalendarEntry>[];
    for (final rawLine in text.split(RegExp(r'[\r\n]+'))) {
      final line = rawLine.trim();
      if (line.isEmpty) continue;
      final parts = line.contains('\t') ? line.split('\t') : line.split(',');
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
      imported.add(
        CalendarEntry(
          id: '${_id('calendar', _clock())}-${imported.length}',
          title: parts.sublist(3).join(',').trim(),
          start: start,
          end: end,
          kind: CalendarEntryKind.blockedTime,
          spaceId: activeSpaceId,
        ),
      );
    }
    if (imported.isEmpty) return 0;
    _data = LifeData(
      tasks: _data.tasks,
      calendar: [..._data.calendar, ...imported],
      spaces: _data.spaces,
      activeSpaceId: activeSpaceId,
      showBlockedTimes: _data.showBlockedTimes,
    );
    await _save();
    return imported.length;
  }

  Future<void> deleteCalendarEntry(CalendarEntry entry) async {
    _data = LifeData(
      tasks: _data.tasks,
      calendar: _data.calendar.where((item) => item.id != entry.id).toList(),
      spaces: _data.spaces,
      activeSpaceId: activeSpaceId,
      showBlockedTimes: _data.showBlockedTimes,
    );
    await _save();
  }

  Future<void> setShowBlockedTimes(bool value) async {
    _data = LifeData(
      tasks: _data.tasks,
      calendar: _data.calendar,
      spaces: _data.spaces,
      activeSpaceId: activeSpaceId,
      showBlockedTimes: value,
    );
    await _save();
  }

  Future<void> selectSpace(String id) async {
    if (!_data.spaces.any((space) => space.id == id)) return;
    _data = LifeData(
      tasks: _data.tasks,
      calendar: _data.calendar,
      spaces: _data.spaces,
      activeSpaceId: id,
      showBlockedTimes: _data.showBlockedTimes,
    );
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
    _data = LifeData(
      tasks: _data.tasks,
      calendar: _data.calendar,
      spaces: [..._data.spaces, shared],
      activeSpaceId: shared.id,
      showBlockedTimes: _data.showBlockedTimes,
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
    _data = LifeData(
      tasks: _data.tasks,
      calendar: _data.calendar,
      spaces: spaces,
      activeSpaceId: activeSpaceId,
      showBlockedTimes: _data.showBlockedTimes,
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
