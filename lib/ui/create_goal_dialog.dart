import 'package:flutter/material.dart';

import '../app/goal_store.dart';
import '../domain/plan_calculator.dart';
import 'app_theme.dart';
import 'progress_format.dart';

Future<void> showCreateGoalDialog(BuildContext context, GoalStore store) {
  return showDialog<void>(
    context: context,
    builder: (context) => _CreateGoalDialog(store: store),
  );
}

Future<void> showPlanGoalDialog(
  BuildContext context,
  GoalStore store,
  String goalId,
) {
  return showDialog<void>(
    context: context,
    builder: (context) => _CreateGoalDialog(
      store: store,
      existingGoalId: goalId,
      startPlanning: true,
    ),
  );
}

class _CreateGoalDialog extends StatefulWidget {
  const _CreateGoalDialog({
    required this.store,
    this.existingGoalId,
    this.startPlanning = false,
  });

  final GoalStore store;
  final String? existingGoalId;
  final bool startPlanning;

  @override
  State<_CreateGoalDialog> createState() => _CreateGoalDialogState();
}

class _CreateGoalDialogState extends State<_CreateGoalDialog> {
  final _nameController = TextEditingController();
  final _amountController = TextEditingController(text: '100');
  final _startingProgressController = TextEditingController(text: '0');
  final _unitController = TextEditingController(text: 'pages');
  late bool _planning;
  bool _wholeUnits = true;
  bool _countDownFromTotal = false;
  bool _saving = false;
  String? _error;
  late DateTime _startDate;
  late DateTime _deadline;

  bool get _isExisting => widget.existingGoalId != null;

