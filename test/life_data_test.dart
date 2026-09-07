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
}
