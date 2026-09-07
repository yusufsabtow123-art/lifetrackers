import 'package:flutter/material.dart';

import '../app/goal_store.dart';
import '../app/theme_controller.dart';
import '../domain/goal.dart';
import 'app_theme.dart';

Future<void> showGoalReminderDialog(
  BuildContext context, {
  required GoalStore store,
  required AppSettingsController settings,
  required String goalId,
}) => showDialog<void>(
  context: context,
  builder: (context) =>
      _GoalReminderDialog(store: store, settings: settings, goalId: goalId),
);

class _GoalReminderDialog extends StatefulWidget {
  const _GoalReminderDialog({
    required this.store,
    required this.settings,
    required this.goalId,
  });
  final GoalStore store;
  final AppSettingsController settings;
  final String goalId;

  @override
  State<_GoalReminderDialog> createState() => _GoalReminderDialogState();
}

class _GoalReminderDialogState extends State<_GoalReminderDialog> {
  late final TextEditingController _message;
  late bool _enabled;
  late ReminderFrequency _frequency;
  late ReminderPurpose _purpose;
  late TimeOfDay _time;
  late Set<int> _weekdays;
  DateTime? _onceDate;

  static const _dayLabels = <int, String>{
    1: 'Mon',
    2: 'Tue',
    3: 'Wed',
    4: 'Thu',
    5: 'Fri',
    6: 'Sat',
    7: 'Sun',
  };

  @override
  void initState() {
    super.initState();
    final goal = widget.store.goalById(widget.goalId)!;
    final saved = goal.reminder;
    _enabled = saved?.enabled ?? true;
    _frequency =
        saved?.frequency ??
        ReminderFrequency.parse(widget.settings.defaultReminderFrequency.name);
    _purpose =
        saved?.purpose ??
        (goal.plan == null
            ? ReminderPurpose.goalCompletion
            : ReminderPurpose.dailyAction);
    _time = TimeOfDay(
      hour: saved?.hour ?? widget.settings.defaultReminderTime.hour,
      minute: saved?.minute ?? widget.settings.defaultReminderTime.minute,
    );
    _weekdays = Set<int>.of(saved?.weekdays ?? const {1, 2, 3, 4, 5, 6, 7});
    _onceDate = saved?.onceAt;
    _message = TextEditingController(
      text: saved?.message.isNotEmpty == true
          ? saved!.message
          : _defaultMessage(goal),
    );
  }

  String _defaultMessage(Goal goal) {
    final plan = goal.plan;
    if (plan == null) return 'Check in on ${goal.name}';
    final action = widget.store.calculator.actionForDate(
      goal,
      widget.store.today,
    );
    if (action <= 0) return 'Check in on ${goal.name}';
    return 'Complete today’s action for ${goal.name}';
  }

