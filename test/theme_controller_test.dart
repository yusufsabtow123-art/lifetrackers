import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:goal_tracker_poc/app/theme_controller.dart';
import 'package:goal_tracker_poc/data/app_settings_repository.dart';
import 'package:goal_tracker_poc/ui/app_theme.dart';

void main() {
  test('appearance defaults to dark and persists the selected mode', () async {
    final repository = MemoryAppSettingsRepository();
    final controller = AppSettingsController(repository);

    await controller.load();
    expect(controller.appearance, AppAppearance.dark);
    expect(controller.themeMode, ThemeMode.dark);
    expect(controller.accentColor, AppAccentColor.coral);
    expect(controller.progressFormat, AppProgressFormat.both);

    await controller.setAppearance(AppAppearance.dark);
    expect(controller.themeMode, ThemeMode.dark);
    expect(repository.settings.appearance, 'dark');

    await controller.setAccentColor(AppAccentColor.rose);
    expect(controller.accentColor, AppAccentColor.rose);
    expect(repository.settings.accentColor, 'rose');

    await controller.setProgressFormat(AppProgressFormat.amount);
    expect(controller.progressFormat, AppProgressFormat.amount);
    expect(repository.settings.progressFormat, 'amount');

    await controller.setShowAbandoned(true);
    expect(controller.showAbandoned, isTrue);
    expect(repository.settings.showAbandoned, isTrue);

    final reloaded = AppSettingsController(repository);
    await reloaded.load();
    expect(reloaded.appearance, AppAppearance.dark);
    expect(reloaded.themeMode, ThemeMode.dark);
    expect(reloaded.accentColor, AppAccentColor.rose);
    expect(reloaded.progressFormat, AppProgressFormat.amount);
    expect(reloaded.showAbandoned, isTrue);
  });

  test('expanded settings persist and restore together', () async {
    final repository = MemoryAppSettingsRepository();
    final controller = AppSettingsController(repository);
    await controller.load();

    await controller.setCategoryEnabled('Finances', false);
    await controller.setCategoriesEnabled(false);
    await controller.setCategoryDragEnabled(false);
    await controller.setDefaultGoalDetailView(GoalDetailView.detailed);
    await controller.setRememberGoalDetailView(true);
    await controller.setGoalDetailed('goal-1', true);
    await controller.setGoalHealthExpanded('goal-1', false);
    await controller.setGoalStatusHidden('paused', true);
    await controller.setMilestonesEnabled(true);
    await controller.setNotificationsEnabled(false);
    await controller.setDefaultReminderFrequency(
      DefaultReminderFrequency.customDays,
    );
    await controller.setDefaultReminderTime(
      const TimeOfDay(hour: 18, minute: 45),
    );
    await controller.setCompletionCheckIns(false);
    await controller.setEndOfDayReview(true);
    await controller.setEndOfDayTime(const TimeOfDay(hour: 21, minute: 30));
    await controller.setQuietHoursEnabled(true);
    await controller.setQuietStart(const TimeOfDay(hour: 22, minute: 0));
    await controller.setQuietEnd(const TimeOfDay(hour: 6, minute: 30));
    await controller.setAutomaticStarts(false);
    await controller.setConnectedGoalBehavior(ConnectedGoalBehavior.nextDay);
    await controller.setAdaptiveWarningMode(AdaptiveWarningMode.gentle);
    await controller.setWidgetShowTodayActions(false);
    await controller.setWidgetShowProgress(false);
    await controller.setWidgetGoalScope(WidgetGoalScope.unfinished);
    await controller.setWidgetCategory('Faith');
    await controller.setWidgetMaxCards(8);

    final reloaded = AppSettingsController(repository);
    await reloaded.load();

    expect(reloaded.categoriesEnabled, isFalse);
    expect(reloaded.categoryDragEnabled, isFalse);
    expect(reloaded.data.enabledCategories, isNot(contains('Finances')));
    expect(reloaded.defaultGoalDetailView, GoalDetailView.detailed);
    expect(reloaded.isGoalDetailed('goal-1'), isTrue);
    expect(reloaded.isGoalHealthExpanded('goal-1'), isFalse);
    expect(reloaded.isGoalStatusHidden('paused'), isTrue);
    expect(reloaded.milestonesEnabled, isTrue);
    expect(reloaded.notificationsEnabled, isFalse);
    expect(
      reloaded.defaultReminderFrequency,
      DefaultReminderFrequency.customDays,
    );
    expect(reloaded.defaultReminderTime, const TimeOfDay(hour: 18, minute: 45));
    expect(reloaded.completionCheckIns, isFalse);
    expect(reloaded.endOfDayReview, isTrue);
    expect(reloaded.endOfDayTime, const TimeOfDay(hour: 21, minute: 30));
    expect(reloaded.quietHoursEnabled, isTrue);
    expect(reloaded.quietStart, const TimeOfDay(hour: 22, minute: 0));
    expect(reloaded.quietEnd, const TimeOfDay(hour: 6, minute: 30));
    expect(reloaded.automaticStarts, isFalse);
    expect(reloaded.connectedGoalBehavior, ConnectedGoalBehavior.nextDay);
    expect(reloaded.adaptiveWarningMode, AdaptiveWarningMode.gentle);
    expect(reloaded.widgetShowTodayActions, isFalse);
    expect(reloaded.widgetShowProgress, isFalse);
    expect(reloaded.widgetGoalScope, WidgetGoalScope.unfinished);
    expect(reloaded.widgetCategory, 'Faith');
    expect(reloaded.widgetMaxCards, 8);
  });

  test('older settings files gain safe defaults without losing choices', () {
    final settings = AppSettingsData.fromJson({
      'appearance': 'dark',
      'show_abandoned': true,
    });

    expect(settings.appearance, 'dark');
    expect(settings.showAbandoned, isTrue);
    expect(settings.accentColor, 'coral');
    expect(settings.progressFormat, 'both');
  });

  test('all 15 accent colors are balanced into three accessible groups', () {
    expect(AppAccentColor.values, hasLength(15));
    for (final group in AppAccentGroup.values) {
      expect(
        AppAccentColor.values.where((accent) => accent.group == group),
        hasLength(5),
      );
    }

    for (final brightness in Brightness.values) {
      for (final accent in AppAccentColor.values) {
        final scheme = buildAppTheme(
          brightness: brightness,
          accentColor: accent.color,
        ).colorScheme;
        expect(
          _contrastRatio(scheme.primary, scheme.onPrimary),
          greaterThanOrEqualTo(4.5),
          reason: '${accent.label} must be readable in ${brightness.name} mode',
        );
      }
    }
  });
}

double _contrastRatio(Color first, Color second) {
  final firstLuminance = first.computeLuminance();
  final secondLuminance = second.computeLuminance();
  final lighter = firstLuminance > secondLuminance
      ? firstLuminance
      : secondLuminance;
  final darker = firstLuminance > secondLuminance
      ? secondLuminance
      : firstLuminance;
  return (lighter + 0.05) / (darker + 0.05);
}
