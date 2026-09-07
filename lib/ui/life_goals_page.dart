import 'package:flutter/material.dart';

import '../app/goal_store.dart';
import '../app/theme_controller.dart';
import '../domain/goal.dart';
import 'app_theme.dart';
import 'create_goal_dialog.dart';
import 'goal_details_sheet.dart';
import 'progress_format.dart';

class LifeGoalsPage extends StatefulWidget {
  const LifeGoalsPage({super.key, required this.store, required this.settings});

  final GoalStore store;
  final AppSettingsController settings;

  @override
  State<LifeGoalsPage> createState() => _LifeGoalsPageState();
}

class _LifeGoalsPageState extends State<LifeGoalsPage> {
  bool _simplified = false;
  String? _category;

  static const _columns = <_GoalColumn>[
    _GoalColumn(
      label: 'To Do',
      statuses: {GoalStatus.ideas, GoalStatus.planned},
      dropStatus: GoalStatus.planned,
      color: Color(0xFF92959F),
    ),
    _GoalColumn(
      label: 'In Progress',
      statuses: {GoalStatus.active},
      dropStatus: GoalStatus.active,
      color: Color(0xFFD8B84E),
    ),
    _GoalColumn(
      label: 'Paused',
      statuses: {GoalStatus.paused},
      dropStatus: GoalStatus.paused,
      color: Color(0xFFE07A6D),
    ),
    _GoalColumn(
      label: 'Completed',
      statuses: {GoalStatus.completed},
      dropStatus: GoalStatus.completed,
      color: Color(0xFF62B98A),
    ),
  ];

  List<Goal> get _goals => widget.store.goals
      .where(
        (goal) =>
            !goal.isTrashed &&
            goal.status != GoalStatus.abandoned &&
            (_category == null || goal.category == _category),
      )
      .toList(growable: false);

  @override
  Widget build(BuildContext context) {
    final mobile = MediaQuery.sizeOf(context).width < 820;
    return Padding(
      padding: EdgeInsets.fromLTRB(mobile ? 14 : 24, 22, mobile ? 14 : 24, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Header(
            mobile: mobile,
            onNewGoal: () => showCreateGoalDialog(context, widget.store),
          ),
          const SizedBox(height: 24),
          _Toolbar(
            simplified: _simplified,
            category: _category,
            categories: widget.store.availableCategories,
            onViewChanged: (value) => setState(() => _simplified = value),
            onCategoryChanged: (value) => setState(() => _category = value),
          ),
          const SizedBox(height: 10),
          Divider(color: context.appBorder),
          const SizedBox(height: 12),
          Expanded(
            child: _goals.isEmpty
                ? _EmptyGoals(
                    onCreate: () => showCreateGoalDialog(context, widget.store),
                  )
                : _simplified
                ? _SimplifiedGoals(
                    goals: _goals,
                    columns: _columns,
                    onOpen: _open,
                  )
                : _Board(
                    mobile: mobile,
                    goals: _goals,
                    columns: _columns,
                    onOpen: _open,
                    onMove: (goal, status) =>
                        widget.store.moveGoal(goal.id, status),
                  ),
          ),
        ],
      ),
    );
  }

  void _open(Goal goal) => showGoalDetailsSheet(
    context,
    widget.store,
    goal.id,
    showAbandoned: widget.settings.showAbandoned,
    progressFormat: widget.settings.progressFormat,
    settings: widget.settings,
  );
}

class _Header extends StatelessWidget {
  const _Header({required this.mobile, required this.onNewGoal});

  final bool mobile;
  final VoidCallback onNewGoal;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Goals', style: Theme.of(context).textTheme.displaySmall),
            const SizedBox(height: 5),
            Text(
              'Plan what matters and keep it moving.',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: context.appMuted),
            ),
          ],
        ),
      ),
      FilledButton.icon(
        key: const Key('new-goal-button'),
        onPressed: onNewGoal,
        icon: const Icon(Icons.add_rounded, size: 17),
        label: Text(mobile ? 'New' : 'New goal'),
      ),
    ],
  );
}

class _Toolbar extends StatelessWidget {
  const _Toolbar({
    required this.simplified,
    required this.category,
    required this.categories,
    required this.onViewChanged,
    required this.onCategoryChanged,
  });

  final bool simplified;
  final String? category;
  final List<String> categories;
  final ValueChanged<bool> onViewChanged;
  final ValueChanged<String?> onCategoryChanged;

