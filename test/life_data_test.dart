import 'package:flutter_test/flutter_test.dart';
import 'package:goal_tracker_poc/data/app_settings_repository.dart';
import 'package:goal_tracker_poc/app/life_store.dart';
import 'package:goal_tracker_poc/data/life_repository.dart';
import 'package:goal_tracker_poc/domain/life_data.dart';

void main() {
  test(
    'Salah settings create five virtual protected blocks without duplicates',
    () {
      final settings = const AppSettingsData().copyWith(salahEnabled: true);
      final store = LifeStore(MemoryLifeRepository(), settings: settings);
      final day = DateTime(2026, 9, 10);

      final first = store.entriesFor(day);
      final second = store.entriesFor(day);

      expect(first.map((entry) => entry.title), [
        'Fajr',
        'Dhuhr',
        'Asr',
        'Maghrib',
        'Isha',
      ]);
      expect(
        first.every((entry) => entry.kind == CalendarEntryKind.blockedTime),
        isTrue,
      );
      expect(first.map((entry) => entry.id).toSet().length, 5);
      expect(second.map((entry) => entry.id), first.map((entry) => entry.id));
      expect(store.calendar, isEmpty);
    },
  );

  test(
    'disabling Salah removes virtual blocks without touching calendar data',
    () {
      final store = LifeStore(
        MemoryLifeRepository(),
        settings: const AppSettingsData().copyWith(salahEnabled: true),
      );
      expect(store.entriesFor(DateTime(2026, 9, 10)), hasLength(5));
      store.applySettings(const AppSettingsData());
      expect(store.entriesFor(DateTime(2026, 9, 10)), isEmpty);
    },
  );

  test(
    'Salah stays visible when custom blocks are hidden and follows the active space',
    () async {
      final day = DateTime(2026, 9, 10);
      final repository = MemoryLifeRepository(
        LifeData(
          spaces: const [
            LifeSpace(
              id: LifeSpace.personalId,
              name: 'Personal',
              isShared: false,
            ),
            LifeSpace(id: 'family', name: 'Family', isShared: true),
          ],
          activeSpaceId: 'family',
          showBlockedTimes: false,
          calendar: [
            CalendarEntry(
              id: 'hidden-custom-block',
              title: 'Private block',
              start: DateTime(2026, 9, 10, 9),
              end: DateTime(2026, 9, 10, 10),
              kind: CalendarEntryKind.blockedTime,
              spaceId: 'family',
            ),
          ],
        ),
      );
      final store = LifeStore(
        repository,
        settings: const AppSettingsData().copyWith(salahEnabled: true),
      );
      await store.load();

      final entries = store.entriesFor(day);

      expect(entries.map((entry) => entry.title), [
        'Fajr',
        'Dhuhr',
        'Asr',
        'Maghrib',
        'Isha',
      ]);
      expect(entries.every((entry) => entry.spaceId == 'family'), isTrue);
      expect(
        entries.any((entry) => entry.id == 'hidden-custom-block'),
        isFalse,
      );
    },
  );

  test('Salah produces five changing protected blocks for the full year', () {
    final store = LifeStore(
      MemoryLifeRepository(),
      settings: const AppSettingsData().copyWith(salahEnabled: true),
    );
    final ids = <String>{};
    final fajrMinutes = <int>{};
    for (
      var day = DateTime(2026);
      day.year == 2026;
      day = day.add(const Duration(days: 1))
    ) {
      final entries = store.entriesFor(day);
      expect(entries, hasLength(5), reason: '$day');
      expect(
        entries.every((entry) => entry.kind == CalendarEntryKind.blockedTime),
        isTrue,
      );
      ids.addAll(entries.map((entry) => entry.id));
      final fajr = entries.firstWhere((entry) => entry.title == 'Fajr').start;
      fajrMinutes.add(fajr.hour * 60 + fajr.minute);
    }
    expect(ids, hasLength(365 * 5));
    expect(fajrMinutes.length, greaterThan(30));
  });

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

  test('task completion notes remain attached to the correct day', () async {
    final repository = MemoryLifeRepository();
    final store = LifeStore(repository, clock: () => DateTime(2027, 1, 5, 12));
    await store.load();
    await store.addTask(
      title: 'Practice',
      dueAt: DateTime(2027, 1, 5),
      repeat: TaskRepeat.daily,
    );

    await store.completeTaskForDate(
      store.tasks.single,
      DateTime(2027, 1, 5),
      note: 'Used the short exercise first.',
      attachments: const [
        LifeAttachment(
          id: 'proof-photo',
          name: 'practice.jpg',
          path: '/private/practice.jpg',
          kind: LifeAttachmentKind.image,
          mimeType: 'image/jpeg',
          sizeBytes: 1200,
        ),
      ],
    );

    final reloaded = LifeData.fromJson(repository.data.toJson());
    final task = reloaded.tasks.single;
    expect(task.isDoneOn(DateTime(2027, 1, 5)), isTrue);
    expect(
      task.completionNoteFor(DateTime(2027, 1, 5))?.text,
      'Used the short exercise first.',
    );
    expect(
      task.completionNoteFor(DateTime(2027, 1, 5))?.attachments.single.name,
      'practice.jpg',
    );
    expect(reloaded.log.single.attachments.single.id, 'proof-photo');
  });

  test('journal entries preserve rich attachments through storage', () async {
    final repository = MemoryLifeRepository();
    final store = LifeStore(repository, clock: () => DateTime(2027, 1, 6, 9));
    await store.load();

    await store.addJournalEntry(
      'A useful reflection with https://example.com',
      attachments: const [
        LifeAttachment(
          id: 'journal-file',
          name: 'reflection.pdf',
          path: '/private/reflection.pdf',
          kind: LifeAttachmentKind.file,
          mimeType: 'application/pdf',
          sizeBytes: 4000,
        ),
      ],
    );

    final reloaded = LifeData.fromJson(repository.data.toJson());
    expect(reloaded.log.single.text, contains('https://example.com'));
    expect(reloaded.log.single.attachments.single.id, 'journal-file');
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

  test('calendar notes remain attached to their event', () async {
    final repository = MemoryLifeRepository();
    final store = LifeStore(repository);
    await store.load();
    await store.addCalendarEntry(
      title: 'Client outreach',
      start: DateTime(2027, 3, 1, 11),
      end: DateTime(2027, 3, 1, 12),
      kind: CalendarEntryKind.event,
      notes: 'Deep work on Q2 planning and strategy. No meetings.',
    );

    final restored = LifeData.fromJson(repository.data.toJson());
    expect(
      restored.calendar.single.notes,
      'Deep work on Q2 planning and strategy. No meetings.',
    );
  });

  test(
    'advanced schedule import preserves category details and skips duplicates',
    () async {
      final repository = MemoryLifeRepository();
      final store = LifeStore(repository);
      await store.load();
      const row =
          '2026-10-01\t11:00 PM\t7:00 AM\tWork\tBoston Scientific\tred\tweekly\tevent';

      expect(await store.importBlockedSchedule(row), 1);
      expect(await store.importBlockedSchedule(row), 0);

      final entry = store.calendar.single;
      expect(entry.location, 'Boston Scientific');
      expect(entry.colorValue, 0xFFE05D62);
      expect(entry.repeat, CalendarRepeat.weekly);
      expect(entry.kind, CalendarEntryKind.event);
    },
  );

  test('weekly overnight events appear on both calendar days', () async {
    final entry = CalendarEntry(
      id: 'overnight-work',
      title: 'Work',
      start: DateTime(2026, 9, 13, 23),
      end: DateTime(2026, 9, 14, 7),
      kind: CalendarEntryKind.event,
      repeat: CalendarRepeat.weekly,
    );

    expect(entry.occursOn(DateTime(2026, 9, 13)), isTrue);
    expect(entry.occursOn(DateTime(2026, 9, 14)), isTrue);
    expect(
      entry.occurrenceStart(DateTime(2026, 9, 14)),
      DateTime(2026, 9, 13, 23),
    );
    expect(
      entry.occurrenceEnd(DateTime(2026, 9, 14)),
      DateTime(2026, 9, 14, 7),
    );
  });

  test('custom weekly recurrence honors interval, weekdays, and end date', () {
    final entry = CalendarEntry(
      id: 'custom-weekly',
      title: 'Workout',
      start: DateTime(2026, 9, 7, 16, 45),
      end: DateTime(2026, 9, 7, 17, 45),
      kind: CalendarEntryKind.event,
      repeat: CalendarRepeat.weekly,
      repeatInterval: 2,
      repeatWeekdays: const {DateTime.monday, DateTime.friday},
      repeatUntil: DateTime(2026, 10, 5),
    );

    expect(entry.occursOn(DateTime(2026, 9, 7)), isTrue);
    expect(entry.occursOn(DateTime(2026, 9, 11)), isTrue);
    expect(entry.occursOn(DateTime(2026, 9, 14)), isFalse);
    expect(entry.occursOn(DateTime(2026, 9, 21)), isTrue);
    expect(entry.occursOn(DateTime(2026, 10, 9)), isFalse);
  });

  test('monthly and yearly recurrence survive storage', () {
    final monthly = CalendarEntry(
      id: 'monthly',
      title: 'Monthly review',
      start: DateTime(2026, 9, 9, 18),
      end: DateTime(2026, 9, 9, 19),
      kind: CalendarEntryKind.event,
      repeat: CalendarRepeat.monthly,
      repeatInterval: 2,
    );
    final restored = CalendarEntry.fromJson(monthly.toJson());

    expect(restored.occursOn(DateTime(2026, 11, 9)), isTrue);
    expect(restored.occursOn(DateTime(2026, 10, 9)), isFalse);
    expect(
      monthly
          .copyWith(repeat: CalendarRepeat.yearly, repeatInterval: 1)
          .occursOn(DateTime(2027, 9, 9)),
      isTrue,
    );
  });
}
