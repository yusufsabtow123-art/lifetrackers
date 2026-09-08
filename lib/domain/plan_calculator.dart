import 'dart:math' as math;

import 'goal.dart';

class PlanSummary {
  const PlanSummary({
    required this.activeDayCount,
    required this.averageDailyAmount,
    required this.wholeUnitHighDays,
    required this.wholeUnitLowAmount,
    required this.wholeUnitHighAmount,
  });

  final int activeDayCount;
  final double averageDailyAmount;
  final int wholeUnitHighDays;
  final int wholeUnitLowAmount;
  final int wholeUnitHighAmount;

  String describe(String unit, {required bool wholeUnits}) {
    if (activeDayCount == 0) return 'Choose a deadline after the start date.';
    if (!wholeUnits) {
      return '${formatAmount(averageDailyAmount)} $unit each active day';
    }
    if (wholeUnitHighDays == 0 || wholeUnitHighAmount == wholeUnitLowAmount) {
      return '$wholeUnitLowAmount ${pluralize(unit, wholeUnitLowAmount)} each active day';
    }
    final lowDays = activeDayCount - wholeUnitHighDays;
    if (wholeUnitLowAmount == 0) {
      return '$wholeUnitHighAmount ${pluralize(unit, wholeUnitHighAmount)} on '
          '$wholeUnitHighDays of $activeDayCount active days';
    }
    return '$wholeUnitLowAmount ${pluralize(unit, wholeUnitLowAmount)} on $lowDays days, '
        '$wholeUnitHighAmount ${pluralize(unit, wholeUnitHighAmount)} on $wholeUnitHighDays days';
  }
}

class GoalHealthSnapshot {
  const GoalHealthSnapshot({
    required this.health,
    required this.expectedProgress,
    required this.requiredDailyPace,
    required this.paceIncrease,
    required this.progressGap,
  });

  final GoalHealth health;
  final double expectedProgress;
  final double requiredDailyPace;
  final double paceIncrease;
  final double progressGap;
}

class PlanCalculator {
  const PlanCalculator();

  PlanSummary summarize({
    required double amount,
    required DateTime start,
    required DateTime deadline,
    required Set<int> activeWeekdays,
  }) {
    final days = _activeDayCount(start, deadline, activeWeekdays);
    return _summaryForDayCount(amount, days);
  }

  PlanSummary _summaryForDayCount(double amount, int days) {
    if (days == 0) {
      return const PlanSummary(
        activeDayCount: 0,
        averageDailyAmount: 0,
        wholeUnitHighDays: 0,
        wholeUnitLowAmount: 0,
        wholeUnitHighAmount: 0,
      );
    }
    final wholeAmount = amount.ceil();
    final low = wholeAmount ~/ days;
    final remainder = wholeAmount % days;
    return PlanSummary(
      activeDayCount: days,
      averageDailyAmount: amount / days,
      wholeUnitHighDays: remainder,
      wholeUnitLowAmount: low,
      wholeUnitHighAmount: remainder == 0 ? low : low + 1,
    );
  }

  List<DateTime> activeDatesBetween(
    DateTime start,
    DateTime end,
    Set<int> activeWeekdays,
  ) {
    final normalizedStart = dateOnly(start);
    final normalizedEnd = dateOnly(end);
    if (normalizedEnd.isBefore(normalizedStart) || activeWeekdays.isEmpty) {
      return const [];
    }
    final dates = <DateTime>[];
    for (
      var day = normalizedStart;
      !day.isAfter(normalizedEnd);
      day = DateTime(day.year, day.month, day.day + 1)
    ) {
      if (activeWeekdays.contains(day.weekday)) dates.add(day);
    }
    return dates;
  }

  double actionForDate(Goal goal, DateTime date) {
    final plan = goal.plan;
    if (plan == null || goal.status != GoalStatus.active) return 0;
    final normalizedDate = dateOnly(date);
    final start = dateOnly(plan.startDate);
    final deadline = dateOnly(plan.deadline);
    if (normalizedDate.isBefore(start) ||
        normalizedDate.isAfter(deadline) ||
        !plan.activeWeekdays.contains(normalizedDate.weekday)) {
      return 0;
    }
    final index =
        _activeDayCount(start, normalizedDate, plan.activeWeekdays) - 1;
    if (!plan.wholeUnits) {
      return math.min(
        plan.acceptedDailyPace,
        plan.totalAmount - goal.completedAmount,
      );
    }
    final summary = _summaryForDayCount(
      math.max(0, plan.totalAmount - plan.initialCompletedAmount),
      _activeDayCount(start, deadline, plan.activeWeekdays),
    );
    final scheduled = index < summary.wholeUnitHighDays
        ? summary.wholeUnitHighAmount.toDouble()
        : summary.wholeUnitLowAmount.toDouble();
    return math.min(scheduled, plan.totalAmount - goal.completedAmount);
  }

