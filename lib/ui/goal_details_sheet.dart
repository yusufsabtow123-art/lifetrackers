import 'package:flutter/material.dart';

import '../app/goal_store.dart';
import '../app/theme_controller.dart';
import '../domain/goal.dart';
import '../domain/plan_calculator.dart';
import 'app_theme.dart';
import 'create_goal_dialog.dart';
import 'goal_progress_update.dart';
import 'goal_steps_section.dart';
import 'reminder_dialog.dart';
import 'progress_format.dart';

enum _GoalMenuAction { editDetails, reminder, plan, removePlan, trash }

Future<void> showGoalDetailsSheet(
  BuildContext context,
  GoalStore store,
  String goalId, {
  required bool showAbandoned,
  required AppProgressFormat progressFormat,
  required AppSettingsController settings,
}) {
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Close goal',
    barrierColor: Colors.black26,
    transitionDuration: MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 240),
    transitionBuilder: (context, animation, secondary, child) =>
        SlideTransition(
          position: Tween(begin: const Offset(.08, 0), end: Offset.zero)
              .animate(
                CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
              ),
          child: FadeTransition(opacity: animation, child: child),
        ),
    pageBuilder: (context, animation, secondary) => _GoalDetailsSheet(
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
        if (!context.isDarkMode && width < 760) {
          return _buildLightGoalDetails(goal, health);
        }
        return Align(
          alignment: width >= 760
              ? Alignment.centerRight
              : Alignment.bottomCenter,
          child: Material(
            color: width >= 760
                ? context.appPanel
                : Theme.of(context).scaffoldBackgroundColor,
            borderRadius: width >= 760
                ? const BorderRadius.horizontal(left: Radius.circular(12))
                : BorderRadius.zero,
            child: SafeArea(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: width >= 760 ? 410 : double.infinity,
                  minHeight:
                      MediaQuery.sizeOf(context).height -
                      MediaQuery.paddingOf(context).vertical,
                  maxHeight:
                      MediaQuery.sizeOf(context).height -
                      MediaQuery.paddingOf(context).vertical,
                ),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          if (width < 760)
                            IconButton(
                              tooltip: 'Close',
                              onPressed: () => Navigator.pop(context),
                              icon: const Icon(Icons.arrow_back, size: 21),
                            )
                          else
                            const Padding(
                              padding: EdgeInsets.only(right: 12),
                              child: Icon(Icons.menu_book_outlined, size: 24),
                            ),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  goal.name,
                                  style: Theme.of(
                                    context,
                                  ).textTheme.titleMedium,
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
                          if (width >= 760)
                            IconButton(
                              tooltip: 'Close',
                              onPressed: () => Navigator.pop(context),
                              icon: const Icon(Icons.close_rounded),
                            ),
                        ],
                      ),
                      const Divider(height: 28),
                      _TodayActionCard(goal: goal, store: widget.store),
                      const Divider(height: 40),
                      if (plan != null)
                        _ReferenceProgress(
                          goal: goal,
                          store: widget.store,
                          health: health,
                          progressFormat: widget.progressFormat,
                        )
                      else
                        OutlinedButton.icon(
                          key: const Key('add-amount-target-button'),
                          onPressed: () =>
                              _handleMenuAction(_GoalMenuAction.plan, goal),
                          icon: const Icon(Icons.add, size: 18),
                          label: const Text('Add amount target'),
                        ),
                      const Divider(height: 40),
                      GoalStepsSection(
                        goal: goal,
                        store: widget.store,
                        compact: true,
                      ),
                      const Divider(height: 36),
                      ExpansionTile(
                        tilePadding: EdgeInsets.zero,
                        leading: const Icon(
                          Icons.description_outlined,
                          size: 19,
                        ),
                        title: const Text(
                          'Details',
                          style: TextStyle(fontSize: 14),
                        ),
                        children: [
                          TextButton.icon(
                            key: const Key('edit-goal-details-button'),
                            onPressed: () => _showGoalSettings(goal),
                            icon: const Icon(Icons.tune_rounded, size: 18),
                            label: const Text('Edit goal details'),
                          ),
                        ],
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

  Widget _buildLightGoalDetails(Goal goal, GoalHealthSnapshot health) {
    final plan = goal.plan;
    final completion = goal.completionFor(widget.store.today);
    final scheduled = plan == null
        ? 0.0
        : widget.store.calculator.actionForDate(goal, widget.store.today);
    final actionAmount = completion?.amount ?? scheduled;
    final actionDone = completion != null;
    return Material(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: SafeArea(
        child: Column(
          children: [
            SizedBox(
              height: 62,
              child: Row(
                children: [
                  IconButton(
                    tooltip: 'Back',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back_rounded),
                  ),
                  Expanded(
                    child: Text(
                      goal.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  PopupMenuButton<_GoalMenuAction>(
                    key: const Key('goal-details-menu'),
                    tooltip: 'Goal options',
                    onSelected: (action) => _handleMenuAction(action, goal),
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
                        child: Text(plan == null ? 'Add plan' : 'Change plan'),
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
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 18),
                children: [
                  if (plan != null && (scheduled > 0 || actionDone))
                    Container(
                      key: const Key('goal-today-action'),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: context.appSoftAmber,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: AppColors.goldText.withValues(alpha: .24),
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 46,
                            height: 46,
                            decoration: const BoxDecoration(
                              color: AppColors.softAmber,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.menu_book_outlined,
                              color: AppColors.goldText,
                            ),
                          ),
                          const SizedBox(width: 11),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Next action',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${actionDone ? 'Completed' : 'Complete'} ${formatAmount(actionAmount)} ${pluralize(plan.unit, actionAmount)}',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          OutlinedButton(
                            onPressed: () => actionDone
                                ? widget.store.undoTodayAction(goal.id)
                                : widget.store.completeTodayAction(goal.id),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.coralText,
                              backgroundColor: context.appSoftRed,
                              side: BorderSide(
                                color: AppColors.coralText.withValues(
                                  alpha: .24,
                                ),
                              ),
                            ),
                            child: Text(actionDone ? 'Undo' : 'Complete'),
                          ),
                        ],
                      ),
                    ),
                  if (plan != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: context.appPanel,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: context.appBorder),
                      ),
                      child: _ReferenceProgress(
                        goal: goal,
                        store: widget.store,
                        health: health,
                        progressFormat: widget.progressFormat,
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.fromLTRB(12, 5, 12, 10),
                    decoration: BoxDecoration(
                      color: context.appPanel,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: context.appBorder),
                    ),
                    child: GoalStepsSection(
                      goal: goal,
                      store: widget.store,
                      compact: true,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Material(
                    color: context.appPanel,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                      side: BorderSide(color: context.appBorder),
                    ),
                    child: ListTile(
                      key: const Key('edit-goal-details-button'),
                      leading: const Icon(Icons.assignment_outlined),
                      title: const Text(
                        'Details',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      subtitle: const Text('Target, notes, and more'),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () => _showGoalSettings(goal),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
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
          'The goal will return to To Do. Its amount, dates, and progress '
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
    return Column(
      key: const Key('goal-today-action'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(Icons.my_location_outlined, size: 18, color: context.appMuted),
            const SizedBox(width: 10),
            const Text('Next action', style: TextStyle(fontSize: 13)),
          ],
        ),
        const SizedBox(height: 14),
        Text(
          '${formatAmount(amount)} ${pluralize(plan.unit, amount)}',
          style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(44)),
          onPressed: () => done
              ? store.undoTodayAction(goal.id)
              : store.completeTodayAction(goal.id),
          icon: Icon(done ? Icons.undo : Icons.check, size: 18),
          label: Text(done ? 'Completed · Undo' : 'Complete'),
        ),
      ],
    );
  }
}

class _ReferenceProgress extends StatelessWidget {
  const _ReferenceProgress({
    required this.health,
    required this.goal,
    required this.store,
    required this.progressFormat,
  });

  final GoalHealthSnapshot health;
  final Goal goal;
  final GoalStore store;
  final AppProgressFormat progressFormat;

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
    return Column(
      key: const Key('goal-schedule-summary'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(Icons.bar_chart_outlined, size: 18, color: context.appMuted),
            const SizedBox(width: 10),
            const Text('Progress & plan', style: TextStyle(fontSize: 13)),
          ],
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            SizedBox(
              width: 88,
              height: 88,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox.expand(
                    child: CircularProgressIndicator(
                      value: goal.progress.clamp(0, 1),
                      color: context.isDarkMode ? null : AppColors.blue,
                      strokeWidth: 7,
                      strokeCap: StrokeCap.round,
                      backgroundColor: context.appBorder,
                    ),
                  ),
                  if (progressFormat != AppProgressFormat.amount)
                    Text(
                      formatProgressPercent(goal.progress),
                      style: const TextStyle(fontSize: 22),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 24),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (progressFormat != AppProgressFormat.percentage)
                    Text(
                      '${formatAmount(goal.completedAmount)} of ${formatAmount(plan.totalAmount)} ${plan.unit}',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.circle, size: 7, color: color),
                      const SizedBox(width: 6),
                      Text(
                        health.health.label,
                        style: TextStyle(fontSize: 12, color: color),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    '${formatAmount(plan.acceptedDailyPace)} ${pluralize(plan.unit, plan.acceptedDailyPace)} per active day',
                    style: TextStyle(fontSize: 12, color: context.appMuted),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Ends ${_date(plan.deadline)}',
                    style: TextStyle(fontSize: 12, color: context.appMuted),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        if (needsMore)
          _MetricRow(
            label: 'Pace needed now',
            value:
                '${formatAmount(health.requiredDailyPace)} ${pluralize(plan.unit, health.requiredDailyPace)} per active day',
          ),
        GoalProgressUpdate(goal: goal, store: store, label: 'Log progress'),
      ],
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
                          child: Text(
                            status == GoalStatus.ideas ? 'To Do' : status.label,
                          ),
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

String _date(DateTime value) {
  const months = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];
  return '${months[value.month - 1]} ${value.day}, ${value.year}';
}
