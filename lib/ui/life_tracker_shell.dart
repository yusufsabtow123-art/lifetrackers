import 'package:flutter/material.dart';

import '../app/goal_store.dart';
import '../app/life_store.dart';
import '../app/theme_controller.dart';
import '../domain/goal.dart';
import '../domain/life_data.dart';
import '../domain/plan_calculator.dart';
import '../platform/goal_notification_service.dart';
import 'app_theme.dart';
import 'goal_details_sheet.dart';
import 'life_calendar_page.dart';
import 'life_goals_page.dart';
import 'life_icons.dart';
import 'life_quotes.dart';
import 'settings_page.dart';
import 'speech_input_button.dart';

enum _Destination { today, goals, tasks, calendar, spaces, ai, more }

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
          appBar: null,
          body: ColoredBox(
            color: Theme.of(context).scaffoldBackgroundColor,
            child: SafeArea(
              child: Row(
                children: [
                  if (wide) _DesktopNavigation(state: this),
                  Expanded(
                    child: AnimatedSwitcher(
                      duration: MediaQuery.disableAnimationsOf(context)
                          ? Duration.zero
                          : LifeMotion.standard,
                      switchInCurve: LifeMotion.curve,
                      switchOutCurve: Curves.easeInCubic,
                      transitionBuilder: (child, animation) => FadeTransition(
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
          ),
          bottomNavigationBar: wide
              ? null
              : _LifeBottomBar(
                  selectedIndex: switch (_destination) {
                    _Destination.today => 0,
                    _Destination.goals => 1,
                    _Destination.tasks => 2,
                    _Destination.calendar => 3,
                    _ => 4,
                  },
                  onSelected: (index) => setState(() {
                    _destination = switch (index) {
                      0 => _Destination.today,
                      1 => _Destination.goals,
                      2 => _Destination.tasks,
                      3 => _Destination.calendar,
                      _ => _Destination.more,
                    };
                  }),
                ),
        );
      },
    );
  }

  Widget _page() => switch (_destination) {
    _Destination.today => TodayPage(
      goalStore: widget.goalStore,
      lifeStore: widget.lifeStore,
      settings: widget.settings,
    ),
    _Destination.goals => LifeGoalsPage(
      store: widget.goalStore,
      settings: widget.settings,
    ),
    _Destination.tasks => TasksPage(
      goalStore: widget.goalStore,
      lifeStore: widget.lifeStore,
      settings: widget.settings,
    ),
    _Destination.calendar => LifeCalendarPage(
      goalStore: widget.goalStore,
      lifeStore: widget.lifeStore,
      settings: widget.settings,
    ),
    _Destination.spaces => SpacesPage(store: widget.lifeStore),
    _Destination.ai => _AiPage(
      onPlan: () => setState(() => _destination = _Destination.goals),
    ),
    _Destination.more =>
      MediaQuery.sizeOf(context).width >= 820
          ? SettingsPage(
              store: widget.goalStore,
              lifeStore: widget.lifeStore,
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
                      lifeStore: widget.lifeStore,
                      settings: widget.settings,
                      notificationService: widget.notificationService,
                    ),
                  ),
                ),
              ),
            ),
  };

  Future<void> _showSpaces() => Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (context) => SpacesPage(store: widget.lifeStore),
    ),
  );
}

class _LifeBottomBar extends StatelessWidget {
  const _LifeBottomBar({required this.selectedIndex, required this.onSelected});

  final int selectedIndex;
  final ValueChanged<int> onSelected;

  static const _items = <(LifeGlyph, String)>[
    (LifeGlyph.today, 'Today'),
    (LifeGlyph.goals, 'Goals'),
    (LifeGlyph.tasks, 'Tasks'),
    (LifeGlyph.calendar, 'Calendar'),
    (LifeGlyph.more, 'More'),
  ];

