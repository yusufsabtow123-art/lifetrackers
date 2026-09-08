import 'package:flutter/material.dart';

import '../app/goal_store.dart';
import '../app/life_store.dart';
import '../app/theme_controller.dart';
import '../domain/goal.dart';
import '../domain/life_data.dart';
import '../domain/plan_calculator.dart';
import '../platform/goal_notification_service.dart';
import 'app_theme.dart';
import 'life_calendar_page.dart';
import 'life_goals_page.dart';
import 'settings_page.dart';

enum _Destination { today, goals, tasks, calendar, ai, more }

class LifeTrackerShell extends StatefulWidget {
  const LifeTrackerShell({
    super.key,
    required this.goalStore,
    required this.lifeStore,
    required this.settings,
    this.notificationService,
  });

  final GoalStore goalStore;
  final LifeStore lifeStore;
  final AppSettingsController settings;
  final GoalNotificationService? notificationService;

  @override
  State<LifeTrackerShell> createState() => _LifeTrackerShellState();
}

class _LifeTrackerShellState extends State<LifeTrackerShell> {
  _Destination _destination = _Destination.today;

  void selectDestination(_Destination destination) {
    setState(() => _destination = destination);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([widget.goalStore, widget.lifeStore]),
      builder: (context, _) {
        final wide = MediaQuery.sizeOf(context).width >= 820;
        final page = _page();
        return Scaffold(
          appBar: wide
              ? null
              : AppBar(
                  toolbarHeight: 48,
                  backgroundColor: context.appPanel,
                  surfaceTintColor: Colors.transparent,
                  titleSpacing: 14,
                  shape: Border(bottom: BorderSide(color: context.appBorder)),
                  title: Row(
                    children: [
                      Text(
                        _activeSpace.name,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: context.appMuted,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 7),
                        child: Text(
                          '/',
                          style: TextStyle(color: context.appMuted),
                        ),
                      ),
                      Text(
                        _title,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  actions: [
                    IconButton(
                      tooltip: 'Change space',
                      onPressed: _showSpacePicker,
                      icon: const Icon(Icons.unfold_more_rounded, size: 19),
                    ),
                  ],
                ),
          body: SafeArea(
            child: Row(
              children: [
                if (wide) _DesktopNavigation(state: this),
                Expanded(
                  child: Column(
                    children: [
                      if (wide)
                        _DesktopTopBar(
                          space: _activeSpace.name,
                          page: _title,
                          onSpace: _showSpacePicker,
                        ),
                      Expanded(
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 190),
                          switchInCurve: Curves.easeOutCubic,
                          switchOutCurve: Curves.easeInCubic,
                          transitionBuilder: (child, animation) =>
                              FadeTransition(
                                opacity: animation,
                                child: SlideTransition(
                                  position: Tween(
                                    begin: const Offset(.01, 0),
                                    end: Offset.zero,
                                  ).animate(animation),
                                  child: child,
                                ),
                              ),
                          child: KeyedSubtree(
                            key: ValueKey(_destination),
                            child: page,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          bottomNavigationBar: wide
              ? null
              : NavigationBar(
                  selectedIndex: switch (_destination) {
                    _Destination.today => 0,
                    _Destination.goals => 1,
                    _Destination.tasks => 2,
                    _Destination.calendar => 3,
                    _ => 4,
                  },
                  onDestinationSelected: (index) => setState(() {
                    _destination = switch (index) {
                      0 => _Destination.today,
                      1 => _Destination.goals,
                      2 => _Destination.tasks,
                      3 => _Destination.calendar,
                      _ => _Destination.more,
                    };
                  }),
                  destinations: const [
                    NavigationDestination(
                      icon: Icon(Icons.today_outlined),
                      selectedIcon: Icon(Icons.today_rounded),
                      label: 'Today',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.flag_outlined),
                      selectedIcon: Icon(Icons.flag_rounded),
                      label: 'Goals',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.check_circle_outline_rounded),
                      selectedIcon: Icon(Icons.check_circle_rounded),
                      label: 'Tasks',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.calendar_month_outlined),
                      selectedIcon: Icon(Icons.calendar_month_rounded),
                      label: 'Calendar',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.grid_view_rounded),
                      label: 'More',
                    ),
                  ],
                ),
        );
      },
    );
  }

  LifeSpace get _activeSpace => widget.lifeStore.spaces.firstWhere(
    (space) => space.id == widget.lifeStore.activeSpaceId,
    orElse: () => const LifeSpace(
      id: LifeSpace.personalId,
      name: 'Personal',
      isShared: false,
    ),
  );

  String get _title => switch (_destination) {
    _Destination.today => 'Today',
    _Destination.goals => 'Goals',
    _Destination.tasks => 'Tasks',
    _Destination.calendar => 'Calendar',
    _Destination.ai => 'AI',
    _Destination.more =>
      MediaQuery.sizeOf(context).width >= 820 ? 'Settings' : 'More',
  };

  Widget _page() => switch (_destination) {
    _Destination.today => TodayPage(
      goalStore: widget.goalStore,
      lifeStore: widget.lifeStore,
    ),
    _Destination.goals => LifeGoalsPage(
      store: widget.goalStore,
      settings: widget.settings,
    ),
    _Destination.tasks => TasksPage(
      goalStore: widget.goalStore,
      lifeStore: widget.lifeStore,
    ),
    _Destination.calendar => LifeCalendarPage(
      goalStore: widget.goalStore,
      lifeStore: widget.lifeStore,
    ),
    _Destination.ai => const _AiPage(),
    _Destination.more =>
      MediaQuery.sizeOf(context).width >= 820
          ? SettingsPage(
              store: widget.goalStore,
              settings: widget.settings,
              notificationService: widget.notificationService,
            )
          : _MorePage(
              goalStore: widget.goalStore,
              lifeStore: widget.lifeStore,
              settings: widget.settings,
              notificationService: widget.notificationService,
              onAi: () => setState(() => _destination = _Destination.ai),
              onSpaces: _showSpaces,
              onSettings: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (context) => Scaffold(
                    appBar: AppBar(title: const Text('Settings')),
                    body: SettingsPage(
                      store: widget.goalStore,
                      settings: widget.settings,
                      notificationService: widget.notificationService,
                    ),
                  ),
                ),
              ),
            ),
  };

  Future<void> _showSpacePicker() async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Choose a space',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              for (final space in widget.lifeStore.spaces)
                _SurfaceTile(
                  icon: space.isShared
                      ? Icons.group_outlined
                      : Icons.person_outline,
                  title: space.name,
                  subtitle: space.isShared ? 'Shared' : 'Only you',
                  trailing: space.id == widget.lifeStore.activeSpaceId
                      ? const Icon(Icons.check_circle_rounded)
                      : null,
                  onTap: () {
                    widget.lifeStore.selectSpace(space.id);
                    Navigator.pop(context);
                  },
                ),
              if (!widget.lifeStore.spaces.any((space) => space.isShared))
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      _createSharedSpace();
                    },
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('Create your free Shared Space'),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _createSharedSpace() async {
    final controller = TextEditingController();
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create Shared Space'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Space name',
            hintText: 'Family, team, or group',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              widget.lifeStore.createSharedSpace(controller.text);
              Navigator.pop(context);
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
    controller.dispose();
  }

  Future<void> _showSpaces() => Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (context) => SpacesPage(store: widget.lifeStore),
    ),
  );
}

