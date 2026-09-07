import 'package:flutter/material.dart';

import '../data/app_settings_repository.dart';

enum AppAppearance {
  system('Follow system', Icons.brightness_auto_outlined),
  light('Light', Icons.light_mode_outlined),
  dark('Dark', Icons.dark_mode_outlined);

  const AppAppearance(this.label, this.icon);
  final String label;
  final IconData icon;
  ThemeMode get themeMode => switch (this) {
    AppAppearance.system => ThemeMode.system,
    AppAppearance.light => ThemeMode.light,
    AppAppearance.dark => ThemeMode.dark,
  };
  static AppAppearance parse(String? value) => AppAppearance.values.firstWhere(
    (item) => item.name == value,
    orElse: () => AppAppearance.system,
  );
}

enum AppAccentGroup {
  cool('Cool'),
  warm('Warm'),
  balanced('Balanced');

  const AppAccentGroup(this.label);
  final String label;
}

enum AppAccentColor {
  emerald('Emerald', AppAccentGroup.cool, Color(0xFF0E9363)),
  ocean('Ocean', AppAccentGroup.cool, Color(0xFF1976A8)),
  royal('Royal blue', AppAccentGroup.cool, Color(0xFF4059AD)),
  teal('Teal', AppAccentGroup.cool, Color(0xFF147D78)),
  slate('Slate', AppAccentGroup.cool, Color(0xFF56677A)),
  rose('Rose', AppAccentGroup.warm, Color(0xFFB94369)),
  berry('Berry', AppAccentGroup.warm, Color(0xFF8F3E72)),
  coral('Coral', AppAccentGroup.warm, Color(0xFFC25547)),
  plum('Plum', AppAccentGroup.warm, Color(0xFF754787)),
  lavender('Lavender', AppAccentGroup.warm, Color(0xFF6F5AA8)),
  amber('Amber', AppAccentGroup.balanced, Color(0xFFA8660A)),
  violet('Violet', AppAccentGroup.balanced, Color(0xFF6558B8)),
  sky('Sky', AppAccentGroup.balanced, Color(0xFF2F7E96)),
  moss('Moss', AppAccentGroup.balanced, Color(0xFF527C43)),
  crimson('Crimson', AppAccentGroup.balanced, Color(0xFFAA3B3B));

  const AppAccentColor(this.label, this.group, this.color);
  final String label;
  final AppAccentGroup group;
  final Color color;

  Color get foregroundColor =>
      color.computeLuminance() > 0.179 ? Colors.black : Colors.white;

  Color get complementaryColor {
    final hsl = HSLColor.fromColor(color);
    final lightness = hsl.lightness.clamp(.38, .56);
    final saturation = hsl.saturation.clamp(.35, .68);
    return hsl
        .withHue((hsl.hue + 180) % 360)
        .withSaturation(saturation)
        .withLightness(lightness)
        .toColor();
  }

  static AppAccentColor parse(String? value) =>
      AppAccentColor.values.firstWhere(
        (item) => item.name == value,
        orElse: () => AppAccentColor.emerald,
      );
}

enum AppProgressFormat {
  percentage('Percentage'),
  amount('Amount completed'),
  both('Both');

  const AppProgressFormat(this.label);
  final String label;
  static AppProgressFormat parse(String? value) =>
      AppProgressFormat.values.firstWhere(
        (item) => item.name == value,
        orElse: () => AppProgressFormat.both,
      );
}

enum GoalDetailView {
  simple('Simple'),
  detailed('Detailed');

  const GoalDetailView(this.label);
  final String label;
  static GoalDetailView parse(String? value) =>
      GoalDetailView.values.firstWhere(
        (item) => item.name == value,
        orElse: () => GoalDetailView.simple,
      );
}

enum DefaultReminderFrequency {
  once('Once'),
  daily('Every day'),
  weekdays('Weekdays'),
  weekly('Every week'),
  customDays('Custom days');

  const DefaultReminderFrequency(this.label);
  final String label;
  static DefaultReminderFrequency parse(String? value) =>
      DefaultReminderFrequency.values.firstWhere(
        (item) => item.name == value,
        orElse: () => DefaultReminderFrequency.daily,
      );
}

enum ConnectedGoalBehavior {
  immediate('Resume right away'),
  nextDay('Resume the next day'),
  keepPending('Keep Pending');

  const ConnectedGoalBehavior(this.label);
  final String label;
  static ConnectedGoalBehavior parse(String? value) =>
      ConnectedGoalBehavior.values.firstWhere(
        (item) => item.name == value,
        orElse: () => ConnectedGoalBehavior.immediate,
      );
}

enum AdaptiveWarningMode {
  natural('Natural'),
  gentle('Gentle'),
  frequent('Frequent'),
  off('Off'),
  customize('Customize');

  const AdaptiveWarningMode(this.label);
  final String label;
  static AdaptiveWarningMode parse(String? value) =>
      AdaptiveWarningMode.values.firstWhere(
        (item) => item.name == value,
        orElse: () => AdaptiveWarningMode.natural,
      );
}

