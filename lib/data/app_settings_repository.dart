import 'dart:convert';
import 'dart:io';

import 'app_data_path.dart';

class AppSettingsData {
  const AppSettingsData({
    this.appearance = 'dark',
    this.accentColor = 'coral',
    this.progressFormat = 'both',
    this.showAbandoned = false,
    this.compactGoalIds = const {},
    this.detailedGoalIds = const {},
    this.collapsedHealthGoalIds = const {},
    this.hiddenGoalStatuses = const {},
    this.defaultGoalDetailView = 'simple',
    this.rememberGoalDetailView = true,
    this.categoriesEnabled = true,
    this.categoryDragEnabled = true,
    this.enabledCategories = const {
      'Faith',
      'Health',
      'Mind',
      'Body',
      'Finances',
      'Work',
      'Personal',
      'Other',
    },
    this.notificationsEnabled = true,
    this.defaultReminderFrequency = 'daily',
    this.defaultReminderHour = 18,
    this.defaultReminderMinute = 0,
    this.completionCheckIns = true,
    this.endOfDayReview = false,
    this.endOfDayHour = 21,
    this.endOfDayMinute = 0,
    this.quietHoursEnabled = true,
    this.quietStartHour = 22,
    this.quietStartMinute = 0,
    this.quietEndHour = 7,
    this.quietEndMinute = 0,
    this.firstReminderEducationSeen = false,
    this.automaticStarts = true,
    this.connectedGoalBehavior = 'immediate',
    this.adaptiveWarningMode = 'natural',
    this.milestonesEnabled = false,
    this.widgetShowTodayActions = true,
    this.widgetShowProgress = true,
    this.widgetGoalScope = 'active',
    this.widgetCategory = '',
    this.widgetMaxCards = 3,
    this.visualStyleVersion = 0,
    this.salahEnabled = false,
    this.salahLatitude = 44.9537,
    this.salahLongitude = -93.0900,
    this.salahLocationName = 'Saint Paul, Minnesota',
    this.salahTimeZone = 'America/Chicago',
    this.salahCalculationMethod = 'northAmerica',
    this.salahAsrMethod = 'shafi',
    this.salahHighLatitudeRule = 'recommended',
    this.salahBlockMinutes = 30,
    this.salahAdjustments = const {},
  });

  final String appearance;
  final String accentColor;
  final String progressFormat;
  final bool showAbandoned;
  final Set<String> compactGoalIds;
  final Set<String> detailedGoalIds;
  final Set<String> collapsedHealthGoalIds;
  final Set<String> hiddenGoalStatuses;
  final String defaultGoalDetailView;
  final bool rememberGoalDetailView;
  final bool categoriesEnabled;
  final bool categoryDragEnabled;
  final Set<String> enabledCategories;
  final bool notificationsEnabled;
  final String defaultReminderFrequency;
  final int defaultReminderHour;
  final int defaultReminderMinute;
  final bool completionCheckIns;
  final bool endOfDayReview;
  final int endOfDayHour;
  final int endOfDayMinute;
  final bool quietHoursEnabled;
  final int quietStartHour;
  final int quietStartMinute;
  final int quietEndHour;
  final int quietEndMinute;
  final bool firstReminderEducationSeen;
  final bool automaticStarts;
  final String connectedGoalBehavior;
  final String adaptiveWarningMode;
  final bool milestonesEnabled;
  final bool widgetShowTodayActions;
  final bool widgetShowProgress;
  final String widgetGoalScope;
  final String widgetCategory;
  final int widgetMaxCards;
  final int visualStyleVersion;
  final bool salahEnabled;
  final double salahLatitude;
  final double salahLongitude;
  final String salahLocationName;
  final String salahTimeZone;
  final String salahCalculationMethod;
  final String salahAsrMethod;
  final String salahHighLatitudeRule;
  final int salahBlockMinutes;
  final Map<String, int> salahAdjustments;

