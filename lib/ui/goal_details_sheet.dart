import 'package:flutter/material.dart';

import '../app/goal_store.dart';
import '../app/theme_controller.dart';
import '../domain/goal.dart';
import '../domain/plan_calculator.dart';
import 'app_theme.dart';
import 'create_goal_dialog.dart';
import 'goal_progress_section.dart';
import 'reminder_dialog.dart';

enum _GoalMenuAction { editDetails, reminder, plan, removePlan, trash }

Future<void> showGoalDetailsSheet(
  BuildContext context,
  GoalStore store,
  String goalId, {
  required bool showAbandoned,
  required AppProgressFormat progressFormat,
  required AppSettingsController settings,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => _GoalDetailsSheet(
      store: store,
      goalId: goalId,
      showAbandoned: showAbandoned,
      progressFormat: progressFormat,
      settings: settings,
    ),
  );
}

class _GoalDetailsSheet extends StatefulWidget {
  const _GoalDetailsSheet({
    required this.store,
    required this.goalId,
    required this.showAbandoned,
    required this.progressFormat,
    required this.settings,
  });

  final GoalStore store;
  final String goalId;
  final bool showAbandoned;
  final AppProgressFormat progressFormat;
  final AppSettingsController settings;

  @override
  State<_GoalDetailsSheet> createState() => _GoalDetailsSheetState();
}

class _GoalDetailsSheetState extends State<_GoalDetailsSheet> {
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.store,
      builder: (context, _) {
        final goal = widget.store.goalById(widget.goalId);
        if (goal == null) return const SizedBox.shrink();
        final plan = goal.plan;
        final health = widget.store.calculator.healthFor(
          goal,
          widget.store.today,
        );
        final width = MediaQuery.sizeOf(context).width;
        return Align(
          alignment: width >= 760
              ? Alignment.centerRight
              : Alignment.bottomCenter,
          child: Material(
            color: context.appPanel,
            borderRadius: width >= 760
                ? const BorderRadius.horizontal(left: Radius.circular(24))
                : const BorderRadius.vertical(top: Radius.circular(24)),
            child: SafeArea(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: width >= 760 ? 540 : double.infinity,
                  maxHeight:
                      MediaQuery.sizeOf(context).height *
                      (width >= 760 ? 1 : .91),
                ),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 46,
                            height: 46,
                            decoration: BoxDecoration(
                              color: plan == null
                                  ? context.appSoftBlue
                                  : context.appSoftGreen,
                              borderRadius: BorderRadius.circular(13),
                            ),
                            child: Icon(
                              plan == null
                                  ? Icons.lightbulb_outline
                                  : Icons.flag_outlined,
                              color: plan == null
                                  ? context.appBlueText
                                  : context.appGreenText,
                            ),
                          ),
                          const SizedBox(width: 13),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  goal.name,
                                  style: Theme.of(
                                    context,
                                  ).textTheme.headlineMedium,
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  goal.status.label,
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ],
                            ),
                          ),
                          PopupMenuButton<_GoalMenuAction>(
                            key: const Key('goal-details-menu'),
                            tooltip: 'Goal options',
                            onSelected: (action) =>
                                _handleMenuAction(action, goal),
                            itemBuilder: (context) => [
                              const PopupMenuItem(
                                value: _GoalMenuAction.editDetails,
                                child: Text('Edit details'),
                              ),
                              PopupMenuItem(
                                value: _GoalMenuAction.reminder,
                                child: Text(
                                  goal.reminder == null
                                      ? 'Add reminder'
                                      : 'Edit reminder',
                                ),
                              ),
                              PopupMenuItem(
                                value: _GoalMenuAction.plan,
                                child: Text(
                                  plan == null ? 'Add plan' : 'Change plan',
                                ),
                              ),
                              if (plan != null)
                                const PopupMenuItem(
                                  value: _GoalMenuAction.removePlan,
                                  child: Text('Remove plan'),
                                ),
                              const PopupMenuDivider(),
                              const PopupMenuItem(
                                value: _GoalMenuAction.trash,
                                child: Text('Move to Trash'),
                              ),
                            ],
                            icon: const Icon(Icons.more_horiz_rounded),
                          ),
                          IconButton(
                            tooltip: 'Close',
                            onPressed: () => Navigator.pop(context),
                            icon: const Icon(Icons.close_rounded),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      _TodayActionCard(goal: goal, store: widget.store),
                      const SizedBox(height: 20),
                      GoalProgressSection(
                        goal: goal,
                        store: widget.store,
                        progressFormat: widget.progressFormat,
                        onAddAmountPlan: () {
                          final navigator = Navigator.of(context);
                          navigator.pop();
                          showPlanGoalDialog(
                            navigator.context,
                            widget.store,
                            goal.id,
                          );
                        },
                      ),
                      if (plan != null) ...[
                        const SizedBox(height: 24),
                        _ScheduleSummary(health: health, goal: goal),
                      ],
                      const SizedBox(height: 18),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          key: const Key('edit-goal-details-button'),
                          onPressed: () => _showGoalSettings(goal),
                          icon: const Icon(Icons.tune_rounded, size: 18),
                          label: const Text('Edit goal details'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _handleMenuAction(_GoalMenuAction action, Goal goal) async {
    switch (action) {
      case _GoalMenuAction.editDetails:
        await _showGoalSettings(goal);
      case _GoalMenuAction.reminder:
        await showGoalReminderDialog(
          context,
          store: widget.store,
          settings: widget.settings,
          goalId: goal.id,
        );
      case _GoalMenuAction.plan:
        final navigator = Navigator.of(context);
        navigator.pop();
        await showPlanGoalDialog(navigator.context, widget.store, goal.id);
      case _GoalMenuAction.removePlan:
        await _confirmRemovePlan(goal);
      case _GoalMenuAction.trash:
        await _confirmTrash(goal);
    }
  }

  Future<void> _showGoalSettings(Goal goal) => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (context) => _GoalSettingsSheet(
      goalId: goal.id,
      store: widget.store,
      settings: widget.settings,
      showAbandoned: widget.showAbandoned,
    ),
  );

  Future<void> _confirmTrash(Goal goal) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.delete_outline_rounded),
        title: const Text('Move this goal to Trash?'),
        content: const Text(
          'The goal will leave the board, but its plan, progress, history, '
          'notes, and Markdown file will stay recoverable in Trash.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: const Key('confirm-trash-goal'),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Move to Trash'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await widget.store.trashGoal(goal.id);
    if (mounted) Navigator.pop(context);
  }

  Future<void> _confirmRemovePlan(Goal goal) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove this plan?'),
        content: const Text(
          'The goal will return to Ideas. Its amount, dates, and progress '
          'history will be removed. You can undo this from the board.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove plan'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await widget.store.removePlan(goal.id);
    if (mounted) Navigator.pop(context);
  }
}