  @override
  Widget build(BuildContext context) => SafeArea(
    top: false,
    child: Container(
      height: 66,
      decoration: BoxDecoration(
        color: context.appPanel,
        border: Border(top: BorderSide(color: context.appBorder)),
      ),
      child: Row(
        children: [
          for (var index = 0; index < _items.length; index++)
            Expanded(
              child: Semantics(
                selected: selectedIndex == index,
                button: true,
                label: _items[index].$2,
                child: InkWell(
                  onTap: () => onSelected(index),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      AnimatedScale(
                        scale: selectedIndex == index ? 1.08 : 1,
                        duration: LifeMotion.quick,
                        curve: LifeMotion.curve,
                        child: LifeGlyphIcon(
                          _items[index].$1,
                          size: 22,
                          selected: selectedIndex == index,
                          color: selectedIndex == index
                              ? Theme.of(context).colorScheme.primary
                              : context.appMuted,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _items[index].$2,
                        style: TextStyle(
                          color: selectedIndex == index
                              ? Theme.of(context).colorScheme.primary
                              : context.appMuted,
                          fontSize: 10,
                          fontWeight: selectedIndex == index
                              ? FontWeight.w600
                              : FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    ),
  );
}

class _DesktopNavigation extends StatelessWidget {
  const _DesktopNavigation({required this.state});
  final _LifeTrackerShellState state;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 188,
      decoration: BoxDecoration(
        color: context.appPanel,
        border: Border(right: BorderSide(color: context.appBorder)),
      ),
      padding: const EdgeInsets.fromLTRB(14, 20, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Row(
              children: [
                const LifeMark(size: 18),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    'Life Tracker',
                    style: Theme.of(context).textTheme.titleMedium,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Icon(Icons.edit_square, size: 16, color: context.appMuted),
              ],
            ),
          ),
          const SizedBox(height: 28),
          _NavItem(
            state: state,
            destination: _Destination.today,
            glyph: LifeGlyph.today,
            label: 'Today',
          ),
          _NavItem(
            state: state,
            destination: _Destination.goals,
            glyph: LifeGlyph.goals,
            label: 'Goals',
          ),
          _NavItem(
            state: state,
            destination: _Destination.tasks,
            glyph: LifeGlyph.tasks,
            label: 'Tasks',
          ),
          _NavItem(
            state: state,
            destination: _Destination.calendar,
            glyph: LifeGlyph.calendar,
            label: 'Calendar',
          ),
          _NavItem(
            state: state,
            destination: _Destination.spaces,
            glyph: LifeGlyph.spaces,
            label: 'Spaces',
          ),
          _NavItem(
            state: state,
            destination: _Destination.ai,
            glyph: LifeGlyph.sparkle,
            label: 'AI',
          ),
          const Spacer(),
          _NavItem(
            state: state,
            destination: _Destination.more,
            glyph: LifeGlyph.settings,
            label: 'Settings',
          ),
          Divider(color: context.appBorder, height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(top: 2),
                  child: LifeMark(size: 22),
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    sayingForDay(state.widget.goalStore.today),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: context.appMuted,
                      fontSize: 9.5,
                      height: 1.35,
                    ),
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
    required this.glyph,
    required this.label,
  });
  final _LifeTrackerShellState state;
  final _Destination destination;
  final LifeGlyph glyph;
  final String label;

  @override
  Widget build(BuildContext context) {
    final selected = state._destination == destination;
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: selected
            ? Color.alphaBlend(
                Theme.of(context).colorScheme.primary.withValues(alpha: .08),
                context.appRaised,
              )
            : Colors.transparent,
        borderRadius: BorderRadius.circular(6),
        child: InkWell(
          borderRadius: BorderRadius.circular(6),
          onTap: () => state.selectDestination(destination),
          child: Container(
            decoration: BoxDecoration(
              border: selected
                  ? Border(
                      left: BorderSide(
                        color: Theme.of(context).colorScheme.primary,
                        width: 2,
                      ),
                    )
                  : null,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 9),
            child: Row(
              children: [
                LifeGlyphIcon(
                  glyph,
                  size: 17,
                  selected: selected,
                  color: selected ? context.appText : context.appMuted,
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
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

class TodayPage extends StatelessWidget {
  const TodayPage({
    super.key,
    required this.goalStore,
    required this.lifeStore,
    required this.settings,
  });
  final GoalStore goalStore;
  final LifeStore lifeStore;
  final AppSettingsController settings;

  @override
  Widget build(BuildContext context) {
    final today = goalStore.today;
    final goals = _goalActions(goalStore, today);
    final tasks = lifeStore.tasksFor(today);
    final pendingTasks = tasks.where((task) => !task.isDoneOn(today)).toList();
    final completedTasks = tasks.where((task) => task.isDoneOn(today)).toList();
    final completedGoals = goalStore.goals
        .where((g) => !g.isTrashed && g.completionFor(today) != null)
        .toList();
    final entries = lifeStore.entriesFor(today);
    final remaining = goals.length + pendingTasks.length;
    final completed = completedTasks.length + completedGoals.length;
    final rows = <({int order, String time, Widget child})>[
      for (final action in goals)
        (
          order: action.goal.reminder == null
              ? -1
              : action.goal.reminder!.hour * 60 + action.goal.reminder!.minute,
          time: action.goal.reminder == null
              ? 'Anytime'
              : TimeOfDay(
                  hour: action.goal.reminder!.hour,
                  minute: action.goal.reminder!.minute,
                ).format(context),
          child: _ActionTile(
            icon: Icons.my_location_outlined,
            title: action.goal.name,
            subtitle:
                '${formatAmount(action.amount)} ${action.goal.plan!.unit}',
            done: false,
            onTap: () => showGoalDetailsSheet(
              context,
              goalStore,
              action.goal.id,
              showAbandoned: settings.showAbandoned,
              progressFormat: settings.progressFormat,
              settings: settings,
            ),
            onToggle: () => goalStore.completeTodayAction(action.goal.id),
          ),
        ),
      for (final task in pendingTasks)
        (
          order: task.dueAt == null
              ? -1
              : task.dueAt!.hour * 60 + task.dueAt!.minute,
          time: task.dueAt == null
              ? 'Anytime'
              : TimeOfDay.fromDateTime(task.dueAt!).format(context),
          child: _TaskTile(
            task: task,
            store: lifeStore,
            date: today,
            completionCheckIns: settings.completionCheckIns,
            onOpen: () =>
                _showTaskEditor(context, lifeStore, goalStore, task: task),
          ),
        ),
      for (final entry in entries)
        (
          order: entry.start.hour * 60 + entry.start.minute,
          time: TimeOfDay.fromDateTime(entry.start).format(context),
          child: _CalendarTile(entry: entry, store: lifeStore),
        ),
    ]..sort((a, b) => a.order.compareTo(b.order));
    final wide = MediaQuery.sizeOf(context).width >= 980;
    final nextTitle = goals.isNotEmpty
        ? goals.first.goal.name
        : pendingTasks.isNotEmpty
        ? pendingTasks.first.title
        : 'Enjoy a little breathing room.';
    final ratio = remaining + completed == 0
        ? 0.0
        : completed / (remaining + completed);
    final plan = ListView(
      padding: EdgeInsets.zero,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Daily plan',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
              ),
            ),
            Text(
              '${pendingTasks.length}',
              key: const Key('today-task-count'),
              style: TextStyle(fontSize: 11, color: context.appMuted),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (rows.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Text(
              'Nothing else due today',
              style: TextStyle(color: context.appMuted),
            ),
          ),
        for (final row in rows)
          _TodayTimelineRow(time: row.time, child: row.child),
        if (completed > 0) ...[
          const SizedBox(height: 12),
          _TodayCompleted(
            count: completed,
            children: [
              for (final goal in completedGoals)
                _ActionTile(
                  icon: Icons.my_location_outlined,
                  title: goal.name,
                  subtitle:
                      '${formatAmount(goal.completionFor(today)!.amount)} ${goal.plan?.unit ?? ''}',
                  done: true,
                  onToggle: () => goalStore.undoTodayAction(goal.id),
                ),
              for (final task in completedTasks)
                _TaskTile(
                  task: task,
                  store: lifeStore,
                  date: today,
                  onOpen: () => _showTaskEditor(
                    context,
                    lifeStore,
                    goalStore,
                    task: task,
                  ),
                ),
            ],
          ),
        ],
      ],
    );
    return _PageFrame(
      title: 'Today',
      subtitle: _friendlyDate(today),
      action: wide
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.search_rounded, size: 19, color: context.appMuted),
                const SizedBox(width: 24),
                Text(
                  'A more intentional day',
                  style: TextStyle(fontSize: 11, color: context.appMuted),
                ),
              ],
            )
          : IconButton(
              tooltip: 'Open calendar',
              onPressed: () {},
              icon: const Icon(Icons.calendar_today_outlined, size: 20),
            ),
      child: Column(
        children: [
          _TodayHero(
            progress: ratio,
            title: nextTitle,
            remaining: remaining,
            scheduled: entries.length,
            onSpeak: remaining == 0
                ? null
                : goals.isNotEmpty
                ? () => _showGoalActionCheckIn(
                    context,
                    goalStore,
                    goals.first.goal,
                  )
                : () => _showTaskCompletionCheckIn(
                    context,
                    lifeStore,
                    pendingTasks.first,
                    today,
                  ),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: wide
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(flex: 5, child: plan),
                      const SizedBox(width: 20),
                      SizedBox(
                        width: 310,
                        child: _TodayFocusPanel(
                          progress: ratio,
                          remaining: remaining,
                          scheduled: entries.length,
                          labels: [
                            for (final action in goals) action.goal.name,
                            for (final task in pendingTasks) task.title,
                          ],
                          completed: completed,
                        ),
                      ),
                    ],
                  )
                : plan,
          ),
        ],
      ),
    );
  }
}

class _TodayHero extends StatelessWidget {
  const _TodayHero({
    required this.progress,
    required this.title,
    required this.remaining,
    required this.scheduled,
    required this.onSpeak,
  });
  final double progress;
  final String title;
  final int remaining;
  final int scheduled;
  final VoidCallback? onSpeak;

  @override
  Widget build(BuildContext context) => Container(
    constraints: const BoxConstraints(minHeight: 108),
    padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
    decoration: BoxDecoration(
      gradient: LinearGradient(
        colors: [context.appRaised, context.appPanel],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: context.appBorder),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: context.isDarkMode ? .18 : .06),
          blurRadius: 24,
          offset: const Offset(0, 10),
        ),
      ],
    ),
    child: Row(
      children: [
        _LifeProgressRing(value: progress, size: 62, stroke: 6),
        const SizedBox(width: 22),
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                remaining == 0 ? 'All clear' : 'Next',
                style: TextStyle(fontSize: 12, color: context.appMuted),
              ),
              const SizedBox(height: 4),
              Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -.2,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                '$remaining left · $scheduled scheduled',
                style: TextStyle(fontSize: 11, color: context.appMuted),
              ),
            ],
          ),
        ),
        if (onSpeak != null) ...[
          const SizedBox(width: 14),
          Material(
            color: Theme.of(context).colorScheme.primary,
            shape: const CircleBorder(),
            child: IconButton(
              tooltip: 'Speak about what you completed',
              onPressed: onSpeak,
              color: Theme.of(context).colorScheme.onPrimary,
              icon: const Icon(Icons.mic_none_rounded),
            ),
          ),
        ],
      ],
    ),
  );
}

