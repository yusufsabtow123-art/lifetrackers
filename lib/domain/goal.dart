enum GoalStatus {
  ideas('Ideas', 'Captured outcomes that are not planned yet.'),
  planned(
    'Planned',
    'Outcomes you intend to begin; planning details may be added separately.',
  ),
  active('Active', 'Outcomes you are working on now.'),
  paused(
    'Paused',
    'Outcomes you still want, but have intentionally put on hold.',
  ),
  completed('Completed', 'Finished outcomes kept as a record.'),
  abandoned('Abandoned', 'Intentionally stopped outcomes kept as history.');

  const GoalStatus(this.label, this.description);

  final String label;
  final String description;

  static GoalStatus parse(String value) {
    if (value == 'blocked') return GoalStatus.paused;
    return GoalStatus.values.firstWhere(
      (status) => status.name == value,
      orElse: () => GoalStatus.ideas,
    );
  }

  static List<GoalStatus> visibleValues({required bool showAbandoned}) =>
      GoalStatus.values
          .where((status) => showAbandoned || status != GoalStatus.abandoned)
          .toList(growable: false);
}

enum GoalHealth {
  none('No schedule'),
  onTrack('On track'),
  atRisk('At risk'),
  behind('Behind');

  const GoalHealth(this.label);

  final String label;
}

abstract final class GoalCategories {
  static const other = 'Other';
  static const builtIn = <String>[
    'Faith',
    'Health',
    'Mind',
    'Body',
    'Finances',
    'Work',
    'Personal',
    other,
  ];
}

enum UrgencyStyle {
  fireRing('Fire ring'),
  policeSiren('Police siren');

  const UrgencyStyle(this.label);

  final String label;

  static UrgencyStyle parse(String? value) => UrgencyStyle.values.firstWhere(
    (style) => style.name == value,
    orElse: () => UrgencyStyle.fireRing,
  );
}

enum ReminderPurpose {
  dailyAction('Daily action'),
  goalCompletion('Goal completion');

  const ReminderPurpose(this.label);

  final String label;

  static ReminderPurpose parse(
    String? value, {
    required ReminderPurpose fallback,
  }) => ReminderPurpose.values.firstWhere(
    (purpose) => purpose.name == value,
    orElse: () => fallback,
  );
}

enum ReminderFrequency {
  once('Once'),
  daily('Every day'),
  weekdays('Weekdays'),
  weekly('Every week'),
  customDays('Custom days');

  const ReminderFrequency(this.label);
  final String label;

  static ReminderFrequency parse(String? value) =>
      ReminderFrequency.values.firstWhere(
        (item) => item.name == value,
        orElse: () => ReminderFrequency.daily,
      );
}

class GoalReminder {
  const GoalReminder({
    this.id = '',
    this.enabled = true,
    required this.message,
    required this.frequency,
    required this.hour,
    required this.minute,
    this.purpose = ReminderPurpose.dailyAction,
    this.weekdays = const {1, 2, 3, 4, 5, 6, 7},
    this.onceAt,
    this.snoozedUntil,
  });

  final String id;
  final bool enabled;
  final String message;
  final ReminderFrequency frequency;
  final int hour;
  final int minute;
  final ReminderPurpose purpose;
  final Set<int> weekdays;
  final DateTime? onceAt;
  final DateTime? snoozedUntil;

  GoalReminder copyWith({
    String? id,
    bool? enabled,
    String? message,
    ReminderFrequency? frequency,
    int? hour,
    int? minute,
    ReminderPurpose? purpose,
    Set<int>? weekdays,
    DateTime? onceAt,
    bool clearOnceAt = false,
    DateTime? snoozedUntil,
    bool clearSnoozedUntil = false,
  }) => GoalReminder(
    id: id ?? this.id,
    enabled: enabled ?? this.enabled,
    message: message ?? this.message,
    frequency: frequency ?? this.frequency,
    hour: hour ?? this.hour,
    minute: minute ?? this.minute,
    purpose: purpose ?? this.purpose,
    weekdays: weekdays ?? this.weekdays,
    onceAt: clearOnceAt ? null : onceAt ?? this.onceAt,
    snoozedUntil: clearSnoozedUntil ? null : snoozedUntil ?? this.snoozedUntil,
  );
}

class ProgressEntry {
  const ProgressEntry({
    required this.recordedAt,
    required this.change,
    required this.completedAfter,
    this.note = '',
  });

  final DateTime recordedAt;
  final double change;
  final double completedAfter;
  final String note;
}

class DailyActionCompletion {
  const DailyActionCompletion({
    required this.actionDate,
    required this.completedAt,
    required this.amount,
    this.note = '',
  });

  final DateTime actionDate;
  final DateTime completedAt;
  final double amount;
  final String note;
}

class GoalStep {
  const GoalStep({
    required this.id,
    required this.title,
    required this.createdAt,
    this.details = '',
    this.completedAt,
  });

  final String id;
  final String title;
  final String details;
  final DateTime createdAt;
  final DateTime? completedAt;

  bool get isCompleted => completedAt != null;

  GoalStep copyWith({
    String? title,
    String? details,
    DateTime? completedAt,
    bool clearCompletedAt = false,
  }) => GoalStep(
    id: id,
    title: title ?? this.title,
    details: details ?? this.details,
    createdAt: createdAt,
    completedAt: clearCompletedAt ? null : completedAt ?? this.completedAt,
  );
}

enum GoalUpdateKind {
  note,
  stepCompletion,
  stepReopened,
  reminderMissed;

  static GoalUpdateKind parse(String? value) =>
      GoalUpdateKind.values.firstWhere(
        (kind) => kind.name == value,
        orElse: () => GoalUpdateKind.note,
      );
}

