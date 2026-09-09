import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../data/goal_repository.dart';
import '../domain/goal.dart';
import '../domain/plan_calculator.dart';

typedef LocalFolderOpener = Future<bool> Function(String path);

class GoalStore extends ChangeNotifier {
  GoalStore({
    required this.repository,
    this.calculator = const PlanCalculator(),
    DateTime Function()? clock,
    LocalFolderOpener? openLocalFolder,
  }) : _clock = clock ?? DateTime.now,
       _openLocalFolder = openLocalFolder ?? _unsupportedFolderOpener;

  final GoalRepository repository;
  final PlanCalculator calculator;
  final DateTime Function() _clock;
  final LocalFolderOpener _openLocalFolder;
  final List<Goal> _goals = [];
  Goal? _undoGoal;

  bool isLoading = true;
  bool isSaving = false;
  DateTime? lastSavedAt;
  String? errorMessage;
  String? undoDescription;
  bool showingTrash = false;
  bool automaticStartsEnabled = true;

  List<Goal> get goals => List.unmodifiable(_goals);

  List<GoalLoadIssue> get loadIssues => repository.loadIssues;
  List<Goal> get trashedGoals =>
      _goals.where((goal) => goal.isTrashed).toList(growable: false);
  String get storagePath => repository.displayPath;
  DateTime get today => dateOnly(_clock());
  bool get canUndo => _undoGoal != null;
  List<String> get availableCategories {
    final custom =
        _goals
            .where((goal) => !GoalCategories.builtIn.contains(goal.category))
            .map((goal) => goal.category)
            .where((category) => category.trim().isNotEmpty)
            .toSet()
            .toList()
          ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return [...GoalCategories.builtIn, ...custom];
  }

  List<Goal> goalsFor(GoalStatus status, {String? category}) => _goals
      .where(
        (goal) =>
            !goal.isTrashed &&
            goal.status == status &&
            (category == null || goal.category == category),
      )
      .toList(growable: false);

  Goal? get pendingStartNotice {
    for (final goal in _goals) {
      if (!goal.isTrashed && goal.showStartNotice) return goal;
    }
    return null;
  }

  void setShowingTrash(bool value) {
    if (showingTrash == value) return;
    showingTrash = value;
    notifyListeners();
  }