class _DesktopTopBar extends StatelessWidget {
  const _DesktopTopBar({
    required this.space,
    required this.page,
    required this.onSpace,
  });

  final String space;
  final String page;
  final VoidCallback onSpace;

  @override
  Widget build(BuildContext context) => Container(
    height: 49,
    padding: const EdgeInsets.symmetric(horizontal: 16),
    decoration: BoxDecoration(
      color: context.appPanel,
      border: Border(bottom: BorderSide(color: context.appBorder)),
    ),
    child: Row(
      children: [
        InkWell(
          onTap: onSpace,
          borderRadius: BorderRadius.circular(5),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
            child: Text(
              space,
              style: TextStyle(color: context.appMuted, fontSize: 11),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 7),
          child: Text(
            '/',
            style: TextStyle(color: context.appMuted, fontSize: 11),
          ),
        ),
        Text(
          page,
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
        ),
        const Spacer(),
        Icon(Icons.undo_rounded, size: 16, color: context.appMuted),
        const SizedBox(width: 16),
        Icon(Icons.download_outlined, size: 16, color: context.appMuted),
        const SizedBox(width: 16),
        const CircleAvatar(
          radius: 11,
          child: Text('YO', style: TextStyle(fontSize: 8)),
        ),
      ],
    ),
  );
}