  @override
  void initState() {
    super.initState();
    _planning = widget.startPlanning;
    final existing = widget.existingGoalId == null
        ? null
        : widget.store.goalById(widget.existingGoalId!);
    if (existing != null) {
      _nameController.text = existing.name;
      final plan = existing.plan;
      if (plan != null) {
        _amountController.text = _editableAmount(plan.totalAmount);
        _startingProgressController.text = _editableAmount(
          existing.completedAmount,
        );
        _unitController.text = plan.unit;
        _wholeUnits = plan.wholeUnits;
        _startDate = plan.startDate;
        _deadline = plan.deadline;
      } else {
        _startDate = widget.store.today;
        _deadline = widget.store.today.add(const Duration(days: 99));
      }
    } else {
      _startDate = widget.store.today;
      _deadline = widget.store.today.add(const Duration(days: 99));
    }
    _amountController.addListener(_refreshPlanningPreview);
    _startingProgressController.addListener(_refreshPlanningPreview);
    _unitController.addListener(_refreshPlanningPreview);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _amountController.dispose();
    _startingProgressController.dispose();
    _unitController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: _planning ? 640 : 500,
          maxHeight: MediaQuery.sizeOf(context).height - 48,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: _planning
                          ? context.appSoftGreen
                          : context.appSoftBlue,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      _planning
                          ? Icons.calendar_month_outlined
                          : Icons.bolt_rounded,
                      color: _planning
                          ? context.appGreenText
                          : context.appBlueText,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _planning
                          ? (_isExisting ? 'Add a plan' : 'Plan this goal')
                          : 'Capture an idea',
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close',
                    onPressed: _saving ? null : () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 22),
              TextField(
                key: const Key('goal-name-field'),
                controller: _nameController,
                autofocus: !_isExisting,
                enabled: !_isExisting,
                textInputAction: _planning
                    ? TextInputAction.next
                    : TextInputAction.done,
                onSubmitted: (_) {
                  if (!_planning) _quickCreate();
                },
                decoration: const InputDecoration(
                  labelText: 'What is the goal?',
                  hintText: 'What do you want to finish?',
                ),
              ),
              if (!_planning) ...[
                const SizedBox(height: 10),
                Text(
                  'Save it now. You can add planning details later.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ] else ...[
                const SizedBox(height: 20),
                _PlanningFields(
                  amountController: _amountController,
                  startingProgressController: _startingProgressController,
                  unitController: _unitController,
                  startDate: _startDate,
                  deadline: _deadline,
                  wholeUnits: _wholeUnits,
                  countDownFromTotal: _countDownFromTotal,
                  onStartDate: () => _pickDate(start: true),
                  onDeadline: () => _pickDate(start: false),
                  onWholeUnitsChanged: (value) =>
                      setState(() => _wholeUnits = value),
                  onCountDownChanged: _setCountDownFromTotal,
                ),
                const SizedBox(height: 10),
                Text(
                  'The proof uses every day for today\'s action. Choosing '
                  'weekdays will arrive with calendar scheduling.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
              const SizedBox(height: 22),
              if (!_planning)
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  alignment: WrapAlignment.end,
                  children: [
                    OutlinedButton(
                      key: const Key('plan-now-button'),
                      onPressed: _saving ? null : _openPlanning,
                      child: const Text('Add planning details'),
                    ),
                    FilledButton(
                      key: const Key('add-to-ideas-button'),
                      onPressed: _saving ? null : _quickCreate,
                      child: const Text('Save idea'),
                    ),
                  ],
                )
              else
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _saving
                            ? null
                            : _isExisting
                            ? () => Navigator.pop(context)
                            : () => setState(() => _planning = false),
                        child: Text(_isExisting ? 'Cancel' : 'Back'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 2,
                      child: FilledButton(
                        key: const Key('create-planned-goal-button'),
                        onPressed: _saving ? null : _savePlan,
                        child: Text(
                          _saving
                              ? 'Saving...'
                              : _isExisting
                              ? 'Save plan'
                              : 'Save planned goal',
                        ),
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

  void _openPlanning() {
    if (_nameController.text.trim().isEmpty) {
      setState(() => _error = 'Enter a goal name first.');
      return;
    }
    setState(() {
      _error = null;
      _planning = true;
    });
  }

  Future<void> _quickCreate() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Enter a goal name.');
      return;
    }
    setState(() => _saving = true);
    await widget.store.createQuick(name);
    if (mounted) Navigator.pop(context);
  }

  Future<void> _savePlan() async {
    final name = _nameController.text.trim();
    final amount = double.tryParse(_amountController.text.trim());
    final startingEntry = double.tryParse(
      _startingProgressController.text.trim(),
    );
    final unit = _unitController.text.trim();
    if (name.isEmpty || amount == null || amount <= 0 || unit.isEmpty) {
      setState(() => _error = 'Enter a name, a positive amount, and a unit.');
      return;
    }
    if (startingEntry == null || startingEntry < 0 || startingEntry > amount) {
      setState(
        () => _error = _countDownFromTotal
            ? 'Enter a current position from 0 to ${formatAmount(amount)}.'
            : 'Already completed must be from 0 to ${formatAmount(amount)}.',
      );
      return;
    }
    final initialCompleted = _countDownFromTotal
        ? amount - startingEntry
        : startingEntry;
    if (_deadline.isBefore(_startDate)) {
      setState(
        () => _error = 'The deadline must be on or after the start date.',
      );
      return;
    }
    setState(() => _saving = true);
    if (_isExisting) {
      await widget.store.addPlan(
        goalId: widget.existingGoalId!,
        amount: amount,
        unit: unit,
        startDate: _startDate,
        deadline: _deadline,
        wholeUnits: _wholeUnits,
        initialCompletedAmount: initialCompleted,
      );
    } else {
      await widget.store.createPlanned(
        name: name,
        amount: amount,
        unit: unit,
        startDate: _startDate,
        deadline: _deadline,
        wholeUnits: _wholeUnits,
        initialCompletedAmount: initialCompleted,
      );
    }
    if (mounted) Navigator.pop(context);
  }

  Future<void> _pickDate({required bool start}) async {
    final initial = start ? _startDate : _deadline;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(widget.store.today.year - 1),
      lastDate: DateTime(widget.store.today.year + 10),
    );
    if (picked == null) return;
    setState(() {
      if (start) {
        _startDate = picked;
        if (_deadline.isBefore(picked)) _deadline = picked;
      } else {
        _deadline = picked;
      }
    });
  }

  void _refreshPlanningPreview() {
    if (mounted && _planning) setState(() {});
  }

  void _setCountDownFromTotal(bool value) {
    final total = double.tryParse(_amountController.text.trim());
    final entered = double.tryParse(_startingProgressController.text.trim());
    setState(() {
      _countDownFromTotal = value;
      if (total != null &&
          total > 0 &&
          entered != null &&
          entered >= 0 &&
          entered <= total) {
        _startingProgressController.text = _editableAmount(total - entered);
      }
    });
  }
}

class _PlanningFields extends StatefulWidget {
  const _PlanningFields({
    required this.amountController,
    required this.startingProgressController,
    required this.unitController,
    required this.startDate,
    required this.deadline,
    required this.wholeUnits,
    required this.countDownFromTotal,
    required this.onStartDate,
    required this.onDeadline,
    required this.onWholeUnitsChanged,
    required this.onCountDownChanged,
  });