enum WidgetGoalScope {
  active('Active goals'),
  plannedAndActive('Planned and Active'),
  unfinished('All unfinished goals');

  const WidgetGoalScope(this.label);
  final String label;
  static WidgetGoalScope parse(String? value) =>
      WidgetGoalScope.values.firstWhere(
        (item) => item.name == value,
        orElse: () => WidgetGoalScope.active,
      );
}

class AppSettingsController extends ChangeNotifier {
  AppSettingsController(this.repository);
  factory AppSettingsController.memory() =>
      AppSettingsController(MemoryAppSettingsRepository());

  final AppSettingsRepository repository;
  AppSettingsData _settings = const AppSettingsData();
  bool _loaded = false;

  AppSettingsData get data => _settings;
  AppAppearance get appearance => AppAppearance.parse(_settings.appearance);
  AppAccentColor get accentColor => AppAccentColor.parse(_settings.accentColor);
  AppProgressFormat get progressFormat =>
      AppProgressFormat.parse(_settings.progressFormat);
  GoalDetailView get defaultGoalDetailView =>
      GoalDetailView.parse(_settings.defaultGoalDetailView);
  DefaultReminderFrequency get defaultReminderFrequency =>
      DefaultReminderFrequency.parse(_settings.defaultReminderFrequency);
  ConnectedGoalBehavior get connectedGoalBehavior =>
      ConnectedGoalBehavior.parse(_settings.connectedGoalBehavior);
  AdaptiveWarningMode get adaptiveWarningMode =>
      AdaptiveWarningMode.parse(_settings.adaptiveWarningMode);
  WidgetGoalScope get widgetGoalScope =>
      WidgetGoalScope.parse(_settings.widgetGoalScope);
  ThemeMode get themeMode => appearance.themeMode;
  bool get showAbandoned => _settings.showAbandoned;
  bool get isLoaded => _loaded;
  bool get categoriesEnabled => _settings.categoriesEnabled;
  bool get categoryDragEnabled => _settings.categoryDragEnabled;
  bool get rememberGoalDetailView => _settings.rememberGoalDetailView;
  bool get notificationsEnabled => _settings.notificationsEnabled;
  bool get completionCheckIns => _settings.completionCheckIns;
  bool get endOfDayReview => _settings.endOfDayReview;
  bool get quietHoursEnabled => _settings.quietHoursEnabled;
  bool get automaticStarts => _settings.automaticStarts;
  bool get milestonesEnabled => _settings.milestonesEnabled;
  bool get widgetShowTodayActions => _settings.widgetShowTodayActions;
  bool get widgetShowProgress => _settings.widgetShowProgress;
  int get widgetMaxCards => _settings.widgetMaxCards;
  String get widgetCategory => _settings.widgetCategory;
  TimeOfDay get defaultReminderTime => TimeOfDay(
    hour: _settings.defaultReminderHour,
    minute: _settings.defaultReminderMinute,
  );
  TimeOfDay get endOfDayTime =>
      TimeOfDay(hour: _settings.endOfDayHour, minute: _settings.endOfDayMinute);
  TimeOfDay get quietStart => TimeOfDay(
    hour: _settings.quietStartHour,
    minute: _settings.quietStartMinute,
  );
  TimeOfDay get quietEnd =>
      TimeOfDay(hour: _settings.quietEndHour, minute: _settings.quietEndMinute);

  bool isCategoryEnabled(String category) =>
      !_settings.categoriesEnabled ||
      _settings.enabledCategories.contains(category);
  List<String> visibleCategories(Iterable<String> categories) =>
      !categoriesEnabled
      ? const []
      : categories
            .where(_settings.enabledCategories.contains)
            .toList(growable: false);
  bool isGoalDetailed(String goalId) => _settings.rememberGoalDetailView
      ? _settings.detailedGoalIds.contains(goalId)
      : defaultGoalDetailView == GoalDetailView.detailed;

  bool isGoalCompact(String goalId) =>
      _settings.compactGoalIds.contains(goalId);
  bool isGoalHealthExpanded(String goalId) =>
      !_settings.collapsedHealthGoalIds.contains(goalId);
  bool isGoalStatusHidden(String statusName) =>
      _settings.hiddenGoalStatuses.contains(statusName);
  Set<String> get hiddenGoalStatuses =>
      Set.unmodifiable(_settings.hiddenGoalStatuses);

  Future<void> load() async {
    _settings = await repository.load();
    _loaded = true;
    notifyListeners();
  }

  Future<void> _commit(AppSettingsData next) async {
    _settings = next;
    notifyListeners();
    await repository.save(_settings);
  }

