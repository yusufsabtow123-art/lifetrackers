import 'dart:async';
import 'dart:convert';
import 'dart:ui';

import 'package:flutter/widgets.dart';
import 'package:home_widget/home_widget.dart';

import '../app/goal_store.dart';
import '../app/theme_controller.dart';
import '../data/app_settings_repository.dart';
import '../data/goal_repository.dart';
import '../domain/goal.dart';
import '../domain/plan_calculator.dart';
import '../ui/progress_format.dart';

const _todayProvider = 'app.localfirst.goal_tracker_poc.TodayWidgetProvider';
const _cardsProvider =
    'app.localfirst.goal_tracker_poc.GoalCardsWidgetProvider';

@pragma('vm:entry-point')
Future<void> goalWidgetCallback(Uri? uri) async {
  if (uri?.scheme != 'goaltracker' || uri?.host != 'done') return;
  final goalId = uri?.queryParameters['id'];
  if (goalId == null) return;
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();
  final repository = await MarkdownGoalRepository.createDefault();
  final store = GoalStore(repository: repository);
  await store.load();
  await store.completeTodayAction(goalId);
  final settingsRepository = await FileAppSettingsRepository.createDefault();
  final settings = AppSettingsController(settingsRepository);
  await settings.load();
  await GoalWidgetService().sync(store.goals, store, settings);
}

class GoalWidgetService {
  Stream<Uri?> get clicks => HomeWidget.widgetClicked;

  Future<void> initialize() async {
    await HomeWidget.registerInteractivityCallback(goalWidgetCallback);
  }

  Future<Uri?> initialUri() => HomeWidget.initiallyLaunchedFromHomeWidget();

  Future<void> sync(
    Iterable<Goal> goals,
    GoalStore store,
    AppSettingsController settings,
  ) async {
    final category = settings.widgetCategory;
    final visibleCategories = settings.data.enabledCategories;
    bool included(Goal goal) {
      if (goal.isTrashed ||
          goal.status == GoalStatus.completed ||
          goal.status == GoalStatus.abandoned) {
        return false;
      }
      if (settings.categoriesEnabled &&
          !visibleCategories.contains(goal.category)) {
        return false;
      }
      if (category.isNotEmpty && goal.category != category) return false;
      return switch (settings.widgetGoalScope) {
        WidgetGoalScope.active => goal.status == GoalStatus.active,
        WidgetGoalScope.plannedAndActive =>
          goal.status == GoalStatus.planned || goal.status == GoalStatus.active,
        WidgetGoalScope.unfinished => true,
      };
    }

    final cards = goals
        .where(included)
        .take(settings.widgetMaxCards)
        .map(
          (goal) => {
            'id': goal.id,
            'name': goal.name,
            'category': settings.categoriesEnabled ? goal.category : '',
            'progress': goal.progress,
            'progress_text': settings.widgetShowProgress
                ? formatGoalProgress(goal, settings.progressFormat)
                : '',
            'urgent': goal.isUrgent,
          },
        )
        .toList(growable: false);

    final today = settings.widgetShowTodayActions
        ? goals
              .where(
                (goal) =>
                    included(goal) &&
                    goal.plan != null &&
                    goal.completionFor(store.today) == null &&
                    store.calculator.actionForDate(goal, store.today) > 0,
              )
              .take(3)
              .map(
                (goal) => {
                  'id': goal.id,
                  'name': goal.name,
                  'action':
                      '${formatAmount(store.calculator.actionForDate(goal, store.today))} ${goal.plan!.unit}',
                },
              )
              .toList(growable: false)
        : const <Map<String, Object?>>[];

    await HomeWidget.saveWidgetData('goal_cards_json', jsonEncode(cards));
    await HomeWidget.saveWidgetData('today_actions_json', jsonEncode(today));
    await HomeWidget.saveWidgetData(
      'widget_primary_color',
      settings.accentColor.color.toARGB32(),
    );
    await HomeWidget.saveWidgetData(
      'widget_secondary_color',
      settings.accentColor.complementaryColor.toARGB32(),
    );
    await HomeWidget.updateWidget(qualifiedAndroidName: _todayProvider);
    await HomeWidget.updateWidget(qualifiedAndroidName: _cardsProvider);
  }

  Future<void> requestPinTodayWidget() =>
      HomeWidget.requestPinWidget(qualifiedAndroidName: _todayProvider);

  Future<void> requestPinCardsWidget() =>
      HomeWidget.requestPinWidget(qualifiedAndroidName: _cardsProvider);
}
