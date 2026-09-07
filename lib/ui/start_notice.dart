import 'package:flutter/material.dart';

import '../app/goal_store.dart';
import '../app/theme_controller.dart';
import '../domain/goal.dart';
import '../domain/plan_calculator.dart';
import 'app_theme.dart';
import 'goal_details_sheet.dart';

class StartNotice extends StatelessWidget {
  const StartNotice({
    super.key,
    required this.store,
    required this.goal,
    required this.showAbandoned,
    required this.progressFormat,
    required this.settings,
  });

  final GoalStore store;
  final Goal goal;
  final bool showAbandoned;
  final AppProgressFormat progressFormat;
  final AppSettingsController settings;

  @override
  Widget build(BuildContext context) {
    final plan = goal.plan!;
    final action = store.calculator.actionForDate(goal, store.today);
    return Container(
      key: const Key('automatic-start-notice'),
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: context.appPanel,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: context.appGreenText.withValues(alpha: 0.45)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x100E9363),
            blurRadius: 20,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Wrap(
        runSpacing: 12,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Icon(
            Icons.celebration_outlined,
            color: context.appGreenText,
            size: 28,
          ),
          const SizedBox(width: 12),
          ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 220, maxWidth: 460),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${goal.name} started today',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                Text(
                  action > 0
                      ? 'Today’s action: ${formatAmount(action)} ${pluralize(plan.unit, action)}'
                      : 'The goal is now Active.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.icon(
                key: const Key('begin-today-button'),
                onPressed: () async {
                  await store.beginToday(goal.id);
                  if (context.mounted) {
                    showGoalDetailsSheet(
                      context,
                      store,
                      goal.id,
                      showAbandoned: showAbandoned,
                      progressFormat: progressFormat,
                      settings: settings,
                    );
                  }
                },
                icon: const Icon(Icons.play_arrow_rounded),
                label: const Text('Begin today’s action'),
              ),
              OutlinedButton.icon(
                key: const Key('delay-start-button'),
                onPressed: () => _delay(context),
                icon: const Icon(Icons.schedule_rounded),
                label: const Text('Delay'),
              ),
              OutlinedButton.icon(
                key: const Key('undo-start-button'),
                onPressed: () => store.undoAutomaticStart(goal.id),
                icon: const Icon(Icons.undo_rounded),
                label: const Text('Undo'),
              ),
              IconButton(
                tooltip: 'Dismiss',
                onPressed: () => store.dismissStartNotice(goal.id),
                icon: const Icon(Icons.close_rounded),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _delay(BuildContext context) async {
    final tomorrow = store.today.add(const Duration(days: 1));
    final picked = await showDatePicker(
      context: context,
      initialDate: tomorrow,
      firstDate: tomorrow,
      lastDate: DateTime(store.today.year + 10),
      helpText: 'Choose a new start date',
    );
    if (picked != null) await store.delayStart(goal.id, picked);
  }
}
