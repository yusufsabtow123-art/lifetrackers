import 'dart:async';

import 'package:flutter/material.dart';

import '../app/goal_store.dart';
import '../app/theme_controller.dart';
import '../domain/goal.dart';
import 'app_theme.dart';
import 'progress_format.dart';
import 'create_goal_dialog.dart';
import 'goal_details_sheet.dart';

class LifeGoalsPage extends StatefulWidget {
  const LifeGoalsPage({super.key, required this.store, required this.settings});

  final GoalStore store;
  final AppSettingsController settings;

  @override
  State<LifeGoalsPage> createState() => _LifeGoalsPageState();
}

class _LifeGoalsPageState extends State<LifeGoalsPage> {
  bool _simplified = true;
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
    final compactSimplified = mobile && _simplified;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        mobile ? 16 : 24,
        mobile ? 18 : 22,
        mobile ? 16 : 24,
        14,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (compactSimplified)
            _SimplifiedHeader(
              onViewChanged: (value) => setState(() => _simplified = value),
            )
          else ...[
            _Header(
              mobile: mobile,
              onNewGoal: () => showCreateGoalDialog(context, widget.store),
            ),
            const SizedBox(height: 14),
            _Toolbar(
              simplified: _simplified,
              category: _category,
              categories: widget.store.availableCategories,
              onViewChanged: (value) => setState(() {
                _simplified = value;
                if (value) _category = null;
              }),
              onCategoryChanged: (value) => setState(() => _category = value),
            ),
            const SizedBox(height: 10),
            Divider(color: context.appBorder),
          ],
          SizedBox(height: compactSimplified ? 16 : 12),
          Expanded(
            child: Stack(
              children: [
                Positioned.fill(
                  child: _goals.isEmpty
                      ? _EmptyGoals(
                          onCreate: () =>
                              showCreateGoalDialog(context, widget.store),
                        )
                      : _simplified
                      ? _SimplifiedGoals(
                          goals: _goals,
                          onOpen: _open,
                          onOptions: _showOptions,
                        )
                      : _Board(
                          mobile: mobile,
                          goals: _goals,
                          columns: _columns,
                          onOpen: _open,
                          onMove: (goal, status) =>
                              widget.store.moveGoal(goal.id, status),
                          onOptions: _showOptions,
                        ),
                ),
                if (compactSimplified)
                  Positioned(
                    right: 2,
                    bottom: 14,
                    child: FloatingActionButton(
                      key: const Key('simplified-new-goal-button'),
                      tooltip: 'New goal',
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Theme.of(context).colorScheme.onPrimary,
                      onPressed: () =>
                          showCreateGoalDialog(context, widget.store),
                      child: const Icon(Icons.add_rounded, size: 31),
                    ),
                  ),
              ],
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

  Future<void> _showOptions(Goal goal) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      useSafeArea: true,
      builder: (sheetContext) => Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text(
                goal.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              subtitle: const Text('Goal options'),
            ),
            ListTile(
              leading: const Icon(Icons.drive_file_move_outline),
              title: const Text('Move to…'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () {
                Navigator.pop(sheetContext);
                _showMoveOptions(goal);
              },
            ),
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('Edit'),
              onTap: () {
                Navigator.pop(sheetContext);
                _open(goal);
              },
            ),
            ListTile(
              leading: const Icon(Icons.copy_rounded),
              title: const Text('Duplicate'),
              onTap: () {
                widget.store.duplicateGoal(goal.id);
                Navigator.pop(sheetContext);
              },
            ),
            ListTile(
              leading: Icon(
                Icons.delete_outline_rounded,
                color: context.appDanger,
              ),
              title: Text(
                'Move to Trash',
                style: TextStyle(color: context.appDanger),
              ),
              onTap: () {
                widget.store.trashGoal(goal.id);
                Navigator.pop(sheetContext);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showMoveOptions(Goal goal) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      useSafeArea: true,
      builder: (sheetContext) => Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ListTile(title: Text('Move goal to')),
            for (final column in _columns)
              ListTile(
                leading: Container(
                  width: 11,
                  height: 11,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: column.color, width: 1.7),
                  ),
                ),
                title: Text(column.label),
                trailing: column.statuses.contains(goal.status)
                    ? const Icon(Icons.check_rounded)
                    : null,
                onTap: () {
                  widget.store.moveGoal(goal.id, column.dropStatus);
                  Navigator.pop(sheetContext);
                },
              ),
          ],
        ),
      ),
    );
  }
}

