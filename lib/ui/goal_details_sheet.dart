import 'package:flutter/material.dart';

import '../app/goal_store.dart';
import '../app/theme_controller.dart';
import '../domain/goal.dart';
import '../domain/plan_calculator.dart';
import 'app_theme.dart';
import 'create_goal_dialog.dart';
import 'goal_progress_section.dart';
import 'reminder_dialog.dart';

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
  late bool _detailed;

  @override
  void initState() {
    super.initState();
    _detailed = widget.settings.isGoalDetailed(widget.goalId);
  }

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
                          Column(
                            children: [
                              IconButton(
                                key: const Key('goal-detail-view-toggle'),
                                tooltip: _detailed
                                    ? 'Use Simple view'
                                    : 'Use Detailed view',
                                onPressed: () {
                                  setState(() => _detailed = !_detailed);
                                  widget.settings.setGoalDetailed(
                                    goal.id,
                                    _detailed,
                                  );
                                },
                                icon: Icon(
                                  _detailed
                                      ? Icons.view_list_rounded
                                      : Icons.view_agenda_outlined,
                                ),
                              ),
                              Text(
                                _detailed ? 'Detailed' : 'Simple',
                                style: Theme.of(context).textTheme.labelSmall,
                              ),
                            ],
                          ),
                          IconButton(
                            tooltip: 'Close',
                            onPressed: () => Navigator.pop(context),
                            icon: const Icon(Icons.close_rounded),
                          ),
                        ],
                      ),
                      const SizedBox(height: 22),
                      DropdownButtonFormField<GoalStatus>(
                        initialValue: goal.status,
                        decoration: const InputDecoration(
                          labelText: 'Board column',
                          helperText: 'This changes where the goal appears.',
                        ),
                        items: [
                          for (final status in GoalStatus.visibleValues(
                            showAbandoned:
                                widget.showAbandoned ||
                                goal.status == GoalStatus.abandoned,
                          ))
                            DropdownMenuItem(
                              value: status,
                              child: Text(status.label),
                            ),
                        ],
                        onChanged: (status) {
                          if (status != null) {
                            widget.store.moveGoal(goal.id, status);
                          }
                        },
                      ),
                      const SizedBox(height: 6),
                      Text(
                        goal.status.description,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: 18),
                      _GoalOrganizationSection(
                        goal: goal,
                        store: widget.store,
                        settings: widget.settings,
                      ),
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
                      if (_detailed && plan != null) ...[
                        const SizedBox(height: 24),
                        _HealthDetails(
                          health: health,
                          goal: goal,
                          settings: widget.settings,
                        ),
                        const SizedBox(height: 18),
                        Text(
                          '${_date(plan.startDate)} → ${_date(plan.deadline)}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        const SizedBox(height: 18),
                        OutlinedButton.icon(
                          onPressed: () => _confirmRemovePlan(goal),
                          icon: const Icon(Icons.undo_rounded),
                          label: const Text('Remove plan and return to Ideas'),
                        ),
                      ],
                      const SizedBox(height: 22),
                      _ReminderSummary(
                        goal: goal,
                        settings: widget.settings,
                        store: widget.store,
                      ),
                      const SizedBox(height: 22),
                      Divider(color: context.appBorder),
                      TextButton.icon(
                        key: const Key('trash-goal-button'),
                        onPressed: () => _confirmTrash(goal),
                        icon: Icon(
                          Icons.delete_outline_rounded,
                          color: Theme.of(context).colorScheme.error,
                        ),
                        label: Text(
                          'Move goal to Trash',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
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

class _ReminderSummary extends StatelessWidget {
  const _ReminderSummary({
    required this.goal,
    required this.settings,
    required this.store,
  });

  final Goal goal;
  final AppSettingsController settings;
  final GoalStore store;

  @override
  Widget build(BuildContext context) {
    final reminder = goal.reminder;
    final time = reminder == null
        ? null
        : TimeOfDay(hour: reminder.hour, minute: reminder.minute);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.appSoftBlue,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context).colorScheme.secondary.withValues(alpha: .35),
        ),
      ),
      child: Row(
        children: [
          Icon(
            reminder == null
                ? Icons.notifications_none_rounded
                : Icons.notifications_active_rounded,
            color: context.appBlueText,
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Reminder',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                Text(
                  reminder == null
                      ? 'No reminder set'
                      : '${reminder.frequency.label} at ${time!.format(context)}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          OutlinedButton(
            onPressed: settings.notificationsEnabled
                ? () => showGoalReminderDialog(
                    context,
                    store: store,
                    settings: settings,
                    goalId: goal.id,
                  )
                : () => ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Reminders are turned off in Settings.'),
                    ),
                  ),
            child: Text(reminder == null ? 'Add' : 'Edit'),
          ),
        ],
      ),
    );
  }
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

class _HealthDetails extends StatelessWidget {
  const _HealthDetails({
    required this.health,
    required this.goal,
    required this.settings,
  });

  final GoalHealthSnapshot health;
  final Goal goal;
  final AppSettingsController settings;

  @override
  Widget build(BuildContext context) {
    final (color, background, message) = switch (health.health) {
      GoalHealth.onTrack => (
        context.appGreenText,
        context.appSoftGreen,
        'Your accepted plan reaches the deadline.',
      ),
      GoalHealth.atRisk => (
        context.appWarningText,
        context.appSoftAmber,
        'A small pace increase is needed.',
      ),
      GoalHealth.behind => (
        context.appDangerText,
        context.appSoftRed,
        'A major pace increase or later deadline is needed.',
      ),
      GoalHealth.none => (
        context.appMuted,
        context.appSoftBlue,
        'Health is shown for active scheduled goals.',
      ),
    };
    final plan = goal.plan;
    if (plan == null) return const SizedBox.shrink();
    String amount(double value) =>
        '${formatAmount(value)} ${pluralize(plan.unit, value)}';
    return AnimatedBuilder(
      animation: settings,
      builder: (context, _) => Container(
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(16),
        ),
        child: ExpansionTile(
          key: PageStorageKey('goal-health-${goal.id}'),
          initiallyExpanded: settings.isGoalHealthExpanded(goal.id),
          onExpansionChanged: (expanded) =>
              settings.setGoalHealthExpanded(goal.id, expanded),
          shape: const Border(),
          collapsedShape: const Border(),
          title: Text(
            health.health.label,
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(color: color),
          ),
          subtitle: Text(message),
          childrenPadding: const EdgeInsets.fromLTRB(17, 0, 17, 17),
          children: [
            if (health.health != GoalHealth.none) ...[
              _MetricRow(
                label: 'Actual progress',
                value: amount(goal.completedAmount),
              ),
              _MetricRow(
                label: 'Expected progress today',
                value: amount(health.expectedProgress * plan.totalAmount),
              ),
              _MetricRow(
                label: 'Schedule difference',
                value: health.progressGap <= 0
                    ? 'On schedule'
                    : '${amount(health.progressGap * plan.totalAmount)} behind',
              ),
              _MetricRow(
                label: 'Accepted pace',
                value: '${amount(plan.acceptedDailyPace)} per active day',
              ),
              _MetricRow(
                label: 'Required pace',
                value: health.requiredDailyPace.isInfinite
                    ? 'Deadline passed'
                    : '${amount(health.requiredDailyPace)} per active day',
              ),
            ],
          ],
        ),
      ),
    );
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
          Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

String _date(DateTime value) =>
    '${value.year}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
