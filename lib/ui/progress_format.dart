import '../app/theme_controller.dart';
import '../domain/goal.dart';
import '../domain/plan_calculator.dart';

String formatPercentValue(double fraction) {
  final percentage = fraction * 100;
  if (percentage == 0) return '0';

  final magnitude = percentage.abs();
  if (magnitude < 0.05) {
    return percentage.isNegative ? '>-0.1' : '<0.1';
  }
  final wouldRoundIncompleteToComplete =
      percentage > 0 && percentage < 100 && percentage.round() == 100;
  if (magnitude < 1) return percentage.toStringAsFixed(1);
  if (wouldRoundIncompleteToComplete) {
    final oneDecimal = percentage.toStringAsFixed(1);
    return oneDecimal == '100.0' ? '<100' : oneDecimal;
  }
  return percentage.round().toString();
}

String formatProgressPercent(double fraction) =>
    '${formatPercentValue(fraction)}%';

String formatGoalProgress(Goal goal, AppProgressFormat format) {
  final percentage = formatProgressPercent(goal.progress);
  final plan = goal.plan;
  final amount = plan == null
      ? '${goal.completedStepCount} of ${goal.steps.length} steps'
      : '${formatAmount(goal.completedAmount)} of '
            '${formatAmount(plan.totalAmount)} ${plan.unit}';
  return switch (format) {
    AppProgressFormat.percentage => percentage,
    AppProgressFormat.amount => amount,
    AppProgressFormat.both => '$percentage · $amount',
  };
}