class _SimplifiedHeader extends StatelessWidget {
  const _SimplifiedHeader({required this.onViewChanged});

  final ValueChanged<bool> onViewChanged;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text('Goals', style: Theme.of(context).textTheme.displaySmall),
      const SizedBox(height: 1),
      Text(
        'Move what matters forward.',
        style: Theme.of(
          context,
        ).textTheme.bodyMedium?.copyWith(color: context.appMuted),
      ),
      const SizedBox(height: 12),
      SizedBox(
        width: double.infinity,
        child: _SimplifiedViewSwitcher(onViewChanged: onViewChanged),
      ),
    ],
  );
}

class _SimplifiedViewSwitcher extends StatelessWidget {
  const _SimplifiedViewSwitcher({required this.onViewChanged});

  final ValueChanged<bool> onViewChanged;

  @override
  Widget build(BuildContext context) => Container(
    height: 36,
    padding: const EdgeInsets.all(2),
    decoration: BoxDecoration(
      border: Border.all(color: context.appBorder),
      borderRadius: BorderRadius.circular(15),
    ),
    child: Row(
      children: [
        Expanded(
          child: _SimplifiedViewChoice(
            label: 'Board',
            selected: false,
            onTap: () => onViewChanged(false),
          ),
        ),
        Expanded(
          child: _SimplifiedViewChoice(
            label: 'Simplified',
            selected: true,
            onTap: () => onViewChanged(true),
          ),
        ),
      ],
    ),
  );
}