class _DesktopNavigation extends StatelessWidget {
  const _DesktopNavigation({required this.state});
  final _LifeTrackerShellState state;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 204,
      decoration: BoxDecoration(
        color: context.appPanel,
        border: Border(right: BorderSide(color: context.appBorder)),
      ),
      padding: const EdgeInsets.fromLTRB(10, 17, 10, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Row(
              children: [
                Container(
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFFE6E6EA), Color(0xFF7774CD)],
                    ),
                  ),
                ),
                const SizedBox(width: 9),
                Text(
                  'Life Tracker',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const Spacer(),
                Icon(Icons.edit_square, size: 16, color: context.appMuted),
              ],
            ),
          ),
          const SizedBox(height: 22),
          _SpaceButton(
            name: state._activeSpace.name,
            shared: state._activeSpace.isShared,
            onTap: state._showSpacePicker,
          ),
          const SizedBox(height: 14),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 2, 8, 8),
            child: Text(
              'Workspace',
              style: TextStyle(color: context.appMuted, fontSize: 10.5),
            ),
          ),
          _NavItem(
            state: state,
            destination: _Destination.goals,
            icon: Icons.flag_outlined,
            label: 'Goals',
          ),
          _NavItem(
            state: state,
            destination: _Destination.tasks,
            icon: Icons.check_circle_outline_rounded,
            label: 'Tasks',
          ),
          _NavItem(
            state: state,
            destination: _Destination.calendar,
            icon: Icons.calendar_month_outlined,
            label: 'Calendar',
          ),
          _NavItem(
            state: state,
            destination: _Destination.ai,
            icon: Icons.auto_awesome_outlined,
            label: 'AI',
          ),
          const SizedBox(height: 14),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 2, 8, 8),
            child: Text(
              'Quick access',
              style: TextStyle(color: context.appMuted, fontSize: 10.5),
            ),
          ),
          _NavItem(
            state: state,
            destination: _Destination.today,
            icon: Icons.check_circle_outline_rounded,
            label: "Today's tasks",
          ),
          const Spacer(),
          _NavItem(
            state: state,
            destination: _Destination.more,
            icon: Icons.settings_outlined,
            label: 'Settings',
          ),
          Divider(color: context.appBorder, height: 20),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 13,
                  child: Text('YO', style: TextStyle(fontSize: 9)),
                ),
                SizedBox(width: 9),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'You',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        'Private · On this device',
                        style: TextStyle(fontSize: 9),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.state,
    required this.destination,
    required this.icon,
    required this.label,
  });
  final _LifeTrackerShellState state;
  final _Destination destination;
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final selected = state._destination == destination;
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: selected ? context.appRaised : Colors.transparent,
        borderRadius: BorderRadius.circular(6),
        child: InkWell(
          borderRadius: BorderRadius.circular(6),
          onTap: () => state.selectDestination(destination),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 8),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 16,
                  color: selected
                      ? Theme.of(context).colorScheme.primary
                      : context.appMuted,
                ),
                const SizedBox(width: 9),
                Text(
                  label,
                  style: TextStyle(
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SpaceButton extends StatelessWidget {
  const _SpaceButton({
    required this.name,
    required this.shared,
    required this.onTap,
  });
  final String name;
  final bool shared;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: context.appRaised,
    borderRadius: BorderRadius.circular(7),
    child: InkWell(
      borderRadius: BorderRadius.circular(7),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        child: Row(
          children: [
            Icon(
              shared ? Icons.group_outlined : Icons.person_outline,
              size: 16,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
            const Icon(Icons.unfold_more_rounded, size: 18),
          ],
        ),
      ),
    ),
  );
}

class TodayPage extends StatelessWidget {
  const TodayPage({
    super.key,
    required this.goalStore,
    required this.lifeStore,
  });
  final GoalStore goalStore;
  final LifeStore lifeStore;

  @override
  Widget build(BuildContext context) {
    final today = goalStore.today;
    final goals = _goalActions(goalStore, today);
    final tasks = lifeStore.tasksFor(today);
    final unfinishedTasks = tasks.where((task) => !task.isDoneOn(today)).length;
    final entries = lifeStore.entriesFor(today);
    return _PageFrame(
      title: 'Today',
      subtitle: _friendlyDate(today),
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          _SummaryStrip(
            first: '${goals.length + unfinishedTasks}',
            firstLabel: 'left to do',
            second: '${entries.length}',
            secondLabel: 'on calendar',
          ),
          const SizedBox(height: 22),
          _SectionTitle(title: 'Daily actions', count: goals.length),
          const SizedBox(height: 9),
          if (goals.isEmpty)
            const _EmptyCard(
              icon: Icons.wb_sunny_outlined,
              title: 'Your day is clear',
              body: 'Active goals with a plan will appear here automatically.',
            )
          else
            for (final action in goals)
              _ActionTile(
                icon: Icons.flag_outlined,
                title: action.goal.name,
                subtitle:
                    '${formatAmount(action.amount)} ${action.goal.plan!.unit}',
                done: action.goal.completionFor(today) != null,
                onToggle: () => action.goal.completionFor(today) == null
                    ? goalStore.completeTodayAction(action.goal.id)
                    : goalStore.undoTodayAction(action.goal.id),
              ),
          const SizedBox(height: 22),
          _SectionTitle(
            title: 'Tasks',
            count: unfinishedTasks,
            countKey: const Key('today-task-count'),
          ),
          const SizedBox(height: 9),
          if (tasks.isEmpty)
            const _EmptyCard(
              icon: Icons.check_circle_outline_rounded,
              title: 'No tasks due today',
              body: 'Add a task from the Tasks page when you need one.',
            )
          else
            for (final task in tasks)
              _TaskTile(
                task: task,
                store: lifeStore,
                date: today,
                onOpen: () =>
                    _showTaskEditor(context, lifeStore, goalStore, task: task),
              ),
          if (entries.isNotEmpty) ...[
            const SizedBox(height: 22),
            _SectionTitle(title: 'Schedule', count: entries.length),
            const SizedBox(height: 9),
            for (final entry in entries)
              _CalendarTile(entry: entry, store: lifeStore),
          ],
        ],
      ),
    );
  }
}

class TasksPage extends StatefulWidget {
  const TasksPage({
    super.key,
    required this.goalStore,
    required this.lifeStore,
  });
  final GoalStore goalStore;
  final LifeStore lifeStore;

  @override
  State<TasksPage> createState() => _TasksPageState();
}

class _TasksPageState extends State<TasksPage> {
  int _filter = 0;

