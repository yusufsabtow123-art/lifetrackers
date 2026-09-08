import 'package:flutter_test/flutter_test.dart';
import 'package:goal_tracker_poc/app/life_store.dart';
import 'package:goal_tracker_poc/data/life_repository.dart';
import 'package:goal_tracker_poc/domain/life_data.dart';

void main() {
  test('repeating tasks are completed per day', () async {
    final repository = MemoryLifeRepository();
    final store = LifeStore(repository, clock: () => DateTime(2027, 1, 5, 12));
    await store.load();
    await store.addTask(
      title: 'Read one page',
      dueAt: DateTime(2027, 1, 5),
      repeat: TaskRepeat.daily,
    );

    final task = store.tasks.single;
    await store.toggleTaskForDate(task, DateTime(2027, 1, 5));

    expect(store.tasks.single.isDoneOn(DateTime(2027, 1, 5)), isTrue);
    expect(store.tasks.single.isDoneOn(DateTime(2027, 1, 6)), isFalse);
  });

  test('tasks can be edited without losing their completion history', () async {
    final repository = MemoryLifeRepository();
    final store = LifeStore(repository, clock: () => DateTime(2027, 1, 5, 12));
    await store.load();
    await store.addTask(
      title: 'Old task name',
      dueAt: DateTime(2027, 1, 5),
      repeat: TaskRepeat.daily,
    );
    await store.toggleTaskForDate(store.tasks.single, DateTime(2027, 1, 5));

    await store.updateTask(
      store.tasks.single.copyWith(title: 'Updated task name'),
    );

    expect(store.tasks.single.title, 'Updated task name');
    expect(store.tasks.single.isDoneOn(DateTime(2027, 1, 5)), isTrue);
  });

  test('imports a changing blocked-time schedule', () async {
    final repository = MemoryLifeRepository();
    final store = LifeStore(repository);
    await store.load();

    final count = await store.importBlockedSchedule('''
2027-01-01,5:45 AM,6:05 AM,Fajr
2027-01-02,5:46 AM,6:06 AM,Fajr
bad row
''');

    expect(count, 2);
    expect(store.calendar, hasLength(2));
    expect(store.calendar.first.kind, CalendarEntryKind.blockedTime);
    expect(store.entriesFor(DateTime(2027, 1, 2)).single.start.minute, 46);
  });

  test('blocked times can all be hidden without deleting them', () async {
    final repository = MemoryLifeRepository();
    final store = LifeStore(repository);
    await store.load();
    await store.addCalendarEntry(
      title: 'Protected time',
      start: DateTime(2027, 2, 1, 9),
      end: DateTime(2027, 2, 1, 10),
      kind: CalendarEntryKind.blockedTime,
    );
    await store.setShowBlockedTimes(false);

    expect(store.entriesFor(DateTime(2027, 2, 1)), isEmpty);
    expect(store.calendar, hasLength(1));
  });

  test('daily blocked time appears at the right time on future days', () async {
    final repository = MemoryLifeRepository();
    final store = LifeStore(repository);
    await store.load();
    await store.addCalendarEntry(
      title: 'Protected focus time',
      start: DateTime(2027, 2, 1, 9, 30),
      end: DateTime(2027, 2, 1, 10, 15),
      kind: CalendarEntryKind.blockedTime,
      repeat: CalendarRepeat.daily,
    );

    final entry = store.entriesFor(DateTime(2027, 2, 8)).single;
    expect(entry.occurrenceStart(DateTime(2027, 2, 8)).hour, 9);
    expect(entry.occurrenceStart(DateTime(2027, 2, 8)).minute, 30);
    expect(entry.occurrenceEnd(DateTime(2027, 2, 8)).hour, 10);
    expect(entry.occurrenceEnd(DateTime(2027, 2, 8)).minute, 15);
  });

  test('calendar entries can be edited without creating duplicates', () async {
    final repository = MemoryLifeRepository();
    final store = LifeStore(repository);
    await store.load();
    await store.addCalendarEntry(
      title: 'Old title',
      start: DateTime(2027, 3, 1, 8),
      end: DateTime(2027, 3, 1, 9),
      kind: CalendarEntryKind.event,
    );

    await store.updateCalendarEntry(
      store.calendar.single.copyWith(title: 'Updated title'),
    );

    expect(store.calendar, hasLength(1));
    expect(store.calendar.single.title, 'Updated title');
  });

  test('calendar colors survive storage and editing', () async {
    final original = CalendarEntry(
      id: 'colored-entry',
      title: 'Focus time',
      start: DateTime(2027, 3, 1, 8),
      end: DateTime(2027, 3, 1, 9),
      kind: CalendarEntryKind.blockedTime,
      colorValue: 0xFF45C7BA,
    );

    final restored = CalendarEntry.fromJson(original.toJson());

    expect(restored.colorValue, 0xFF45C7BA);
    expect(restored.copyWith(colorValue: 0xFF9B66D9).colorValue, 0xFF9B66D9);
  });
}
