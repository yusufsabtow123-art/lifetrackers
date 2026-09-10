import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app/goal_store.dart';
import '../app/life_store.dart';
import '../app/theme_controller.dart';
import '../domain/goal.dart';
import '../domain/life_data.dart';
import '../domain/plan_calculator.dart';
import 'app_theme.dart';

enum _CalendarView { schedule, day, threeDays, week, month }

class LifeCalendarPage extends StatefulWidget {
  const LifeCalendarPage({
    super.key,
    required this.goalStore,
    required this.lifeStore,
    this.settings,
  });

  final GoalStore goalStore;
  final LifeStore lifeStore;
  final AppSettingsController? settings;

  @override
  State<LifeCalendarPage> createState() => _LifeCalendarPageState();
}

class _LifeCalendarPageState extends State<LifeCalendarPage> {
  static const _hourHeight = 36.0;

  late DateTime _selected = widget.goalStore.today;
  late DateTime _month = DateTime(_selected.year, _selected.month);
  late final ScrollController _timelineController = ScrollController(
    // Start early enough to reveal seasonal Fajr while retaining the complete
    // midnight-to-midnight grid above and below.
    initialScrollOffset: 4 * _hourHeight - 16,
  );
  _CalendarView _view = _CalendarView.week;
  bool _mobileViewExplicit = false;

  @override
  void dispose() {
    _timelineController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mobile = MediaQuery.sizeOf(context).width < 820;
    final effectiveView =
        mobile && !_mobileViewExplicit && _view == _CalendarView.week
        ? _CalendarView.day
        : _view;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        mobile ? 14 : 24,
        mobile ? 16 : 22,
        mobile ? 14 : 24,
        12,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (mobile)
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Calendar',
                    style: Theme.of(context).textTheme.displaySmall,
                  ),
                ),
                IconButton(
                  tooltip: effectiveView == _CalendarView.month
                      ? 'Day'
                      : 'Month',
                  onPressed: () => setState(() {
                    _mobileViewExplicit = true;
                    _view = effectiveView == _CalendarView.month
                        ? _CalendarView.day
                        : _CalendarView.month;
                  }),
                  icon: const Icon(Icons.calendar_today_outlined, size: 20),
                ),
                PopupMenuButton<String>(
                  tooltip: 'Calendar options',
                  onSelected: (value) {
                    if (value == 'today') {
                      setState(() {
                        _selected = widget.goalStore.today;
                        _month = DateTime(_selected.year, _selected.month);
                        _view = mobile ? _CalendarView.day : _CalendarView.week;
                      });
                    }
                    if (value == 'blocks') {
                      widget.lifeStore.setShowBlockedTimes(
                        !widget.lifeStore.data.showBlockedTimes,
                      );
                    }
                    if (value == 'import') _openImport();
                    if (value.startsWith('view:')) {
                      final name = value.substring(5);
                      setState(() {
                        _mobileViewExplicit = true;
                        _view = _CalendarView.values.firstWhere(
                          (item) => item.name == name,
                        );
                      });
                    }
                  },
                  itemBuilder: (_) => [
                    const PopupMenuItem(
                      value: 'today',
                      child: Text('Go to today'),
                    ),
                    PopupMenuItem(
                      value: 'blocks',
                      child: Text(
                        widget.lifeStore.data.showBlockedTimes
                            ? widget.settings?.salahEnabled == true
                                  ? 'Hide other blocked times'
                                  : 'Hide blocked times'
                            : widget.settings?.salahEnabled == true
                            ? 'Show other blocked times'
                            : 'Show blocked times',
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'import',
                      child: Text('Import changing blocked times'),
                    ),
                    const PopupMenuDivider(),
                    for (final view in _CalendarView.values)
                      PopupMenuItem(
                        value: 'view:${view.name}',
                        child: Text(_calendarViewLabel(view)),
                      ),
                  ],
                  icon: const Icon(Icons.more_vert, size: 20),
                ),
              ],
            )
          else
            _CalendarHeader(
              selected: _selected,
              view: _view,
              onViewChanged: (value) => setState(() => _view = value),
              onToday: () => setState(() {
                _selected = widget.goalStore.today;
                _month = DateTime(_selected.year, _selected.month);
                _view = _CalendarView.week;
              }),
              onAdd: () => _openEditor(_selected),
              onImport: _openImport,
            ),
          const SizedBox(height: 6),
          if (!mobile)
            Row(
              children: [
                _ViewSelector(
                  value: _view,
                  onChanged: (v) => setState(() => _view = v),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _BlockedTimesControl(
                    store: widget.lifeStore,
                    salahEnabled: widget.settings?.salahEnabled == true,
                  ),
                ),
              ],
            ),
          const SizedBox(height: 10),
          Expanded(
            child: Stack(
              children: [
                Positioned.fill(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 180),
                    child: switch (effectiveView) {
                      _CalendarView.schedule => _buildScheduleView(),
                      _CalendarView.week => _buildWeekView(),
                      _CalendarView.threeDays => _buildThreeDayView(),
                      _CalendarView.day => _buildDayView(),
                      _CalendarView.month => _buildMonthView(),
                    },
                  ),
                ),
                if (mobile)
                  Positioned(
                    right: 12,
                    bottom: 12,
                    child: FloatingActionButton(
                      key: const Key('calendar-floating-add-button'),
                      tooltip: 'Add to calendar',
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Theme.of(context).colorScheme.onPrimary,
                      shape: const CircleBorder(),
                      onPressed: () => _openEditor(_selected),
                      child: const Icon(Icons.add_rounded),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDayView() => Column(
    key: const ValueKey('calendar-day-view'),
    children: [
      _WeekStrip(
        selected: _selected,
        today: widget.goalStore.today,
        lifeStore: widget.lifeStore,
        goalStore: widget.goalStore,
        onSelect: (date) => setState(() {
          _selected = date;
          _month = DateTime(date.year, date.month);
        }),
        onPrevious: () => setState(() {
          _selected = _selected.subtract(const Duration(days: 7));
          _month = DateTime(_selected.year, _selected.month);
        }),
        onNext: () => setState(() {
          _selected = _selected.add(const Duration(days: 7));
          _month = DateTime(_selected.year, _selected.month);
        }),
      ),
      const SizedBox(height: 10),
      Expanded(
        child: _DaySchedule(
          key: const Key('calendar-day-timeline'),
          date: _selected,
          goalStore: widget.goalStore,
          lifeStore: widget.lifeStore,
          scrollController: _timelineController,
          hourHeight: _hourHeight,
          onAddAt: (start, end) =>
              _openEditor(_selected, initialTime: start, initialEndTime: end),
          onOpenEntry: (entry) => _openEditor(_selected, entry: entry),
          completionCheckIns: widget.settings?.completionCheckIns ?? true,
        ),
      ),
    ],
  );

  Widget _buildWeekView() => _WeekSchedule(
    key: const ValueKey('calendar-week-view'),
    selected: _selected,
    today: widget.goalStore.today,
    goalStore: widget.goalStore,
    lifeStore: widget.lifeStore,
    scrollController: _timelineController,
    hourHeight: _hourHeight,
    completionCheckIns: widget.settings?.completionCheckIns ?? true,
    onSelect: (date) => setState(() {
      _selected = date;
      _month = DateTime(date.year, date.month);
    }),
    onAddAt: (date, start, end) =>
        _openEditor(date, initialTime: start, initialEndTime: end),
    onOpenEntry: (date, entry) => _openEditor(date, entry: entry),
  );

  Widget _buildThreeDayView() => _WeekSchedule(
    key: const ValueKey('calendar-three-day-view'),
    selected: _selected,
    today: widget.goalStore.today,
    goalStore: widget.goalStore,
    lifeStore: widget.lifeStore,
    scrollController: _timelineController,
    hourHeight: _hourHeight,
    dayCount: 3,
    completionCheckIns: widget.settings?.completionCheckIns ?? true,
    onSelect: (date) => setState(() {
      _selected = date;
      _month = DateTime(date.year, date.month);
    }),
    onAddAt: (date, start, end) =>
        _openEditor(date, initialTime: start, initialEndTime: end),
    onOpenEntry: (date, entry) => _openEditor(date, entry: entry),
  );

  Widget _buildScheduleView() => _ScheduleAgenda(
    key: const ValueKey('calendar-schedule-view'),
    start: _selected,
    goalStore: widget.goalStore,
    lifeStore: widget.lifeStore,
    onOpenEntry: (date, entry) => _openEditor(date, entry: entry),
    onSelectDay: (date) => setState(() {
      _selected = date;
      _month = DateTime(date.year, date.month);
      _view = _CalendarView.day;
    }),
  );

  Widget _buildMonthView() => _MonthOverview(
    key: const ValueKey('calendar-month-view'),
    month: _month,
    selected: _selected,
    goalStore: widget.goalStore,
    lifeStore: widget.lifeStore,
    onPrevious: () => setState(() {
      _month = DateTime(_month.year, _month.month - 1);
    }),
    onNext: () => setState(() {
      _month = DateTime(_month.year, _month.month + 1);
    }),
    onSelect: (date) => setState(() {
      _selected = date;
      _month = DateTime(date.year, date.month);
      _view = MediaQuery.sizeOf(context).width < 820
          ? _CalendarView.day
          : _CalendarView.week;
    }),
  );

  Future<void> _openEditor(
    DateTime date, {
    CalendarEntry? entry,
    TimeOfDay? initialTime,
    TimeOfDay? initialEndTime,
  }) {
    if (entry?.id.startsWith('salah-') ?? false) return Future.value();
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => _CalendarEditorSheet(
        store: widget.lifeStore,
        initialDate: date,
        entry: entry,
        initialTime: initialTime,
        initialEndTime: initialEndTime,
      ),
    );
  }

  Future<void> _openImport() => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => _ScheduleImportSheet(store: widget.lifeStore),
  );
}