  final TextEditingController amountController;
  final TextEditingController startingProgressController;
  final TextEditingController unitController;
  final DateTime startDate;
  final DateTime deadline;
  final bool wholeUnits;
  final bool countDownFromTotal;
  final VoidCallback onStartDate;
  final VoidCallback onDeadline;
  final ValueChanged<bool> onWholeUnitsChanged;
  final ValueChanged<bool> onCountDownChanged;

  @override
  State<_PlanningFields> createState() => _PlanningFieldsState();
}

class _PlanningFieldsState extends State<_PlanningFields> {
  @override
  Widget build(BuildContext context) {
    return ExpansionPanelList.radio(
      expandedHeaderPadding: EdgeInsets.zero,
      elevation: 0,
      dividerColor: context.appBorder,
      initialOpenPanelValue: 0,
      children: [
        ExpansionPanelRadio(
          value: 0,
          canTapOnHeader: true,
          headerBuilder: (context, expanded) => const _PlanSectionHeader(
            number: 1,
            title: 'Outcome',
            subtitle: 'What does finished mean?',
          ),
          body: Padding(
            key: const ValueKey('plan-outcome-panel'),
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    key: const Key('total-amount-field'),
                    controller: widget.amountController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Total amount',
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: widget.unitController,
                    decoration: const InputDecoration(
                      labelText: 'Unit',
                      hintText: 'pages',
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        ExpansionPanelRadio(
          value: 1,
          canTapOnHeader: true,
          headerBuilder: (context, expanded) => _PlanSectionHeader(
            number: 2,
            title: 'Starting point',
            subtitle: widget.startingProgressController.text.trim() == '0'
                ? 'Optional'
                : '${widget.startingProgressController.text.trim()} already entered',
          ),
          body: Padding(
            key: const ValueKey('plan-starting-point-panel'),
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              children: [
                TextField(
                  key: const Key('starting-progress-field'),
                  controller: widget.startingProgressController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    labelText: widget.countDownFromTotal
                        ? 'Current position'
                        : 'Already completed',
                  ),
                ),
                ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  title: const Text('Advanced'),
                  children: [
                    SwitchListTile.adaptive(
                      key: const Key('count-down-progress-switch'),
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Count down from the total'),
                      subtitle: const Text(
                        'For numbered work that moves from the highest number toward zero.',
                      ),
                      value: widget.countDownFromTotal,
                      onChanged: widget.onCountDownChanged,
                    ),
                  ],
                ),
                _StartingProgressPreview(
                  totalText: widget.amountController.text,
                  progressText: widget.startingProgressController.text,
                  unit: widget.unitController.text,
                  countDownFromTotal: widget.countDownFromTotal,
                ),
              ],
            ),
          ),
        ),
        ExpansionPanelRadio(
          value: 2,
          canTapOnHeader: true,
          headerBuilder: (context, expanded) => _PlanSectionHeader(
            number: 3,
            title: 'Schedule',
            subtitle:
                '${_dateLabel(widget.startDate)} to ${_dateLabel(widget.deadline)}',
          ),
          body: Padding(
            key: const ValueKey('plan-schedule-panel'),
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Row(
              children: [
                Expanded(
                  child: _DateButton(
                    label: 'Starting from',
                    date: widget.startDate,
                    onPressed: widget.onStartDate,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _DateButton(
                    label: 'Deadline',
                    date: widget.deadline,
                    onPressed: widget.onDeadline,
                  ),
                ),
              ],
            ),
          ),
        ),
        ExpansionPanelRadio(
          value: 3,
          canTapOnHeader: true,
          headerBuilder: (context, expanded) => const _PlanSectionHeader(
            number: 4,
            title: 'Daily action and options',
            subtitle: 'Keep the suggested work practical',
          ),
          body: Padding(
            key: const ValueKey('plan-daily-action-panel'),
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: const Text('Keep this unit whole'),
              subtitle: const Text(
                'Pages, lessons, and sessions will not become awkward decimals.',
              ),
              value: widget.wholeUnits,
              onChanged: widget.onWholeUnitsChanged,
            ),
          ),
        ),
      ],
    );
  }

