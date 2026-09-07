import 'package:flutter/material.dart';

import '../app/goal_store.dart';
import '../app/theme_controller.dart';
import '../domain/goal.dart';
import 'app_theme.dart';
import 'goal_progress_update.dart';
import 'goal_steps_section.dart';
import 'progress_format.dart';

class GoalProgressSection extends StatelessWidget {
  const GoalProgressSection({
    super.key,
    required this.goal,
    required this.store,
    required this.progressFormat,
    required this.onAddAmountPlan,
  });

  final Goal goal;
  final GoalStore store;
  final AppProgressFormat progressFormat;
  final VoidCallback onAddAmountPlan;

  @override
  Widget build(BuildContext context) {
    final plan = goal.plan;
    return Container(
      key: const Key('unified-progress-section'),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.appRaised,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: context.appBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Progress', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 4),
          Text(
            'Track the amount, check off the steps, or use both.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 14),
          if (plan == null) ...[
            const Text(
              'No amount target yet. You can use the checklist by itself or '
              'add an amount and schedule.',
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              key: const Key('add-amount-target-button'),
              onPressed: onAddAmountPlan,
              icon: const Icon(Icons.straighten_rounded),
              label: const Text('Add amount target'),
            ),
          ] else ...[
            Row(
              children: [
                Expanded(
                  child: Text(
                    formatGoalProgress(goal, progressFormat),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                GoalProgressUpdate(goal: goal, store: store),
              ],
            ),
            const SizedBox(height: 10),
            LinearProgressIndicator(
              value: goal.progress,
              minHeight: 10,
              borderRadius: BorderRadius.circular(20),
              color: Theme.of(context).colorScheme.primary,
              backgroundColor: context.appPanel,
            ),
          ],
          const SizedBox(height: 18),
          Divider(color: context.appBorder),
          const SizedBox(height: 10),
          GoalStepsSection(goal: goal, store: store),
        ],
      ),
    );
  }
}