  Future<void> load() async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();
    try {
      _goals
        ..clear()
        ..addAll(await repository.loadAll());
      await _applyAutomaticStarts();
    } catch (error) {
      errorMessage = 'Could not load the local goal files: $error';
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<Goal> createQuick(String name) async {
    final now = _clock();
    final goal = Goal(
      id: _newId(name, now),
      name: name.trim(),
      status: GoalStatus.ideas,
      createdAt: now,
      updatedAt: now,
    );
    _goals.add(goal);
    notifyListeners();
    await _save(goal);
    return goal;
  }

  Future<Goal> createPlanned({
    required String name,
    required double amount,
    required String unit,
    required DateTime startDate,
    required DateTime deadline,
    required bool wholeUnits,
    double initialCompletedAmount = 0,
  }) async {
    const activeWeekdays = {1, 2, 3, 4, 5, 6, 7};
    final now = _clock();
    final initial = initialCompletedAmount.clamp(0.0, amount).toDouble();
    final summary = calculator.summarize(
      amount: math.max(0, amount - initial),
      start: startDate,
      deadline: deadline,
      activeWeekdays: activeWeekdays,
    );
    final plan = GoalPlan(
      totalAmount: amount,
      unit: unit.trim(),
      startDate: dateOnly(startDate),
      deadline: dateOnly(deadline),
      activeWeekdays: Set.unmodifiable(activeWeekdays),
      wholeUnits: wholeUnits,
      acceptedDailyPace: summary.averageDailyAmount,
      initialCompletedAmount: initial,
    );
    final startsNow =
        automaticStartsEnabled && !dateOnly(startDate).isAfter(today);
    final completedAtStart = initial >= amount;
    final goal = Goal(
      id: _newId(name, now),
      name: name.trim(),
      status: completedAtStart
          ? GoalStatus.completed
          : startsNow
          ? GoalStatus.active
          : GoalStatus.planned,
      createdAt: now,
      updatedAt: now,
      plan: plan,
      completedAmount: initial,
      progressHistory: initial > 0
          ? [
              ProgressEntry(
                recordedAt: now,
                change: initial,
                completedAfter: initial,
                note: 'Starting progress',
              ),
            ]
          : const [],
      startedAutomaticallyAt: startsNow && !completedAtStart ? now : null,
      showStartNotice: startsNow && !completedAtStart,
    );
    _goals.add(goal);
    notifyListeners();
    await _save(goal);
    return goal;
  }

  Future<Goal> duplicateGoal(String goalId) async {
    final source = _find(goalId);
    if (source == null) throw ArgumentError.value(goalId, 'goalId');
    final now = _clock();
    final duplicate = Goal(
      id: _newId('${source.name} copy', now),
      name: '${source.name} copy',
      status: source.status,
      createdAt: now,
      updatedAt: now,
      category: source.category,
      isUrgent: false,
      plan: source.plan,
      completedAmount: source.completedAmount,
      progressHistory: source.progressHistory,
      dailyActionCompletions: source.dailyActionCompletions,
      steps: source.steps,
      updates: source.updates,
    );
    _goals.add(duplicate);
    notifyListeners();
    await _save(duplicate);
    return duplicate;
  }

  Future<void> moveGoal(String goalId, GoalStatus status) async {
    final goal = _find(goalId);
    if (goal == null || goal.status == status) return;
    _rememberUndo(goal, 'Move ${goal.name} back to ${goal.status.label}');
    await _replace(
      goal.copyWith(
        status: status,
        showStartNotice: false,
        updatedAt: _clock(),
      ),
    );
  }

  Future<void> setCategory(String goalId, String category) async {
    final goal = _find(goalId);
    final trimmed = category.trim();
    if (goal == null || trimmed.isEmpty || goal.category == trimmed) return;
    _rememberUndo(goal, 'Restore ${goal.name} to ${goal.category}');
    await _replace(goal.copyWith(category: trimmed, updatedAt: _clock()));
  }

  Future<void> setUrgency(
    String goalId, {
    required bool isUrgent,
    UrgencyStyle? style,
  }) async {
    final goal = _find(goalId);
    if (goal == null) return;
    final nextStyle = style ?? goal.urgencyStyle;
    if (goal.isUrgent == isUrgent && goal.urgencyStyle == nextStyle) return;
    _rememberUndo(
      goal,
      goal.isUrgent ? 'Make ${goal.name} urgent again' : 'Remove urgency',
    );
    await _replace(
      goal.copyWith(
        isUrgent: isUrgent,
        urgencyStyle: nextStyle,
        updatedAt: _clock(),
      ),
    );
  }

  Future<void> setReminder(String goalId, GoalReminder reminder) async {
    final goal = _find(goalId);
    if (goal == null) return;
    _rememberUndo(goal, 'Restore the previous reminder');
    final identifiedReminder = reminder.id.trim().isEmpty
        ? reminder.copyWith(id: '${goal.id}-reminder-main')
        : reminder;
    await _replace(
      goal.copyWith(reminder: identifiedReminder, updatedAt: _clock()),
    );
  }

  Future<void> removeReminder(String goalId) async {
    final goal = _find(goalId);
    if (goal == null || goal.reminder == null) return;
    _rememberUndo(goal, 'Restore the reminder');
    await _replace(goal.copyWith(clearReminder: true, updatedAt: _clock()));
  }

  Future<void> snoozeReminder(String goalId, DateTime until) async {
    final goal = _find(goalId);
    final reminder = goal?.reminder;
    if (goal == null || reminder == null) return;
    await _replace(
      goal.copyWith(
        reminder: reminder.copyWith(snoozedUntil: until),
        updatedAt: _clock(),
      ),
    );
  }

  Future<void> recordProgress(
    String goalId,
    double completedAmount, {
    String note = '',
  }) async {
    final goal = _find(goalId);
    final plan = goal?.plan;
    if (goal == null || plan == null) return;
    if (completedAmount < 0 || completedAmount > plan.totalAmount) {
      throw ArgumentError.value(
        completedAmount,
        'completedAmount',
        'Must be between 0 and ${plan.totalAmount}.',
      );
    }
    final next = completedAmount;
    final change = next - goal.completedAmount;
    if (change == 0) return;
    _rememberUndo(goal, 'Restore the previous progress');
    final history = List<ProgressEntry>.of(goal.progressHistory)
      ..add(
        ProgressEntry(
          recordedAt: _clock(),
          change: change,
          completedAfter: next,
          note: note.trim(),
        ),
      );
    await _replace(
      goal.copyWith(
        completedAmount: next,
        progressHistory: history,
        showStartNotice: false,
        updatedAt: _clock(),
      ),
    );
  }

  Future<void> addStep(
    String goalId,
    String title, {
    String details = '',
  }) async {
    await addSteps(goalId, [title], details: details);
  }

  Future<void> addSteps(
    String goalId,
    Iterable<String> titles, {
    String details = '',
  }) async {
    final goal = _find(goalId);
    final cleaned = titles
        .map((title) => title.trim())
        .where((title) => title.isNotEmpty)
        .toList(growable: false);
    if (goal == null || cleaned.isEmpty) return;
    final now = _clock();
    _rememberUndo(
      goal,
      cleaned.length == 1 ? 'Remove the new step' : 'Remove the new steps',
    );
    final additions = <GoalStep>[];
    for (var index = 0; index < cleaned.length; index++) {
      final createdAt = now.add(Duration(microseconds: index));
      additions.add(
        GoalStep(
          id: _newStepId(goal, createdAt, additional: additions),
          title: cleaned[index],
          details: details.trim(),
          createdAt: createdAt,
        ),
      );
    }
    await _replace(
      goal.copyWith(steps: [...goal.steps, ...additions], updatedAt: now),
    );
  }

  Future<void> updateStep(
    String goalId,
    String stepId, {
    required String title,
    String details = '',
  }) async {
    final goal = _find(goalId);
    final trimmed = title.trim();
    if (goal == null || trimmed.isEmpty) return;
    final index = goal.steps.indexWhere((step) => step.id == stepId);
    if (index < 0) return;
    final step = goal.steps[index];
    final nextDetails = details.trim();
    if (step.title == trimmed && step.details == nextDetails) return;
    _rememberUndo(goal, 'Restore the previous step details');
    final steps = List<GoalStep>.of(goal.steps);
    steps[index] = step.copyWith(title: trimmed, details: nextDetails);
    final updates = goal.updates
        .map(
          (update) => update.stepId == stepId
              ? update.copyWith(stepTitle: trimmed)
              : update,
        )
        .toList(growable: false);
    await _replace(
      goal.copyWith(steps: steps, updates: updates, updatedAt: _clock()),
    );
  }

  Future<void> reorderStep(String goalId, int oldIndex, int newIndex) async {
    final goal = _find(goalId);
    if (goal == null ||
        oldIndex < 0 ||
        oldIndex >= goal.steps.length ||
        newIndex < 0 ||
        newIndex > goal.steps.length ||
        oldIndex == newIndex) {
      return;
    }
    _rememberUndo(goal, 'Restore the previous step order');
    final steps = List<GoalStep>.of(goal.steps);
    final step = steps.removeAt(oldIndex);
    final destination = newIndex > oldIndex ? newIndex - 1 : newIndex;
    steps.insert(destination, step);
    await _replace(goal.copyWith(steps: steps, updatedAt: _clock()));
  }

  Future<void> toggleStep(String goalId, String stepId) async {
    final goal = _find(goalId);
    if (goal == null) return;
    final index = goal.steps.indexWhere((step) => step.id == stepId);
    if (index < 0) return;
    final step = goal.steps[index];
    if (!step.isCompleted) {
      await completeStep(goalId, stepId);
      return;
    }
    await reopenStep(goalId, stepId);
  }

  Future<void> completeStep(
    String goalId,
    String stepId, {
    String note = '',
  }) async {
    final goal = _find(goalId);
    if (goal == null) return;
    final index = goal.steps.indexWhere((step) => step.id == stepId);
    if (index < 0 || goal.steps[index].isCompleted) return;
    final step = goal.steps[index];
    final now = _clock();
    _rememberUndo(goal, 'Uncheck ${step.title}');
    final steps = List<GoalStep>.of(goal.steps);
    steps[index] = step.copyWith(completedAt: now);
    final updateText = note.trim().isEmpty ? 'Completed' : note.trim();
    final updates = [
      ...goal.updates,
      GoalUpdate(
        id: _newUpdateId(goal, now),
        recordedAt: now,
        text: updateText,
        stepId: step.id,
        stepTitle: step.title,
        kind: GoalUpdateKind.stepCompletion,
      ),
    ];
    await _replace(
      goal.copyWith(steps: steps, updates: updates, updatedAt: now),
    );
  }

  Future<void> reopenStep(String goalId, String stepId) async {
    final goal = _find(goalId);
    if (goal == null) return;
    final index = goal.steps.indexWhere((step) => step.id == stepId);
    if (index < 0 || !goal.steps[index].isCompleted) return;
    final step = goal.steps[index];
    final now = _clock();
    _rememberUndo(goal, 'Mark ${step.title} complete again');
    final steps = List<GoalStep>.of(goal.steps);
    steps[index] = step.copyWith(clearCompletedAt: true);
    final updates = [
      ...goal.updates,
      GoalUpdate(
        id: _newUpdateId(goal, now),
        recordedAt: now,
        text: 'Reopened',
        stepId: step.id,
        stepTitle: step.title,
        kind: GoalUpdateKind.stepReopened,
      ),
    ];
    await _replace(
      goal.copyWith(steps: steps, updates: updates, updatedAt: now),
    );
  }

  Future<void> removeStep(String goalId, String stepId) async {
    final goal = _find(goalId);
    if (goal == null) return;
    final index = goal.steps.indexWhere((step) => step.id == stepId);
    if (index < 0) return;
    final step = goal.steps[index];
    _rememberUndo(goal, 'Restore ${step.title}');
    final updates = goal.updates
        .map(
          (update) => update.stepId == stepId
              ? update.copyWith(clearStep: true, kind: GoalUpdateKind.note)
              : update,
        )
        .toList(growable: false);
    await _replace(
      goal.copyWith(
        steps: goal.steps
            .where((candidate) => candidate.id != stepId)
            .toList(growable: false),
        updates: updates,
        updatedAt: _clock(),
      ),
    );
  }

  Future<void> addUpdate(
    String goalId,
    String text, {
    String? stepId,
    GoalUpdateKind kind = GoalUpdateKind.note,
    String? updateId,
  }) async {
    final goal = _find(goalId);
    final trimmed = text.trim();
    if (goal == null || trimmed.isEmpty) return;
    final requestedId = updateId?.trim();
    if (requestedId?.isNotEmpty == true &&
        goal.updates.any((update) => update.id == requestedId)) {
      return;
    }
    final relatedStepId =
        stepId != null && goal.steps.any((step) => step.id == stepId)
        ? stepId
        : null;
    final relatedStepTitle = relatedStepId == null
        ? null
        : goal.steps.firstWhere((step) => step.id == relatedStepId).title;
    _rememberUndo(goal, 'Remove the latest update');
    final now = _clock();
    await _replace(
      goal.copyWith(
        updates: [
          ...goal.updates,
          GoalUpdate(
            id: requestedId?.isNotEmpty == true
                ? requestedId!
                : _newUpdateId(goal, now),
            recordedAt: now,
            text: trimmed,
            stepId: relatedStepId,
            stepTitle: relatedStepTitle,
            kind: kind,
          ),
        ],
        updatedAt: now,
      ),
    );
  }

  Future<void> recordMissedReminder(
    String goalId, {
    required String occurrenceId,
  }) => addUpdate(
    goalId,
    'Marked not done from a reminder.',
    kind: GoalUpdateKind.reminderMissed,
    updateId: 'notification-$occurrenceId-not-done',
  );

  Future<void> editUpdate(String goalId, String updateId, String text) async {
    final goal = _find(goalId);
    final trimmed = text.trim();
    if (goal == null || trimmed.isEmpty) return;
    final index = goal.updates.indexWhere((update) => update.id == updateId);
    if (index < 0 || goal.updates[index].text == trimmed) return;
    final now = _clock();
    _rememberUndo(goal, 'Restore the previous update');
    final updates = List<GoalUpdate>.of(goal.updates);
    updates[index] = updates[index].copyWith(text: trimmed, editedAt: now);
    await _replace(goal.copyWith(updates: updates, updatedAt: now));
  }

  Future<void> deleteUpdate(String goalId, String updateId) async {
    final goal = _find(goalId);
    if (goal == null || !goal.updates.any((update) => update.id == updateId)) {
      return;
    }
    _rememberUndo(goal, 'Restore the deleted update');
    await _replace(
      goal.copyWith(
        updates: goal.updates
            .where((update) => update.id != updateId)
            .toList(growable: false),
        updatedAt: _clock(),
      ),
    );
  }

  Future<void> moveUpdate(
    String goalId,
    String updateId, {
    String? stepId,
  }) async {
    final goal = _find(goalId);
    if (goal == null) return;
    final index = goal.updates.indexWhere((update) => update.id == updateId);
    if (index < 0) return;
    GoalStep? step;
    if (stepId != null) {
      for (final candidate in goal.steps) {
        if (candidate.id == stepId) {
          step = candidate;
          break;
        }
      }
      if (step == null) return;
    }
    final now = _clock();
    _rememberUndo(goal, 'Restore the update location');
    final updates = List<GoalUpdate>.of(goal.updates);
    updates[index] = step == null
        ? updates[index].copyWith(
            clearStep: true,
            kind: GoalUpdateKind.note,
            editedAt: now,
          )
        : updates[index].copyWith(
            stepId: step.id,
            stepTitle: step.title,
            kind: GoalUpdateKind.note,
            editedAt: now,
          );
    await _replace(goal.copyWith(updates: updates, updatedAt: now));
  }

  Future<void> completeTodayAction(String goalId, {String note = ''}) async {
    final goal = _find(goalId);
    final plan = goal?.plan;
    if (goal == null || plan == null || goal.completionFor(today) != null) {
      return;
    }
    final amount = calculator.actionForDate(goal, today);
    if (amount <= 0) return;
    final next = math.min(plan.totalAmount, goal.completedAmount + amount);
    final actualChange = next - goal.completedAmount;
    if (actualChange <= 0) return;
    _rememberUndo(goal, 'Mark today\'s action not complete');
    final now = _clock();
    await _replace(
      goal.copyWith(
        completedAmount: next,
        progressHistory: [
          ...goal.progressHistory,
          ProgressEntry(
            recordedAt: now,
            change: actualChange,
            completedAfter: next,
            note: note.trim(),
          ),
        ],
        dailyActionCompletions: [
          ...goal.dailyActionCompletions,
          DailyActionCompletion(
            actionDate: today,
            completedAt: now,
            amount: actualChange,
            note: note.trim(),
          ),
        ],
        showStartNotice: false,
        updatedAt: now,
      ),
    );
  }

  Future<void> undoTodayAction(String goalId) async {
    final goal = _find(goalId);
    final plan = goal?.plan;
    final completion = goal?.completionFor(today);
    if (goal == null || plan == null || completion == null) return;
    _rememberUndo(goal, 'Mark today\'s action complete again');
    final next = math.max(0, goal.completedAmount - completion.amount);
    final completions = List<DailyActionCompletion>.of(
      goal.dailyActionCompletions,
    )..remove(completion);
    await _replace(
      goal.copyWith(
        completedAmount: next.toDouble(),
        progressHistory: [
          ...goal.progressHistory,
          ProgressEntry(
            recordedAt: _clock(),
            change: -completion.amount,
            completedAfter: next.toDouble(),
            note: 'Reverted today\'s action',
          ),
        ],
        dailyActionCompletions: completions,
        updatedAt: _clock(),
      ),
    );
  }

  Future<void> addPlan({
    required String goalId,
    required double amount,
    required String unit,
    required DateTime startDate,
    required DateTime deadline,
    required bool wholeUnits,
    double initialCompletedAmount = 0,
  }) async {
    final goal = _find(goalId);
    if (goal == null) return;
    const activeWeekdays = {1, 2, 3, 4, 5, 6, 7};
    final initial = initialCompletedAmount.clamp(0.0, amount).toDouble();
    final summary = calculator.summarize(
      amount: math.max(0, amount - initial),
      start: startDate,
      deadline: deadline,
      activeWeekdays: activeWeekdays,
    );
    final plan = GoalPlan(
      totalAmount: amount,
      unit: unit.trim(),
      startDate: dateOnly(startDate),
      deadline: dateOnly(deadline),
      activeWeekdays: activeWeekdays,
      wholeUnits: wholeUnits,
      acceptedDailyPace: summary.averageDailyAmount,
      initialCompletedAmount: initial,
    );
    final startsNow =
        automaticStartsEnabled && !dateOnly(startDate).isAfter(today);
    final completedAtStart = initial >= amount;
    _rememberUndo(goal, 'Remove the new plan');
    await _replace(
      goal.copyWith(
        status: completedAtStart
            ? GoalStatus.completed
            : startsNow
            ? GoalStatus.active
            : GoalStatus.planned,
        plan: plan,
        completedAmount: initial,
        progressHistory: initial > 0
            ? [
                ...goal.progressHistory,
                ProgressEntry(
                  recordedAt: _clock(),
                  change: initial - goal.completedAmount,
                  completedAfter: initial,
                  note: 'Starting progress',
                ),
              ]
            : goal.progressHistory,
        startedAutomaticallyAt: startsNow && !completedAtStart
            ? _clock()
            : null,
        clearStartedAutomaticallyAt: !startsNow || completedAtStart,
        showStartNotice: startsNow && !completedAtStart,
        updatedAt: _clock(),
      ),
    );
  }

  Future<void> removePlan(String goalId) async {
    final goal = _find(goalId);
    if (goal == null || goal.plan == null) return;
    _rememberUndo(goal, 'Restore the removed plan');
    await _replace(
      goal.copyWith(
        status: GoalStatus.ideas,
        clearPlan: true,
        completedAmount: 0,
        progressHistory: const [],
        dailyActionCompletions: const [],
        clearStartedAutomaticallyAt: true,
        showStartNotice: false,
        updatedAt: _clock(),
      ),
    );
  }

  Future<void> trashGoal(String goalId) async {
    final goal = _find(goalId);
    if (goal == null || goal.isTrashed) return;
    _rememberUndo(goal, 'Restore ${goal.name}');
    await _replace(
      goal.copyWith(
        trashedAt: _clock(),
        showStartNotice: false,
        updatedAt: _clock(),
      ),
    );
  }

  Future<void> restoreGoal(String goalId) async {
    final goal = _find(goalId);
    if (goal == null || !goal.isTrashed) return;
    _rememberUndo(goal, 'Move ${goal.name} back to Trash');
    await _replace(
      goal.copyWith(
        clearTrashedAt: true,
        showStartNotice: false,
        updatedAt: _clock(),
      ),
    );
  }

  Future<void> deleteForever(String goalId) async {
    final goal = _find(goalId);
    if (goal == null || !goal.isTrashed) return;
    isSaving = true;
    notifyListeners();
    try {
      await repository.delete(goal);
      _goals.removeWhere((candidate) => candidate.id == goal.id);
      if (_undoGoal?.id == goal.id) {
        _undoGoal = null;
        undoDescription = null;
      }
      errorMessage = null;
    } catch (error) {
      errorMessage = 'Could not permanently delete ${goal.name}: $error';
    } finally {
      isSaving = false;
      notifyListeners();
    }
  }

  Future<void> undoLastChange() async {
    final goal = _undoGoal;
    if (goal == null) return;
    _undoGoal = null;
    undoDescription = null;
    await _replace(goal.copyWith(updatedAt: _clock()));
  }

  Future<bool> openStorageFolder() => _openLocalFolder(storagePath);

  Future<void> beginToday(String goalId) async {
    final goal = _find(goalId);
    if (goal == null) return;
    await _replace(goal.copyWith(showStartNotice: false, updatedAt: _clock()));
  }

  Future<void> delayStart(String goalId, DateTime newDate) async {
    final goal = _find(goalId);
    final plan = goal?.plan;
    if (goal == null || plan == null) return;
    _rememberUndo(goal, 'Restore the previous start date');
    final summary = calculator.summarize(
      amount: math.max(0, plan.totalAmount - goal.completedAmount),
      start: newDate,
      deadline: plan.deadline,
      activeWeekdays: plan.activeWeekdays,
    );
    await _replace(
      goal.copyWith(
        status: GoalStatus.planned,
        plan: plan.copyWith(
          startDate: dateOnly(newDate),
          acceptedDailyPace: summary.averageDailyAmount,
          initialCompletedAmount: goal.completedAmount,
        ),
        clearStartedAutomaticallyAt: true,
        showStartNotice: false,
        updatedAt: _clock(),
      ),
    );
  }

  Future<void> undoAutomaticStart(String goalId) async {
    final goal = _find(goalId);
    if (goal == null) return;
    _rememberUndo(goal, 'Restore the automatic start');
    await _replace(
      goal.copyWith(
        status: GoalStatus.planned,
        showStartNotice: false,
        updatedAt: _clock(),
      ),
    );
  }

  Future<void> dismissStartNotice(String goalId) async {
    final goal = _find(goalId);
    if (goal == null) return;
    await _replace(goal.copyWith(showStartNotice: false, updatedAt: _clock()));
  }

  Goal? goalById(String id) => _find(id);

  Future<void> _applyAutomaticStarts() async {
    if (!automaticStartsEnabled) return;
    for (final goal in List<Goal>.of(_goals)) {
      if (goal.isTrashed) continue;
      final plan = goal.plan;
      if (goal.status != GoalStatus.planned ||
          plan == null ||
          goal.startedAutomaticallyAt != null ||
          plan.startDate.isAfter(today)) {
        continue;
      }
      final started = goal.copyWith(
        status: GoalStatus.active,
        startedAutomaticallyAt: _clock(),
        showStartNotice: true,
        updatedAt: _clock(),
      );
      await _replace(started, notify: false);
    }
  }

  Goal? _find(String id) {
    for (final goal in _goals) {
      if (goal.id == id) return goal;
    }
    return null;
  }

  void _rememberUndo(Goal goal, String description) {
    _undoGoal = goal;
    undoDescription = description;
    notifyListeners();
  }

  Future<void> _replace(Goal goal, {bool notify = true}) async {
    final index = _goals.indexWhere((candidate) => candidate.id == goal.id);
    if (index < 0) return;
    _goals[index] = goal;
    if (notify) notifyListeners();
    await _save(goal);
  }

  Future<void> _save(Goal goal) async {
    isSaving = true;
    notifyListeners();
    try {
      await repository.save(goal);
      errorMessage = null;
      lastSavedAt = _clock();
    } catch (error) {
      errorMessage = 'Could not save ${goal.name}: $error';
    } finally {
      isSaving = false;
      notifyListeners();
    }
  }

  static Future<bool> _unsupportedFolderOpener(String _) async => false;

  String _newId(String name, DateTime now) {
    final slug = name
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-|-$'), '');
    return '${now.microsecondsSinceEpoch}-${slug.isEmpty ? 'goal' : slug}';
  }

  String _newStepId(
    Goal goal,
    DateTime now, {
    Iterable<GoalStep> additional = const [],
  }) {
    final base = '${goal.id}-step-${now.microsecondsSinceEpoch}';
    var candidate = base;
    var suffix = 2;
    while (goal.steps.any((step) => step.id == candidate) ||
        additional.any((step) => step.id == candidate)) {
      candidate = '$base-$suffix';
      suffix++;
    }
    return candidate;
  }

  String _newUpdateId(Goal goal, DateTime now) {
    final base = '${goal.id}-update-${now.microsecondsSinceEpoch}';
    var candidate = base;
    var suffix = 2;
    while (goal.updates.any((update) => update.id == candidate)) {
      candidate = '$base-$suffix';
      suffix++;
    }
    return candidate;
  }
}