class _TodayActionCard extends StatelessWidget {
  const _TodayActionCard({required this.goal, required this.store});

  final Goal goal;
  final GoalStore store;

  @override
  Widget build(BuildContext context) {
    final plan = goal.plan;
    if (plan == null) return const SizedBox.shrink();
    final completion = goal.completionFor(store.today);
    final scheduled = store.calculator.actionForDate(goal, store.today);
    if (scheduled <= 0 && completion == null) return const SizedBox.shrink();
    final amount = completion?.amount ?? scheduled;
    final done = completion != null;
    return AnimatedContainer(
      key: const Key('goal-today-action'),
      duration: const Duration(milliseconds: 180),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: done ? context.appSoftGreen : context.appSoftBlue,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Checkbox(
            value: done,
            onChanged: (_) => done
                ? store.undoTodayAction(goal.id)
                : store.completeTodayAction(goal.id),
          ),
          const SizedBox(width: 7),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  done ? 'Today’s action is done' : 'Today’s action',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 2),
                Text(
                  '${formatAmount(amount)} ${pluralize(plan.unit, amount)}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ScheduleSummary extends StatelessWidget {
  const _ScheduleSummary({required this.health, required this.goal});

  final GoalHealthSnapshot health;
  final Goal goal;

  @override
  Widget build(BuildContext context) {
    final plan = goal.plan!;
    final color = switch (health.health) {
      GoalHealth.onTrack => context.appGreenText,
      GoalHealth.atRisk => context.appWarningText,
      GoalHealth.behind => context.appDangerText,
      GoalHealth.none => context.appMuted,
    };
    final needsMore =
        health.health == GoalHealth.atRisk ||
        health.health == GoalHealth.behind;
    return Container(
      key: const Key('goal-schedule-summary'),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.appPanel,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.appBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.schedule_rounded, size: 18, color: color),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  health.health.label,
                  style: Theme.of(
                    context,
                  ).textTheme.titleMedium?.copyWith(color: color),
                ),
              ),
              Text(
                'Due ${_date(plan.deadline)}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
          const SizedBox(height: 11),
          _MetricRow(
            label: 'Current pace',
            value:
                '${formatAmount(plan.acceptedDailyPace)} ${pluralize(plan.unit, plan.acceptedDailyPace)} per active day',
          ),
          if (needsMore)
            _MetricRow(
              label: 'Pace needed now',
              value:
                  '${formatAmount(health.requiredDailyPace)} ${pluralize(plan.unit, health.requiredDailyPace)} per active day',
            ),
        ],
      ),
    );
  }
}