class _LifeProgressRing extends StatelessWidget {
  const _LifeProgressRing({
    required this.value,
    required this.size,
    required this.stroke,
  });
  final double value;
  final double size;
  final double stroke;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: size,
    height: size,
    child: Stack(
      alignment: Alignment.center,
      children: [
        SizedBox.expand(
          child: CircularProgressIndicator(
            value: value.clamp(0, 1),
            strokeWidth: stroke,
            strokeCap: StrokeCap.round,
            backgroundColor: context.appBorder,
          ),
        ),
        Align(
          alignment: Alignment.topCenter,
          child: Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary,
              shape: BoxShape.circle,
            ),
          ),
        ),
      ],
    ),
  );
}

class _TodayTimelineRow extends StatelessWidget {
  const _TodayTimelineRow({required this.time, required this.child});
  final String time;
  final Widget child;

  @override
  Widget build(BuildContext context) => IntrinsicHeight(
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          width: 58,
          child: Padding(
            padding: const EdgeInsets.only(top: 15),
            child: Text(
              time,
              style: TextStyle(fontSize: 10, color: context.appMuted),
            ),
          ),
        ),
        Stack(
          alignment: Alignment.topCenter,
          children: [
            Container(width: 1, color: context.appBorder),
            Container(
              width: 7,
              height: 7,
              margin: const EdgeInsets.only(top: 17),
              decoration: BoxDecoration(
                color: context.appMuted,
                shape: BoxShape.circle,
              ),
            ),
          ],
        ),
        const SizedBox(width: 12),
        Expanded(child: child),
      ],
    ),
  );
}

