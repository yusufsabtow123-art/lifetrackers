import 'package:flutter/material.dart';

import '../app/life_store.dart';
import '../domain/life_data.dart';
import 'app_theme.dart';
import 'speech_input_button.dart';

Future<void> showTaskCompletionCheckIn(
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
