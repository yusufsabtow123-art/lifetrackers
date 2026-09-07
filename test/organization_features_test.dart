import 'package:flutter_test/flutter_test.dart';
import 'package:goal_tracker_poc/app/goal_store.dart';
import 'package:goal_tracker_poc/app/theme_controller.dart';
import 'package:goal_tracker_poc/data/app_settings_repository.dart';
import 'package:goal_tracker_poc/data/goal_markdown_codec.dart';
import 'package:goal_tracker_poc/data/goal_repository.dart';
import 'package:goal_tracker_poc/domain/goal.dart';

void main() {
  test('categories filter one board and urgency is saved', () async {
    final repository = MemoryGoalRepository();
    final store = GoalStore(
      repository: repository,
      clock: () => DateTime(2026, 8, 1, 8),
    );
    await store.load();
    final faithGoal = await store.createQuick('Memorize a surah');
    final healthGoal = await store.createQuick('Walk every day');

    expect(faithGoal.category, GoalCategories.other);
    await store.setCategory(faithGoal.id, 'Faith');
    await store.setCategory(healthGoal.id, 'Health');
    await store.setUrgency(
      faithGoal.id,
      isUrgent: true,
      style: UrgencyStyle.policeSiren,
    );

    expect(store.goalsFor(GoalStatus.ideas, category: 'Faith'), hasLength(1));
    expect(store.goalsFor(GoalStatus.ideas, category: 'Health'), hasLength(1));
    final saved = (await repository.loadAll()).firstWhere(
      (goal) => goal.id == faithGoal.id,
    );
    expect(saved.category, 'Faith');
    expect(saved.isUrgent, isTrue);
    expect(saved.urgencyStyle, UrgencyStyle.policeSiren);
  });

  test('organization and multiline steps round-trip through Markdown', () {
    const codec = GoalMarkdownCodec();
    final goal = Goal(
      id: 'faith-goal',
      name: 'Finish the Quran',
      status: GoalStatus.active,
      category: 'Faith',
      isUrgent: true,
      urgencyStyle: UrgencyStyle.policeSiren,
      createdAt: DateTime.utc(2026, 8, 1),
      updatedAt: DateTime.utc(2026, 8, 2),
      steps: [
        GoalStep(
          id: 'long-step',
          title: 'Memorize one page\nReview it again before going to sleep.',
          createdAt: DateTime.utc(2026, 8, 1),
        ),
      ],
    );

    final markdown = codec.encode(goal);
    expect(markdown, contains('category: "Faith"'));
    expect(markdown, contains('urgency_style: "policeSiren"'));
    expect(
      markdown,
      contains('- [ ] Memorize one page\n  Review it again before'),
    );

    final decoded = codec.decode(markdown);
    expect(decoded.category, 'Faith');
    expect(decoded.isUrgent, isTrue);
    expect(decoded.urgencyStyle, UrgencyStyle.policeSiren);
    expect(decoded.steps.single.title, goal.steps.single.title);

    final removedLegacyStyle = markdown.replaceFirst(
      'urgency_style: "policeSiren"',
      'urgency_style: "firefighterSiren"',
    );
    expect(
      codec.decode(removedLegacyStyle).urgencyStyle,
      UrgencyStyle.fireRing,
    );

    final legacy = markdown
        .replaceFirst(RegExp(r'^category:.*\n', multiLine: true), '')
        .replaceFirst(RegExp(r'^is_urgent:.*\n', multiLine: true), '')
        .replaceFirst(RegExp(r'^urgency_style:.*\n', multiLine: true), '');
    final legacyDecoded = codec.decode(legacy);
    expect(legacyDecoded.category, GoalCategories.other);
    expect(legacyDecoded.isUrgent, isFalse);
    expect(legacyDecoded.urgencyStyle, UrgencyStyle.fireRing);
  });

  test('compact card choice is device-local and persists', () async {
    final repository = MemoryAppSettingsRepository();
    final controller = AppSettingsController(repository);
    await controller.load();

    expect(controller.isGoalCompact('goal-1'), isFalse);
    await controller.toggleGoalCompact('goal-1');
    expect(controller.isGoalCompact('goal-1'), isTrue);
    expect(repository.settings.compactGoalIds, contains('goal-1'));

    final reloaded = AppSettingsController(repository);
    await reloaded.load();
    expect(reloaded.isGoalCompact('goal-1'), isTrue);

    final legacySettings = AppSettingsData.fromJson({'appearance': 'dark'});
    expect(legacySettings.compactGoalIds, isEmpty);
  });
}