  @override
  Widget build(BuildContext context) {
    final now = widget.goalStore.today;
    final tasks = widget.lifeStore.tasks.where((task) {
      if (task.spaceId != widget.lifeStore.activeSpaceId) return false;
      if (_filter == 0) return task.occursOn(now);
      if (_filter == 1) return task.dueAt != null && task.dueAt!.isAfter(now);
      return true;
    }).toList();
    return _PageFrame(
      title: 'Tasks',
      subtitle: 'Clear actions, with only the detail you need.',
      action: FilledButton.icon(
        onPressed: () =>
            _showTaskEditor(context, widget.lifeStore, widget.goalStore),
        icon: const Icon(Icons.add_rounded),
        label: const Text('New task'),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SegmentedButton<int>(
            segments: const [
              ButtonSegment(value: 0, label: Text('Today')),
              ButtonSegment(value: 1, label: Text('Upcoming')),
              ButtonSegment(value: 2, label: Text('All')),
            ],
            selected: {_filter},
            onSelectionChanged: (value) =>
                setState(() => _filter = value.first),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: tasks.isEmpty
                ? const _EmptyCard(
                    icon: Icons.task_alt_rounded,
                    title: 'Nothing here yet',
                    body:
                        'Add one clear next action. You can connect it to a goal, date, place, or person.',
                  )
                : ListView(
                    children: [
                      for (final task in tasks)
                        _TaskTile(
                          task: task,
                          store: widget.lifeStore,
                          onOpen: () => _showTaskEditor(
                            context,
                            widget.lifeStore,
                            widget.goalStore,
                            task: task,
                          ),
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class CalendarPage extends StatefulWidget {
  const CalendarPage({
    super.key,
    required this.goalStore,
    required this.lifeStore,
  });
  final GoalStore goalStore;
  final LifeStore lifeStore;

  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  late DateTime _selected = widget.goalStore.today;
  late DateTime _month = DateTime(_selected.year, _selected.month);

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 980;
    final calendar = _MonthCalendar(
      month: _month,
      selected: _selected,
      goalStore: widget.goalStore,
      lifeStore: widget.lifeStore,
      onSelect: (date) => setState(() => _selected = date),
      onPrevious: () =>
          setState(() => _month = DateTime(_month.year, _month.month - 1)),
      onNext: () =>
          setState(() => _month = DateTime(_month.year, _month.month + 1)),
    );
    final agenda = _DayAgenda(
      date: _selected,
      goalStore: widget.goalStore,
      lifeStore: widget.lifeStore,
    );
    return _PageFrame(
      title: 'Calendar',
      subtitle:
          'See your commitments, daily actions, and protected time together.',
      action: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton.filledTonal(
            tooltip: 'Import changing blocked times',
            onPressed: () => _showScheduleImport(context, widget.lifeStore),
            icon: const Icon(Icons.playlist_add_rounded),
          ),
          const SizedBox(width: 8),
          FilledButton.icon(
            onPressed: () =>
                _showCalendarEditor(context, widget.lifeStore, _selected),
            icon: const Icon(Icons.add_rounded),
            label: const Text('Add'),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  widget.lifeStore.data.showBlockedTimes
                      ? 'Blocked times are shown'
                      : 'Blocked times are hidden',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: context.appMuted),
                ),
              ),
              Switch(
                value: widget.lifeStore.data.showBlockedTimes,
                onChanged: widget.lifeStore.setShowBlockedTimes,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Expanded(
            child: wide
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(flex: 3, child: calendar),
                      const SizedBox(width: 14),
                      Expanded(flex: 2, child: agenda),
                    ],
                  )
                : ListView(
                    children: [calendar, const SizedBox(height: 14), agenda],
                  ),
          ),
        ],
      ),
    );
  }
}

class _MonthCalendar extends StatelessWidget {
  const _MonthCalendar({
    required this.month,
    required this.selected,
    required this.goalStore,
    required this.lifeStore,
    required this.onSelect,
    required this.onPrevious,
    required this.onNext,
  });
  final DateTime month;
  final DateTime selected;
  final GoalStore goalStore;
  final LifeStore lifeStore;
  final ValueChanged<DateTime> onSelect;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final first = DateTime(month.year, month.month, 1);
    final start = first.subtract(Duration(days: first.weekday - 1));
    return Container(
      decoration: BoxDecoration(
        color: context.appPanel,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: context.appBorder),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              IconButton(
                onPressed: onPrevious,
                icon: const Icon(Icons.chevron_left_rounded),
              ),
              Expanded(
                child: Text(
                  '${_monthName(month.month)} ${month.year}',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              IconButton(
                onPressed: onNext,
                icon: const Icon(Icons.chevron_right_rounded),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              for (final day in ['M', 'T', 'W', 'T', 'F', 'S', 'S'])
                Expanded(child: Text(day, textAlign: TextAlign.center)),
            ],
          ),
          const SizedBox(height: 6),
          for (var week = 0; week < 6; week++)
            SizedBox(
              height: MediaQuery.sizeOf(context).width < 500 ? 44 : 52,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var weekday = 0; weekday < 7; weekday++)
                    Expanded(
                      child: _DayCell(
                        date: start.add(Duration(days: week * 7 + weekday)),
                        currentMonth: month.month,
                        selected: selected,
                        hasGoal: _goalActions(
                          goalStore,
                          start.add(Duration(days: week * 7 + weekday)),
                        ).isNotEmpty,
                        hasTask: lifeStore
                            .tasksFor(
                              start.add(Duration(days: week * 7 + weekday)),
                            )
                            .isNotEmpty,
                        hasEntry: lifeStore
                            .entriesFor(
                              start.add(Duration(days: week * 7 + weekday)),
                            )
                            .isNotEmpty,
                        onTap: onSelect,
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.date,
    required this.currentMonth,
    required this.selected,
    required this.hasGoal,
    required this.hasTask,
    required this.hasEntry,
    required this.onTap,
  });
  final DateTime date;
  final int currentMonth;
  final DateTime selected;
  final bool hasGoal;
  final bool hasTask;
  final bool hasEntry;
  final ValueChanged<DateTime> onTap;

  @override
  Widget build(BuildContext context) {
    final active = _sameDate(date, selected);
    return Padding(
      padding: const EdgeInsets.all(2),
      child: InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: () => onTap(date),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          decoration: BoxDecoration(
            color: active
                ? Theme.of(context).colorScheme.primary.withValues(alpha: .16)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
            border: active
                ? Border.all(
                    color: Theme.of(
                      context,
                    ).colorScheme.primary.withValues(alpha: .55),
                  )
                : null,
          ),
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '${date.day}',
                style: TextStyle(
                  color: date.month == currentMonth
                      ? null
                      : context.appMuted.withValues(alpha: .45),
                  fontWeight: active ? FontWeight.w800 : FontWeight.w500,
                ),
              ),
              const SizedBox(height: 5),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (hasGoal) _dot(Theme.of(context).colorScheme.primary),
                  if (hasTask) _dot(const Color(0xFF55C891)),
                  if (hasEntry) _dot(const Color(0xFFF1B84B)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _dot(Color color) => Container(
    width: 5,
    height: 5,
    margin: const EdgeInsets.symmetric(horizontal: 1.5),
    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
  );
}

class _DayAgenda extends StatelessWidget {
  const _DayAgenda({
    required this.date,
    required this.goalStore,
    required this.lifeStore,
  });
  final DateTime date;
  final GoalStore goalStore;
  final LifeStore lifeStore;

  @override
  Widget build(BuildContext context) {
    final goals = _goalActions(goalStore, date);
    final tasks = lifeStore.tasksFor(date);
    final entries = lifeStore.entriesFor(date);
    final empty = goals.isEmpty && tasks.isEmpty && entries.isEmpty;
    return Container(
      decoration: BoxDecoration(
        color: context.appPanel,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: context.appBorder),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            _friendlyDate(date),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          if (empty)
            const _EmptyCard(
              icon: Icons.event_available_outlined,
              title: 'Open day',
              body: 'Nothing is scheduled yet.',
            )
          else ...[
            for (final action in goals)
              _ActionTile(
                icon: Icons.flag_outlined,
                title: action.goal.name,
                subtitle:
                    '${formatAmount(action.amount)} ${action.goal.plan!.unit}',
                done: action.goal.completionFor(date) != null,
                onToggle: _sameDate(date, goalStore.today)
                    ? () => action.goal.completionFor(date) == null
                          ? goalStore.completeTodayAction(action.goal.id)
                          : goalStore.undoTodayAction(action.goal.id)
                    : null,
              ),
            for (final task in tasks)
              _TaskTile(task: task, store: lifeStore, date: date),
            for (final entry in entries)
              _CalendarTile(entry: entry, store: lifeStore),
          ],
        ],
      ),
    );
  }
}

class SpacesPage extends StatelessWidget {
  const SpacesPage({super.key, required this.store});
  final LifeStore store;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: store,
    builder: (context, _) {
      final active = store.spaces.firstWhere(
        (space) => space.id == store.activeSpaceId,
      );
      final hasShared = store.spaces.any((space) => space.isShared);
      return Scaffold(
        appBar: AppBar(title: const Text('Spaces')),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(18),
            children: [
              const _EmptyCard(
                icon: Icons.lock_outline_rounded,
                title: 'Your Personal Space stays private',
                body:
                    'It works completely offline. Only things you deliberately place in a Shared Space are meant to leave this device.',
              ),
              const SizedBox(height: 14),
              for (final space in store.spaces)
                _SurfaceTile(
                  icon: space.isShared
                      ? Icons.group_outlined
                      : Icons.person_outline,
                  title: space.name,
                  subtitle: space.isShared
                      ? '${space.members.length} member${space.members.length == 1 ? '' : 's'}'
                      : 'Only you',
                  onTap: () => store.selectSpace(space.id),
                ),
              if (!hasShared) ...[
                const SizedBox(height: 8),
                FilledButton.icon(
                  onPressed: () => _createSharedSpace(context),
                  icon: const Icon(Icons.group_add_outlined),
                  label: const Text('Create your free Shared Space'),
                ),
                const SizedBox(height: 8),
                Text(
                  'One online Shared Space will be free. More online spaces will be part of the paid version.',
                  textAlign: TextAlign.center,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: context.appMuted),
                ),
              ],
              if (active.isShared) ...[
                const SizedBox(height: 22),
                Text('Members', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 10),
                for (final member in active.members)
                  _SurfaceTile(
                    icon: member.role == SpaceRole.owner
                        ? Icons.workspace_premium_outlined
                        : member.role == SpaceRole.manager
                        ? Icons.admin_panel_settings_outlined
                        : Icons.person_outline,
                    title: member.name,
                    subtitle: member.role.label,
                  ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () => _addMember(context),
                  icon: const Icon(Icons.person_add_alt_1_rounded),
                  label: const Text('Add a person'),
                ),
                const SizedBox(height: 12),
                Text(
                  'Online invitations and syncing will be added with the paid online service. Local roles and assignments are ready now.',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: context.appMuted),
                ),
              ],
            ],
          ),
        ),
      );
    },
  );

  Future<void> _createSharedSpace(BuildContext context) async {
    final controller = TextEditingController();
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create Shared Space'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Space name',
            hintText: 'Family, team, or group',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              store.createSharedSpace(controller.text);
              Navigator.pop(context);
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
    controller.dispose();
  }

  Future<void> _addMember(BuildContext context) async {
    final controller = TextEditingController();
    var role = SpaceRole.member;
    await showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Add a person'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: controller,
                autofocus: true,
                decoration: const InputDecoration(labelText: 'Name'),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<SpaceRole>(
                initialValue: role,
                items: const [
                  DropdownMenuItem(
                    value: SpaceRole.member,
                    child: Text('Member'),
                  ),
                  DropdownMenuItem(
                    value: SpaceRole.manager,
                    child: Text('Manager'),
                  ),
                ],
                onChanged: (value) =>
                    setState(() => role = value ?? SpaceRole.member),
                decoration: const InputDecoration(labelText: 'Role'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                if (controller.text.trim().isNotEmpty) {
                  store.addMember(controller.text, role);
                }
                Navigator.pop(context);
              },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
    controller.dispose();
  }
}

