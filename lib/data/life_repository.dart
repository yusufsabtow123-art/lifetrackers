import 'dart:convert';
import 'dart:io';

import '../domain/life_data.dart';
import 'app_data_path.dart';
import 'goal_repository.dart';

abstract interface class LifeRepository {
  String get displayPath;
  Future<LifeData> load();
  Future<void> save(LifeData data);
}

class MarkdownLifeRepository implements LifeRepository {
  MarkdownLifeRepository(this.file, {GoalFileWriter? writer})
    : writer = writer ?? const AtomicGoalFileWriter();

  final File file;
  final GoalFileWriter writer;

  static Future<MarkdownLifeRepository> createDefault() async {
    final root = await resolveGoalTrackerDataRoot();
    return MarkdownLifeRepository(
      File('$root${Platform.pathSeparator}life-tracker.md'),
    );
  }

  @override
  String get displayPath => file.path;

  @override
  Future<LifeData> load() async {
    if (!await file.exists()) return const LifeData();
    final text = await file.readAsString();
    final match = RegExp(
      r'<!-- LIFE_TRACKER_DATA\s*(\{[\s\S]*\})\s*-->',
    ).firstMatch(text);
    if (match == null) return const LifeData();
    final decoded = jsonDecode(match.group(1)!) as Map<String, Object?>;
    return LifeData.fromJson(decoded);
  }

  @override
  Future<void> save(LifeData data) async {
    final buffer = StringBuffer('# Life Tracker\n\n');
    buffer.writeln(
      'This readable file contains your tasks, calendar, and spaces.',
    );
    buffer.writeln();
    buffer.writeln('## Tasks');
    if (data.tasks.isEmpty) buffer.writeln('- No tasks yet.');
    for (final task in data.tasks) {
      buffer.writeln('- [${task.isCompleted ? 'x' : ' '}] ${task.title}');
      for (final note in task.completionNotes) {
        buffer.writeln(
          '  - ${note.day.toIso8601String().split('T').first}: ${note.text}',
        );
      }
    }
    buffer.writeln();
    buffer.writeln('## Calendar');
    if (data.calendar.isEmpty) buffer.writeln('- No calendar entries yet.');
    for (final entry in data.calendar) {
      buffer.writeln('- ${entry.start.toIso8601String()} — ${entry.title}');
    }
    buffer.writeln();
    buffer.writeln('<!-- LIFE_TRACKER_DATA');
    buffer.writeln(const JsonEncoder.withIndent('  ').convert(data.toJson()));
    buffer.writeln('-->');
    await writer.write(file, buffer.toString());
  }
}

class MemoryLifeRepository implements LifeRepository {
  MemoryLifeRepository([this.data = const LifeData()]);

  LifeData data;

  @override
  String get displayPath => 'In-memory test storage';

  @override
  Future<LifeData> load() async => data;

  @override
  Future<void> save(LifeData data) async => this.data = data;
}