  AppSettingsData copyWith({
    String? appearance,
    String? accentColor,
    String? progressFormat,
    bool? showAbandoned,
    Set<String>? compactGoalIds,
    Set<String>? detailedGoalIds,
    Set<String>? collapsedHealthGoalIds,
    Set<String>? hiddenGoalStatuses,
    String? defaultGoalDetailView,
    bool? rememberGoalDetailView,
    bool? categoriesEnabled,
    bool? categoryDragEnabled,
    Set<String>? enabledCategories,
    bool? notificationsEnabled,
    String? defaultReminderFrequency,
    int? defaultReminderHour,
    int? defaultReminderMinute,
    bool? completionCheckIns,
    bool? endOfDayReview,
    int? endOfDayHour,
    int? endOfDayMinute,
    bool? quietHoursEnabled,
    int? quietStartHour,
    int? quietStartMinute,
    int? quietEndHour,
    int? quietEndMinute,
    bool? firstReminderEducationSeen,
    bool? automaticStarts,
    String? connectedGoalBehavior,
    String? adaptiveWarningMode,
    bool? milestonesEnabled,
    bool? widgetShowTodayActions,
    bool? widgetShowProgress,
    String? widgetGoalScope,
    String? widgetCategory,
    int? widgetMaxCards,
    int? visualStyleVersion,
    bool? salahEnabled,
    double? salahLatitude,
    double? salahLongitude,
    String? salahLocationName,
    String? salahTimeZone,
    String? salahCalculationMethod,
    String? salahAsrMethod,
    String? salahHighLatitudeRule,
    int? salahBlockMinutes,
    Map<String, int>? salahAdjustments,
  }) => AppSettingsData(
    appearance: appearance ?? this.appearance,
    accentColor: accentColor ?? this.accentColor,
    progressFormat: progressFormat ?? this.progressFormat,
    showAbandoned: showAbandoned ?? this.showAbandoned,
    compactGoalIds: compactGoalIds ?? this.compactGoalIds,
    detailedGoalIds: detailedGoalIds ?? this.detailedGoalIds,
    collapsedHealthGoalIds:
        collapsedHealthGoalIds ?? this.collapsedHealthGoalIds,
    hiddenGoalStatuses: hiddenGoalStatuses ?? this.hiddenGoalStatuses,
    defaultGoalDetailView: defaultGoalDetailView ?? this.defaultGoalDetailView,
    rememberGoalDetailView:
        rememberGoalDetailView ?? this.rememberGoalDetailView,
    categoriesEnabled: categoriesEnabled ?? this.categoriesEnabled,
    categoryDragEnabled: categoryDragEnabled ?? this.categoryDragEnabled,
    enabledCategories: enabledCategories ?? this.enabledCategories,
    notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
    defaultReminderFrequency:
        defaultReminderFrequency ?? this.defaultReminderFrequency,
    defaultReminderHour: defaultReminderHour ?? this.defaultReminderHour,
    defaultReminderMinute: defaultReminderMinute ?? this.defaultReminderMinute,
    completionCheckIns: completionCheckIns ?? this.completionCheckIns,
    endOfDayReview: endOfDayReview ?? this.endOfDayReview,
    endOfDayHour: endOfDayHour ?? this.endOfDayHour,
    endOfDayMinute: endOfDayMinute ?? this.endOfDayMinute,
    quietHoursEnabled: quietHoursEnabled ?? this.quietHoursEnabled,
    quietStartHour: quietStartHour ?? this.quietStartHour,
    quietStartMinute: quietStartMinute ?? this.quietStartMinute,
    quietEndHour: quietEndHour ?? this.quietEndHour,
    quietEndMinute: quietEndMinute ?? this.quietEndMinute,
    firstReminderEducationSeen:
        firstReminderEducationSeen ?? this.firstReminderEducationSeen,
    automaticStarts: automaticStarts ?? this.automaticStarts,
    connectedGoalBehavior: connectedGoalBehavior ?? this.connectedGoalBehavior,
    adaptiveWarningMode: adaptiveWarningMode ?? this.adaptiveWarningMode,
    milestonesEnabled: milestonesEnabled ?? this.milestonesEnabled,
    widgetShowTodayActions:
        widgetShowTodayActions ?? this.widgetShowTodayActions,
    widgetShowProgress: widgetShowProgress ?? this.widgetShowProgress,
    widgetGoalScope: widgetGoalScope ?? this.widgetGoalScope,
    widgetCategory: widgetCategory ?? this.widgetCategory,
    widgetMaxCards: widgetMaxCards ?? this.widgetMaxCards,
    visualStyleVersion: visualStyleVersion ?? this.visualStyleVersion,
    salahEnabled: salahEnabled ?? this.salahEnabled,
    salahLatitude: salahLatitude ?? this.salahLatitude,
    salahLongitude: salahLongitude ?? this.salahLongitude,
    salahLocationName: salahLocationName ?? this.salahLocationName,
    salahTimeZone: salahTimeZone ?? this.salahTimeZone,
    salahCalculationMethod:
        salahCalculationMethod ?? this.salahCalculationMethod,
    salahAsrMethod: salahAsrMethod ?? this.salahAsrMethod,
    salahHighLatitudeRule: salahHighLatitudeRule ?? this.salahHighLatitudeRule,
    salahBlockMinutes: salahBlockMinutes ?? this.salahBlockMinutes,
    salahAdjustments: salahAdjustments ?? this.salahAdjustments,
  );