  GoalHealthSnapshot healthFor(Goal goal, DateTime today) {
    final plan = goal.plan;
    if (plan == null || goal.status != GoalStatus.active) {
      return const GoalHealthSnapshot(
        health: GoalHealth.none,
        expectedProgress: 0,
        requiredDailyPace: 0,
        paceIncrease: 0,
        progressGap: 0,
      );
    }

    final start = dateOnly(plan.startDate);
    final deadline = dateOnly(plan.deadline);
    final normalizedToday = dateOnly(today);
    final allDateCount = _activeDayCount(start, deadline, plan.activeWeekdays);
    final elapsed = _activeDayCount(
      start,
      normalizedToday.isAfter(deadline) ? deadline : normalizedToday,
      plan.activeWeekdays,
    );
    final initial = plan.initialCompletedAmount
        .clamp(0.0, plan.totalAmount)
        .toDouble();
    final plannedAmount = math.max(0.0, plan.totalAmount - initial);
    final expectedAmount = allDateCount == 0
        ? initial
        : initial + plannedAmount * (elapsed / allDateCount).clamp(0.0, 1.0);
    final expected = plan.totalAmount <= 0
        ? 0.0
        : (expectedAmount / plan.totalAmount).clamp(0.0, 1.0);
    final remainingStart = normalizedToday.isBefore(start)
        ? start
        : normalizedToday;
    final remainingDates = _activeDayCount(
      remainingStart,
      deadline,
      plan.activeWeekdays,
    );
    final remainingAmount = math.max(
      0.0,
      plan.totalAmount - goal.completedAmount,
    );
    final required = remainingDates == 0
        ? double.infinity
        : remainingAmount / remainingDates;
    final accepted = plan.acceptedDailyPace;
    final paceIncrease = accepted <= 0
        ? double.infinity
        : math.max(0.0, (required - accepted) / accepted);
    final progressGap = math.max(0.0, expected - goal.progress);

    final health =
        (remainingAmount > 0 && remainingDates == 0) ||
            paceIncrease >= 0.25 ||
            progressGap >= 0.10
        ? GoalHealth.behind
        : paceIncrease >= 0.10 || progressGap >= 0.05
        ? GoalHealth.atRisk
        : GoalHealth.onTrack;

    return GoalHealthSnapshot(
      health: health,
      expectedProgress: expected,
      requiredDailyPace: required,
      paceIncrease: paceIncrease,
      progressGap: progressGap,
    );
  }

  int _activeDayCount(DateTime start, DateTime end, Set<int> activeWeekdays) {
    final normalizedStart = dateOnly(start);
    final normalizedEnd = dateOnly(end);
    if (normalizedEnd.isBefore(normalizedStart) || activeWeekdays.isEmpty) {
      return 0;
    }
    final utcStart = DateTime.utc(
      normalizedStart.year,
      normalizedStart.month,
      normalizedStart.day,
    );
    final utcEnd = DateTime.utc(
      normalizedEnd.year,
      normalizedEnd.month,
      normalizedEnd.day,
    );
    final inclusiveDays = utcEnd.difference(utcStart).inDays + 1;
    final fullWeeks = inclusiveDays ~/ DateTime.daysPerWeek;
    final remainingDays = inclusiveDays % DateTime.daysPerWeek;
    var count = fullWeeks * activeWeekdays.length;
    for (var offset = 0; offset < remainingDays; offset++) {
      final weekday =
          ((normalizedStart.weekday - 1 + offset) % DateTime.daysPerWeek) + 1;
      if (activeWeekdays.contains(weekday)) count++;
    }
    return count;
  }
}

DateTime dateOnly(DateTime value) =>
    DateTime(value.year, value.month, value.day);

bool isSameDate(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

String formatAmount(double value) {
  if (value.isInfinite) return 'Not possible';
  if (value == value.roundToDouble()) return value.toInt().toString();
  return value
      .toStringAsFixed(value.abs() < 10 ? 1 : 2)
      .replaceFirst(RegExp(r'\.0+$'), '');
}

String pluralize(String unit, num amount) {
  if (amount == 1 || unit.endsWith('s')) return unit;
  return '${unit}s';
}
