import 'package:flutter/material.dart';

import '../app/goal_store.dart';
import '../domain/goal.dart';
import '../domain/plan_calculator.dart';

class GoalProgressUpdate extends StatelessWidget {
  const GoalProgressUpdate({
    super.key,
    required this.goal,
    required this.store,
    this.label = 'Log amount',
  });

  final Goal goal;
  final GoalStore store;
  final String label;

  @override
  Widget build(BuildContext context) {
    return FilledButton.tonalIcon(
      key: const Key('log-amount-progress-button'),
      onPressed: () => _showAmountDialog(context),
      icon: const Icon(Icons.bar_chart_outlined, size: 18),
      label: Text(label),
    );
  }

  Future<void> _showAmountDialog(BuildContext context) async {
    final plan = goal.plan!;
    final saved = await showDialog<double>(
      context: context,
      barrierDismissible: false,
      builder: (context) => _AmountProgressDialog(goal: goal, store: store),
    );

    if (saved == plan.totalAmount &&
        goal.status != GoalStatus.completed &&
        context.mounted) {
      final complete = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          icon: const Icon(Icons.celebration_outlined),
          title: const Text('Move this goal to Completed?'),
          content: const Text(
            'The full amount is finished. You can move the goal now or keep it '
            'in its current column.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Keep it here'),
            ),
            FilledButton(
              key: const Key('confirm-progress-complete'),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Move to Completed'),
            ),
          ],
        ),
      );
      if (complete == true) {
        await store.moveGoal(goal.id, GoalStatus.completed);
      }
    }
  }
}

class _AmountProgressDialog extends StatefulWidget {
  const _AmountProgressDialog({required this.goal, required this.store});

  final Goal goal;
  final GoalStore store;

  @override
  State<_AmountProgressDialog> createState() => _AmountProgressDialogState();
}

class _AmountProgressDialogState extends State<_AmountProgressDialog> {
  late final TextEditingController _amount;
  late final TextEditingController _note;
  String? _error;
  var _saving = false;

  GoalPlan get _plan => widget.goal.plan!;

  @override
  void initState() {
    super.initState();
    _amount = TextEditingController(
      text: formatAmount(widget.goal.completedAmount),
    );
    _note = TextEditingController();
  }

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    final parsed = double.tryParse(_amount.text.trim().replaceAll(',', '.'));
    if (parsed == null || parsed < 0 || parsed > _plan.totalAmount) {
      setState(() {
        _error = 'Enter a total from 0 to ${formatAmount(_plan.totalAmount)}.';
      });
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.store.recordProgress(
        widget.goal.id,
        parsed,
        note: _note.text,
      );
      if (mounted) Navigator.pop(context, parsed);
    } on Object catch (caught) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = 'Could not save progress: $caught';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      icon: const Icon(Icons.add_chart_rounded),
      title: const Text('Log amount progress'),
      content: SizedBox(
        width: 430,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Currently ${formatAmount(widget.goal.completedAmount)} of '
              '${formatAmount(_plan.totalAmount)} ${_plan.unit}.',
            ),
            const SizedBox(height: 12),
            TextField(
              key: const Key('completed-amount-field'),
              controller: _amount,
              autofocus: true,
              enabled: !_saving,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(
                labelText: 'New total completed',
                suffixText: _plan.unit,
                helperText:
                    'Enter the total completed so far, not only today’s amount.',
                errorText: _error,
              ),
              onSubmitted: (_) => _save(),
            ),
            const SizedBox(height: 10),
            TextField(
              key: const Key('progress-note-field'),
              controller: _note,
              enabled: !_saving,
              minLines: 1,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'Note (optional)'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: const Key('save-progress-button'),
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Save'),
        ),
      ],
    );
  }
}