class _TodayCompleted extends StatelessWidget {
  const _TodayCompleted({required this.count, required this.children});
  final int count;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => ExpansionTile(
    tilePadding: const EdgeInsets.symmetric(horizontal: 14),
    childrenPadding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
    collapsedBackgroundColor: context.appRaised,
    backgroundColor: context.appPanel,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    collapsedShape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
      side: BorderSide(color: context.appBorder),
    ),
    leading: const Icon(Icons.check_circle, color: Color(0xFF79CB8B), size: 20),
    title: const Text('Completed', style: TextStyle(fontSize: 13)),
    trailing: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('$count', style: TextStyle(fontSize: 11, color: context.appMuted)),
        const SizedBox(width: 8),
        const Icon(Icons.expand_more_rounded, size: 18),
      ],
    ),
    children: children,
  );
}

class _TodayFocusPanel extends StatelessWidget {
  const _TodayFocusPanel({
    required this.progress,
    required this.remaining,
    required this.scheduled,
    required this.labels,
    required this.completed,
  });
  final double progress;
  final int remaining;
  final int scheduled;
  final List<String> labels;
  final int completed;

  @override
  Widget build(BuildContext context) => ListView(
    children: [
      Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: context.appRaised.withValues(alpha: .78),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: context.appBorder),
        ),
        child: Column(
          children: [
            Row(
              children: [
                _LifeProgressRing(value: progress, size: 54, stroke: 5),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Today's focus",
                        style: TextStyle(fontSize: 11, color: context.appMuted),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        '$remaining left · $scheduled scheduled',
                        style: const TextStyle(fontSize: 14),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Divider(color: context.appBorder),
            for (final label in labels.take(4))
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 9),
                child: Row(
                  children: [
                    Icon(
                      Icons.square_outlined,
                      size: 17,
                      color: context.appMuted,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
      if (completed > 0) ...[
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
          decoration: BoxDecoration(
            color: context.appRaised,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: context.appBorder),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.check_circle,
                color: Color(0xFF79CB8B),
                size: 20,
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Completed',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
              ),
              Text(
                '$completed',
                style: TextStyle(fontSize: 11, color: context.appMuted),
              ),
            ],
          ),
        ),
      ],
    ],
  );
}

class TasksPage extends StatefulWidget {
  const TasksPage({
    super.key,
    required this.goalStore,
    required this.lifeStore,
    required this.settings,
  });
  final GoalStore goalStore;
  final LifeStore lifeStore;
  final AppSettingsController settings;

  @override
  State<TasksPage> createState() => _TasksPageState();
}