  @override
  Widget build(BuildContext context) {
    final viewControls = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _ViewButton(
          selected: !simplified,
          icon: Icons.view_kanban_outlined,
          label: 'Board',
          onTap: () => onViewChanged(false),
        ),
        const SizedBox(width: 4),
        _ViewButton(
          selected: simplified,
          icon: Icons.format_list_bulleted_rounded,
          label: 'Simplified',
          onTap: () => onViewChanged(true),
        ),
      ],
    );
    final filter = PopupMenuButton<String?>(
      tooltip: 'Filter goals',
      initialValue: category,
      onSelected: onCategoryChanged,
      itemBuilder: (context) => [
        const PopupMenuItem<String?>(value: null, child: Text('All goals')),
        for (final item in categories)
          PopupMenuItem<String?>(value: item, child: Text(item)),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
        decoration: BoxDecoration(
          color: context.appPanel,
          border: Border.all(color: context.appBorder),
          borderRadius: BorderRadius.circular(7),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(category ?? 'All goals'),
            const SizedBox(width: 7),
            const Icon(Icons.keyboard_arrow_down_rounded, size: 17),
          ],
        ),
      ),
    );
    return LayoutBuilder(
      builder: (context, constraints) => constraints.maxWidth < 430
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Align(alignment: Alignment.centerLeft, child: viewControls),
                const SizedBox(height: 8),
                Align(alignment: Alignment.centerRight, child: filter),
              ],
            )
          : Row(children: [viewControls, const Spacer(), filter]),
    );
  }
}

class _ViewButton extends StatelessWidget {
  const _ViewButton({
    required this.selected,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final bool selected;
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: selected ? context.appRaised : Colors.transparent,
    borderRadius: BorderRadius.circular(7),
    child: InkWell(
      borderRadius: BorderRadius.circular(7),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: selected ? context.appText : context.appMuted,
            ),
            const SizedBox(width: 7),
            Text(
              label,
              style: TextStyle(
                color: selected ? context.appText : context.appMuted,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _Board extends StatelessWidget {
  const _Board({
    required this.mobile,
    required this.goals,
    required this.columns,
    required this.onOpen,
    required this.onMove,
  });

  final bool mobile;
  final List<Goal> goals;
  final List<_GoalColumn> columns;
  final ValueChanged<Goal> onOpen;
  final void Function(Goal, GoalStatus) onMove;

  @override
  Widget build(BuildContext context) {
    if (mobile) {
      final width = (MediaQuery.sizeOf(context).width * .84).clamp(
        272.0,
        342.0,
      );
      return ListView.separated(
        key: const Key('mobile-goal-board'),
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: columns.length,
        separatorBuilder: (_, _) => const SizedBox(width: 12),
        itemBuilder: (context, index) => SizedBox(
          width: width,
          child: _BoardColumn(
            column: columns[index],
            goals: goals
                .where((goal) => columns[index].statuses.contains(goal.status))
                .toList(),
            onOpen: onOpen,
            onMove: onMove,
          ),
        ),
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var index = 0; index < columns.length; index++) ...[
          Expanded(
            child: _BoardColumn(
              column: columns[index],
              goals: goals
                  .where(
                    (goal) => columns[index].statuses.contains(goal.status),
                  )
                  .toList(),
              onOpen: onOpen,
              onMove: onMove,
            ),
          ),
          if (index < columns.length - 1) const SizedBox(width: 12),
        ],
      ],
    );
  }
}

class _BoardColumn extends StatelessWidget {
  const _BoardColumn({
    required this.column,
    required this.goals,
    required this.onOpen,
    required this.onMove,
  });

  final _GoalColumn column;
  final List<Goal> goals;
  final ValueChanged<Goal> onOpen;
  final void Function(Goal, GoalStatus) onMove;

  @override
  Widget build(BuildContext context) => DragTarget<Goal>(
    key: Key('life-goal-column-${column.dropStatus.name}'),
    onWillAcceptWithDetails: (details) =>
        !column.statuses.contains(details.data.status),
    onAcceptWithDetails: (details) => onMove(details.data, column.dropStatus),
    builder: (context, candidates, rejected) => AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      decoration: BoxDecoration(
        color: candidates.isEmpty
            ? Colors.transparent
            : column.color.withValues(alpha: .06),
        borderRadius: BorderRadius.circular(9),
        border: Border.all(
          color: candidates.isEmpty
              ? Colors.transparent
              : column.color.withValues(alpha: .42),
        ),
      ),
      padding: const EdgeInsets.all(4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(2, 2, 2, 10),
            child: Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: column.color, width: 1.5),
                  ),
                ),
                const SizedBox(width: 7),
                Text(
                  column.label,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 5),
                Text(
                  '${goals.length}',
                  style: TextStyle(color: context.appMuted, fontSize: 11),
                ),
                const Spacer(),
                Icon(Icons.add_rounded, size: 17, color: context.appMuted),
              ],
            ),
          ),
          Expanded(
            child: goals.isEmpty
                ? Center(
                    child: Text(
                      'Drop a goal here',
                      style: TextStyle(color: context.appMuted, fontSize: 11),
                    ),
                  )
                : ListView.separated(
                    padding: EdgeInsets.zero,
                    itemCount: goals.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final goal = goals[index];
                      return LongPressDraggable<Goal>(
                        data: goal,
                        feedback: Material(
                          color: Colors.transparent,
                          child: SizedBox(
                            width: 270,
                            child: _GoalCard(goal: goal, onTap: null),
                          ),
                        ),
                        childWhenDragging: Opacity(
                          opacity: .28,
                          child: _GoalCard(goal: goal, onTap: null),
                        ),
                        child: _GoalCard(goal: goal, onTap: () => onOpen(goal)),
                      );
                    },
                  ),
          ),
        ],
      ),
    ),
  );
}