class _MorePage extends StatelessWidget {
  const _MorePage({
    required this.goalStore,
    required this.lifeStore,
    required this.settings,
    required this.notificationService,
    required this.onAi,
    required this.onSpaces,
    required this.onSettings,
  });
  final GoalStore goalStore;
  final LifeStore lifeStore;
  final AppSettingsController settings;
  final GoalNotificationService? notificationService;
  final VoidCallback onAi;
  final VoidCallback onSpaces;
  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) => _PageFrame(
    title: 'More',
    subtitle: 'Spaces, AI, appearance, notifications, and your local files.',
    child: ListView(
      children: [
        _SurfaceTile(
          icon: Icons.group_outlined,
          title: 'Spaces and people',
          subtitle: 'Personal and Shared Space',
          onTap: onSpaces,
        ),
        _SurfaceTile(
          icon: Icons.auto_awesome_outlined,
          title: 'AI',
          subtitle: 'Work in progress',
          onTap: onAi,
        ),
        _SurfaceTile(
          icon: Icons.settings_outlined,
          title: 'Settings',
          subtitle: 'Appearance, notifications, goals, widgets, and files',
          onTap: onSettings,
        ),
        const SizedBox(height: 12),
        _SurfaceTile(
          icon: Icons.description_outlined,
          title: 'Tasks and calendar file',
          subtitle: lifeStore.storagePath,
        ),
      ],
    ),
  );
}

