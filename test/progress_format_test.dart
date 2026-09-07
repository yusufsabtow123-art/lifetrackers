import 'package:flutter_test/flutter_test.dart';
import 'package:goal_tracker_poc/app/theme_controller.dart';
import 'package:goal_tracker_poc/domain/goal.dart';
import 'package:goal_tracker_poc/ui/progress_format.dart';

void main() {
  test('formats meaningful small progress without showing zero', () {
    expect(formatProgressPercent(0), '0%');
    expect(formatProgressPercent(2 / 604), '0.3%');
    expect(formatProgressPercent(1 / 10000), '<0.1%');
    expect(formatProgressPercent(102 / 604), '17%');
    expect(formatProgressPercent(603 / 604), '99.8%');
    expect(formatProgressPercent(0.9999), '<100%');
    expect(formatProgressPercent(1), '100%');
  });

  test('formats a step-based goal without inventing an amount', () {
    final goal = Goal(
      id: 'lasagna',
      name: 'Make lasagna',
      status: GoalStatus.active,
      createdAt: DateTime(2026, 8, 11),
      updatedAt: DateTime(2026, 8, 11),
      steps: [
        GoalStep(
          id: 'sauce',
          title: 'Make sauce',
          createdAt: DateTime(2026, 8, 11),
        ),
        GoalStep(
          id: 'cheese',
          title: 'Buy cheese',
          createdAt: DateTime(2026, 8, 11),
          completedAt: DateTime(2026, 8, 11, 10),
        ),
      ],
    );

    expect(formatGoalProgress(goal, AppProgressFormat.percentage), '50%');
    expect(formatGoalProgress(goal, AppProgressFormat.amount), '1 of 2 steps');
    expect(
      formatGoalProgress(goal, AppProgressFormat.both),
      '50% · 1 of 2 steps',
    );
  });
}
