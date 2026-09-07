import 'dart:io';

import '../domain/goal.dart';
import 'app_data_path.dart';
import 'goal_markdown_codec.dart';

abstract interface class GoalRepository {
  String get displayPath;

  List<GoalLoadIssue> get loadIssues;

  Future<List<Goal>> loadAll();

  Future<void> save(Goal goal);

  Future<void> delete(Goal goal);
}

class GoalLoadIssue {
  const GoalLoadIssue({required this.path, required this.message});

  final String path;
  final String message;
}

abstract interface class GoalFileWriter {
  Future<void> write(File target, String contents);
}

class AtomicGoalFileWriter implements GoalFileWriter {
  const AtomicGoalFileWriter();

  @override
  Future<void> write(File target, String contents) async {
    final temporary = File('${target.path}.tmp');
    final backup = File('${target.path}.bak');
    await target.parent.create(recursive: true);
    if (await temporary.exists()) await temporary.delete();
    await temporary.writeAsString(contents, flush: true);

    var movedPreviousFile = false;
    try {
      if (await backup.exists()) await backup.delete();
      if (await target.exists()) {
        await target.rename(backup.path);
        movedPreviousFile = true;
      }
      await temporary.rename(target.path);
      if (await backup.exists()) {
        try {
          await backup.delete();
        } on FileSystemException {
          // A stale backup is harmless and is cleaned on the next load.
        }
      }
    } on Object {
      if (!await target.exists() &&
          movedPreviousFile &&
          await backup.exists()) {
        await backup.rename(target.path);
      }
      rethrow;
    } finally {
      if (await temporary.exists()) {
        try {
          await temporary.delete();
        } on FileSystemException {
          // Recovery removes an interrupted temporary file on the next load.
        }
      }
    }
  }
}

class MarkdownGoalRepository implements GoalRepository {
  MarkdownGoalRepository(
    this.directory, {
    GoalMarkdownCodec? codec,
    GoalFileWriter? writer,
  }) : codec = codec ?? const GoalMarkdownCodec(),
       writer = writer ?? const AtomicGoalFileWriter();

  final Directory directory;
  final GoalMarkdownCodec codec;
  final GoalFileWriter writer;
  final List<GoalLoadIssue> _loadIssues = [];

  static Future<MarkdownGoalRepository> createDefault() async {
    final root = await resolveGoalTrackerDataRoot();
    final directory = Directory('$root${Platform.pathSeparator}goals');
    return MarkdownGoalRepository(directory);
  }

  @override
  String get displayPath => directory.path;

  @override
  List<GoalLoadIssue> get loadIssues => List.unmodifiable(_loadIssues);

  Directory get _trashDirectory =>
      Directory('${directory.path}${Platform.pathSeparator}trash');

  @override
  Future<List<Goal>> loadAll() async {
    await directory.create(recursive: true);
    await _trashDirectory.create(recursive: true);
    _loadIssues.clear();
    await _recoverInterruptedWrites(directory);
    await _recoverInterruptedWrites(_trashDirectory);
    final goalsById = <String, Goal>{};
    await _loadDirectory(directory, goalsById);
    await _loadDirectory(_trashDirectory, goalsById);
    final goals = goalsById.values.toList();
    goals.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return goals;
  }

  @override
  Future<void> save(Goal goal) async {
    final activeFile = _fileFor(goal, directory);
    final trashFile = _fileFor(goal, _trashDirectory);
    final target = goal.isTrashed ? trashFile : activeFile;
    final stale = goal.isTrashed ? activeFile : trashFile;
    final contents = codec.encode(goal);
    codec.decode(contents);
    await writer.write(target, contents);
    if (await stale.exists()) {
      await stale.delete();
    }
  }

  @override
  Future<void> delete(Goal goal) async {
    for (final file in [
      _fileFor(goal, directory),
      _fileFor(goal, _trashDirectory),
    ]) {
      if (await file.exists()) await file.delete();
    }
  }

  Future<void> _loadDirectory(
    Directory source,
    Map<String, Goal> goalsById,
  ) async {
    await for (final entity in source.list()) {
      if (entity is! File || !entity.path.toLowerCase().endsWith('.md')) {
        continue;
      }
      try {
        final goal = codec.decode(await entity.readAsString());
        final existing = goalsById[goal.id];
        if (existing == null || goal.updatedAt.isAfter(existing.updatedAt)) {
          goalsById[goal.id] = goal;
        }
        if (existing != null) {
          _loadIssues.add(
            GoalLoadIssue(
              path: entity.path,
              message:
                  'Another file has the same goal identifier. The newest '
                  'recognized copy was loaded; neither file was changed.',
            ),
          );
        }
      } on Object catch (error) {
        _loadIssues.add(
          GoalLoadIssue(
            path: entity.path,
            message: 'This goal could not be read: $error',
          ),
        );
      }
    }
  }

  Future<void> _recoverInterruptedWrites(Directory source) async {
    await for (final entity in source.list()) {
      if (entity is! File) continue;
      if (entity.path.endsWith('.md.bak')) {
        final target = File(
          entity.path.substring(0, entity.path.length - '.bak'.length),
        );
        if (await target.exists()) {
          await entity.delete();
        } else {
          await entity.rename(target.path);
        }
      } else if (entity.path.endsWith('.md.tmp')) {
        await entity.delete();
      }
    }
  }

  File _fileFor(Goal goal, Directory parent) =>
      File('${parent.path}${Platform.pathSeparator}${goal.id}.md');
}

class MemoryGoalRepository implements GoalRepository {
  MemoryGoalRepository([Iterable<Goal> seed = const []])
    : _goals = {for (final goal in seed) goal.id: goal};

  final Map<String, Goal> _goals;

  @override
  List<GoalLoadIssue> get loadIssues => const [];

  @override
  String get displayPath => 'In-memory test storage';

  @override
  Future<List<Goal>> loadAll() async => _goals.values.toList();

  @override
  Future<void> save(Goal goal) async => _goals[goal.id] = goal;

  @override
  Future<void> delete(Goal goal) async => _goals.remove(goal.id);
}
