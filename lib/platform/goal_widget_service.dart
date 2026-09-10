import 'dart:async';
import 'dart:convert';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:home_widget/home_widget.dart';

import '../app/goal_store.dart';
import '../app/life_store.dart';
import '../app/theme_controller.dart';
import '../data/app_settings_repository.dart';
import '../data/goal_repository.dart';
import '../data/life_repository.dart';
import '../domain/goal.dart';
import '../domain/plan_calculator.dart';
import '../ui/progress_format.dart';

const _todayProvider = 'app.localfirst.goal_tracker_poc.TodayWidgetProvider';
const _cardsProvider =
    'app.localfirst.goal_tracker_poc.GoalCardsWidgetProvider';
const _calendarProvider =
    'app.localfirst.goal_tracker_poc.CalendarWidgetProvider';

@pragma('vm:entry-point')
Future<void> goalWidgetCallback(Uri? uri) async {
  if (uri?.scheme != 'goaltracker' || uri?.host != 'done') return;
  final goalId = uri?.queryParameters['id'];
  if (goalId == null) return;
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();
  final settingsRepository = await FileAppSettingsRepository.createDefault();
  final settings = AppSettingsController(settingsRepository);
  await settings.load();
  final goalRepository = await MarkdownGoalRepository.createDefault();
  final goalStore = GoalStore(repository: goalRepository);
  final lifeRepository = await MarkdownLifeRepository.createDefault();
  final lifeStore = LifeStore(lifeRepository, settings: settings.data);
  await Future.wait([goalStore.load(), lifeStore.load()]);
  if (uri?.queryParameters['type'] == 'task') {
    final task = lifeStore.tasks.where((item) => item.id == goalId).firstOrNull;
    final date = DateTime.tryParse(uri?.queryParameters['date'] ?? '');
    if (task != null) {
      await lifeStore.completeTaskForDate(task, date ?? DateTime.now());
    }
  } else {
    await goalStore.completeTodayAction(goalId);
  }
  await GoalWidgetService().sync(
    goalStore.goals,
    goalStore,
    lifeStore,
    settings,
  );
}

class GoalWidgetService {
  // These providers are Android home-screen widgets, not Windows widgets.
  bool get _supported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  Stream<Uri?> get clicks =>
      _supported ? HomeWidget.widgetClicked : const Stream<Uri?>.empty();

  Future<void> initialize() async {
    if (!_supported) return;
    await HomeWidget.registerInteractivityCallback(goalWidgetCallback);
  }

  Future<Uri?> initialUri() async =>
      _supported ? await HomeWidget.initiallyLaunchedFromHomeWidget() : null;

  Future<void> sync(
    Iterable<Goal> goals,
    GoalStore store,
    LifeStore? lifeStore,
    AppSettingsController settings,
  ) async {
    if (!_supported) return;
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

    final today = <Map<String, Object?>>[];
    if (settings.widgetShowTodayActions) {
      for (final goal in goals) {
        if (!included(goal) ||
            goal.plan == null ||
            goal.completionFor(store.today) != null) {
          continue;
        }
        final amount = store.calculator.actionForDate(goal, store.today);
        if (amount <= 0) continue;
        today.add({
          'type': 'goal',
          'id': goal.id,
          'name': goal.name,
          'action': '${formatAmount(amount)} ${goal.plan!.unit}',
        });
        if (today.length == 3) break;
      }
      if (today.length < 3 && lifeStore != null) {
        for (final task in lifeStore.tasksFor(store.today)) {
          if (task.isDoneOn(store.today)) continue;
          today.add({
            'type': 'task',
            'id': task.id,
            'name': task.goalId == null ? 'Task' : 'Linked task',
            'action': task.title,
            'date': store.today.toIso8601String(),
          });
          if (today.length == 3) break;
        }
      }
    }

    await HomeWidget.saveWidgetData('goal_cards_json', jsonEncode(cards));
    await HomeWidget.saveWidgetData('today_actions_json', jsonEncode(today));
    final calendarItems = <Map<String, Object?>>[];
    if (lifeStore != null) {
      for (var offset = 0; offset < 2 && calendarItems.length < 8; offset++) {
        final day = DateTime(
          store.today.year,
          store.today.month,
          store.today.day + offset,
        );
        for (final entry in lifeStore.entriesFor(day)) {
          final start = entry.occurrenceStart(day);
          final minute = start.minute.toString().padLeft(2, '0');
          final hour = start.hour == 0
              ? 12
              : start.hour > 12
              ? start.hour - 12
              : start.hour;
          calendarItems.add({
            'title': entry.title,
            'time':
                '${offset == 0 ? 'Today' : 'Tomorrow'} · '
                '$hour:$minute ${start.hour >= 12 ? 'PM' : 'AM'}',
          });
          if (calendarItems.length == 8) break;
        }
      }
    }
    await HomeWidget.saveWidgetData(
      'calendar_schedule_json',
      jsonEncode(calendarItems),
    );
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
    await HomeWidget.updateWidget(qualifiedAndroidName: _calendarProvider);
  }

  Future<void> requestPinTodayWidget() async {
    if (!_supported) return;
    await HomeWidget.requestPinWidget(qualifiedAndroidName: _todayProvider);
  }

  Future<void> requestPinCardsWidget() async {
    if (!_supported) return;
    await HomeWidget.requestPinWidget(qualifiedAndroidName: _cardsProvider);
  }

  Future<void> requestPinCalendarWidget() async {
    if (!_supported) return;
    await HomeWidget.requestPinWidget(qualifiedAndroidName: _calendarProvider);
  }
}