class GoalUpdate {
  const GoalUpdate({
    this.id = '',
    required this.recordedAt,
    required this.text,
    this.stepId,
    this.stepTitle,
    this.kind = GoalUpdateKind.note,
    this.editedAt,
  });

  final String id;
  final DateTime recordedAt;
  final String text;
  final String? stepId;
  final String? stepTitle;
  final GoalUpdateKind kind;
  final DateTime? editedAt;

  GoalUpdate copyWith({
    String? text,
    String? stepId,
    String? stepTitle,
    bool clearStep = false,
    GoalUpdateKind? kind,
    DateTime? editedAt,
  }) => GoalUpdate(
    id: id,
    recordedAt: recordedAt,
    text: text ?? this.text,
    stepId: clearStep ? null : stepId ?? this.stepId,
    stepTitle: clearStep ? null : stepTitle ?? this.stepTitle,
    kind: kind ?? this.kind,
    editedAt: editedAt ?? this.editedAt,
  );
}

class GoalPlan {
  const GoalPlan({
    required this.totalAmount,
    required this.unit,
    required this.startDate,
    required this.deadline,
    required this.activeWeekdays,
    required this.wholeUnits,
    required this.acceptedDailyPace,
    this.initialCompletedAmount = 0,
  });

  final double totalAmount;
  final String unit;
  final DateTime startDate;
  final DateTime deadline;
  final Set<int> activeWeekdays;
  final bool wholeUnits;
  final double acceptedDailyPace;
  final double initialCompletedAmount;

  GoalPlan copyWith({
    DateTime? startDate,
    DateTime? deadline,
    double? acceptedDailyPace,
    double? initialCompletedAmount,
  }) => GoalPlan(
    totalAmount: totalAmount,
    unit: unit,
    startDate: startDate ?? this.startDate,
    deadline: deadline ?? this.deadline,
    activeWeekdays: activeWeekdays,
    wholeUnits: wholeUnits,
    acceptedDailyPace: acceptedDailyPace ?? this.acceptedDailyPace,
    initialCompletedAmount:
        initialCompletedAmount ?? this.initialCompletedAmount,
  );
}

class Goal {
  const Goal({
    required this.id,
    required this.name,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.category = GoalCategories.other,
    this.isUrgent = false,
    this.urgencyStyle = UrgencyStyle.fireRing,
    this.reminder,
    this.plan,
    this.completedAmount = 0,
    this.progressHistory = const [],
    this.dailyActionCompletions = const [],
    this.steps = const [],
    this.updates = const [],
    this.startedAutomaticallyAt,
    this.showStartNotice = false,
    this.trashedAt,
  });

  final String id;
  final String name;
  final GoalStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;
  final GoalPlan? plan;
  final String category;
  final bool isUrgent;
  final UrgencyStyle urgencyStyle;
  final GoalReminder? reminder;
  final double completedAmount;
  final List<ProgressEntry> progressHistory;
  final List<DailyActionCompletion> dailyActionCompletions;
  final List<GoalStep> steps;
  final List<GoalUpdate> updates;
  final DateTime? startedAutomaticallyAt;
  final bool showStartNotice;
  final DateTime? trashedAt;

  bool get isTrashed => trashedAt != null;

  double get progress {
    final total = plan?.totalAmount ?? 0;
    if (total > 0) return (completedAmount / total).clamp(0, 1);
    if (steps.isEmpty) return 0;
    return steps.where((step) => step.isCompleted).length / steps.length;
  }

  int get completedStepCount => steps.where((step) => step.isCompleted).length;

  DailyActionCompletion? completionFor(DateTime date) {
    for (final completion in dailyActionCompletions) {
      if (completion.actionDate.year == date.year &&
          completion.actionDate.month == date.month &&
          completion.actionDate.day == date.day) {
        return completion;
      }
    }
    return null;
  }

  Goal copyWith({
    String? name,
    GoalStatus? status,
    GoalPlan? plan,
    String? category,
    bool? isUrgent,
    UrgencyStyle? urgencyStyle,
    GoalReminder? reminder,
    bool clearReminder = false,
    bool clearPlan = false,
    double? completedAmount,
    List<ProgressEntry>? progressHistory,
    List<DailyActionCompletion>? dailyActionCompletions,
    List<GoalStep>? steps,
    List<GoalUpdate>? updates,
    DateTime? startedAutomaticallyAt,
    bool clearStartedAutomaticallyAt = false,
    bool? showStartNotice,
    DateTime? trashedAt,
    bool clearTrashedAt = false,
    DateTime? updatedAt,
  }) => Goal(
    id: id,
    name: name ?? this.name,
    status: status ?? this.status,
    createdAt: createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    category: category ?? this.category,
    isUrgent: isUrgent ?? this.isUrgent,
    urgencyStyle: urgencyStyle ?? this.urgencyStyle,
    reminder: clearReminder ? null : reminder ?? this.reminder,
    plan: clearPlan ? null : plan ?? this.plan,
    completedAmount: completedAmount ?? this.completedAmount,
    progressHistory: progressHistory ?? this.progressHistory,
    dailyActionCompletions:
        dailyActionCompletions ?? this.dailyActionCompletions,
    steps: steps ?? this.steps,
    updates: updates ?? this.updates,
    startedAutomaticallyAt: clearStartedAutomaticallyAt
        ? null
        : startedAutomaticallyAt ?? this.startedAutomaticallyAt,
    showStartNotice: showStartNotice ?? this.showStartNotice,
    trashedAt: clearTrashedAt ? null : trashedAt ?? this.trashedAt,
  );
}
