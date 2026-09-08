import 'package:flutter_test/flutter_test.dart';
import 'package:goal_tracker_poc/domain/goal.dart';
import 'package:goal_tracker_poc/domain/plan_calculator.dart';

void main() {
  const calculator = PlanCalculator();
  final everyDay = {1, 2, 3, 4, 5, 6, 7};

  test('spreads whole-unit remainders evenly without decimals', () {
    final summary = calculator.summarize(
      amount: 100,
      start: DateTime(2026, 1, 1),
      deadline: DateTime(2026, 3, 31),
      activeWeekdays: everyDay,
    );

    expect(summary.activeDayCount, 90);
    expect(summary.wholeUnitLowAmount, 1);
    expect(summary.wholeUnitHighAmount, 2);
    expect(summary.wholeUnitHighDays, 10);
    expect(
      summary.describe('page', wholeUnits: true),
      '1 page on 80 days, 2 pages on 10 days',
    );
  });

  test('uses the confirmed natural health thresholds', () {
    Goal goalWithProgress(double completed) => Goal(
      id: 'goal-1',
      name: 'Read 100 pages',
      status: GoalStatus.active,
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 10),
      completedAmount: completed,
      plan: GoalPlan(
        totalAmount: 100,
        unit: 'pages',
        startDate: DateTime(2026, 1, 1),
        deadline: DateTime(2026, 4, 10),
        activeWeekdays: everyDay,
        wholeUnits: true,
        acceptedDailyPace: 1,
      ),
    );

    expect(
      calculator.healthFor(goalWithProgress(10), DateTime(2026, 1, 10)).health,
      GoalHealth.onTrack,
    );
    expect(
      calculator.healthFor(goalWithProgress(5), DateTime(2026, 1, 10)).health,
      GoalHealth.atRisk,
    );
    expect(
      calculator.healthFor(goalWithProgress(0), DateTime(2026, 1, 10)).health,
      GoalHealth.behind,
    );
  });

  test('starting progress is excluded from remaining daily work', () {
    final goal = Goal(
      id: 'quran',
      name: 'Memorize the Quran',
      status: GoalStatus.active,
      createdAt: DateTime(2026, 8, 1),
      updatedAt: DateTime(2026, 8, 1),
      completedAmount: 102,
      plan: GoalPlan(
        totalAmount: 604,
        unit: 'pages',
        startDate: DateTime(2026, 8, 1),
        deadline: DateTime(2026, 8, 10),
        activeWeekdays: everyDay,
        wholeUnits: true,
        acceptedDailyPace: 50.2,
        initialCompletedAmount: 102,
      ),
    );

    expect(calculator.actionForDate(goal, DateTime(2026, 8, 1)), 51);
    expect(
      calculator.healthFor(goal, DateTime(2026, 8, 1)).expectedProgress,
      closeTo(152.2 / 604, 0.0001),
    );
  });

  test('long schedules and selected weekdays keep exact day positions', () {
    final goal = Goal(
      id: 'long-plan',
      name: 'Long plan',
      status: GoalStatus.active,
      createdAt: DateTime(2020, 1, 1),
      updatedAt: DateTime(2020, 1, 1),
      plan: GoalPlan(
        totalAmount: 100000,
        unit: 'items',
        startDate: DateTime(2020, 1, 1),
        deadline: DateTime(2120, 12, 31),
        activeWeekdays: const {DateTime.monday, DateTime.wednesday},
        wholeUnits: true,
        acceptedDailyPace: 20,
      ),
    );

    expect(
      calculator.actionForDate(goal, DateTime(2100, 6, 14)),
      greaterThan(0),
    );
    expect(calculator.actionForDate(goal, DateTime(2100, 6, 15)), 0);
  });
}