class _CalendarHeader extends StatelessWidget {
  const _CalendarHeader({
    required this.selected,
    required this.view,
    required this.onViewChanged,
    required this.onToday,
    required this.onAdd,
    required this.onImport,
  });

  final DateTime selected;
  final _CalendarView view;
  final ValueChanged<_CalendarView> onViewChanged;
  final VoidCallback onToday;
  final VoidCallback onAdd;
  final VoidCallback onImport;

  @override
  Widget build(BuildContext context) {
    final narrow = MediaQuery.sizeOf(context).width < 520;
    final title = Text(
      'Calendar',
      style: Theme.of(context).textTheme.displaySmall,
    );
    final actions = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        TextButton(onPressed: onToday, child: const Text('Today')),
        IconButton(
          tooltip: 'Import changing blocked times',
          onPressed: onImport,
          icon: const Icon(Icons.playlist_add_rounded),
        ),
        if (!narrow) ...[
          const SizedBox(width: 4),
          FilledButton.icon(
            key: const Key('calendar-add-button'),
            onPressed: onAdd,
            icon: const Icon(Icons.add_rounded, size: 19),
            label: const Text('Add'),
          ),
        ],
      ],
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (narrow) ...[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: title),
              actions,
            ],
          ),
        ] else
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: title),
              actions,
            ],
          ),
      ],
    );
  }
}

class _ViewSelector extends StatelessWidget {
  const _ViewSelector({required this.value, required this.onChanged});
  final _CalendarView value;
  final ValueChanged<_CalendarView> onChanged;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(3),
    decoration: BoxDecoration(
      color: context.appPanel,
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: context.appBorder),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _ViewButton(
          label: 'Schedule',
          icon: Icons.view_agenda_outlined,
          selected: value == _CalendarView.schedule,
          onTap: () => onChanged(_CalendarView.schedule),
        ),
        _ViewButton(
          label: 'Day',
          icon: Icons.view_day_outlined,
          selected: value == _CalendarView.day,
          onTap: () => onChanged(_CalendarView.day),
        ),
        _ViewButton(
          label: '3 days',
          icon: Icons.view_week_outlined,
          selected: value == _CalendarView.threeDays,
          onTap: () => onChanged(_CalendarView.threeDays),
        ),
        _ViewButton(
          label: 'Week',
          icon: Icons.calendar_view_week_outlined,
          selected: value == _CalendarView.week,
          onTap: () => onChanged(_CalendarView.week),
        ),
        _ViewButton(
          label: 'Month',
          icon: Icons.calendar_view_month_outlined,
          selected: value == _CalendarView.month,
          onTap: () => onChanged(_CalendarView.month),
        ),
      ],
    ),
  );
}

class _ViewButton extends StatelessWidget {
  const _ViewButton({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(6),
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: selected ? context.appRaised : Colors.transparent,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: selected ? null : context.appMuted),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              color: selected ? null : context.appMuted,
            ),
          ),
        ],
      ),
    ),
  );
}

class _BlockedTimesControl extends StatelessWidget {
  const _BlockedTimesControl({required this.store, required this.salahEnabled});
  final LifeStore store;
  final bool salahEnabled;

  @override
  Widget build(BuildContext context) => Container(
    height: 42,
    padding: const EdgeInsets.only(left: 12, right: 4),
    decoration: BoxDecoration(
      color: context.appPanel,
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: context.appBorder),
    ),
    child: Row(
      children: [
        Icon(Icons.block_outlined, size: 17, color: context.appMuted),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            store.data.showBlockedTimes
                ? salahEnabled
                      ? 'Other blocked times'
                      : 'Blocked times'
                : salahEnabled
                ? 'Other blocks hidden'
                : 'Blocks hidden',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
        Switch(
          value: store.data.showBlockedTimes,
          onChanged: store.setShowBlockedTimes,
        ),
      ],
    ),
  );
}

class _WeekStrip extends StatelessWidget {
  const _WeekStrip({
    required this.selected,
    required this.today,
    required this.lifeStore,
    required this.goalStore,
    required this.onSelect,
    required this.onPrevious,
    required this.onNext,
  });