class _GoalSettingsSheet extends StatelessWidget {
  const _GoalSettingsSheet({
    required this.goalId,
    required this.store,
    required this.settings,
    required this.showAbandoned,
  });

  final String goalId;
  final GoalStore store;
  final AppSettingsController settings;
  final bool showAbandoned;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: store,
    builder: (context, _) {
      final goal = store.goalById(goalId);
      if (goal == null) return const SizedBox.shrink();
      return FractionallySizedBox(
        heightFactor: .82,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 540),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 2, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Edit goal details',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<GoalStatus>(
                    key: const Key('goal-status-field'),
                    initialValue: goal.status,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Status'),
                    items: [
                      for (final status in GoalStatus.visibleValues(
                        showAbandoned:
                            showAbandoned ||
                            goal.status == GoalStatus.abandoned,
                      ))
                        DropdownMenuItem(
                          value: status,
                          child: Text(status.label),
                        ),
                    ],
                    onChanged: (status) {
                      if (status != null) store.moveGoal(goal.id, status);
                    },
                  ),
                  const SizedBox(height: 16),
                  _GoalOrganizationSection(
                    goal: goal,
                    store: store,
                    settings: settings,
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    },
  );
}

class _GoalOrganizationSection extends StatelessWidget {
  const _GoalOrganizationSection({
    required this.goal,
    required this.store,
    required this.settings,
  });

  final Goal goal;
  final GoalStore store;
  final AppSettingsController settings;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.appRaised,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.appBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Organize', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          if (settings.categoriesEnabled) ...[
            DropdownButtonFormField<String>(
              key: const Key('goal-category-field'),
              initialValue: goal.category,
              decoration: const InputDecoration(
                labelText: 'Category',
                helperText:
                    'Categories organize this board; they do not create new boards.',
              ),
              items: [
                for (final category in {
                  goal.category,
                  ...settings.visibleCategories(store.availableCategories),
                })
                  DropdownMenuItem(value: category, child: Text(category)),
              ],
              onChanged: (value) {
                if (value != null) store.setCategory(goal.id, value);
              },
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                key: const Key('create-custom-category'),
                onPressed: () => _createCustomCategory(context),
                icon: const Icon(Icons.add_rounded),
                label: const Text('Create custom category'),
              ),
            ),
            const SizedBox(height: 10),
          ],
          Material(
            color: Colors.transparent,
            child: SwitchListTile(
              key: const Key('goal-urgent-switch'),
              contentPadding: EdgeInsets.zero,
              title: const Text('Urgent'),
              subtitle: const Text(
                'Give this card a clear, lightweight warning ring.',
              ),
              value: goal.isUrgent,
              onChanged: (value) => store.setUrgency(goal.id, isUrgent: value),
            ),
          ),
          if (goal.isUrgent) ...[
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final style in UrgencyStyle.values)
                  ChoiceChip(
                    key: Key('urgency-style-${style.name}'),
                    label: Text(style.label),
                    selected: goal.urgencyStyle == style,
                    onSelected: (_) =>
                        store.setUrgency(goal.id, isUrgent: true, style: style),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _createCustomCategory(BuildContext context) async {
    final controller = TextEditingController();
    final category = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create custom category'),
        content: TextField(
          key: const Key('custom-category-name'),
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Category name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final value = controller.text.trim();
              if (value.isNotEmpty) Navigator.pop(context, value);
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (category == null) return;
    await settings.setCategoryEnabled(category, true);
    await store.setCategory(goal.id, category);
  }
}

class _MetricRow extends StatelessWidget {
  const _MetricRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(label, style: Theme.of(context).textTheme.bodySmall),
          ),
          const SizedBox(width: 10),
          Flexible(
            flex: 2,
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

String _date(DateTime value) =>
    '${value.year}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