class _TasksPageState extends State<TasksPage> {
  int _filter = 0;
  bool _showCompleted = true;

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
      subtitle: '',
      action: FilledButton.icon(
        onPressed: () =>
            _showTaskEditor(context, widget.lifeStore, widget.goalStore),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add task'),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _TextTabs(
            labels: const ['Today', 'Upcoming', 'All'],
            selected: _filter,
            onSelected: (value) => setState(() => _filter = value),
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
                      for (final task in tasks.where(
                        (t) => _filter == 0 ? !t.isDoneOn(now) : !t.isCompleted,
                      ))
                        _TaskTile(
                          task: task,
                          date: _filter == 0 ? now : null,
                          store: widget.lifeStore,
                          completionCheckIns:
                              widget.settings.completionCheckIns,
                          onOpen: () => _showTaskEditor(
                            context,
                            widget.lifeStore,
                            widget.goalStore,
                            task: task,
                          ),
                        ),
                      if (tasks.any(
                        (t) => _filter == 0 ? t.isDoneOn(now) : t.isCompleted,
                      )) ...[
                        const SizedBox(height: 12),
                        InkWell(
                          onTap: () =>
                              setState(() => _showCompleted = !_showCompleted),
                          borderRadius: BorderRadius.circular(8),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            child: Row(
                              children: [
                                Icon(
                                  _showCompleted
                                      ? Icons.keyboard_arrow_down
                                      : Icons.chevron_right,
                                  size: 18,
                                ),
                                const SizedBox(width: 8),
                                const Text('Completed'),
                                const Spacer(),
                                Text(
                                  '${tasks.where((t) => _filter == 0 ? t.isDoneOn(now) : t.isCompleted).length}',
                                  style: TextStyle(color: context.appMuted),
                                ),
                              ],
                            ),
                          ),
                        ),
                        if (_showCompleted)
                          for (final task in tasks.where(
                            (t) =>
                                _filter == 0 ? t.isDoneOn(now) : t.isCompleted,
                          ))
                            _TaskTile(
                              task: task,
                              store: widget.lifeStore,
                              date: _filter == 0 ? now : null,
                              completionCheckIns:
                                  widget.settings.completionCheckIns,
                              onOpen: () => _showTaskEditor(
                                context,
                                widget.lifeStore,
                                widget.goalStore,
                                task: task,
                              ),
                            ),
                      ],
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
      final mobile = MediaQuery.sizeOf(context).width < 820;
      final active = store.spaces.firstWhere(
        (space) => space.id == store.activeSpaceId,
      );
      final hasShared = store.spaces.any((space) => space.isShared);
      final assigned = store.tasks
          .where(
            (task) =>
                task.spaceId == active.id &&
                task.assignee.toLowerCase() == 'you' &&
                !task.isCompleted,
          )
          .toList();
      final body = ListView(
        padding: EdgeInsets.zero,
        children: [
          Row(
            children: [
              Expanded(
                child: _TextTabs(
                  labels: const ['Personal Space', 'Shared Spaces'],
                  selected: active.isShared ? 1 : 0,
                  onSelected: (index) {
                    final matches = store.spaces.where(
                      (s) => s.isShared == (index == 1),
                    );
                    if (matches.isEmpty) {
                      _createSharedSpace(context);
                    } else {
                      store.selectSpace(matches.first.id);
                    }
                  },
                ),
              ),
              if (!mobile) ...[
                const SizedBox(width: 12),
                FilledButton.icon(
                  onPressed: () => _createSharedSpace(context),
                  icon: const Icon(Icons.add_rounded, size: 17),
                  label: const Text('Create space'),
                ),
              ],
            ],
          ),
          const SizedBox(height: 14),
          for (final space in store.spaces.where(
            (s) => s.isShared == active.isShared,
          ))
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Material(
                color: context.appRaised.withValues(alpha: .9),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(11),
                  side: BorderSide(color: context.appBorder),
                ),
                borderRadius: BorderRadius.circular(10),
                child: ListTile(
                  leading: Icon(
                    space.isShared ? Icons.group_outlined : Icons.lock_outline,
                    size: 23,
                  ),
                  title: Text(space.name, style: const TextStyle(fontSize: 14)),
                  subtitle: const Text(
                    'Private · On this device',
                    style: TextStyle(fontSize: 11),
                  ),
                  trailing: Icon(
                    space.id == active.id ? Icons.check : Icons.chevron_right,
                    size: 17,
                  ),
                  onTap: () => store.selectSpace(space.id),
                ),
              ),
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
            const Text(
              'Members',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 14),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final member in active.members)
                    SizedBox(
                      width: 76,
                      child: Column(
                        children: [
                          CircleAvatar(
                            radius: 23,
                            backgroundColor: context.appRaised,
                            foregroundColor: context.appText,
                            child: Text(
                              member.name.isEmpty
                                  ? '?'
                                  : member.name[0].toUpperCase(),
                              style: TextStyle(color: context.appText),
                            ),
                          ),
                          const SizedBox(height: 7),
                          Text(
                            member.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 12),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            member.role.label,
                            style: TextStyle(
                              fontSize: 10,
                              color: context.appMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  SizedBox(
                    width: 76,
                    child: Column(
                      children: [
                        IconButton.outlined(
                          onPressed: () => _addMember(context),
                          icon: const Icon(Icons.add, size: 21),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Add member',
                          style: TextStyle(fontSize: 10),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (assigned.isNotEmpty) ...[
              const SizedBox(height: 22),
              Text(
                'Assigned to you',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 10),
              for (final task in assigned)
                _SurfaceTile(
                  icon: Icons.check_circle_outline_rounded,
                  title: task.title,
                  subtitle: task.dueAt == null
                      ? 'No date'
                      : _shortDate(task.dueAt!),
                ),
            ],
          ],
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: context.appRaised.withValues(alpha: .66),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: context.appBorder),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.lock_outline_rounded,
                  size: 18,
                  color: context.appMuted,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Spaces are private and stored on this device. Online invitations and syncing are not available yet.',
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: context.appMuted),
                  ),
                ),
              ],
            ),
          ),
        ],
      );
      if (mobile) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('Spaces'),
            centerTitle: false,
            actions: [
              IconButton(
                tooltip: 'Create space',
                onPressed: () => _createSharedSpace(context),
                icon: const Icon(Icons.add_rounded),
              ),
            ],
          ),
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              child: body,
            ),
          ),
        );
      }
      return _PageFrame(
        title: 'Spaces',
        subtitle: 'Keep life organized. Share what matters.',
        child: Align(
          alignment: Alignment.topLeft,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: body,
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
        const _GroupLabel('SPACES'),
        _SurfaceTile(
          icon: Icons.group_outlined,
          title: 'Spaces and people',
          subtitle: 'Personal and Shared Space',
          onTap: onSpaces,
        ),
        const SizedBox(height: 22),
        const _GroupLabel('TOOLS'),
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
        const SizedBox(height: 22),
        const _GroupLabel('YOUR DATA'),
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
  const _AiPage({required this.onPlan});
  final VoidCallback onPlan;
  @override
  Widget build(BuildContext context) => _PageFrame(
    title: 'AI',
    subtitle: '',
    child: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 330),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 98,
              height: 92,
              child: Stack(
                children: [
                  Positioned(
                    left: 8,
                    top: 10,
                    child: Icon(
                      Icons.subject_outlined,
                      size: 70,
                      color: context.appMuted,
                    ),
                  ),
                  const Positioned(
                    right: 0,
                    bottom: 0,
                    child: LifeMark(size: 40),
                  ),
                  Positioned(
                    right: 0,
                    top: 4,
                    child: LifeGlyphIcon(
                      LifeGlyph.sparkle,
                      size: 20,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Work in progress',
              style: TextStyle(fontSize: 21, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 16),
            Text(
              'In the future, AI can suggest a goal plan, tasks and a calendar schedule.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                height: 1.65,
                color: context.appMuted,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'You can still plan manually anytime.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: context.appMuted),
            ),
            const SizedBox(height: 28),
            FilledButton(onPressed: onPlan, child: const Text('Plan manually')),
          ],
        ),
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
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.displaySmall,
                    ),
                    if (subtitle.isNotEmpty) const SizedBox(height: 5),
                    if (subtitle.isNotEmpty)
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

class _GroupLabel extends StatelessWidget {
  const _GroupLabel(this.label);
  final String label;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
    child: Text(
      label,
      style: TextStyle(
        color: context.appMuted,
        fontSize: 10,
        fontWeight: FontWeight.w700,
        letterSpacing: .9,
      ),
    ),
  );
}

class _TextTabs extends StatelessWidget {
  const _TextTabs({
    required this.labels,
    required this.selected,
    required this.onSelected,
  });
  final List<String> labels;
  final int selected;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(borderRadius: BorderRadius.circular(12)),
    child: Wrap(
      runSpacing: 6,
      children: [
        for (var index = 0; index < labels.length; index++)
          InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: () => onSelected(index),
            child: AnimatedContainer(
              duration: MediaQuery.disableAnimationsOf(context)
                  ? Duration.zero
                  : const Duration(milliseconds: 160),
              margin: const EdgeInsets.only(right: 6),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
              decoration: BoxDecoration(
                color: selected == index
                    ? context.appRaised
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: selected == index
                      ? context.appBorder
                      : context.appBorder.withValues(alpha: .45),
                ),
              ),
              child: Text(
                labels[index],
                style: TextStyle(
                  fontSize: 12,
                  color: selected == index ? context.appText : context.appMuted,
                  fontWeight: selected == index
                      ? FontWeight.w600
                      : FontWeight.w400,
                ),
              ),
            ),
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
    this.onTap,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.zero,
    child: Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: context.appBorder)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 13),
          child: Row(
            children: [
              Icon(icon, size: 18, color: context.appMuted),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(fontWeight: FontWeight.w600),
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
              if (onTap != null) const Icon(Icons.chevron_right_rounded),
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
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Material(
      color: context.appRaised.withValues(alpha: .86),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(9),
        side: BorderSide(color: context.appBorder.withValues(alpha: .82)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(2, 5, 10, 5),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              IconButton(
                tooltip: done ? 'Mark incomplete' : 'Complete',
                onPressed: onToggle,
                icon: Icon(
                  done ? Icons.check_circle : Icons.circle_outlined,
                  size: 22,
                  color: done ? const Color(0xFF74D786) : context.appText,
                ),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 12.5,
                          height: 1.25,
                          fontWeight: FontWeight.w500,
                          color: done ? context.appMuted : context.appText,
                        ),
                      ),
                      if (subtitle.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(icon, size: 13, color: context.appMuted),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                subtitle,
                                style: TextStyle(
                                  fontSize: 10,
                                  height: 1.25,
                                  color: context.appMuted,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              if (onTap != null)
                Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: Icon(
                    Icons.chevron_right,
                    size: 17,
                    color: context.appMuted,
                  ),
                ),
            ],
          ),
        ),
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
    this.completionCheckIns = false,
  });
  final LifeTask task;
  final LifeStore store;
  final DateTime? date;
  final VoidCallback? onOpen;
  final bool completionCheckIns;
  @override
  Widget build(BuildContext context) {
    final details = <String>[
      if (task.dueAt != null)
        '${_shortDate(task.dueAt!)} · ${TimeOfDay.fromDateTime(task.dueAt!).format(context)}',
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
        onToggle: () {
          final taskDate = date ?? task.dueAt ?? DateTime.now();
          final done = date == null ? task.isCompleted : task.isDoneOn(date!);
          if (done) {
            if (date == null) {
              store.toggleTask(task);
            } else {
              store.toggleTaskForDate(task, date!);
            }
            return;
          }
          if (completionCheckIns) {
            store.completeTaskForDate(task, taskDate);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text('Task finished'),
                action: SnackBarAction(
                  label: 'Add progress note',
                  onPressed: () => _showTaskCompletionCheckIn(
                    context,
                    store,
                    task,
                    taskDate,
                  ),
                ),
              ),
            );
            return;
          }
          store.completeTaskForDate(task, taskDate);
        },
      ),
    );
  }
}