class _GoalCard extends StatelessWidget {
  const _GoalCard({required this.goal, required this.onTap});

  final Goal goal;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final progress = formatProgressPercent(goal.progress);
    final amount = goal.plan == null
        ? goal.steps.isEmpty
              ? 'No plan yet'
              : '${goal.completedStepCount} of ${goal.steps.length} steps'
        : '${_number(goal.completedAmount)} of ${_number(goal.plan!.totalAmount)} ${goal.plan!.unit}';
    final date = goal.plan?.deadline;
    return Material(
      color: context.appPanel,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 132),
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: context.appBorder.withValues(alpha: .9)),
            boxShadow: [
              if (context.isDarkMode)
                BoxShadow(
                  color: Colors.black.withValues(alpha: .08),
                  blurRadius: 10,
                ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    width: 9,
                    height: 9,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: _categoryColor(goal.category),
                        width: 1.5,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      goal.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  if (goal.isUrgent)
                    const Padding(
                      padding: EdgeInsets.only(left: 6),
                      child: Icon(
                        Icons.local_fire_department_outlined,
                        size: 16,
                        color: Color(0xFFE07A6D),
                      ),
                    ),
                  Icon(
                    Icons.more_horiz_rounded,
                    size: 17,
                    color: context.appMuted,
                  ),
                ],
              ),
              const SizedBox(height: 13),
              Text(
                amount,
                style: TextStyle(color: context.appMuted, fontSize: 11),
              ),
              const SizedBox(height: 20),
              if (goal.plan != null || goal.steps.isNotEmpty) ...[
                Row(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: LinearProgressIndicator(
                          value: goal.progress,
                          minHeight: 3,
                          backgroundColor: context.appRaised,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      progress,
                      style: TextStyle(color: context.appMuted, fontSize: 10),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
              ],
              Row(
                children: [
                  Icon(
                    Icons.calendar_today_outlined,
                    size: 13,
                    color: context.appMuted,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    date == null ? 'No date' : _shortDate(date),
                    style: TextStyle(color: context.appMuted, fontSize: 10.5),
                  ),
                  const Spacer(),
                  Text(
                    goal.category,
                    style: TextStyle(color: context.appMuted, fontSize: 10.5),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SimplifiedGoals extends StatelessWidget {
  const _SimplifiedGoals({
    required this.goals,
    required this.columns,
    required this.onOpen,
  });

  final List<Goal> goals;
  final List<_GoalColumn> columns;
  final ValueChanged<Goal> onOpen;

  @override
  Widget build(BuildContext context) => ListView(
    children: [
      for (final column in columns) ...[
        Padding(
          padding: const EdgeInsets.fromLTRB(2, 10, 2, 8),
          child: Row(
            children: [
              Container(
                width: 9,
                height: 9,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: column.color, width: 1.5),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                column.label,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
        for (final goal in goals.where(
          (goal) => column.statuses.contains(goal.status),
        ))
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _GoalCard(goal: goal, onTap: () => onOpen(goal)),
          ),
      ],
    ],
  );
}

class _EmptyGoals extends StatelessWidget {
  const _EmptyGoals({required this.onCreate});

  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) => Center(
    child: Container(
      width: 430,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: context.appPanel,
        border: Border.all(color: context.appBorder),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.center_focus_weak_rounded, color: context.appMuted),
          const SizedBox(height: 16),
          const Text(
            'Your next goal starts here',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 10),
          Text(
            'Capture an idea, add a plan when you’re ready, and take it one task at a time.',
            textAlign: TextAlign.center,
            style: TextStyle(color: context.appMuted),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: onCreate,
            icon: const Icon(Icons.add_rounded),
            label: const Text('Create your first goal'),
          ),
        ],
      ),
    ),
  );
}

class _GoalColumn {
  const _GoalColumn({
    required this.label,
    required this.statuses,
    required this.dropStatus,
    required this.color,
  });

  final String label;
  final Set<GoalStatus> statuses;
  final GoalStatus dropStatus;
  final Color color;
}

Color _categoryColor(String category) => switch (category) {
  'Faith' => const Color(0xFFD8B84E),
  'Health' || 'Body' => const Color(0xFF62B98A),
  'Mind' => const Color(0xFF7E9CCB),
  'Finances' || 'Work' => const Color(0xFFB18AD1),
  _ => const Color(0xFF92959F),
};

String _number(double value) => value == value.roundToDouble()
    ? value.round().toString()
    : value.toStringAsFixed(1);

String _shortDate(DateTime date) {
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return '${months[date.month - 1]} ${date.day}, ${date.year}';
}
