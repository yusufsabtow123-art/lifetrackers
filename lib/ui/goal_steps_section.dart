import 'package:flutter/material.dart';

import '../app/goal_store.dart';
import '../domain/goal.dart';
import '../domain/step_batch_parser.dart';
import 'app_theme.dart';

class GoalStepsSection extends StatefulWidget {
  const GoalStepsSection({super.key, required this.goal, required this.store});

  final Goal goal;
  final GoalStore store;

  @override
  State<GoalStepsSection> createState() => _GoalStepsSectionState();
}

class _GoalStepsSectionState extends State<GoalStepsSection> {
  final _singleStep = TextEditingController();

  @override
  void dispose() {
    _singleStep.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final goal = widget.goal;
    return Column(
      key: const Key('goal-steps-section'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Checklist',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            if (goal.steps.isNotEmpty)
              Text(
                '${goal.completedStepCount} of ${goal.steps.length} done',
                style: Theme.of(context).textTheme.bodySmall,
              ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'Check a step when it is finished.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        if (goal.steps.isNotEmpty) ...[
          const SizedBox(height: 10),
          ReorderableListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            buildDefaultDragHandles: false,
            itemCount: goal.steps.length,
            onReorderItem: (oldIndex, newIndex) => widget.store.reorderStep(
              goal.id,
              oldIndex,
              newIndex > oldIndex ? newIndex + 1 : newIndex,
            ),
            itemBuilder: (context, index) {
              final step = goal.steps[index];
              return _StepCard(
                key: ValueKey(step.id),
                goal: goal,
                step: step,
                index: index,
                store: widget.store,
                onToggle: () => _toggleStep(step),
                onEdit: () => _editStep(step),
                onDelete: () => _deleteStep(step),
              );
            },
          ),
        ],
        const SizedBox(height: 12),
        TextField(
          key: const Key('add-goal-step-field'),
          controller: _singleStep,
          minLines: 1,
          maxLines: 4,
          decoration: const InputDecoration(
            labelText: 'Add one small step',
            hintText: 'Example: Make sauce',
            helperText: 'Text containing + or = stays in this one step.',
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilledButton.icon(
              key: const Key('add-goal-step-button'),
              onPressed: _addSingleStep,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add step'),
            ),
            OutlinedButton.icon(
              key: const Key('add-many-steps-button'),
              onPressed: _addManySteps,
              icon: const Icon(Icons.playlist_add_rounded),
              label: const Text('Add many steps'),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _addSingleStep() async {
    if (_singleStep.text.trim().isEmpty) return;
    await widget.store.addStep(widget.goal.id, _singleStep.text);
    _singleStep.clear();
  }

  Future<void> _addManySteps() async {
    final titles = await showDialog<List<String>>(
      context: context,
      builder: (context) => const _AddManyStepsDialog(),
    );
    if (titles != null) await widget.store.addSteps(widget.goal.id, titles);
  }

  Future<void> _toggleStep(GoalStep step) async {
    if (step.isCompleted) {
      await widget.store.reopenStep(widget.goal.id, step.id);
      return;
    }
    await widget.store.completeStep(widget.goal.id, step.id);
  }

  Future<void> _editStep(GoalStep step) async {
    final title = TextEditingController(text: step.title);
    final details = TextEditingController(text: step.details);
    final changed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit step'),
        content: SizedBox(
          width: 440,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                key: const Key('edit-step-title'),
                controller: title,
                autofocus: true,
                decoration: const InputDecoration(labelText: 'Title'),
              ),
              const SizedBox(height: 10),
              TextField(
                key: const Key('edit-step-details'),
                controller: details,
                minLines: 2,
                maxLines: 5,
                decoration: const InputDecoration(
                  labelText: 'Details (optional)',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(context, title.text.trim().isNotEmpty),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (changed == true) {
      await widget.store.updateStep(
        widget.goal.id,
        step.id,
        title: title.text,
        details: details.text,
      );
    }
    title.dispose();
    details.dispose();
  }

  Future<void> _deleteStep(GoalStep step) async {
    final hasHistory = widget.goal.updates.any(
      (update) => update.stepId == step.id,
    );
    if (hasHistory) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Delete this step?'),
          content: const Text(
            'Its saved activity will remain in the file for compatibility. '
            'You can undo this change.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete step'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }
    await widget.store.removeStep(widget.goal.id, step.id);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${step.title} deleted.'),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: widget.store.undoLastChange,
        ),
      ),
    );
  }
}

class _StepCard extends StatelessWidget {
  const _StepCard({
    super.key,
    required this.goal,
    required this.step,
    required this.index,
    required this.store,
    required this.onToggle,
    required this.onEdit,
    required this.onDelete,
  });

  final Goal goal;
  final GoalStep step;
  final int index;
  final GoalStore store;
  final VoidCallback onToggle;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: context.appPanel,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: context.appBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ReorderableDragStartListener(
                  index: index,
                  child: const Padding(
                    padding: EdgeInsets.only(top: 8, right: 8),
                    child: Icon(Icons.drag_indicator_rounded),
                  ),
                ),
                Checkbox(
                  key: Key('step-toggle-${step.id}'),
                  value: step.isCompleted,
                  onChanged: (_) => onToggle(),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        step.title,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          decoration: step.isCompleted
                              ? TextDecoration.lineThrough
                              : null,
                        ),
                      ),
                      if (step.details.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(step.details),
                      ],
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  tooltip: 'Step options',
                  onSelected: (action) {
                    switch (action) {
                      case 'edit':
                        onEdit();
                      case 'up':
                        store.reorderStep(goal.id, index, index - 1);
                      case 'down':
                        store.reorderStep(goal.id, index, index + 2);
                      case 'delete':
                        onDelete();
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(value: 'edit', child: Text('Edit')),
                    if (index > 0)
                      const PopupMenuItem(value: 'up', child: Text('Move up')),
                    if (index < goal.steps.length - 1)
                      const PopupMenuItem(
                        value: 'down',
                        child: Text('Move down'),
                      ),
                    const PopupMenuItem(value: 'delete', child: Text('Delete')),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _AddManyStepsDialog extends StatefulWidget {
  const _AddManyStepsDialog();

  @override
  State<_AddManyStepsDialog> createState() => _AddManyStepsDialogState();
}

class _AddManyStepsDialogState extends State<_AddManyStepsDialog> {
  final _controller = TextEditingController();
  final _parser = const StepBatchParser();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final preview = _parser.parse(_controller.text);
    return AlertDialog(
      title: const Text('Add many steps'),
      content: SizedBox(
        width: 500,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Enter one per line, or separate items with spaced + signs. '
                'A spaced = sign marks the final result.',
              ),
              const SizedBox(height: 10),
              TextField(
                key: const Key('batch-steps-field'),
                controller: _controller,
                autofocus: true,
                minLines: 4,
                maxLines: 8,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  hintText: 'Get pot + Add water + Cook = Rice ready',
                ),
              ),
              const SizedBox(height: 14),
              Text('Preview', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 6),
              if (preview.items.isEmpty)
                const Text('Enter at least two steps.')
              else
                for (var index = 0; index < preview.items.length; index++)
                  ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(
                      radius: 13,
                      child: Text('${index + 1}'),
                    ),
                    title: Text(preview.items[index].title),
                    trailing: preview.items[index].isFinalResult
                        ? const Chip(label: Text('Final result'))
                        : null,
                  ),
              if (preview.items.length == 1)
                const Text('Add one more item to use batch entry.'),
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
          key: const Key('confirm-add-many-steps'),
          onPressed: preview.canAdd
              ? () => Navigator.pop(context, preview.titles)
              : null,
          child: const Text('Add steps'),
        ),
      ],
    );
  }
}