  Map<String, Object?> toJson() => {
    'appearance': appearance,
    'accent_color': accentColor,
    'progress_format': progressFormat,
    'show_abandoned': showAbandoned,
    'compact_goal_ids': compactGoalIds.toList()..sort(),
    'detailed_goal_ids': detailedGoalIds.toList()..sort(),
    'collapsed_health_goal_ids': collapsedHealthGoalIds.toList()..sort(),
    'hidden_goal_statuses': hiddenGoalStatuses.toList()..sort(),
    'default_goal_detail_view': defaultGoalDetailView,
    'remember_goal_detail_view': rememberGoalDetailView,
    'categories_enabled': categoriesEnabled,
    'category_drag_enabled': categoryDragEnabled,
    'enabled_categories': enabledCategories.toList()..sort(),
    'notifications_enabled': notificationsEnabled,
    'default_reminder_frequency': defaultReminderFrequency,
    'default_reminder_hour': defaultReminderHour,
    'default_reminder_minute': defaultReminderMinute,
    'completion_check_ins': completionCheckIns,
    'end_of_day_review': endOfDayReview,
    'end_of_day_hour': endOfDayHour,
    'end_of_day_minute': endOfDayMinute,
    'quiet_hours_enabled': quietHoursEnabled,
    'quiet_start_hour': quietStartHour,
    'quiet_start_minute': quietStartMinute,
    'quiet_end_hour': quietEndHour,
    'quiet_end_minute': quietEndMinute,
    'first_reminder_education_seen': firstReminderEducationSeen,
    'automatic_starts': automaticStarts,
    'connected_goal_behavior': connectedGoalBehavior,
    'adaptive_warning_mode': adaptiveWarningMode,
    'milestones_enabled': milestonesEnabled,
    'widget_show_today_actions': widgetShowTodayActions,
    'widget_show_progress': widgetShowProgress,
    'widget_goal_scope': widgetGoalScope,
    'widget_category': widgetCategory,
    'widget_max_cards': widgetMaxCards,
    'visual_style_version': visualStyleVersion,
    'salah_enabled': salahEnabled,
    'salah_latitude': salahLatitude,
    'salah_longitude': salahLongitude,
    'salah_location_name': salahLocationName,
    'salah_time_zone': salahTimeZone,
    'salah_calculation_method': salahCalculationMethod,
    'salah_asr_method': salahAsrMethod,
    'salah_high_latitude_rule': salahHighLatitudeRule,
    'salah_block_minutes': salahBlockMinutes,
    'salah_adjustments': salahAdjustments,
  };