  Future<void> setAppearance(AppAppearance value) =>
      _commit(_settings.copyWith(appearance: value.name));
  Future<void> setAccentColor(AppAccentColor value) =>
      _commit(_settings.copyWith(accentColor: value.name));
  Future<void> setProgressFormat(AppProgressFormat value) =>
      _commit(_settings.copyWith(progressFormat: value.name));
  Future<void> setShowAbandoned(bool value) =>
      _commit(_settings.copyWith(showAbandoned: value));
  Future<void> setDefaultGoalDetailView(GoalDetailView value) =>
      _commit(_settings.copyWith(defaultGoalDetailView: value.name));
  Future<void> setRememberGoalDetailView(bool value) =>
      _commit(_settings.copyWith(rememberGoalDetailView: value));
  Future<void> setGoalDetailed(String goalId, bool value) async {
    if (!_settings.rememberGoalDetailView) return;
    final ids = Set<String>.of(_settings.detailedGoalIds);
    value ? ids.add(goalId) : ids.remove(goalId);
    await _commit(_settings.copyWith(detailedGoalIds: ids));
  }

  Future<void> toggleGoalCompact(String goalId) async {
    final ids = Set<String>.of(_settings.compactGoalIds);
    if (!ids.add(goalId)) {
      ids.remove(goalId);
    }
    await _commit(_settings.copyWith(compactGoalIds: ids));
  }

  Future<void> setGoalHealthExpanded(String goalId, bool value) async {
    final ids = Set<String>.of(_settings.collapsedHealthGoalIds);
    value ? ids.remove(goalId) : ids.add(goalId);
    await _commit(_settings.copyWith(collapsedHealthGoalIds: ids));
  }

  Future<void> setGoalStatusHidden(String statusName, bool value) async {
    final statuses = Set<String>.of(_settings.hiddenGoalStatuses);
    value ? statuses.add(statusName) : statuses.remove(statusName);
    await _commit(_settings.copyWith(hiddenGoalStatuses: statuses));
  }

  Future<void> setCategoriesEnabled(bool value) =>
      _commit(_settings.copyWith(categoriesEnabled: value));
  Future<void> setCategoryDragEnabled(bool value) =>
      _commit(_settings.copyWith(categoryDragEnabled: value));
  Future<void> setCategoryEnabled(String category, bool value) async {
    final categories = Set<String>.of(_settings.enabledCategories);
    value ? categories.add(category) : categories.remove(category);
    await _commit(_settings.copyWith(enabledCategories: categories));
  }

  Future<void> setNotificationsEnabled(bool value) =>
      _commit(_settings.copyWith(notificationsEnabled: value));
  Future<void> setDefaultReminderFrequency(DefaultReminderFrequency value) =>
      _commit(_settings.copyWith(defaultReminderFrequency: value.name));
  Future<void> setDefaultReminderTime(TimeOfDay value) => _commit(
    _settings.copyWith(
      defaultReminderHour: value.hour,
      defaultReminderMinute: value.minute,
    ),
  );
  Future<void> setCompletionCheckIns(bool value) =>
      _commit(_settings.copyWith(completionCheckIns: value));
  Future<void> setEndOfDayReview(bool value) =>
      _commit(_settings.copyWith(endOfDayReview: value));
  Future<void> setEndOfDayTime(TimeOfDay value) => _commit(
    _settings.copyWith(endOfDayHour: value.hour, endOfDayMinute: value.minute),
  );
  Future<void> setQuietHoursEnabled(bool value) =>
      _commit(_settings.copyWith(quietHoursEnabled: value));
  Future<void> setQuietStart(TimeOfDay value) => _commit(
    _settings.copyWith(
      quietStartHour: value.hour,
      quietStartMinute: value.minute,
    ),
  );
  Future<void> setQuietEnd(TimeOfDay value) => _commit(
    _settings.copyWith(quietEndHour: value.hour, quietEndMinute: value.minute),
  );
  Future<void> setFirstReminderEducationSeen(bool value) =>
      _commit(_settings.copyWith(firstReminderEducationSeen: value));
  Future<void> setAutomaticStarts(bool value) =>
      _commit(_settings.copyWith(automaticStarts: value));
  Future<void> setConnectedGoalBehavior(ConnectedGoalBehavior value) =>
      _commit(_settings.copyWith(connectedGoalBehavior: value.name));
  Future<void> setAdaptiveWarningMode(AdaptiveWarningMode value) =>
      _commit(_settings.copyWith(adaptiveWarningMode: value.name));
  Future<void> setMilestonesEnabled(bool value) =>
      _commit(_settings.copyWith(milestonesEnabled: value));
  Future<void> setWidgetShowTodayActions(bool value) =>
      _commit(_settings.copyWith(widgetShowTodayActions: value));
  Future<void> setWidgetShowProgress(bool value) =>
      _commit(_settings.copyWith(widgetShowProgress: value));
  Future<void> setWidgetGoalScope(WidgetGoalScope value) =>
      _commit(_settings.copyWith(widgetGoalScope: value.name));
  Future<void> setWidgetCategory(String value) =>
      _commit(_settings.copyWith(widgetCategory: value));
  Future<void> setWidgetMaxCards(int value) =>
      _commit(_settings.copyWith(widgetMaxCards: value.clamp(1, 8)));
}
