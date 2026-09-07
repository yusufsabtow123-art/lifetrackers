import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:goal_tracker_poc/data/goal_markdown_codec.dart';
import 'package:goal_tracker_poc/data/goal_repository.dart';
import 'package:goal_tracker_poc/domain/goal.dart';

void main() {
  test('a failed replacement leaves the previous valid goal intact', () async {
    final directory = await Directory.systemTemp.createTemp('goal-atomic-');
    addTearDown(() => directory.delete(recursive: true));
    final original = _goal(name: 'Original');
    await MarkdownGoalRepository(directory).save(original);

    final failing = MarkdownGoalRepository(
      directory,
      writer: const _FailingWriter(),
    );
    await expectLater(
      failing.save(original.copyWith(name: 'Changed')),
      throwsA(isA<FileSystemException>()),
    );

    final loaded = await MarkdownGoalRepository(directory).loadAll();
    expect(loaded.single.name, 'Original');
  });

  test('an interrupted replacement restores its backup on load', () async {
    final directory = await Directory.systemTemp.createTemp('goal-recover-');
    addTearDown(() => directory.delete(recursive: true));
    final repository = MarkdownGoalRepository(directory);
    await repository.save(_goal(name: 'Recoverable'));
    final target = File('${directory.path}${Platform.pathSeparator}goal-1.md');
    final backup = File('${target.path}.bak');
    final temporary = File('${target.path}.tmp');
    await target.rename(backup.path);
    await temporary.writeAsString('partially written');

    final loaded = await MarkdownGoalRepository(directory).loadAll();

    expect(loaded.single.name, 'Recoverable');
    expect(await target.exists(), isTrue);
    expect(await backup.exists(), isFalse);
    expect(await temporary.exists(), isFalse);
  });

  test(
    'one malformed file is reported and does not block valid goals',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'goal-malformed-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final repository = MarkdownGoalRepository(directory);
      await repository.save(_goal(name: 'Valid'));
      final malformed = File(
        '${directory.path}${Platform.pathSeparator}broken.md',
      );
      const originalMalformedText = 'This is not a goal metadata header.';
      await malformed.writeAsString(originalMalformedText);

      final loaded = await repository.loadAll();

      expect(loaded.single.name, 'Valid');
      expect(repository.loadIssues, hasLength(1));
      expect(repository.loadIssues.single.path, malformed.path);
      expect(
        repository.loadIssues.single.message,
        contains('could not be read'),
      );
      expect(await malformed.readAsString(), originalMalformedText);
    },
  );

  test('legacy identifiers are deterministic across repeated loads', () {
    const codec = GoalMarkdownCodec();
    final markdown = codec.encode(
      _goal(
        name: 'Legacy',
        steps: [
          GoalStep(
            id: '',
            title: 'Step without an identifier',
            createdAt: DateTime.utc(2026, 8, 1),
          ),
        ],
        updates: [
          GoalUpdate(
            recordedAt: DateTime.utc(2026, 8, 1, 9),
            text: 'Update without an identifier',
          ),
        ],
      ),
    );
    final withoutIds = markdown
        .replaceFirst('"id":""', '"id":null')
        .replaceFirst('"id":""', '"id":null');

    final first = codec.decode(withoutIds);
    final second = codec.decode(withoutIds);

    expect(first.steps.single.id, isNotEmpty);
    expect(first.steps.single.id, second.steps.single.id);
    expect(first.updates.single.id, isNotEmpty);
    expect(first.updates.single.id, second.updates.single.id);
  });
}

Goal _goal({
  required String name,
  List<GoalStep> steps = const [],
  List<GoalUpdate> updates = const [],
}) => Goal(
  id: 'goal-1',
  name: name,
  status: GoalStatus.active,
  createdAt: DateTime.utc(2026, 8, 1),
  updatedAt: DateTime.utc(2026, 8, 1),
  steps: steps,
  updates: updates,
);

class _FailingWriter implements GoalFileWriter {
  const _FailingWriter();

  @override
  Future<void> write(File target, String contents) {
    throw FileSystemException('Injected write failure', target.path);
  }
}