class _SimplifiedViewChoice extends StatelessWidget {
  const _SimplifiedViewChoice({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: selected ? context.appSoftRed : Colors.transparent,
    borderRadius: BorderRadius.circular(13),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(13),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? context.appDangerText : context.appMuted,
              fontSize: 13,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ),
      ),
    ),
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
            if (!mobile) const SizedBox(height: 5),
            if (!mobile)
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
      child: MediaQuery.sizeOf(context).width < 520
          ? Padding(
              padding: const EdgeInsets.all(12),
              child: Icon(
                Icons.filter_list,
                size: 20,
                color: category == null
                    ? context.appMuted
                    : Theme.of(context).colorScheme.primary,
              ),
            )
          : Container(
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
    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 8,
      runSpacing: 8,
      children: [viewControls, filter],
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
                fontSize: 12,
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

class _Board extends StatefulWidget {
  const _Board({
    required this.mobile,
    required this.goals,
    required this.columns,
    required this.onOpen,
    required this.onMove,
    required this.onOptions,
  });

  final bool mobile;
  final List<Goal> goals;
  final List<_GoalColumn> columns;
  final ValueChanged<Goal> onOpen;
  final void Function(Goal, GoalStatus) onMove;
  final ValueChanged<Goal> onOptions;

  @override
  State<_Board> createState() => _BoardState();
}

class _BoardState extends State<_Board> {
  final _scrollController = ScrollController();
  Timer? _edgeScrollTimer;
  int _edgeDirection = 0;

  @override
  void dispose() {
    _edgeScrollTimer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  void _updateEdgeScroll(Offset globalPosition) {
    if (!widget.mobile) return;
    final renderObject = context.findRenderObject();
    if (renderObject is! RenderBox) return;
    final local = renderObject.globalToLocal(globalPosition);
    const edge = 58.0;
    final nextDirection = local.dx < edge
        ? -1
        : local.dx > renderObject.size.width - edge
        ? 1
        : 0;
    if (nextDirection == _edgeDirection) return;
    _stopEdgeScroll();
    if (nextDirection == 0) return;
    _edgeDirection = nextDirection;
    _edgeScrollTimer = Timer.periodic(const Duration(milliseconds: 16), (_) {
      if (!_scrollController.hasClients) return;
      final position = _scrollController.position;
      final next = (position.pixels + _edgeDirection * 3.2).clamp(
        position.minScrollExtent,
        position.maxScrollExtent,
      );
      _scrollController.jumpTo(next);
    });
  }

  void _stopEdgeScroll() {
    _edgeScrollTimer?.cancel();
    _edgeScrollTimer = null;
    _edgeDirection = 0;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.mobile) {
      final width = (MediaQuery.sizeOf(context).width * .84).clamp(
        272.0,
        342.0,
      );
      return ListView.separated(
        key: const Key('mobile-goal-board'),
        controller: _scrollController,
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: widget.columns.length,
        separatorBuilder: (_, _) => const SizedBox(width: 12),
        itemBuilder: (context, index) => SizedBox(
          width: width,
          child: _BoardColumn(
            column: widget.columns[index],
            goals: widget.goals
                .where(
                  (goal) =>
                      widget.columns[index].statuses.contains(goal.status),
                )
                .toList(),
            onOpen: widget.onOpen,
            onMove: widget.onMove,
            onOptions: widget.onOptions,
            onDragUpdate: _updateEdgeScroll,
            onDragStopped: _stopEdgeScroll,
          ),
        ),
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var index = 0; index < widget.columns.length; index++) ...[
          Expanded(
            child: _BoardColumn(
              column: widget.columns[index],
              goals: widget.goals
                  .where(
                    (goal) =>
                        widget.columns[index].statuses.contains(goal.status),
                  )
                  .toList(),
              onOpen: widget.onOpen,
              onMove: widget.onMove,
              onOptions: widget.onOptions,
            ),
          ),
          if (index < widget.columns.length - 1) const SizedBox(width: 12),
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
    required this.onOptions,
    this.onDragUpdate,
    this.onDragStopped,
  });

  final _GoalColumn column;
  final List<Goal> goals;
  final ValueChanged<Goal> onOpen;
  final void Function(Goal, GoalStatus) onMove;
  final ValueChanged<Goal> onOptions;
  final ValueChanged<Offset>? onDragUpdate;
  final VoidCallback? onDragStopped;

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
            ? context.appPanel.withValues(alpha: .65)
            : column.color.withValues(alpha: .06),
        borderRadius: BorderRadius.circular(9),
        border: Border.all(
          color: candidates.isEmpty
              ? Colors.transparent
              : column.color.withValues(alpha: .42),
        ),
      ),
      padding: const EdgeInsets.all(9),
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
                Expanded(
                  child: Text(
                    column.label,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 5),
                Text(
                  '${goals.length}',
                  style: TextStyle(color: context.appMuted, fontSize: 11),
                ),
                const SizedBox(width: 8),
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
                        onDragUpdate: (details) =>
                            onDragUpdate?.call(details.globalPosition),
                        onDragEnd: (_) => onDragStopped?.call(),
                        onDraggableCanceled: (_, _) => onDragStopped?.call(),
                        onDragCompleted: () => onDragStopped?.call(),
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
                        child: _GoalCard(
                          goal: goal,
                          onTap: () => onOpen(goal),
                          onOptions: () => onOptions(goal),
                        ),
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
  const _GoalCard({required this.goal, required this.onTap, this.onOptions});

  final Goal goal;
  final VoidCallback? onTap;
  final VoidCallback? onOptions;

  @override
  Widget build(BuildContext context) {
    final amount = goal.plan == null
        ? goal.steps.isEmpty
              ? 'No plan yet'
              : '${goal.completedStepCount} of ${goal.steps.length} steps'
        : '${_number(goal.completedAmount)} of ${_number(goal.plan!.totalAmount)} ${goal.plan!.unit}';
    final date = goal.plan?.deadline;
    final progress = goal.plan != null
        ? goal.progress
        : goal.steps.isEmpty
        ? 0.0
        : goal.completedStepCount / goal.steps.length;
    final color = goal.status == GoalStatus.completed
        ? const Color(0xFF85CC96)
        : Theme.of(context).colorScheme.primary;
    return Material(
      color: context.appRaised,
      borderRadius: BorderRadius.circular(11),
      child: InkWell(
        borderRadius: BorderRadius.circular(11),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 9, 10, 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(11),
            border: Border.all(color: context.appBorder.withValues(alpha: .5)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      goal.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        height: 1.4,
                      ),
                    ),
                  ),
                  if (goal.isUrgent)
                    const Icon(
                      Icons.local_fire_department_outlined,
                      size: 16,
                      color: AppColors.danger,
                    ),
                  IconButton(
                    tooltip: 'Goal options',
                    onPressed: onOptions,
                    icon: Icon(
                      Icons.more_vert,
                      size: 17,
                      color: context.appMuted,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Semantics(
                    label: '${(progress * 100).round()} percent completed',
                    child: SizedBox(
                      width: 48,
                      height: 48,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          SizedBox.expand(
                            child: CircularProgressIndicator(
                              value: progress.clamp(0, 1),
                              strokeWidth: 5,
                              strokeCap: StrokeCap.round,
                              backgroundColor: context.appBorder,
                              color: color,
                            ),
                          ),
                          if (goal.status == GoalStatus.completed)
                            Icon(Icons.check, size: 22, color: color),
                          if (goal.status != GoalStatus.completed)
                            Text(
                              formatProgressPercent(progress),
                              style: const TextStyle(fontSize: 10),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          amount,
                          style: const TextStyle(fontSize: 12, height: 1.4),
                        ),
                        if (date != null) ...[
                          const SizedBox(height: 9),
                          Row(
                            children: [
                              Icon(
                                Icons.calendar_today_outlined,
                                size: 12,
                                color: color,
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  _shortDate(date),
                                  style: TextStyle(fontSize: 11, color: color),
                                ),
                              ),
                            ],
                          ),
                        ],
                        if (goal.category.isNotEmpty) ...[
                          const SizedBox(height: 7),
                          Text(
                            goal.category,
                            style: TextStyle(
                              fontSize: 10,
                              color: context.appMuted,
                            ),
                          ),
                        ],
                      ],
                    ),
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
    required this.onOpen,
    required this.onOptions,
  });

  final List<Goal> goals;
  final ValueChanged<Goal> onOpen;
  final ValueChanged<Goal> onOptions;

  static const _groups = <_SimplifiedGoalGroup>[
    _SimplifiedGoalGroup(
      label: 'Ideas',
      statuses: {GoalStatus.ideas, GoalStatus.planned},
    ),
    _SimplifiedGoalGroup(label: 'In progress', statuses: {GoalStatus.active}),
    _SimplifiedGoalGroup(label: 'Paused', statuses: {GoalStatus.paused}),
    _SimplifiedGoalGroup(label: 'Finished', statuses: {GoalStatus.completed}),
  ];

  @override
  Widget build(BuildContext context) {
    return ListView(
      key: const Key('simplified-goal-list'),
      padding: const EdgeInsets.only(bottom: 92),
      children: [
        for (var groupIndex = 0; groupIndex < _groups.length; groupIndex++) ...[
          if (groupIndex > 0) const SizedBox(height: 16),
          _SimplifiedSectionHeader(
            group: _groups[groupIndex],
            count: goals
                .where(
                  (goal) => _groups[groupIndex].statuses.contains(goal.status),
                )
                .length,
          ),
          for (final goal in goals.where(
            (goal) => _groups[groupIndex].statuses.contains(goal.status),
          ))
            _SimpleGoalRow(
              key: Key('simplified-goal-${goal.id}'),
              goal: goal,
              onTap: () => onOpen(goal),
              onOptions: () => onOptions(goal),
            ),
        ],
      ],
    );
  }
}

class _SimplifiedGoalGroup {
  const _SimplifiedGoalGroup({required this.label, required this.statuses});

  final String label;
  final Set<GoalStatus> statuses;
}

class _SimplifiedSectionHeader extends StatelessWidget {
  const _SimplifiedSectionHeader({required this.group, required this.count});

  final _SimplifiedGoalGroup group;
  final int count;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Row(
      children: [
        Icon(
          switch (group.label) {
            'Ideas' => Icons.lightbulb_outline_rounded,
            'In progress' => Icons.radio_button_checked_rounded,
            'Paused' => Icons.pause_circle_filled_rounded,
            _ => Icons.check_circle_rounded,
          },
          size: 17,
          color: switch (group.label) {
            'Ideas' => context.appWarningText,
            'In progress' => context.appBlueText,
            'Paused' => context.appWarningText,
            _ => context.appGreenText,
          },
        ),
        const SizedBox(width: 7),
        Text(
          group.label,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(width: 12),
        Text('$count', style: TextStyle(color: context.appMuted, fontSize: 13)),
        const SizedBox(width: 15),
        Expanded(
          child: Divider(color: context.appBorder.withValues(alpha: .8)),
        ),
      ],
    ),
  );
}

class _SimpleGoalRow extends StatelessWidget {
  const _SimpleGoalRow({
    super.key,
    required this.goal,
    required this.onTap,
    required this.onOptions,
  });

  final Goal goal;
  final VoidCallback onTap;
  final VoidCallback onOptions;

  @override
  Widget build(BuildContext context) {
    final percentage = goal.status == GoalStatus.completed
        ? 100
        : (goal.progress * 100).round();
    return Material(
      color: context.appPanel,
      borderRadius: BorderRadius.circular(8),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        onLongPress: onOptions,
        child: Container(
          height: 46,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          margin: const EdgeInsets.only(bottom: 4),
          decoration: BoxDecoration(
            color: context.appRaised.withValues(alpha: .34),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: context.appBorder.withValues(alpha: .72)),
          ),
          child: Row(
            children: [
              Semantics(
                label: '${goal.name}, $percentage percent complete',
                child: Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: goal.status == GoalStatus.completed
                        ? context.appSuccess
                        : Colors.transparent,
                    border: Border.all(
                      color: goal.status == GoalStatus.completed
                          ? context.appSuccess
                          : context.appText,
                      width: 1.5,
                    ),
                  ),
                  child: goal.status == GoalStatus.completed
                      ? Icon(
                          Icons.check_rounded,
                          size: 14,
                          color: context.appPanel,
                        )
                      : null,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      goal.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (percentage > 0 &&
                        goal.status != GoalStatus.completed) ...[
                      const SizedBox(height: 5),
                      Row(
                        children: [
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: LinearProgressIndicator(
                                value: percentage / 100,
                                minHeight: 4,
                                backgroundColor: context.appBorder,
                                color: goal.status == GoalStatus.paused
                                    ? context.appPending
                                    : Theme.of(context).colorScheme.secondary,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '$percentage%',
                            style: TextStyle(
                              fontSize: 10,
                              color: context.appMuted,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Goal actions',
                onPressed: onOptions,
                visualDensity: VisualDensity.compact,
                icon: Icon(
                  Icons.more_vert_rounded,
                  size: 19,
                  color: context.appMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
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
            'Create a goal, add a plan when you’re ready, and take it one task at a time.',
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