class _AiPage extends StatelessWidget {
  const _AiPage();

  @override
  Widget build(BuildContext context) => const _PageFrame(
    title: 'AI',
    subtitle: 'Optional help will live here without replacing the manual app.',
    child: Center(
      child: _EmptyCard(
        icon: Icons.auto_awesome_outlined,
        title: 'Work in progress',
        body: 'The rest of Life Tracker works without AI.',
      ),
    ),
  );
}

class _PageFrame extends StatelessWidget {
  const _PageFrame({
    required this.title,
    required this.subtitle,
    required this.child,
    this.action,
  });
  final String title;
  final String subtitle;
  final Widget child;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final mobile = MediaQuery.sizeOf(context).width < 820;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        mobile ? 14 : 24,
        mobile ? 18 : 22,
        mobile ? 14 : 24,
        14,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (mobile)
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(title, style: Theme.of(context).textTheme.displaySmall),
                const SizedBox(height: 5),
                Text(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: context.appMuted),
                ),
                if (action != null) ...[
                  const SizedBox(height: 12),
                  Align(alignment: Alignment.centerRight, child: action),
                ],
              ],
            )
          else
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: Theme.of(context).textTheme.displaySmall,
                      ),
                      const SizedBox(height: 5),
                      Text(
                        subtitle,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: context.appMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                if (action != null) ...[const SizedBox(width: 12), action!],
              ],
            ),
          const SizedBox(height: 20),
          Expanded(child: child),
        ],
      ),
    );
  }
}

class _SummaryStrip extends StatelessWidget {
  const _SummaryStrip({
    required this.first,
    required this.firstLabel,
    required this.second,
    required this.secondLabel,
  });
  final String first;
  final String firstLabel;
  final String second;
  final String secondLabel;

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: context.appPanel,
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: context.appBorder),
    ),
    padding: const EdgeInsets.symmetric(vertical: 18),
    child: Row(
      children: [
        _metric(context, first, firstLabel),
        Container(width: 1, height: 36, color: context.appBorder),
        _metric(context, second, secondLabel),
      ],
    ),
  );

  Widget _metric(BuildContext context, String value, String label) => Expanded(
    child: Column(
      children: [
        Text(
          value,
          style: Theme.of(
            context,
          ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
        ),
        Text(
          label,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: context.appMuted),
        ),
      ],
    ),
  );
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({
    required this.title,
    required this.count,
    this.countKey,
  });
  final String title;
  final int count;
  final Key? countKey;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Text(title, style: Theme.of(context).textTheme.titleLarge),
      ),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration: BoxDecoration(
          color: context.appRaised,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text('$count', key: countKey),
      ),
    ],
  );
}

class _EmptyCard extends StatelessWidget {
  const _EmptyCard({
    required this.icon,
    required this.title,
    required this.body,
  });
  final IconData icon;
  final String title;
  final String body;
  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: context.appPanel,
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: context.appBorder),
    ),
    padding: const EdgeInsets.all(20),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: Theme.of(context).colorScheme.primary),
        const SizedBox(height: 10),
        Text(
          title,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 5),
        Text(
          body,
          textAlign: TextAlign.center,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: context.appMuted),
        ),
      ],
    ),
  );
}

class _SurfaceTile extends StatelessWidget {
  const _SurfaceTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.trailing,
    this.onTap,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Material(
      color: context.appPanel,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: context.appBorder),
          ),
          padding: const EdgeInsets.all(15),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: context.appRaised,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(icon, size: 20),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: context.appMuted),
                    ),
                  ],
                ),
              ),
              if (trailing != null)
                trailing!
              else if (onTap != null)
                const Icon(Icons.chevron_right_rounded),
            ],
          ),
        ),
      ),
    ),
  );
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.done,
    this.onToggle,
    this.onTap,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final bool done;
  final VoidCallback? onToggle;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => _SurfaceTile(
    icon: icon,
    title: title,
    subtitle: subtitle,
    onTap: onTap,
    trailing: IconButton(
      onPressed: onToggle,
      icon: Icon(
        done
            ? Icons.check_circle_rounded
            : Icons.radio_button_unchecked_rounded,
        color: done ? const Color(0xFF55C891) : context.appMuted,
      ),
    ),
  );
}

