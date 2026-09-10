import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:goal_tracker_poc/app/life_store.dart';
import 'package:goal_tracker_poc/data/life_repository.dart';
import 'package:goal_tracker_poc/domain/life_data.dart';
import 'package:goal_tracker_poc/ui/app_theme.dart';
import 'package:goal_tracker_poc/ui/task_completion_page.dart';

void main() {
  test('structured completion record remains backward compatible', () {
    final oldRecord = TaskCompletionNote.fromJson({
      'day': '2026-09-08T00:00:00.000',
      'recordedAt': '2026-09-08T15:07:00.000',
      'text': 'Older note',
    });

    expect(oldRecord.outcome, TaskCompletionOutcome.completed);
    expect(oldRecord.effort, TaskCompletionEffort.normal);
    expect(oldRecord.people, isEmpty);

    final record = oldRecord.copyWith(
      actualStartAt: DateTime(2026, 9, 8, 14, 18),
      actualEndAt: DateTime(2026, 9, 8, 15, 7),
      scheduledStartAt: DateTime(2026, 9, 8, 14),
      scheduledEndAt: DateTime(2026, 9, 8, 15),
      locationName: 'Masjid Dawah',
      locationAddress: '605 Fairview Ave N, Saint Paul, MN',
      people: const [CompletionPerson(id: 'ahmed', name: 'Ahmed')],
      effort: TaskCompletionEffort.hard,
    );
    final restored = TaskCompletionNote.fromJson(record.toJson());

    expect(restored.actualEndAt, DateTime(2026, 9, 8, 15, 7));
    expect(restored.isLate, isTrue);
    expect(restored.locationName, 'Masjid Dawah');
    expect(restored.people.single.name, 'Ahmed');
    expect(restored.effort, TaskCompletionEffort.hard);
  });

  test('saving a completion record persists every structured field', () async {
    final task = LifeTask(
      id: 'quran',
      title: 'Memorize 1 Quran page',
      createdAt: DateTime(2026, 9, 1),
      dueAt: DateTime(2026, 9, 8, 14),
    );
    final repository = MemoryLifeRepository(LifeData(tasks: [task]));
    final store = LifeStore(repository);
    await store.load();
    final record = TaskCompletionNote(
      day: DateTime(2026, 9, 8),
      recordedAt: DateTime(2026, 9, 8, 15, 7),
      text: 'Memorized two pages.',
      outcome: TaskCompletionOutcome.partiallyCompleted,
      actualStartAt: DateTime(2026, 9, 8, 14, 18),
      actualEndAt: DateTime(2026, 9, 8, 15, 7),
      scheduledStartAt: DateTime(2026, 9, 8, 14),
      scheduledEndAt: DateTime(2026, 9, 8, 15),
      locationName: 'Masjid Dawah',
      locationAddress: '605 Fairview Ave N, Saint Paul, MN',
      attachments: const [
        LifeAttachment(
          id: 'notes',
          name: 'revision-notes.pdf',
          path: 'revision-notes.pdf',
          kind: LifeAttachmentKind.file,
          sizeBytes: 250880,
        ),
      ],
      people: const [
        CompletionPerson(id: 'ahmed', name: 'Ahmed', phone: '555-0100'),
      ],
      effort: TaskCompletionEffort.hard,
    );

    await store.saveTaskCompletionRecord(task, record);

    final savedTask = repository.data.tasks.single;
    final saved = savedTask.completionNotes.single;
    expect(savedTask.isCompleted, isTrue);
    expect(saved.outcome, TaskCompletionOutcome.partiallyCompleted);
    expect(saved.text, 'Memorized two pages.');
    expect(saved.actualStartAt, DateTime(2026, 9, 8, 14, 18));
    expect(saved.locationName, 'Masjid Dawah');
    expect(saved.attachments.single.name, 'revision-notes.pdf');
    expect(saved.people.single.phone, '555-0100');
    expect(saved.effort, TaskCompletionEffort.hard);
  });

  testWidgets('completion record follows the approved information hierarchy', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final repository = MemoryLifeRepository();
    final store = LifeStore(repository);
    await store.load();
    final task = LifeTask(
      id: 'quran',
      title: 'Memorize 1 Quran page',
      createdAt: DateTime(2026, 9, 1),
      dueAt: DateTime(2026, 9, 8, 14),
      completedAt: DateTime(2026, 9, 8, 15, 7),
      completionNotes: [
        TaskCompletionNote(
          day: DateTime(2026, 9, 8),
          recordedAt: DateTime(2026, 9, 8, 15, 7),
          text:
              'Memorized two pages and reviewed yesterday’s page. The second page needs more revision.',
          scheduledStartAt: DateTime(2026, 9, 8, 14),
          scheduledEndAt: DateTime(2026, 9, 8, 15),
          actualStartAt: DateTime(2026, 9, 8, 14, 18),
          actualEndAt: DateTime(2026, 9, 8, 15, 7),
          locationName: 'Masjid Dawah',
          locationAddress: '605 Fairview Ave N, Saint Paul, MN',
          people: const [CompletionPerson(id: 'ahmed', name: 'Ahmed')],
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(brightness: Brightness.dark),
        home: TaskCompletionPage(
          store: store,
          task: task,
          day: DateTime(2026, 9, 8),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Completion record'), findsOneWidget);
    expect(find.text('Memorize 1 Quran page'), findsOneWidget);
    expect(find.text('Completed'), findsWidgets);
    expect(find.text('Late'), findsOneWidget);
    expect(find.text('49 min actual'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Masjid Dawah'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Masjid Dawah'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Save completion'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Save completion'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
