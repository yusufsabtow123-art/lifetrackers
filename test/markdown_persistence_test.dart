import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:goal_tracker_poc/data/goal_markdown_codec.dart';
import 'package:goal_tracker_poc/data/goal_repository.dart';
import 'package:goal_tracker_poc/domain/goal.dart';
import 'package:goal_tracker_poc/domain/life_data.dart';

void main() {
  test('Markdown remains readable and round-trips all board data', () {
    const codec = GoalMarkdownCodec();
    final goal = Goal(
      id: 'goal-123',
      name: 'Finish the Quran',
      status: GoalStatus.active,
      createdAt: DateTime.utc(2026, 8, 1, 9),
      updatedAt: DateTime.utc(2026, 8, 2, 9),
      completedAmount: 20,
      reminder: const GoalReminder(
        id: 'goal-123-reminder-main',
        message: 'Memorize today’s page',
        frequency: ReminderFrequency.customDays,
        purpose: ReminderPurpose.dailyAction,
        hour: 18,
        minute: 15,
        weekdays: {1, 3, 5},
        snoozedUntil: null,
      ),
      plan: GoalPlan(
        totalAmount: 100,
        unit: 'pages',
        startDate: DateTime(2026, 8, 1),
        deadline: DateTime(2026, 11, 8),
        activeWeekdays: const {1, 2, 3, 4, 5, 6, 7},
        wholeUnits: true,
        acceptedDailyPace: 1,
        initialCompletedAmount: 20,
      ),
      progressHistory: [
        ProgressEntry(
          recordedAt: DateTime.utc(2026, 8, 2, 9),
          change: 20,
          completedAfter: 20,
          note: 'Reviewed the first section.',
        ),
      ],
      dailyActionCompletions: [
        DailyActionCompletion(
          actionDate: DateTime.utc(2026, 8, 2),
          completedAt: DateTime.utc(2026, 8, 2, 9),
          amount: 20,
          note: 'Reviewed the first section.',
          record: TaskCompletionNote(
            day: DateTime.utc(2026, 8, 2),
            recordedAt: DateTime.utc(2026, 8, 2, 9),
            text: 'Reviewed the first section.',
            locationName: 'Masjid Dawah',
            people: const [CompletionPerson(id: 'ahmed', name: 'Ahmed')],
          ),
        ),
      ],
      steps: [
        GoalStep(
          id: 'make-sauce',
          title: 'Make sauce',
          details: 'Use the tomatoes from the market.',
          createdAt: DateTime.utc(2026, 8, 2, 8),
        ),
        GoalStep(
          id: 'buy-cheese',
          title: 'Buy cheese',
          createdAt: DateTime.utc(2026, 8, 2, 8, 5),
          completedAt: DateTime.utc(2026, 8, 2, 8, 30),
        ),
      ],
      updates: [
        GoalUpdate(
          id: 'update-tomatoes',
          recordedAt: DateTime.utc(2026, 8, 2, 8, 20),
          text: 'Got tomatoes',
          stepId: 'make-sauce',
          stepTitle: 'Make sauce',
          editedAt: DateTime.utc(2026, 8, 2, 8, 25),
        ),
      ],
    );

    final markdown = codec.encode(goal);
    expect(markdown, contains('# Finish the Quran'));
    expect(markdown, contains('20 completed'));
    expect(markdown, contains('Reviewed the first section.'));
    expect(markdown, contains('- [ ] Make sauce'));
    expect(markdown, contains('- [x] Buy cheese'));
    expect(markdown, contains('[Make sauce] Got tomatoes'));
    expect(markdown, contains('Details: Use the tomatoes from the market.'));
    expect(markdown, contains('Got tomatoes (edited)'));
    expect(markdown, contains('"step_id":"make-sauce"'));
    final decoded = codec.decode(markdown);
    expect(
      decoded.dailyActionCompletions.single.record!.locationName,
      'Masjid Dawah',
    );
    expect(
      decoded.dailyActionCompletions.single.record!.people.single.name,
      'Ahmed',
    );
    expect(decoded.name, goal.name);
    expect(decoded.status, GoalStatus.active);
    final pausedMarkdown = codec.encode(
      goal.copyWith(status: GoalStatus.paused),
    );
    expect(pausedMarkdown, contains('status: "paused"'));
    final legacyBlocked = pausedMarkdown.replaceFirst('"paused"', '"blocked"');
    expect(codec.decode(legacyBlocked).status, GoalStatus.paused);
    expect(decoded.plan?.totalAmount, 100);
    expect(decoded.plan?.initialCompletedAmount, 20);
    expect(markdown, contains('initial_completed_amount: 20.0'));
    expect(markdown, contains('Memorize today’s page'));
    expect(decoded.reminder?.frequency, ReminderFrequency.customDays);
    expect(decoded.reminder?.hour, 18);
    expect(decoded.reminder?.minute, 15);
    expect(decoded.reminder?.weekdays, {1, 3, 5});
    expect(decoded.reminder?.message, 'Memorize today’s page');
    expect(decoded.reminder?.id, 'goal-123-reminder-main');
    expect(decoded.reminder?.purpose, ReminderPurpose.dailyAction);
    final legacyWithoutStartingProgress = markdown.replaceFirst(
      RegExp(r'initial_completed_amount:.*\n'),
      '',
    );
    expect(
      codec.decode(legacyWithoutStartingProgress).plan?.initialCompletedAmount,
      0,
    );
    expect(decoded.plan?.activeWeekdays, goal.plan?.activeWeekdays);
    expect(decoded.progressHistory.single.change, 20);
    expect(decoded.progressHistory.single.note, 'Reviewed the first section.');
    expect(
      decoded.dailyActionCompletions.single.note,
      'Reviewed the first section.',
    );
    expect(decoded.steps, hasLength(2));
    expect(decoded.steps.first.title, 'Make sauce');
    expect(decoded.steps.first.details, 'Use the tomatoes from the market.');
    expect(decoded.steps.first.isCompleted, isFalse);
    expect(decoded.steps.last.isCompleted, isTrue);
    expect(decoded.updates.single.text, 'Got tomatoes');
    expect(decoded.updates.single.id, 'update-tomatoes');
    expect(decoded.updates.single.editedAt, DateTime.utc(2026, 8, 2, 8, 25));
    expect(decoded.updates.single.stepId, 'make-sauce');
    expect(decoded.updates.single.stepTitle, 'Make sauce');

    final legacyWithoutStepsOrUpdates = markdown
        .replaceFirst(RegExp(r'^steps:.*\n', multiLine: true), '')
        .replaceFirst(RegExp(r'^updates:.*\n', multiLine: true), '');
    final legacyDecoded = codec.decode(legacyWithoutStepsOrUpdates);
    expect(legacyDecoded.steps, isEmpty);
    expect(legacyDecoded.updates, isEmpty);
  });

  test(
    'repository reconstructs the board from one Markdown file per goal',
    () async {
      final directory = await Directory.systemTemp.createTemp('goal-poc-test-');
      addTearDown(() => directory.delete(recursive: true));
      final repository = MarkdownGoalRepository(directory);
      final first = Goal(
        id: 'one',
        name: 'First',
        status: GoalStatus.ideas,
        createdAt: DateTime.utc(2026, 1, 1),
        updatedAt: DateTime.utc(2026, 1, 1),
      );
      final second = Goal(
        id: 'two',
        name: 'Second',
        status: GoalStatus.completed,
        createdAt: DateTime.utc(2026, 1, 2),
        updatedAt: DateTime.utc(2026, 1, 2),
      );

      await repository.save(first);
      await repository.save(second);
      final files = await directory
          .list()
          .where((entry) => entry is File)
          .toList();
      final loaded = await MarkdownGoalRepository(directory).loadAll();

      expect(files, hasLength(2));
      expect(loaded.map((goal) => goal.name), ['First', 'Second']);
      expect(loaded.last.status, GoalStatus.completed);
    },
  );
  test(
    'trash moves Markdown files recoverably and delete removes them',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'goal-trash-test-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final repository = MarkdownGoalRepository(directory);
      final goal = Goal(
        id: 'recoverable',
        name: 'Recover me',
        status: GoalStatus.active,
        createdAt: DateTime.utc(2026, 8, 5),
        updatedAt: DateTime.utc(2026, 8, 5),
      );
      final activeFile = File(
        '${directory.path}${Platform.pathSeparator}recoverable.md',
      );
      final trashFile = File(
        '${directory.path}${Platform.pathSeparator}trash'
        '${Platform.pathSeparator}recoverable.md',
      );

      await repository.save(goal);
      expect(await activeFile.exists(), isTrue);

      final trashed = goal.copyWith(
        trashedAt: DateTime.utc(2026, 8, 5, 12),
        updatedAt: DateTime.utc(2026, 8, 5, 12),
      );
      await repository.save(trashed);

      expect(await activeFile.exists(), isFalse);
      expect(await trashFile.exists(), isTrue);
      expect((await repository.loadAll()).single.isTrashed, isTrue);

      final restored = trashed.copyWith(
        clearTrashedAt: true,
        updatedAt: DateTime.utc(2026, 8, 5, 13),
      );
      await repository.save(restored);
      expect(await activeFile.exists(), isTrue);
      expect(await trashFile.exists(), isFalse);

      await repository.save(trashed);
      await repository.delete(trashed);
      expect(await activeFile.exists(), isFalse);
      expect(await trashFile.exists(), isFalse);
    },
  );
}