class _TaskTile extends StatelessWidget {
  const _TaskTile({
    required this.task,
    required this.store,
    this.date,
    this.onOpen,
  });
  final LifeTask task;
  final LifeStore store;
  final DateTime? date;
  final VoidCallback? onOpen;
  @override
  Widget build(BuildContext context) {
    final details = <String>[
      if (task.dueAt != null) _shortDate(task.dueAt!),
      if (task.repeat != TaskRepeat.none) task.repeat.label,
      if (task.location.isNotEmpty) task.location,
      if (task.assignee.isNotEmpty) 'Assigned to ${task.assignee}',
    ];
    return Dismissible(
      key: ValueKey(task.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        decoration: BoxDecoration(
          color: const Color(0xFFD35B63).withValues(alpha: .16),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Icon(
          Icons.delete_outline_rounded,
          color: Color(0xFFD35B63),
        ),
      ),
      onDismissed: (_) => store.deleteTask(task),
      child: _ActionTile(
        icon: Icons.check_circle_outline_rounded,
        title: task.title,
        subtitle: details.isEmpty ? 'No date' : details.join('  ·  '),
        onTap: onOpen,
        done: date == null ? task.isCompleted : task.isDoneOn(date!),
        onToggle: () => date == null
            ? store.toggleTask(task)
            : store.toggleTaskForDate(task, date!),
      ),
    );
  }
}

class _CalendarTile extends StatelessWidget {
  const _CalendarTile({required this.entry, required this.store});
  final CalendarEntry entry;
  final LifeStore store;
  @override
  Widget build(BuildContext context) => Dismissible(
    key: ValueKey(entry.id),
    direction: DismissDirection.endToStart,
    onDismissed: (_) => store.deleteCalendarEntry(entry),
    background: Container(
      alignment: Alignment.centerRight,
      padding: const EdgeInsets.only(right: 24),
      child: const Icon(Icons.delete_outline_rounded, color: Color(0xFFD35B63)),
    ),
    child: _SurfaceTile(
      icon: entry.kind == CalendarEntryKind.blockedTime
          ? Icons.block_outlined
          : Icons.event_outlined,
      title: entry.title,
      subtitle:
          '${_time(entry.start)}–${_time(entry.end)}${entry.location.isEmpty ? '' : '  ·  ${entry.location}'}',
    ),
  );
}

Future<void> _showTaskEditor(
  BuildContext context,
  LifeStore store,
  GoalStore goals, {
  LifeTask? task,
}) async {
  final editing = task != null;
  final title = TextEditingController(text: task?.title ?? '');
  final notes = TextEditingController(text: task?.notes ?? '');
  final location = TextEditingController(text: task?.location ?? '');
  var due = task?.dueAt ?? goals.today;
  var repeat = task?.repeat ?? TaskRepeat.none;
  String? goalId = task?.goalId;
  var assignee = task?.assignee ?? '';
  final activeSpace = store.spaces.firstWhere(
    (space) => space.id == store.activeSpaceId,
  );
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          4,
          20,
          MediaQuery.viewInsetsOf(context).bottom + 22,
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                editing ? 'Edit task' : 'New task',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              TextField(
                key: const Key('task-title-field'),
                controller: title,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'What needs to be done?',
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: notes,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Notes (optional)',
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        final chosen = await showDatePicker(
                          context: context,
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2100),
                          initialDate: due,
                        );
                        if (chosen != null) setState(() => due = chosen);
                      },
                      icon: const Icon(Icons.calendar_today_outlined),
                      label: Text(_shortDate(due)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: DropdownButtonFormField<TaskRepeat>(
                      isExpanded: true,
                      initialValue: repeat,
                      items: [
                        for (final item in TaskRepeat.values)
                          DropdownMenuItem(
                            value: item,
                            child: Text(item.label),
                          ),
                      ],
                      onChanged: (value) =>
                          setState(() => repeat = value ?? TaskRepeat.none),
                      decoration: const InputDecoration(labelText: 'Repeat'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String?>(
                isExpanded: true,
                initialValue: goalId,
                items: [
                  const DropdownMenuItem<String?>(
                    value: null,
                    child: Text('No connected goal'),
                  ),
                  for (final goal in goals.goals.where(
                    (goal) => !goal.isTrashed,
                  ))
                    DropdownMenuItem<String?>(
                      value: goal.id,
                      child: Text(goal.name, overflow: TextOverflow.ellipsis),
                    ),
                ],
                onChanged: (value) => setState(() => goalId = value),
                decoration: const InputDecoration(labelText: 'Goal (optional)'),
              ),
              const SizedBox(height: 10),
              if (activeSpace.isShared) ...[
                DropdownButtonFormField<String>(
                  isExpanded: true,
                  initialValue: assignee,
                  items: [
                    const DropdownMenuItem(
                      value: '',
                      child: Text('Unassigned'),
                    ),
                    for (final member in activeSpace.members)
                      DropdownMenuItem(
                        value: member.name,
                        child: Text(member.name),
                      ),
                  ],
                  onChanged: (value) => setState(() => assignee = value ?? ''),
                  decoration: const InputDecoration(
                    labelText: 'Assign to (optional)',
                  ),
                ),
                const SizedBox(height: 10),
              ],
              TextField(
                controller: location,
                decoration: const InputDecoration(
                  labelText: 'Location (optional)',
                  prefixIcon: Icon(Icons.location_on_outlined),
                ),
              ),
              const SizedBox(height: 18),
              FilledButton(
                key: const Key('task-save-button'),
                onPressed: () {
                  if (title.text.trim().isEmpty) return;
                  if (task == null) {
                    store.addTask(
                      title: title.text,
                      notes: notes.text,
                      dueAt: due,
                      repeat: repeat,
                      goalId: goalId,
                      location: location.text,
                      assignee: assignee,
                    );
                  } else {
                    store.updateTask(
                      task.copyWith(
                        title: title.text.trim(),
                        notes: notes.text.trim(),
                        dueAt: due,
                        repeat: repeat,
                        goalId: goalId,
                        clearGoal: goalId == null,
                        location: location.text.trim(),
                        assignee: assignee.trim(),
                      ),
                    );
                  }
                  Navigator.pop(context);
                },
                child: Text(editing ? 'Save changes' : 'Add task'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
  await Future<void>.delayed(const Duration(milliseconds: 350));
  title.dispose();
  notes.dispose();
  location.dispose();
}

Future<void> _showCalendarEditor(
  BuildContext context,
  LifeStore store,
  DateTime date,
) async {
  final title = TextEditingController();
  final location = TextEditingController();
  var kind = CalendarEntryKind.event;
  var startTime = const TimeOfDay(hour: 9, minute: 0);
  var endTime = const TimeOfDay(hour: 10, minute: 0);
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          4,
          20,
          MediaQuery.viewInsetsOf(context).bottom + 22,
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Add to calendar',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 14),
              SegmentedButton<CalendarEntryKind>(
                segments: const [
                  ButtonSegment(
                    value: CalendarEntryKind.event,
                    icon: Icon(Icons.event_outlined),
                    label: Text('Event'),
                  ),
                  ButtonSegment(
                    value: CalendarEntryKind.blockedTime,
                    icon: Icon(Icons.block_outlined),
                    label: Text('Blocked time'),
                  ),
                ],
                selected: {kind},
                onSelectionChanged: (value) =>
                    setState(() => kind = value.first),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: title,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: kind == CalendarEntryKind.blockedTime
                      ? 'What is this time protected for?'
                      : 'Event name',
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () async {
                        final value = await showTimePicker(
                          context: context,
                          initialTime: startTime,
                        );
                        if (value != null) setState(() => startTime = value);
                      },
                      child: Text('Starts ${startTime.format(context)}'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () async {
                        final value = await showTimePicker(
                          context: context,
                          initialTime: endTime,
                        );
                        if (value != null) setState(() => endTime = value);
                      },
                      child: Text('Ends ${endTime.format(context)}'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              TextField(
                controller: location,
                decoration: const InputDecoration(
                  labelText: 'Location (optional)',
                  prefixIcon: Icon(Icons.location_on_outlined),
                ),
              ),
              const SizedBox(height: 18),
              FilledButton(
                onPressed: () {
                  if (title.text.trim().isEmpty) return;
                  final start = DateTime(
                    date.year,
                    date.month,
                    date.day,
                    startTime.hour,
                    startTime.minute,
                  );
                  var end = DateTime(
                    date.year,
                    date.month,
                    date.day,
                    endTime.hour,
                    endTime.minute,
                  );
                  if (!end.isAfter(start)) {
                    end = end.add(const Duration(days: 1));
                  }
                  store.addCalendarEntry(
                    title: title.text,
                    start: start,
                    end: end,
                    kind: kind,
                    location: location.text,
                  );
                  Navigator.pop(context);
                },
                child: const Text('Save'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
  title.dispose();
  location.dispose();
}

Future<void> _showScheduleImport(BuildContext context, LifeStore store) async {
  final controller = TextEditingController();
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        4,
        20,
        MediaQuery.viewInsetsOf(context).bottom + 22,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Import changing blocked times',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 7),
            Text(
              'Paste rows from a sheet. Use: date, start, end, name. Each row can have a different time.',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: context.appMuted),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: controller,
              autofocus: true,
              minLines: 7,
              maxLines: 12,
              decoration: const InputDecoration(
                hintText:
                    '2027-01-01,5:45 AM,6:05 AM,Fajr\n2027-01-02,5:46 AM,6:06 AM,Fajr',
              ),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () async {
                final count = await store.importBlockedSchedule(
                  controller.text,
                );
                if (!context.mounted) return;
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      count == 0
                          ? 'No valid rows were found.'
                          : 'Added $count blocked time${count == 1 ? '' : 's'}.',
                    ),
                  ),
                );
              },
              child: const Text('Import schedule'),
            ),
          ],
        ),
      ),
    ),
  );
  controller.dispose();
}

class _GoalAction {
  const _GoalAction(this.goal, this.amount);
  final Goal goal;
  final double amount;
}

List<_GoalAction> _goalActions(GoalStore store, DateTime date) {
  final actions = <_GoalAction>[];
  for (final goal in store.goals) {
    if (goal.isTrashed) continue;
    final amount = store.calculator.actionForDate(goal, date);
    if (amount > 0) actions.add(_GoalAction(goal, amount));
  }
  return actions;
}

String _friendlyDate(DateTime date) =>
    '${_weekdayName(date.weekday)}, ${_monthName(date.month)} ${date.day}';
String _shortDate(DateTime date) =>
    '${_monthName(date.month).substring(0, 3)} ${date.day}';
String _time(DateTime date) {
  final hour = date.hour == 0
      ? 12
      : date.hour > 12
      ? date.hour - 12
      : date.hour;
  return '$hour:${date.minute.toString().padLeft(2, '0')} ${date.hour >= 12 ? 'PM' : 'AM'}';
}

String _weekdayName(int day) => const [
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
  'Sunday',
][day - 1];
String _monthName(int month) => const [
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
][month - 1];
bool _sameDate(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;
