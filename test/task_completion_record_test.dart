import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:goal_tracker_poc/app/life_store.dart';
import 'package:goal_tracker_poc/app/goal_store.dart';
import 'package:goal_tracker_poc/data/goal_repository.dart';
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
      amountCompleted: 1.5,
    );
    final restored = TaskCompletionNote.fromJson(record.toJson());

    expect(restored.actualEndAt, DateTime(2026, 9, 8, 15, 7));
    expect(restored.isLate, isTrue);
    expect(restored.locationName, 'Masjid Dawah');
    expect(restored.people.single.name, 'Ahmed');
    expect(restored.effort, TaskCompletionEffort.hard);
    expect(restored.amountCompleted, 1.5);
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

  testWidgets(
    'partial completion without a numeric target requires and reveals notes',
    (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final task = LifeTask(
        id: 'call',
        title: 'Call Ahmed',
        createdAt: DateTime(2026, 9, 11),
        dueAt: DateTime(2026, 9, 11, 10, 30),
      );
      final repository = MemoryLifeRepository(LifeData(tasks: [task]));
      final store = LifeStore(repository);
      await store.load();

      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(),
          home: TaskCompletionPage(
            store: store,
            task: task,
            day: DateTime(2026, 9, 11),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const Key('completion-outcome-partiallyCompleted')),
      );
      await tester.pumpAndSettle();
      expect(find.text('Partially completed'), findsNWidgets(2));
      final save = tester.widget<FilledButton>(
        find.byKey(const Key('save-completion-record')),
      );
      save.onPressed!();
      await tester.pumpAndSettle();

      expect(find.textContaining('Not completed'), findsOneWidget);
      expect(find.textContaining('A note is required'), findsOneWidget);
      expect(repository.data.tasks.single.isCompleted, isFalse);

      await tester.enterText(
        find.byKey(const Key('completion-record-notes')),
        'Reached Ahmed but need to follow up tomorrow.',
      );
      await tester.tap(find.byKey(const Key('save-completion-record')));
      await tester.pumpAndSettle();
      expect(repository.data.tasks.single.isCompleted, isTrue);
    },
  );

  testWidgets('numeric partial goal completion saves the entered amount', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final goals = GoalStore(
      repository: MemoryGoalRepository(),
      clock: () => DateTime(2026, 9, 11, 9),
    );
    await goals.load();
    final goal = await goals.createPlanned(
      name: 'Memorize the Quran',
      amount: 604,
      unit: 'pages',
      startDate: DateTime(2026, 9, 11),
      deadline: DateTime(2026, 12, 31),
      wholeUnits: true,
    );
    final planned = goals.calculator.actionForDate(goal, goals.today);

    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: TaskCompletionPage.forGoal(
          goalStore: goals,
          goal: goal,
          day: goals.today,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const Key('completion-outcome-partiallyCompleted')),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('completion-partial-amount')),
      '${planned / 2}',
    );
    tester
        .widget<FilledButton>(find.byKey(const Key('save-completion-record')))
        .onPressed!();
    await tester.pumpAndSettle();

    final saved = goals.goalById(goal.id)!;
    expect(
      saved.completionFor(goals.today)?.amount,
      closeTo(planned / 2, .001),
    );
    expect(
      saved.completionFor(goals.today)?.record?.amountCompleted,
      closeTo(planned / 2, .001),
    );
  });
}