  static AppSettingsData fromJson(Object? value) {
    if (value is! Map<String, Object?>) return const AppSettingsData();
    const d = AppSettingsData();
    Set<String> setOf(String key, Set<String> fallback) =>
        value.containsKey(key)
        ? (value[key] as List<Object?>? ?? const []).whereType<String>().toSet()
        : fallback;
    int intOf(String key, int fallback) =>
        (value[key] as num?)?.toInt() ?? fallback;
    return AppSettingsData(
      appearance: value['appearance'] as String? ?? d.appearance,
      accentColor: value['accent_color'] as String? ?? d.accentColor,
      progressFormat: value['progress_format'] as String? ?? d.progressFormat,
      showAbandoned: value['show_abandoned'] as bool? ?? d.showAbandoned,
      compactGoalIds: setOf('compact_goal_ids', const {}),
      detailedGoalIds: setOf('detailed_goal_ids', const {}),
      collapsedHealthGoalIds: setOf('collapsed_health_goal_ids', const {}),
      hiddenGoalStatuses: setOf('hidden_goal_statuses', const {}),
      defaultGoalDetailView:
          value['default_goal_detail_view'] as String? ??
          d.defaultGoalDetailView,
      rememberGoalDetailView:
          value['remember_goal_detail_view'] as bool? ??
          d.rememberGoalDetailView,
      categoriesEnabled:
          value['categories_enabled'] as bool? ?? d.categoriesEnabled,
      categoryDragEnabled:
          value['category_drag_enabled'] as bool? ?? d.categoryDragEnabled,
      enabledCategories: setOf('enabled_categories', d.enabledCategories),
      notificationsEnabled:
          value['notifications_enabled'] as bool? ?? d.notificationsEnabled,
      defaultReminderFrequency:
          value['default_reminder_frequency'] as String? ??
          d.defaultReminderFrequency,
      defaultReminderHour: intOf(
        'default_reminder_hour',
        d.defaultReminderHour,
      ),
      defaultReminderMinute: intOf(
        'default_reminder_minute',
        d.defaultReminderMinute,
      ),
      completionCheckIns:
          value['completion_check_ins'] as bool? ?? d.completionCheckIns,
      endOfDayReview: value['end_of_day_review'] as bool? ?? d.endOfDayReview,
      endOfDayHour: intOf('end_of_day_hour', d.endOfDayHour),
      endOfDayMinute: intOf('end_of_day_minute', d.endOfDayMinute),
      quietHoursEnabled:
          value['quiet_hours_enabled'] as bool? ?? d.quietHoursEnabled,
      quietStartHour: intOf('quiet_start_hour', d.quietStartHour),
      quietStartMinute: intOf('quiet_start_minute', d.quietStartMinute),
      quietEndHour: intOf('quiet_end_hour', d.quietEndHour),
      quietEndMinute: intOf('quiet_end_minute', d.quietEndMinute),
      firstReminderEducationSeen:
          value['first_reminder_education_seen'] as bool? ??
          d.firstReminderEducationSeen,
      automaticStarts: value['automatic_starts'] as bool? ?? d.automaticStarts,
      connectedGoalBehavior:
          value['connected_goal_behavior'] as String? ??
          d.connectedGoalBehavior,
      adaptiveWarningMode:
          value['adaptive_warning_mode'] as String? ?? d.adaptiveWarningMode,
      milestonesEnabled:
          value['milestones_enabled'] as bool? ?? d.milestonesEnabled,
      widgetShowTodayActions:
          value['widget_show_today_actions'] as bool? ??
          d.widgetShowTodayActions,
      widgetShowProgress:
          value['widget_show_progress'] as bool? ?? d.widgetShowProgress,
      widgetGoalScope:
          value['widget_goal_scope'] as String? ?? d.widgetGoalScope,
      widgetCategory: value['widget_category'] as String? ?? d.widgetCategory,
      widgetMaxCards: intOf('widget_max_cards', d.widgetMaxCards),
      visualStyleVersion: intOf('visual_style_version', d.visualStyleVersion),
      salahEnabled: value['salah_enabled'] as bool? ?? d.salahEnabled,
      salahLatitude:
          (value['salah_latitude'] as num?)?.toDouble() ?? d.salahLatitude,
      salahLongitude:
          (value['salah_longitude'] as num?)?.toDouble() ?? d.salahLongitude,
      salahLocationName:
          value['salah_location_name'] as String? ?? d.salahLocationName,
      salahTimeZone: value['salah_time_zone'] as String? ?? d.salahTimeZone,
      salahCalculationMethod:
          value['salah_calculation_method'] as String? ??
          d.salahCalculationMethod,
      salahAsrMethod: value['salah_asr_method'] as String? ?? d.salahAsrMethod,
      salahHighLatitudeRule:
          value['salah_high_latitude_rule'] as String? ??
          d.salahHighLatitudeRule,
      salahBlockMinutes: intOf('salah_block_minutes', d.salahBlockMinutes),
      salahAdjustments:
          (value['salah_adjustments'] as Map?)?.map(
            (key, item) => MapEntry(key.toString(), (item as num).toInt()),
          ) ??
          d.salahAdjustments,
    );
  }
}

abstract interface class AppSettingsRepository {
  Future<AppSettingsData> load();
  Future<void> save(AppSettingsData settings);
}

class FileAppSettingsRepository implements AppSettingsRepository {
  FileAppSettingsRepository(this.file);
  final File file;

  static Future<FileAppSettingsRepository> createDefault() async {
    final root = await resolveGoalTrackerDataRoot();
    return FileAppSettingsRepository(
      File('$root${Platform.pathSeparator}settings.json'),
    );
  }

  @override
  Future<AppSettingsData> load() async {
    if (!await file.exists()) return const AppSettingsData();
    try {
      return AppSettingsData.fromJson(jsonDecode(await file.readAsString()));
    } on Object {
      return const AppSettingsData();
    }
  }

  @override
  Future<void> save(AppSettingsData settings) async {
    await file.parent.create(recursive: true);
    const encoder = JsonEncoder.withIndent('  ');
    await file.writeAsString(
      '${encoder.convert(settings.toJson())}\n',
      flush: true,
    );
  }
}

class MemoryAppSettingsRepository implements AppSettingsRepository {
  MemoryAppSettingsRepository([this.settings = const AppSettingsData()]);
  AppSettingsData settings;
  @override
  Future<AppSettingsData> load() async => settings;
  @override
  Future<void> save(AppSettingsData settings) async => this.settings = settings;
}