  @override
  void dispose() {
    _message.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final goal = widget.store.goalById(widget.goalId)!;
    return AlertDialog(
      title: const Text('Reminder'),
      content: SizedBox(
        width: 470,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Remind me about this goal'),
                subtitle: const Text('Uses the device notification system.'),
                value: _enabled,
                onChanged: (value) => setState(() => _enabled = value),
              ),
              TextField(
                controller: _message,
                enabled: _enabled,
                decoration: const InputDecoration(labelText: 'Reminder text'),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<ReminderPurpose>(
                initialValue: _purpose,
                decoration: const InputDecoration(
                  labelText: 'What is this reminder checking?',
                ),
                items: [
                  for (final item in ReminderPurpose.values)
                    DropdownMenuItem(value: item, child: Text(item.label)),
                ],
                onChanged: !_enabled
                    ? null
                    : (value) {
                        if (value != null) setState(() => _purpose = value);
                      },
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<ReminderFrequency>(
                initialValue: _frequency,
                decoration: const InputDecoration(labelText: 'How often?'),
                items: [
                  for (final item in ReminderFrequency.values)
                    DropdownMenuItem(value: item, child: Text(item.label)),
                ],
                onChanged: !_enabled
                    ? null
                    : (value) {
                        if (value == null) return;
                        setState(() {
                          _frequency = value;
                          if (value == ReminderFrequency.weekdays) {
                            _weekdays = {1, 2, 3, 4, 5};
                          } else if (value == ReminderFrequency.daily) {
                            _weekdays = {1, 2, 3, 4, 5, 6, 7};
                          } else if (value == ReminderFrequency.weekly) {
                            _weekdays = {DateTime.now().weekday};
                          }
                        });
                      },
              ),
              if (_frequency == ReminderFrequency.customDays ||
                  _frequency == ReminderFrequency.weekly) ...[
                const SizedBox(height: 12),
                Text(
                  _frequency == ReminderFrequency.weekly
                      ? 'Day of the week'
                      : 'Days',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 7),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final entry in _dayLabels.entries)
                      FilterChip(
                        label: Text(entry.value),
                        selected: _weekdays.contains(entry.key),
                        onSelected: !_enabled
                            ? null
                            : (selected) => setState(() {
                                if (_frequency == ReminderFrequency.weekly) {
                                  _weekdays = {entry.key};
                                } else if (selected) {
                                  _weekdays.add(entry.key);
                                } else if (_weekdays.length > 1) {
                                  _weekdays.remove(entry.key);
                                }
                              }),
                      ),
                  ],
                ),
              ],
              if (_frequency == ReminderFrequency.once) ...[
                const SizedBox(height: 10),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Date'),
                  subtitle: Text(
                    _onceDate == null
                        ? 'Choose a date'
                        : MaterialLocalizations.of(
                            context,
                          ).formatMediumDate(_onceDate!),
                  ),
                  trailing: const Icon(Icons.calendar_today_outlined),
                  onTap: !_enabled ? null : _pickDate,
                ),
              ],
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Time'),
                subtitle: Text(_time.format(context)),
                trailing: const Icon(Icons.schedule_rounded),
                onTap: !_enabled ? null : _pickTime,
              ),
              Container(
                padding: const EdgeInsets.all(13),
                decoration: BoxDecoration(
                  color: context.appSoftBlue,
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Text(
                  _purpose == ReminderPurpose.dailyAction
                      ? 'The notification offers Done, Not done, and Delay.'
                      : 'The notification offers Done and Not yet for the '
                            'whole goal.',
                ),
              ),
              if (!widget.settings.data.firstReminderEducationSeen) ...[
                const SizedBox(height: 10),
                const Text(
                  'You can turn reminders off for this goal here, or turn all '
                  'reminders off in Settings.',
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        if (goal.reminder != null)
          TextButton(
            onPressed: () async {
              await widget.store.removeReminder(goal.id);
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('Remove'),
          ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _enabled ? _save : null,
          child: const Text('Save reminder'),
        ),
      ],
    );
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _onceDate ?? now.add(const Duration(days: 1)),
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: DateTime(now.year + 5),
    );
    if (picked != null) setState(() => _onceDate = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(context: context, initialTime: _time);
    if (picked != null) setState(() => _time = picked);
  }

  Future<void> _save() async {
    final text = _message.text.trim();
    if (text.isEmpty) return;
    DateTime? onceAt;
    if (_frequency == ReminderFrequency.once) {
      final date = _onceDate ?? DateTime.now().add(const Duration(days: 1));
      onceAt = DateTime(
        date.year,
        date.month,
        date.day,
        _time.hour,
        _time.minute,
      );
    }
    await widget.store.setReminder(
      widget.goalId,
      GoalReminder(
        id: widget.store.goalById(widget.goalId)?.reminder?.id ?? '',
        enabled: true,
        message: text,
        frequency: _frequency,
        hour: _time.hour,
        minute: _time.minute,
        purpose: _purpose,
        weekdays: switch (_frequency) {
          ReminderFrequency.daily => const {1, 2, 3, 4, 5, 6, 7},
          ReminderFrequency.weekdays => const {1, 2, 3, 4, 5},
          ReminderFrequency.weekly ||
          ReminderFrequency.customDays => Set.unmodifiable(_weekdays),
          ReminderFrequency.once => const {},
        },
        onceAt: onceAt,
      ),
    );
    await widget.settings.setFirstReminderEducationSeen(true);
    if (mounted) Navigator.pop(context);
  }
}