  final DateTime selected;
  final DateTime today;
  final LifeStore lifeStore;
  final GoalStore goalStore;
  final ValueChanged<DateTime> onSelect;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final weekStart = _dateOnly(
      selected.subtract(Duration(days: selected.weekday - 1)),
    );
    return Container(
      decoration: BoxDecoration(
        color: MediaQuery.sizeOf(context).width < 820
            ? Colors.transparent
            : context.appPanel,
        borderRadius: BorderRadius.circular(8),
        border: MediaQuery.sizeOf(context).width < 820
            ? null
            : Border.all(color: context.appBorder),
      ),
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 6),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                visualDensity: VisualDensity.compact,
                onPressed: onPrevious,
                icon: const Icon(Icons.chevron_left_rounded),
              ),
              Expanded(
                child: Text(
                  '${_monthName(selected.month)} ${selected.year}',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                onPressed: onNext,
                icon: const Icon(Icons.chevron_right_rounded),
              ),
            ],
          ),
          Row(
            children: [
              for (var i = 0; i < 7; i++)
                Expanded(
                  child: _WeekDay(
                    date: weekStart.add(Duration(days: i)),
                    selected: selected,
                    today: today,
                    hasItems:
                        lifeStore
                            .entriesFor(weekStart.add(Duration(days: i)))
                            .isNotEmpty ||
                        lifeStore
                            .tasksFor(weekStart.add(Duration(days: i)))
                            .isNotEmpty ||
                        _goalActions(
                          goalStore,
                          weekStart.add(Duration(days: i)),
                        ).isNotEmpty,
                    onSelect: onSelect,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _WeekDay extends StatelessWidget {
  const _WeekDay({
    required this.date,
    required this.selected,
    required this.today,
    required this.hasItems,
    required this.onSelect,
  });
  final DateTime date;
  final DateTime selected;
  final DateTime today;
  final bool hasItems;
  final ValueChanged<DateTime> onSelect;

  @override
  Widget build(BuildContext context) {
    final active = _sameDate(date, selected);
    final isToday = _sameDate(date, today);
    return InkWell(
      onTap: () => onSelect(date),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Column(
          children: [
            Text(
              _weekdayLetter(date.weekday),
              style: TextStyle(fontSize: 10, color: context.appMuted),
            ),
            const SizedBox(height: 3),
            AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 31,
              height: 31,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: active
                    ? Theme.of(context).colorScheme.primary
                    : Colors.transparent,
                shape: BoxShape.circle,
                border: isToday && !active
                    ? Border.all(color: Theme.of(context).colorScheme.primary)
                    : null,
              ),
              child: Text(
                '${date.day}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: active || isToday
                      ? FontWeight.w800
                      : FontWeight.w500,
                  color: active
                      ? Theme.of(context).colorScheme.onPrimary
                      : null,
                ),
              ),
            ),
            const SizedBox(height: 3),
            Container(
              width: 4,
              height: 4,
              decoration: BoxDecoration(
                color: hasItems
                    ? Theme.of(context).colorScheme.primary
                    : Colors.transparent,
                shape: BoxShape.circle,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ScheduleAgenda extends StatelessWidget {
  const _ScheduleAgenda({
    super.key,
    required this.start,
    required this.goalStore,
    required this.lifeStore,
    required this.onOpenEntry,
    required this.onSelectDay,
  });

  final DateTime start;
  final GoalStore goalStore;
  final LifeStore lifeStore;
  final void Function(DateTime, CalendarEntry) onOpenEntry;
  final ValueChanged<DateTime> onSelectDay;

  @override
  Widget build(BuildContext context) => ListView.builder(
    padding: const EdgeInsets.only(bottom: 88),
    itemCount: 45,
    itemBuilder: (context, index) {
      final day = _dateOnly(start.add(Duration(days: index)));
      final entries = lifeStore.entriesFor(day);
      final tasks = lifeStore.tasksFor(day);
      final goals = _goalActions(goalStore, day);
      if (entries.isEmpty && tasks.isEmpty && goals.isEmpty) {
        return const SizedBox.shrink();
      }
      return Semantics(
        header: true,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              InkWell(
                onTap: () => onSelectDay(day),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    _friendlyDate(day),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              ),
              Container(
                decoration: BoxDecoration(
                  color: context.appPanel,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: context.appBorder),
                ),
                child: Column(
                  children: [
                    for (final entry in entries)
                      ListTile(
                        leading: Container(
                          width: 4,
                          height: 34,
                          decoration: BoxDecoration(
                            color: _calendarEntryColor(context, entry),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        title: Text(entry.title),
                        subtitle: Text(
                          '${TimeOfDay.fromDateTime(entry.occurrenceStart(day)).format(context)} – '
                          '${TimeOfDay.fromDateTime(entry.occurrenceEnd(day)).format(context)}',
                        ),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: entry.id.startsWith('salah-')
                            ? null
                            : () => onOpenEntry(day, entry),
                      ),
                    for (final task in tasks)
                      ListTile(
                        leading: Icon(
                          task.isDoneOn(day)
                              ? Icons.check_circle_rounded
                              : Icons.radio_button_unchecked_rounded,
                          color: task.isDoneOn(day) ? context.appSuccess : null,
                        ),
                        title: Text(task.title),
                        subtitle: const Text('Task'),
                        onTap: () => lifeStore.toggleTaskForDate(task, day),
                      ),
                    for (final action in goals)
                      ListTile(
                        leading: const Icon(Icons.flag_outlined),
                        title: Text(action.goal.name),
                        subtitle: Text(
                          '${formatAmount(action.amount)} ${action.goal.plan!.unit}',
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

class _WeekSchedule extends StatelessWidget {
  const _WeekSchedule({
    super.key,
    required this.selected,
    required this.today,
    required this.goalStore,
    required this.lifeStore,
    required this.scrollController,
    required this.hourHeight,
    required this.completionCheckIns,
    required this.onSelect,
    required this.onAddAt,
    required this.onOpenEntry,
    this.dayCount = 7,
  });

  final DateTime selected;
  final DateTime today;
  final GoalStore goalStore;
  final LifeStore lifeStore;
  final ScrollController scrollController;
  final double hourHeight;
  final bool completionCheckIns;
  final ValueChanged<DateTime> onSelect;
  final void Function(DateTime date, TimeOfDay start, TimeOfDay end) onAddAt;
  final void Function(DateTime date, CalendarEntry entry) onOpenEntry;
  final int dayCount;

  @override
  Widget build(BuildContext context) {
    final weekStart = dayCount == 7
        ? _dateOnly(selected.subtract(Duration(days: selected.weekday - 1)))
        : _dateOnly(selected);
    final days = List.generate(
      dayCount,
      (index) => weekStart.add(Duration(days: index)),
    );
    return Container(
      decoration: BoxDecoration(
        color: context.appPanel,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: context.appBorder),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          SizedBox(
            height: 62,
            child: Row(
              children: [
                SizedBox(
                  width: 56,
                  child: IconButton(
                    tooltip: 'Previous $dayCount days',
                    onPressed: () =>
                        onSelect(selected.subtract(Duration(days: dayCount))),
                    icon: const Icon(Icons.chevron_left_rounded, size: 19),
                  ),
                ),
                for (final day in days)
                  Expanded(
                    child: InkWell(
                      onTap: () => onSelect(day),
                      child: Container(
                        decoration: BoxDecoration(
                          color: _sameDate(day, selected)
                              ? Theme.of(
                                  context,
                                ).colorScheme.primary.withValues(alpha: .075)
                              : null,
                          border: Border(
                            left: BorderSide(color: context.appBorder),
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              _weekdayShort(day.weekday),
                              style: TextStyle(
                                color: _sameDate(day, selected)
                                    ? Theme.of(context).colorScheme.primary
                                    : context.appMuted,
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Container(
                              width: 26,
                              height: 26,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: _sameDate(day, today)
                                    ? Theme.of(context).colorScheme.primary
                                    : Colors.transparent,
                                shape: BoxShape.circle,
                              ),
                              child: Text(
                                '${day.day}',
                                style: TextStyle(
                                  color: _sameDate(day, today)
                                      ? Theme.of(context).colorScheme.onPrimary
                                      : null,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                SizedBox(
                  width: 40,
                  child: IconButton(
                    tooltip: 'Next $dayCount days',
                    onPressed: () =>
                        onSelect(selected.add(Duration(days: dayCount))),
                    icon: const Icon(Icons.chevron_right_rounded, size: 19),
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: context.appBorder),
          Expanded(
            child: Scrollbar(
              controller: scrollController,
              thumbVisibility: true,
              child: SingleChildScrollView(
                controller: scrollController,
                child: SizedBox(
                  height: 24 * hourHeight,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SizedBox(
                        width: 56,
                        child: Stack(
                          children: [
                            for (var hour = 0; hour < 24; hour++)
                              Positioned(
                                top: hour * hourHeight - 7,
                                right: 8,
                                child: Text(
                                  _hourLabel(hour),
                                  style: TextStyle(
                                    color: context.appMuted,
                                    fontSize: 9,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      for (final day in days)
                        Expanded(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: _sameDate(day, selected)
                                  ? Theme.of(context).colorScheme.primary
                                        .withValues(alpha: .018)
                                  : null,
                              border: Border(
                                left: BorderSide(color: context.appBorder),
                              ),
                            ),
                            child: _TimelineCanvas(
                              date: day,
                              entries: lifeStore.entriesFor(day),
                              hourHeight: hourHeight,
                              onAddAt: (start, end) => onAddAt(day, start, end),
                              onOpenEntry: (entry) => onOpenEntry(day, entry),
                            ),
                          ),
                        ),
                      const SizedBox(width: 40),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Divider(height: 1, color: context.appBorder),
          _CalendarDaySummary(
            date: selected,
            goalStore: goalStore,
            lifeStore: lifeStore,
            completionCheckIns: completionCheckIns,
          ),
        ],
      ),
    );
  }
}

class _CalendarDaySummary extends StatelessWidget {
  const _CalendarDaySummary({
    required this.date,
    required this.goalStore,
    required this.lifeStore,
    required this.completionCheckIns,
  });

  final DateTime date;
  final GoalStore goalStore;
  final LifeStore lifeStore;
  final bool completionCheckIns;

  @override
  Widget build(BuildContext context) {
    final goals = _goalActions(goalStore, date);
    final tasks = lifeStore.tasksFor(date);
    return SizedBox(
      height: 94,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            flex: 2,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 11, 12, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${_weekdayName(date.weekday)}, ${_monthName(date.month)} ${date.day} · Daily goals',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 9),
                  Expanded(
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: goals.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 8),
                      itemBuilder: (context, index) {
                        final action = goals[index];
                        return _AllDayItem(
                          icon: Icons.flag_outlined,
                          label:
                              '${action.goal.name} · ${formatAmount(action.amount)} ${action.goal.plan!.unit}',
                          done: action.goal.completionFor(date) != null,
                          onTap: _sameDate(date, goalStore.today)
                              ? () => action.goal.completionFor(date) == null
                                    ? goalStore.completeTodayAction(
                                        action.goal.id,
                                      )
                                    : goalStore.undoTodayAction(action.goal.id)
                              : null,
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
          VerticalDivider(width: 1, color: context.appBorder),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 11, 12, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Tasks (${tasks.where((task) => !task.isDoneOn(date)).length})',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 7),
                  Expanded(
                    child: ListView.builder(
                      itemCount: tasks.length,
                      itemBuilder: (context, index) {
                        final task = tasks[index];
                        return InkWell(
                          onTap: () async {
                            if (task.isDoneOn(date)) {
                              await lifeStore.toggleTaskForDate(task, date);
                            } else {
                              await lifeStore.completeTaskForDate(task, date);
                            }
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 3),
                            child: Row(
                              children: [
                                Icon(
                                  task.isDoneOn(date)
                                      ? Icons.check_box_rounded
                                      : Icons.check_box_outline_blank_rounded,
                                  size: 16,
                                  color: task.isDoneOn(date)
                                      ? const Color(0xFF7FD28A)
                                      : context.appMuted,
                                ),
                                const SizedBox(width: 7),
                                Expanded(
                                  child: Text(
                                    task.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 11),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DaySchedule extends StatelessWidget {
  const _DaySchedule({
    super.key,
    required this.date,
    required this.goalStore,
    required this.lifeStore,
    required this.scrollController,
    required this.hourHeight,
    required this.onAddAt,
    required this.onOpenEntry,
    required this.completionCheckIns,
  });

  final DateTime date;
  final GoalStore goalStore;
  final LifeStore lifeStore;
  final ScrollController scrollController;
  final double hourHeight;
  final _AddTimeRange onAddAt;
  final ValueChanged<CalendarEntry> onOpenEntry;
  final bool completionCheckIns;

  @override
  Widget build(BuildContext context) {
    final goals = _goalActions(goalStore, date);
    final tasks = lifeStore.tasksFor(date);
    final entries = lifeStore.entriesFor(date);
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: MediaQuery.sizeOf(context).width < 820
            ? Colors.transparent
            : context.appPanel,
        borderRadius: BorderRadius.circular(8),
        border: MediaQuery.sizeOf(context).width < 820
            ? null
            : Border.all(color: context.appBorder),
      ),
      child: Column(
        children: [
          _AllDayStrip(
            date: date,
            goals: goals,
            tasks: tasks,
            goalStore: goalStore,
            lifeStore: lifeStore,
            completionCheckIns: completionCheckIns,
          ),
          Divider(color: context.appBorder),
          Expanded(
            child: Scrollbar(
              controller: scrollController,
              thumbVisibility: MediaQuery.sizeOf(context).width >= 820,
              child: SingleChildScrollView(
                controller: scrollController,
                child: SizedBox(
                  height: 24 * hourHeight,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SizedBox(
                        width: 54,
                        child: Stack(
                          children: [
                            for (var hour = 0; hour < 24; hour++)
                              Positioned(
                                top: hour * hourHeight - 7,
                                right: 8,
                                child: Text(
                                  _hourLabel(hour),
                                  style: TextStyle(
                                    color: context.appMuted,
                                    fontSize: 9.5,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: _TimelineCanvas(
                          date: date,
                          entries: entries,
                          hourHeight: hourHeight,
                          onAddAt: onAddAt,
                          onOpenEntry: onOpenEntry,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AllDayStrip extends StatelessWidget {
  const _AllDayStrip({
    required this.date,
    required this.goals,
    required this.tasks,
    required this.goalStore,
    required this.lifeStore,
    required this.completionCheckIns,
  });

  final DateTime date;
  final List<_GoalAction> goals;
  final List<LifeTask> tasks;
  final GoalStore goalStore;
  final LifeStore lifeStore;
  final bool completionCheckIns;

  @override
  Widget build(BuildContext context) {
    final hasItems = goals.isNotEmpty || tasks.isNotEmpty;
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 50, maxHeight: 104),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 54,
            child: Padding(
              padding: const EdgeInsets.only(top: 17, right: 8),
              child: Text(
                'All day',
                textAlign: TextAlign.right,
                style: TextStyle(fontSize: 9.5, color: context.appMuted),
              ),
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(6, 7, 10, 7),
              child: hasItems
                  ? Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final action in goals)
                          _AllDayItem(
                            icon: Icons.flag_outlined,
                            label:
                                '${action.goal.name} · ${formatAmount(action.amount)} ${action.goal.plan!.unit}',
                            done: action.goal.completionFor(date) != null,
                            onTap: _sameDate(date, goalStore.today)
                                ? () => action.goal.completionFor(date) == null
                                      ? goalStore.completeTodayAction(
                                          action.goal.id,
                                        )
                                      : goalStore.undoTodayAction(
                                          action.goal.id,
                                        )
                                : null,
                          ),
                        for (final task in tasks)
                          _AllDayItem(
                            icon: Icons.check_circle_outline_rounded,
                            label: task.title,
                            done: task.isDoneOn(date),
                            onTap: () {
                              if (task.isDoneOn(date)) {
                                lifeStore.toggleTaskForDate(task, date);
                              } else {
                                lifeStore.completeTaskForDate(task, date);
                              }
                            },
                          ),
                      ],
                    )
                  : Padding(
                      padding: const EdgeInsets.symmetric(vertical: 9),
                      child: Text(
                        'No all-day actions',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: context.appMuted,
                        ),
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AllDayItem extends StatelessWidget {
  const _AllDayItem({
    required this.icon,
    required this.label,
    required this.done,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final bool done;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(6),
    child: Container(
      constraints: const BoxConstraints(maxWidth: 280),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: context.appRaised,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: context.appBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: context.appMuted),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 10.5,
                decoration: done ? TextDecoration.lineThrough : null,
                color: done ? context.appMuted : null,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

typedef _AddTimeRange = void Function(TimeOfDay start, TimeOfDay end);

class _TimelineCanvas extends StatefulWidget {
  const _TimelineCanvas({
    required this.date,
    required this.entries,
    required this.hourHeight,
    required this.onAddAt,
    required this.onOpenEntry,
  });
  final DateTime date;
  final List<CalendarEntry> entries;
  final double hourHeight;
  final _AddTimeRange onAddAt;
  final ValueChanged<CalendarEntry> onOpenEntry;

  @override
  State<_TimelineCanvas> createState() => _TimelineCanvasState();
}

class _TimelineCanvasState extends State<_TimelineCanvas> {
  double? _selectionStart;
  double? _selectionEnd;

  int _snappedMinute(double y) =>
      ((y / widget.hourHeight * 60 / 15).round() * 15).clamp(0, 1440);

  TimeOfDay _timeFromMinute(int minute) {
    final safe = minute.clamp(0, 1439);
    return TimeOfDay(hour: safe ~/ 60, minute: safe % 60);
  }

  @override
  Widget build(BuildContext context) {
    final occurrences = _placeOccurrences(widget.entries, widget.date);
    final now = DateTime.now();
    final showNow = _sameDate(now, widget.date);
    return LayoutBuilder(
      builder: (context, constraints) => GestureDetector(
        key: ValueKey(
          'calendar-timeline-${widget.date.year}-${widget.date.month}-${widget.date.day}',
        ),
        behavior: HitTestBehavior.opaque,
        onTapUp: (details) {
          final rawMinutes = details.localPosition.dy / widget.hourHeight * 60;
          final snapped = ((rawMinutes / 15).floor() * 15).clamp(0, 1425);
          widget.onAddAt(
            TimeOfDay(hour: snapped ~/ 60, minute: snapped % 60),
            _timeFromMinute(snapped + 60),
          );
        },
        onLongPressStart: (details) => setState(() {
          _selectionStart = details.localPosition.dy;
          _selectionEnd = details.localPosition.dy + widget.hourHeight;
        }),
        onLongPressMoveUpdate: (details) => setState(() {
          _selectionEnd = details.localPosition.dy;
        }),
        onLongPressEnd: (_) {
          final startY = _selectionStart;
          final endY = _selectionEnd;
          if (startY == null || endY == null) return;
          final first = _snappedMinute(math.min(startY, endY));
          var last = _snappedMinute(math.max(startY, endY));
          if (last <= first) last = math.min(1440, first + 30);
          setState(() {
            _selectionStart = null;
            _selectionEnd = null;
          });
          widget.onAddAt(_timeFromMinute(first), _timeFromMinute(last));
        },
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            for (var hour = 0; hour < 24; hour++)
              Positioned(
                left: 0,
                right: 0,
                top: hour * widget.hourHeight,
                child: Divider(height: 1, color: context.appBorder),
              ),
            for (var hour = 0; hour < 24; hour++)
              Positioned(
                left: 0,
                right: 0,
                top: hour * widget.hourHeight + widget.hourHeight / 2,
                child: Divider(
                  height: 1,
                  color: context.appBorder.withValues(alpha: .35),
                ),
              ),
            for (final occurrence in occurrences)
              _buildEntry(context, constraints.maxWidth, occurrence),
            if (_selectionStart case final start?)
              Positioned(
                left: 4,
                right: 4,
                top: math.min(start, _selectionEnd ?? start),
                height: math.max(20, (start - (_selectionEnd ?? start)).abs()),
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Theme.of(
                        context,
                      ).colorScheme.primary.withValues(alpha: .22),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ),
                ),
              ),
            if (showNow)
              Positioned(
                top: (now.hour * 60 + now.minute) / 60 * widget.hourHeight,
                left: 0,
                right: 0,
                child: Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Color(0xFFE26868),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const Expanded(
                      child: Divider(height: 1, color: Color(0xFFE26868)),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildEntry(
    BuildContext context,
    double width,
    _CalendarOccurrence occurrence,
  ) {
    const gap = 3.0;
    final available = width - 8;
    final laneWidth = available / occurrence.laneCount;
    final left = 4 + occurrence.lane * laneWidth;
    final top = occurrence.startMinute / 60 * widget.hourHeight + 1;
    final height = math.max(
      28.0,
      (occurrence.endMinute - occurrence.startMinute) / 60 * widget.hourHeight -
          2,
    );
    final blocked = occurrence.entry.kind == CalendarEntryKind.blockedTime;
    final color = _calendarEntryColor(context, occurrence.entry);
    return Positioned(
      key: Key('calendar-entry-${occurrence.entry.id}'),
      top: top,
      left: left,
      width: math.max(30, laneWidth - gap),
      height: height,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => widget.onOpenEntry(occurrence.entry),
          borderRadius: BorderRadius.circular(6),
          child: Container(
            padding: const EdgeInsets.fromLTRB(7, 5, 5, 4),
            decoration: BoxDecoration(
              color: Color.alphaBlend(
                color.withValues(alpha: blocked ? .20 : .24),
                context.appPanel,
              ),
              borderRadius: BorderRadius.circular(6),
              border: Border(left: BorderSide(color: color, width: 3)),
            ),
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (blocked)
                  IgnorePointer(
                    child: CustomPaint(
                      painter: _BlockedTimePainter(
                        color: color.withValues(alpha: .18),
                      ),
                    ),
                  ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      occurrence.entry.title,
                      maxLines: height >= 48 ? 2 : 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (height >= 45)
                      Text(
                        '${_time(occurrence.start)}–${_time(occurrence.end)}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 9, color: context.appMuted),
                      ),
                    if (height >= 66 && occurrence.entry.location.isNotEmpty)
                      Text(
                        occurrence.entry.location,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 9, color: context.appMuted),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BlockedTimePainter extends CustomPainter {
  const _BlockedTimePainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1;
    const gap = 8.0;
    for (var x = -size.height; x < size.width; x += gap) {
      canvas.drawLine(
        Offset(x, size.height),
        Offset(x + size.height, 0),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _BlockedTimePainter oldDelegate) =>
      oldDelegate.color != color;
}

class _MonthOverview extends StatelessWidget {
  const _MonthOverview({
    super.key,
    required this.month,
    required this.selected,
    required this.goalStore,
    required this.lifeStore,
    required this.onPrevious,
    required this.onNext,
    required this.onSelect,
  });
  final DateTime month;
  final DateTime selected;
  final GoalStore goalStore;
  final LifeStore lifeStore;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final ValueChanged<DateTime> onSelect;

  @override
  Widget build(BuildContext context) {
    final first = DateTime(month.year, month.month);
    final start = first.subtract(Duration(days: first.weekday - 1));
    return LayoutBuilder(
      builder: (context, constraints) => ListView(
        children: [
          Container(
            decoration: BoxDecoration(
              color: context.appPanel,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: context.appBorder),
            ),
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 12),
            child: Column(
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
                Row(
                  children: [
                    for (final day in const ['M', 'T', 'W', 'T', 'F', 'S', 'S'])
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 7),
                          child: Text(
                            day,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 10,
                              color: context.appMuted,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: 42,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 7,
                    childAspectRatio: 1,
                  ),
                  itemBuilder: (context, index) {
                    final date = start.add(Duration(days: index));
                    return _MonthDayCell(
                      date: date,
                      month: month,
                      selected: selected,
                      hasGoal: _goalActions(goalStore, date).isNotEmpty,
                      hasTask: lifeStore.tasksFor(date).isNotEmpty,
                      entries: lifeStore.entriesFor(date),
                      onTap: onSelect,
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _SelectedDaySummary(
            date: selected,
            goalStore: goalStore,
            lifeStore: lifeStore,
            onSelect: onSelect,
          ),
        ],
      ),
    );
  }
}

class _MonthDayCell extends StatelessWidget {
  const _MonthDayCell({
    required this.date,
    required this.month,
    required this.selected,
    required this.hasGoal,
    required this.hasTask,
    required this.entries,
    required this.onTap,
  });
  final DateTime date;
  final DateTime month;
  final DateTime selected;
  final bool hasGoal;
  final bool hasTask;
  final List<CalendarEntry> entries;
  final ValueChanged<DateTime> onTap;

  @override
  Widget build(BuildContext context) {
    final active = _sameDate(date, selected);
    final muted = date.month != month.month;
    final colors = <Color>[
      if (hasGoal) Theme.of(context).colorScheme.primary,
      if (hasTask) const Color(0xFF55C891),
      ...entries.map((entry) => _calendarEntryColor(context, entry)),
    ];
    final itemCount = (hasGoal ? 1 : 0) + (hasTask ? 1 : 0) + entries.length;
    final occupiedMinutes = entries.fold<int>(0, (total, entry) {
      final start = entry.occurrenceStart(date);
      final end = entry.occurrenceEnd(date);
      return total + math.max(0, end.difference(start).inMinutes);
    });
    final density = (occupiedMinutes / (12 * 60)).clamp(0.0, 1.0);
    return Padding(
      padding: const EdgeInsets.all(2),
      child: InkWell(
        onTap: () => onTap(date),
        borderRadius: BorderRadius.circular(7),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          decoration: BoxDecoration(
            color: active
                ? Theme.of(context).colorScheme.primary.withValues(alpha: .18)
                : context.appRaised.withValues(alpha: .05 + density * .16),
            borderRadius: BorderRadius.circular(7),
            border: active
                ? Border.all(
                    color: Theme.of(
                      context,
                    ).colorScheme.primary.withValues(alpha: .65),
                  )
                : null,
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Positioned(
                top: 5,
                left: 0,
                right: 0,
                child: Text(
                  '${date.day}',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: active ? FontWeight.w800 : FontWeight.w500,
                    color: muted
                        ? context.appMuted.withValues(alpha: .45)
                        : null,
                  ),
                ),
              ),
              if (itemCount > 0)
                Positioned(
                  left: 4,
                  right: 4,
                  bottom: 3,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '$itemCount',
                        semanticsLabel: '$itemCount scheduled items',
                        style: TextStyle(
                          fontSize: 9,
                          height: 1,
                          color: muted ? context.appMuted : context.appText,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 3),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(3),
                        child: Row(
                          children: [
                            for (final color in colors.take(3))
                              Expanded(
                                child: Container(height: 3, color: color),
                              ),
                          ],
                        ),
                      ),
                      if (colors.length > 3)
                        Padding(
                          padding: const EdgeInsets.only(top: 1),
                          child: Container(
                            height: 1,
                            color: context.appMuted.withValues(alpha: .6),
                          ),
                        ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SelectedDaySummary extends StatelessWidget {
  const _SelectedDaySummary({
    required this.date,
    required this.goalStore,
    required this.lifeStore,
    required this.onSelect,
  });
  final DateTime date;
  final GoalStore goalStore;
  final LifeStore lifeStore;
  final ValueChanged<DateTime> onSelect;

  @override
  Widget build(BuildContext context) {
    final entries = lifeStore.entriesFor(date);
    final taskCount = lifeStore.tasksFor(date).length;
    final goalCount = _goalActions(goalStore, date).length;
    return InkWell(
      onTap: () => onSelect(date),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: context.appPanel,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: context.appBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    _friendlyDate(date),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                const Icon(Icons.chevron_right_rounded),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '${entries.length} timed · $taskCount tasks · $goalCount goal actions',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: context.appMuted),
            ),
            for (final entry in entries.take(4)) ...[
              const SizedBox(height: 9),
              Row(
                children: [
                  Container(
                    width: 3,
                    height: 24,
                    color: _calendarEntryColor(context, entry),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      entry.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    _time(entry.occurrenceStart(date)),
                    style: TextStyle(fontSize: 10, color: context.appMuted),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _CalendarEditorSheet extends StatefulWidget {
  const _CalendarEditorSheet({
    required this.store,
    required this.initialDate,
    this.entry,
    this.initialTime,
    this.initialEndTime,
  });
  final LifeStore store;
  final DateTime initialDate;
  final CalendarEntry? entry;
  final TimeOfDay? initialTime;
  final TimeOfDay? initialEndTime;

  @override
  State<_CalendarEditorSheet> createState() => _CalendarEditorSheetState();
}

class _CalendarEditorSheetState extends State<_CalendarEditorSheet> {
  late final TextEditingController _title;
  late final TextEditingController _location;
  late DateTime _date;
  late CalendarEntryKind _kind;
  late CalendarRepeat _repeat;
  late int _repeatInterval;
  late Set<int> _repeatWeekdays;
  DateTime? _repeatUntil;
  late int _colorValue;
  late TimeOfDay _startTime;
  late TimeOfDay _endTime;
  String? _error;

  bool get _editing => widget.entry != null;

  @override
  void initState() {
    super.initState();
    final entry = widget.entry;
    _title = TextEditingController(text: entry?.title ?? '');
    _location = TextEditingController(text: entry?.location ?? '');
    _date = entry == null
        ? _dateOnly(widget.initialDate)
        : _dateOnly(entry.start);
    _kind = entry?.kind ?? CalendarEntryKind.event;
    _repeat = entry?.repeat ?? CalendarRepeat.none;
    _repeatInterval = entry?.repeatInterval ?? 1;
    _repeatWeekdays = {...(entry?.repeatWeekdays ?? const <int>{})};
    _repeatUntil = entry?.repeatUntil;
    _colorValue =
        entry?.colorValue ??
        (entry?.kind == CalendarEntryKind.blockedTime
            ? 0xFFD16A61
            : 0xFF6F72E8);
    _startTime = entry == null
        ? widget.initialTime ?? const TimeOfDay(hour: 9, minute: 0)
        : TimeOfDay.fromDateTime(entry.start);
    if (entry != null) {
      _endTime = TimeOfDay.fromDateTime(entry.end);
    } else if (widget.initialEndTime != null) {
      _endTime = widget.initialEndTime!;
    } else {
      final startMinutes = _startTime.hour * 60 + _startTime.minute + 60;
      _endTime = TimeOfDay(
        hour: (startMinutes ~/ 60) % 24,
        minute: startMinutes % 60,
      );
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _location.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FractionallySizedBox(
    heightFactor: .9,
    child: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620),
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            2,
            20,
            MediaQuery.viewInsetsOf(context).bottom + 18,
          ),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        _editing ? 'Edit calendar item' : 'Add to calendar',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    if (_editing)
                      IconButton(
                        tooltip: 'Delete',
                        onPressed: _delete,
                        icon: const Icon(
                          Icons.delete_outline_rounded,
                          color: Color(0xFFD96A72),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    color: context.appRaised,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: context.appBorder),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: _KindButton(
                          label: 'Event',
                          icon: Icons.event_outlined,
                          selected: _kind == CalendarEntryKind.event,
                          onTap: () =>
                              setState(() => _kind = CalendarEntryKind.event),
                        ),
                      ),
                      Expanded(
                        child: _KindButton(
                          label: 'Blocked time',
                          icon: Icons.block_outlined,
                          selected: _kind == CalendarEntryKind.blockedTime,
                          onTap: () => setState(
                            () => _kind = CalendarEntryKind.blockedTime,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  key: const Key('calendar-title-field'),
                  controller: _title,
                  autofocus: !_editing,
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(
                    labelText: _kind == CalendarEntryKind.blockedTime
                        ? 'What is this time protected for?'
                        : 'Event name',
                  ),
                ),
                const SizedBox(height: 12),
                _CalendarColorField(
                  color: Color(_colorValue),
                  onTap: _pickColor,
                ),
                const SizedBox(height: 12),
                _EditorRow(
                  icon: Icons.calendar_today_outlined,
                  label: 'Date',
                  value: _fullDate(_date),
                  onTap: _pickDate,
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _EditorRow(
                        icon: Icons.schedule_outlined,
                        label: 'Starts',
                        value: _startTime.format(context),
                        onTap: () => _pickTime(start: true),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _EditorRow(
                        icon: Icons.schedule_outlined,
                        label: 'Ends',
                        value: _endTime.format(context),
                        onTap: () => _pickTime(start: false),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<CalendarRepeat>(
                  initialValue: _repeat,
                  decoration: const InputDecoration(
                    labelText: 'Repeat',
                    prefixIcon: Icon(Icons.repeat_rounded),
                  ),
                  items: [
                    for (final repeat in CalendarRepeat.values)
                      DropdownMenuItem(
                        value: repeat,
                        child: Text(repeat.label),
                      ),
                  ],
                  onChanged: (value) =>
                      setState(() => _repeat = value ?? CalendarRepeat.none),
                ),
                if (_repeat != CalendarRepeat.none) ...[
                  const SizedBox(height: 10),
                  _RepeatOptions(
                    repeat: _repeat,
                    interval: _repeatInterval,
                    weekdays: _repeatWeekdays,
                    until: _repeatUntil,
                    onIntervalChanged: (value) =>
                        setState(() => _repeatInterval = value.clamp(1, 99)),
                    onWeekdaysChanged: (value) =>
                        setState(() => _repeatWeekdays = value),
                    onPickUntil: _pickRepeatUntil,
                    onClearUntil: () => setState(() => _repeatUntil = null),
                  ),
                ],
                const SizedBox(height: 12),
                TextField(
                  controller: _location,
                  decoration: const InputDecoration(
                    labelText: 'Location (optional)',
                    prefixIcon: Icon(Icons.location_on_outlined),
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    _error!,
                    style: TextStyle(
                      color: context.appDangerText,
                      fontSize: 12,
                    ),
                  ),
                ],
                const SizedBox(height: 18),
                FilledButton(
                  key: const Key('calendar-save-button'),
                  onPressed: _save,
                  child: Text(_editing ? 'Save changes' : 'Add to calendar'),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );

  Future<void> _pickDate() async {
    final chosen = await showDatePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      initialDate: _date,
    );
    if (chosen != null && mounted) setState(() => _date = chosen);
  }

  Future<void> _pickTime({required bool start}) async {
    final chosen = await showTimePicker(
      context: context,
      initialTime: start ? _startTime : _endTime,
    );
    if (chosen == null || !mounted) return;
    setState(() {
      if (start) {
        _startTime = chosen;
      } else {
        _endTime = chosen;
      }
    });
  }

  Future<void> _pickRepeatUntil() async {
    final chosen = await showDatePicker(
      context: context,
      firstDate: _date,
      lastDate: DateTime(2100),
      initialDate: _repeatUntil ?? _date.add(const Duration(days: 30)),
    );
    if (chosen != null && mounted) setState(() => _repeatUntil = chosen);
  }

  Future<void> _save() async {
    final title = _title.text.trim();
    if (title.isEmpty) {
      setState(() => _error = 'Add a name first.');
      return;
    }
    final start = DateTime(
      _date.year,
      _date.month,
      _date.day,
      _startTime.hour,
      _startTime.minute,
    );
    var end = DateTime(
      _date.year,
      _date.month,
      _date.day,
      _endTime.hour,
      _endTime.minute,
    );
    if (!end.isAfter(start)) end = end.add(const Duration(days: 1));
    final existing = widget.entry;
    if (existing == null) {
      await widget.store.addCalendarEntry(
        title: title,
        start: start,
        end: end,
        kind: _kind,
        location: _location.text,
        repeat: _repeat,
        repeatInterval: _repeatInterval,
        repeatWeekdays: _repeatWeekdays,
        repeatUntil: _repeatUntil,
        colorValue: _colorValue,
      );
    } else {
      await widget.store.updateCalendarEntry(
        existing.copyWith(
          title: title,
          start: start,
          end: end,
          kind: _kind,
          location: _location.text.trim(),
          repeat: _repeat,
          repeatInterval: _repeatInterval,
          repeatWeekdays: _repeatWeekdays,
          repeatUntil: _repeatUntil,
          clearRepeatUntil: _repeatUntil == null,
          colorValue: _colorValue,
        ),
      );
    }
    if (mounted) Navigator.pop(context);
  }

  Future<void> _pickColor() async {
    final chosen = await showDialog<Color>(
      context: context,
      builder: (context) => _CalendarColorDialog(initial: Color(_colorValue)),
    );
    if (chosen != null && mounted) {
      setState(() => _colorValue = chosen.toARGB32());
    }
  }

  Future<void> _delete() async {
    final entry = widget.entry;
    if (entry == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete this calendar item?'),
        content: Text('“${entry.title}” will be removed.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await widget.store.deleteCalendarEntry(entry);
    if (mounted) Navigator.pop(context);
  }
}

class _RepeatOptions extends StatelessWidget {
  const _RepeatOptions({
    required this.repeat,
    required this.interval,
    required this.weekdays,
    required this.until,
    required this.onIntervalChanged,
    required this.onWeekdaysChanged,
    required this.onPickUntil,
    required this.onClearUntil,
  });

  final CalendarRepeat repeat;
  final int interval;
  final Set<int> weekdays;
  final DateTime? until;
  final ValueChanged<int> onIntervalChanged;
  final ValueChanged<Set<int>> onWeekdaysChanged;
  final VoidCallback onPickUntil;
  final VoidCallback onClearUntil;

  String get _unit => switch (repeat) {
    CalendarRepeat.daily => interval == 1 ? 'day' : 'days',
    CalendarRepeat.weekly => interval == 1 ? 'week' : 'weeks',
    CalendarRepeat.monthly => interval == 1 ? 'month' : 'months',
    CalendarRepeat.yearly => interval == 1 ? 'year' : 'years',
    _ => 'period',
  };

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: context.appRaised.withValues(alpha: .62),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: context.appBorder),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (repeat != CalendarRepeat.weekdays)
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Repeat every',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ),
              IconButton(
                tooltip: 'Decrease interval',
                onPressed: interval > 1
                    ? () => onIntervalChanged(interval - 1)
                    : null,
                icon: const Icon(Icons.remove_rounded, size: 18),
              ),
              Text(
                '$interval $_unit',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              IconButton(
                tooltip: 'Increase interval',
                onPressed: () => onIntervalChanged(interval + 1),
                icon: const Icon(Icons.add_rounded, size: 18),
              ),
            ],
          ),
        if (repeat == CalendarRepeat.weekly) ...[
          const SizedBox(height: 4),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (var day = DateTime.monday; day <= DateTime.sunday; day++)
                FilterChip(
                  label: Text(_weekdayLetter(day)),
                  selected: weekdays.contains(day),
                  onSelected: (selected) {
                    final next = {...weekdays};
                    if (selected) {
                      next.add(day);
                    } else {
                      next.remove(day);
                    }
                    onWeekdaysChanged(next);
                  },
                ),
            ],
          ),
        ],
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: Text(
                until == null
                    ? 'Ends · Never'
                    : 'Ends · ${_monthName(until!.month)} ${until!.day}, ${until!.year}',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (until != null)
              IconButton(
                tooltip: 'No end date',
                onPressed: onClearUntil,
                icon: const Icon(Icons.close_rounded, size: 17),
              ),
            TextButton(
              onPressed: onPickUntil,
              child: const Text('Choose date'),
            ),
          ],
        ),
      ],
    ),
  );
}

class _CalendarColorField extends StatelessWidget {
  const _CalendarColorField({required this.color, required this.onTap});

  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    key: const Key('calendar-color-button'),
    onTap: onTap,
    borderRadius: BorderRadius.circular(8),
    child: Container(
      constraints: const BoxConstraints(minHeight: 54),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: context.appRaised,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: context.appBorder),
      ),
      child: Row(
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withValues(alpha: .35)),
            ),
          ),
          const SizedBox(width: 11),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('Color', style: TextStyle(fontSize: 9)),
                SizedBox(height: 2),
                Text(
                  'Choose a preset or any color',
                  style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded, size: 18),
        ],
      ),
    ),
  );
}

class _CalendarColorDialog extends StatefulWidget {
  const _CalendarColorDialog({required this.initial});

  final Color initial;

  @override
  State<_CalendarColorDialog> createState() => _CalendarColorDialogState();
}

class _CalendarColorDialogState extends State<_CalendarColorDialog> {
  static const _presets = <int>[
    0xFFE05D62,
    0xFFF09A48,
    0xFFF1C94A,
    0xFF70C982,
    0xFF45C7BA,
    0xFF4FA3E3,
    0xFF6F72E8,
    0xFF9B66D9,
    0xFFD46FA6,
    0xFFB8785E,
    0xFF89909B,
    0xFFD16A61,
  ];

  late HSVColor _selected;
  final _spectrumKey = GlobalKey();
  final _hueKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _selected = HSVColor.fromColor(widget.initial);
  }

  void _setSaturationAndValue(Offset point) {
    final box = _spectrumKey.currentContext?.findRenderObject();
    if (box is! RenderBox) return;
    final size = box.size;
    setState(() {
      _selected = _selected
          .withSaturation((point.dx / size.width).clamp(0.0, 1.0))
          .withValue((1 - point.dy / size.height).clamp(0.0, 1.0));
    });
  }

  void _setHue(double x) {
    final box = _hueKey.currentContext?.findRenderObject();
    if (box is! RenderBox) return;
    setState(() {
      _selected = _selected.withHue((x / box.size.width).clamp(0.0, 1.0) * 360);
    });
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Choose color'),
    content: SizedBox(
      width: 380,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Presets', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 10),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                for (final value in _presets)
                  InkWell(
                    key: Key('calendar-color-$value'),
                    onTap: () => setState(
                      () => _selected = HSVColor.fromColor(Color(value)),
                    ),
                    customBorder: const CircleBorder(),
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: Color(value),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: _selected.toColor().toARGB32() == value
                              ? Colors.white
                              : Colors.white.withValues(alpha: .18),
                          width: 2,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 20),
            Text('Any color', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 10),
            GestureDetector(
              key: _spectrumKey,
              onTapDown: (details) =>
                  _setSaturationAndValue(details.localPosition),
              onPanUpdate: (details) =>
                  _setSaturationAndValue(details.localPosition),
              child: SizedBox(
                key: const Key('calendar-color-spectrum'),
                height: 150,
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: ColoredBox(
                        color: HSVColor.fromAHSV(
                          1,
                          _selected.hue,
                          1,
                          1,
                        ).toColor(),
                      ),
                    ),
                    const Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Colors.white, Colors.transparent],
                          ),
                        ),
                      ),
                    ),
                    const Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Colors.transparent, Colors.black],
                          ),
                        ),
                      ),
                    ),
                    Align(
                      alignment: Alignment(
                        _selected.saturation * 2 - 1,
                        (1 - _selected.value) * 2 - 1,
                      ),
                      child: Container(
                        width: 14,
                        height: 14,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                          boxShadow: const [BoxShadow(blurRadius: 3)],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            GestureDetector(
              key: _hueKey,
              onTapDown: (details) => _setHue(details.localPosition.dx),
              onPanUpdate: (details) => _setHue(details.localPosition.dx),
              child: Container(
                key: const Key('calendar-color-hue'),
                height: 22,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  gradient: const LinearGradient(
                    colors: [
                      Color(0xFFFF0000),
                      Color(0xFFFFFF00),
                      Color(0xFF00FF00),
                      Color(0xFF00FFFF),
                      Color(0xFF0000FF),
                      Color(0xFFFF00FF),
                      Color(0xFFFF0000),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        key: const Key('calendar-color-done'),
        onPressed: () => Navigator.pop(context, _selected.toColor()),
        child: const Text('Done'),
      ),
    ],
  );
}

class _KindButton extends StatelessWidget {
  const _KindButton({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(6),
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      decoration: BoxDecoration(
        color: selected
            ? Theme.of(context).colorScheme.primary.withValues(alpha: .24)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 17),
          const SizedBox(width: 7),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    ),
  );
}

class _EditorRow extends StatelessWidget {
  const _EditorRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(8),
    child: Container(
      constraints: const BoxConstraints(minHeight: 54),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: context.appRaised,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: context.appBorder),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: context.appMuted),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  label,
                  style: TextStyle(fontSize: 9, color: context.appMuted),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
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

class _ScheduleImportSheet extends StatefulWidget {
  const _ScheduleImportSheet({required this.store});
  final LifeStore store;

  @override
  State<_ScheduleImportSheet> createState() => _ScheduleImportSheetState();
}

class _ScheduleImportSheetState extends State<_ScheduleImportSheet> {
  final _controller = TextEditingController();
  bool _saving = false;
  String? _selectedFileName;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedPadding(
    duration: const Duration(milliseconds: 180),
    curve: Curves.easeOut,
    padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
    child: FractionallySizedBox(
      heightFactor: MediaQuery.viewInsetsOf(context).bottom > 0 ? .98 : .82,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 620),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 2, 20, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Import changing blocked times',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 7),
                Text(
                  'Choose a schedule file or paste rows. Tab-separated columns are date, start, end, name, location, color, repeat, and kind. Existing matching rows are skipped.',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: context.appMuted),
                ),
                const SizedBox(height: 14),
                OutlinedButton.icon(
                  onPressed: _saving ? null : _chooseFile,
                  icon: const Icon(Icons.upload_file_rounded),
                  label: Text(
                    _selectedFileName == null
                        ? 'Choose schedule file'
                        : 'Selected: $_selectedFileName',
                  ),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: TextField(
                    controller: _controller,
                    autofocus: true,
                    expands: true,
                    minLines: null,
                    maxLines: null,
                    textAlignVertical: TextAlignVertical.top,
                    decoration: const InputDecoration(
                      hintText:
                          '2027-01-01\t5:45 AM\t6:15 AM\tFajr\tSaint Paul, MN\tgreen\tnone\tblockedTime',
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                FilledButton(
                  onPressed: _saving ? null : _import,
                  child: Text(_saving ? 'Importing…' : 'Import schedule'),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );

  Future<void> _chooseFile() async {
    try {
      const channel = MethodChannel('life_tracker/files');
      if (Platform.isAndroid) {
        final selected = await channel.invokeMapMethod<String, Object?>(
          'chooseScheduleText',
        );
        if (selected == null || !mounted) return;
        setState(() {
          _selectedFileName = selected['name'] as String? ?? 'schedule';
          _controller.text = selected['text'] as String? ?? '';
        });
        return;
      }
      if (!Platform.isWindows) {
        _showFileError('Use paste import on this platform.');
        return;
      }
      final path = await channel.invokeMethod<String>('chooseScheduleFile');
      if (path == null || path.isEmpty || !mounted) return;
      final file = File(path);
      final text = await file.readAsString();
      if (!mounted) return;
      setState(() {
        _controller.text = text;
        _selectedFileName = file.uri.pathSegments.last;
      });
    } on Object {
      _showFileError('That schedule file could not be opened.');
    }
  }

  void _showFileError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _import() async {
    setState(() => _saving = true);
    final count = await widget.store.importBlockedSchedule(_controller.text);
    if (!mounted) return;
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          count == 0
              ? 'No new valid rows were found.'
              : 'Added $count calendar item${count == 1 ? '' : 's'}.',
        ),
      ),
    );
  }
}

class _CalendarOccurrence {
  const _CalendarOccurrence({
    required this.entry,
    required this.start,
    required this.end,
    required this.startMinute,
    required this.endMinute,
    required this.lane,
    required this.laneCount,
  });
  final CalendarEntry entry;
  final DateTime start;
  final DateTime end;
  final int startMinute;
  final int endMinute;
  final int lane;
  final int laneCount;
}

class _OccurrenceDraft {
  const _OccurrenceDraft({
    required this.entry,
    required this.start,
    required this.end,
    required this.startMinute,
    required this.endMinute,
  });
  final CalendarEntry entry;
  final DateTime start;
  final DateTime end;
  final int startMinute;
  final int endMinute;
}

List<_CalendarOccurrence> _placeOccurrences(
  List<CalendarEntry> entries,
  DateTime date,
) {
  final dayStart = _dateOnly(date);
  final dayEnd = dayStart.add(const Duration(days: 1));
  final drafts = <_OccurrenceDraft>[];
  for (final entry in entries) {
    final rawStart = entry.occurrenceStart(date);
    final rawEnd = entry.occurrenceEnd(date);
    final start = rawStart.isBefore(dayStart) ? dayStart : rawStart;
    final end = rawEnd.isAfter(dayEnd) ? dayEnd : rawEnd;
    if (!end.isAfter(start)) continue;
    drafts.add(
      _OccurrenceDraft(
        entry: entry,
        start: start,
        end: end,
        startMinute: start.difference(dayStart).inMinutes.clamp(0, 1440),
        endMinute: end.difference(dayStart).inMinutes.clamp(0, 1440),
      ),
    );
  }
  drafts.sort((a, b) {
    final byStart = a.startMinute.compareTo(b.startMinute);
    return byStart != 0 ? byStart : b.endMinute.compareTo(a.endMinute);
  });
  final result = <_CalendarOccurrence>[];
  var index = 0;
  while (index < drafts.length) {
    final cluster = <_OccurrenceDraft>[drafts[index]];
    var clusterEnd = drafts[index].endMinute;
    var next = index + 1;
    while (next < drafts.length && drafts[next].startMinute < clusterEnd) {
      cluster.add(drafts[next]);
      clusterEnd = math.max(clusterEnd, drafts[next].endMinute);
      next++;
    }
    final laneEnds = <int>[];
    final lanes = <int>[];
    for (final draft in cluster) {
      var lane = laneEnds.indexWhere((end) => end <= draft.startMinute);
      if (lane < 0) {
        lane = laneEnds.length;
        laneEnds.add(draft.endMinute);
      } else {
        laneEnds[lane] = draft.endMinute;
      }
      lanes.add(lane);
    }
    for (var i = 0; i < cluster.length; i++) {
      final draft = cluster[i];
      result.add(
        _CalendarOccurrence(
          entry: draft.entry,
          start: draft.start,
          end: draft.end,
          startMinute: draft.startMinute,
          endMinute: draft.endMinute,
          lane: lanes[i],
          laneCount: laneEnds.length,
        ),
      );
    }
    index = next;
  }
  return result;
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

DateTime _dateOnly(DateTime date) => DateTime(date.year, date.month, date.day);

bool _sameDate(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

String _calendarViewLabel(_CalendarView view) => switch (view) {
  _CalendarView.schedule => 'Schedule',
  _CalendarView.day => 'Day',
  _CalendarView.threeDays => '3 days',
  _CalendarView.week => 'Week',
  _CalendarView.month => 'Month',
};

String _weekdayLetter(int weekday) =>
    const ['M', 'T', 'W', 'T', 'F', 'S', 'S'][weekday - 1];

String _weekdayShort(int weekday) =>
    const ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'][weekday - 1];

String _friendlyDate(DateTime date) =>
    '${_weekdayName(date.weekday)}, ${_monthName(date.month)} ${date.day}';

String _fullDate(DateTime date) =>
    '${_weekdayName(date.weekday)}, ${_monthName(date.month)} ${date.day}, ${date.year}';

String _hourLabel(int hour) {
  if (hour == 0) return '12 AM';
  if (hour == 12) return '12 PM';
  return hour > 12 ? '${hour - 12} PM' : '$hour AM';
}

String _time(DateTime date) {
  final hour = date.hour == 0
      ? 12
      : date.hour > 12
      ? date.hour - 12
      : date.hour;
  return '$hour:${date.minute.toString().padLeft(2, '0')} ${date.hour >= 12 ? 'PM' : 'AM'}';
}

Color _calendarEntryColor(BuildContext context, CalendarEntry entry) {
  final value = entry.colorValue;
  if (value != null) return Color(value);
  return entry.kind == CalendarEntryKind.blockedTime
      ? const Color(0xFFD16A61)
      : Theme.of(context).colorScheme.primary;
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