Future<void> _showTaskCompletionCheckIn(
  BuildContext context,
  LifeStore store,
  LifeTask task,
  DateTime day,
) async {
  final note = TextEditingController(
    text: task.completionNoteFor(day)?.text ?? '',
  );
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (context) => Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        2,
        20,
        MediaQuery.viewInsetsOf(context).bottom + 22,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: context.appSoftGreen,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.check_rounded, color: context.appSuccess),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Task finished',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    Text(
                      task.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            'How did you do it?',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 4),
          Text(
            'Optional. Keep a useful record of what worked.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 10),
          TextField(
            key: const Key('task-completion-note'),
            controller: note,
            autofocus: true,
            minLines: 3,
            maxLines: 6,
            decoration: InputDecoration(
              hintText: 'Add a progress note…',
              suffixIcon: SpeechInputButton(controller: note),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    store.completeTaskForDate(task, day);
                    Navigator.pop(context);
                  },
                  child: const Text('Done without note'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton(
                  onPressed: () {
                    store.completeTaskForDate(task, day, note: note.text);
                    Navigator.pop(context);
                  },
                  child: const Text('Save note'),
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );
  await Future<void>.delayed(const Duration(milliseconds: 300));
  note.dispose();
}

Future<void> _showGoalActionCheckIn(
  BuildContext context,
  GoalStore store,
  Goal goal,
) async {
  final note = TextEditingController();
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (context) => Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        2,
        20,
        MediaQuery.viewInsetsOf(context).bottom + 22,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Finish today\'s action',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 4),
          Text(
            goal.name,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: context.appMuted),
          ),
          const SizedBox(height: 18),
          TextField(
            key: const Key('goal-completion-note'),
            controller: note,
            autofocus: true,
            minLines: 3,
            maxLines: 6,
            decoration: InputDecoration(
              labelText: 'How did you do it? (optional)',
              hintText: 'Speak or type a useful progress note…',
              suffixIcon: SpeechInputButton(controller: note),
            ),
          ),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: () {
              store.completeTodayAction(goal.id, note: note.text);
              Navigator.pop(context);
            },
            icon: const Icon(Icons.check_rounded),
            label: const Text('Complete and save'),
          ),
        ],
      ),
    ),
  );
  await Future<void>.delayed(const Duration(milliseconds: 300));
  note.dispose();
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
}) {
  ScaffoldMessenger.of(context).hideCurrentSnackBar();
  return Navigator.of(context).push<void>(
    MaterialPageRoute(
      builder: (_) => _TaskEditor(store: store, goals: goals, task: task),
    ),
  );
}