  String _dateLabel(DateTime date) =>
      MaterialLocalizations.of(context).formatCompactDate(date);
}

class _PlanSectionHeader extends StatelessWidget {
  const _PlanSectionHeader({
    required this.number,
    required this.title,
    required this.subtitle,
  });

  final int number;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) => ListTile(
    leading: CircleAvatar(
      radius: 16,
      backgroundColor: context.appSoftGreen,
      foregroundColor: context.appGreenText,
      child: Text(number.toString()),
    ),
    title: Text(title),
    subtitle: Text(subtitle),
  );
}

class _StartingProgressPreview extends StatelessWidget {
  const _StartingProgressPreview({
    required this.totalText,
    required this.progressText,
    required this.unit,
    required this.countDownFromTotal,
  });

  final String totalText;
  final String progressText;
  final String unit;
  final bool countDownFromTotal;

  @override
  Widget build(BuildContext context) {
    final total = double.tryParse(totalText.trim());
    final entered = double.tryParse(progressText.trim());
    final valid =
        total != null &&
        total > 0 &&
        entered != null &&
        entered >= 0 &&
        entered <= total;
    final completed = !valid
        ? 0.0
        : countDownFromTotal
        ? total - entered
        : entered;
    final remaining = valid ? total - completed : 0.0;
    final percentage = valid ? formatProgressPercent(completed / total) : '0%';
    final normalizedUnit = unit.trim().isEmpty ? 'units' : unit.trim();

    return Container(
      key: const Key('starting-progress-summary'),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.appSoftBlue,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.appBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.donut_large_rounded, color: context.appBlueText),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              valid
                  ? '${formatAmount(completed)} of ${formatAmount(total)} '
                        '$normalizedUnit complete · $percentage\n'
                        '${formatAmount(remaining)} $normalizedUnit remaining'
                  : 'Enter valid progress to preview what is complete and remaining.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}

class _DateButton extends StatelessWidget {
  const _DateButton({
    required this.label,
    required this.date,
    required this.onPressed,
  });

  final String label;
  final DateTime date;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 2),
          Row(
            children: [
              const Icon(Icons.calendar_today_outlined, size: 17),
              const SizedBox(width: 7),
              Flexible(child: Text(_formatDate(date))),
            ],
          ),
        ],
      ),
    );
  }
}

String _formatDate(DateTime date) {
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

String _editableAmount(double value) {
  if (value == value.roundToDouble()) return value.toInt().toString();
  return value
      .toStringAsFixed(12)
      .replaceFirst(RegExp(r'0+$'), '')
      .replaceFirst(RegExp(r'\.$'), '');
}