class _TaskEditor extends StatefulWidget {
  const _TaskEditor({required this.store, required this.goals, this.task});
  final LifeStore store;
  final GoalStore goals;
  final LifeTask? task;
  @override
  State<_TaskEditor> createState() => _TaskEditorState();
}

class _TaskEditorState extends State<_TaskEditor> {
  late final _title = TextEditingController(text: widget.task?.title ?? '');
  late final _notes = TextEditingController(text: widget.task?.notes ?? '');
  late final _location = TextEditingController(
    text: widget.task?.location ?? '',
  );
  late DateTime _due = widget.task?.dueAt ?? widget.goals.today;
  late bool _hasDate = widget.task == null || widget.task!.dueAt != null;
  late TaskRepeat _repeat = widget.task?.repeat ?? TaskRepeat.none;
  late String? _goalId = widget.task?.goalId;
  late String _assignee = widget.task?.assignee ?? '';
  bool _saving = false;
  String? _error;
  @override
  void dispose() {
    _title.dispose();
    _notes.dispose();
    _location.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    if (_title.text.trim().isEmpty) {
      setState(() => _error = 'Give the task a title.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      if (widget.task == null) {
        await widget.store.addTask(
          title: _title.text,
          notes: _notes.text,
          dueAt: _hasDate ? _due : null,
          repeat: _repeat,
          goalId: _goalId,
          location: _location.text,
          assignee: _assignee,
        );
      } else {
        await widget.store.updateTask(
          widget.task!.copyWith(
            title: _title.text.trim(),
            notes: _notes.text.trim(),
            dueAt: _hasDate ? _due : null,
            clearDue: !_hasDate,
            repeat: _repeat,
            goalId: _goalId,
            clearGoal: _goalId == null,
            location: _location.text.trim(),
            assignee: _assignee,
          ),
        );
      }
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = 'Could not save. Please try again.';
        });
      }
    }
  }

  Widget _label(String text) => Padding(
    padding: const EdgeInsets.only(top: 20, bottom: 8),
    child: Text(text, style: TextStyle(fontSize: 12, color: context.appMuted)),
  );

  @override
  Widget build(BuildContext context) {
    final space = widget.store.spaces.firstWhere(
      (s) => s.id == (widget.task?.spaceId ?? widget.store.activeSpaceId),
    );
    final availableGoals = widget.goals.goals
        .where((g) => !g.isTrashed || g.id == _goalId)
        .toList();
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.task == null ? 'Add task' : 'Edit task',
          style: const TextStyle(fontSize: 16),
        ),
      ),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
              children: [
                _label('Title'),
                TextField(
                  key: const Key('task-title-field'),
                  controller: _title,
                  decoration: const InputDecoration(
                    hintText: 'What needs to be done?',
                  ),
                ),
                _label('Date and time'),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          final date = await showDatePicker(
                            context: context,
                            firstDate: DateTime(2020),
                            lastDate: DateTime(2100),
                            initialDate: _due,
                          );
                          if (date != null && mounted) {
                            _hasDate = true;
                            setState(
                              () => _due = DateTime(
                                date.year,
                                date.month,
                                date.day,
                                _due.hour,
                                _due.minute,
                              ),
                            );
                          }
                        },
                        icon: const Icon(
                          Icons.calendar_today_outlined,
                          size: 17,
                        ),
                        label: Text(_hasDate ? _shortDate(_due) : 'No date'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        key: const Key('task-time-button'),
                        onPressed: () async {
                          final time = await showTimePicker(
                            context: context,
                            initialTime: TimeOfDay.fromDateTime(_due),
                          );
                          if (time != null && mounted) {
                            _hasDate = true;
                            setState(
                              () => _due = DateTime(
                                _due.year,
                                _due.month,
                                _due.day,
                                time.hour,
                                time.minute,
                              ),
                            );
                          }
                        },
                        icon: const Icon(Icons.schedule, size: 17),
                        label: Text(
                          TimeOfDay.fromDateTime(_due).format(context),
                        ),
                      ),
                    ),
                  ],
                ),
                _label('Repeat'),
                DropdownButtonFormField<TaskRepeat>(
                  initialValue: _repeat,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.repeat, size: 18),
                  ),
                  items: [
                    for (final r in TaskRepeat.values)
                      DropdownMenuItem(value: r, child: Text(r.label)),
                  ],
                  onChanged: (v) =>
                      setState(() => _repeat = v ?? TaskRepeat.none),
                ),
                _label('Linked goal'),
                DropdownButtonFormField<String?>(
                  initialValue: availableGoals.any((g) => g.id == _goalId)
                      ? _goalId
                      : null,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.my_location_outlined, size: 18),
                  ),
                  items: [
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text('No connected goal'),
                    ),
                    for (final g in availableGoals)
                      DropdownMenuItem(
                        value: g.id,
                        child: Text(g.name, overflow: TextOverflow.ellipsis),
                      ),
                  ],
                  onChanged: (v) => setState(() => _goalId = v),
                ),
                _label('Location'),
                TextField(
                  controller: _location,
                  decoration: const InputDecoration(
                    hintText: 'Add location',
                    prefixIcon: Icon(Icons.location_on_outlined, size: 18),
                  ),
                ),
                if (space.isShared) ...[
                  _label('Assigned to'),
                  DropdownButtonFormField<String>(
                    initialValue: _assignee,
                    isExpanded: true,
                    items: [
                      const DropdownMenuItem(
                        value: '',
                        child: Text('Unassigned'),
                      ),
                      for (final name in {
                        ...space.members.map((m) => m.name),
                        if (_assignee.isNotEmpty) _assignee,
                      })
                        DropdownMenuItem(value: name, child: Text(name)),
                    ],
                    onChanged: (v) => setState(() => _assignee = v ?? ''),
                  ),
                ],
                _label('Notes'),
                TextField(
                  controller: _notes,
                  minLines: 3,
                  maxLines: 6,
                  decoration: InputDecoration(
                    hintText: 'Add a note…',
                    suffixIcon: SpeechInputButton(controller: _notes),
                  ),
                ),
                if (widget.task != null &&
                    widget.task!.completionNotes.isNotEmpty) ...[
                  _label('Progress notes'),
                  for (final note in widget.task!.completionNotes)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text(note.text),
                    ),
                ],
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: Text(
                      _error!,
                      style: TextStyle(color: context.appDangerText),
                    ),
                  ),
                const SizedBox(height: 24),
                FilledButton(
                  key: const Key('task-save-button'),
                  onPressed: _saving ? null : _save,
                  child: Text(_saving ? 'Saving…' : 'Save'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
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
