import 'package:flutter/material.dart';

import '../app/life_store.dart';
import '../domain/life_data.dart';
import '../platform/attachment_picker.dart';
import 'app_theme.dart';
import 'speech_input_button.dart';

Future<bool> showTaskCompletionCheckIn(
  BuildContext context,
  LifeStore store,
  LifeTask task,
  DateTime day,
) async {
  final note = TextEditingController(
    text: task.completionNoteFor(day)?.text ?? '',
  );
  final attachments =
      task.completionNoteFor(day)?.attachments.toList() ?? <LifeAttachment>[];
  final completed = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (context) => StatefulBuilder(
      builder: (context, setSheetState) => AnimatedPadding(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        padding: EdgeInsets.fromLTRB(
          20,
          2,
          20,
          MediaQuery.viewInsetsOf(context).bottom + 22,
        ),
        child: SingleChildScrollView(
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
                contentInsertionConfiguration: ContentInsertionConfiguration(
                  allowedMimeTypes: const [
                    'image/png',
                    'image/jpeg',
                    'image/gif',
                    'image/webp',
                  ],
                  onContentInserted: (content) async {
                    final attachment = await AttachmentPicker
                        .importKeyboardContent(content);
                    if (attachment != null) {
                      setSheetState(() => attachments.add(attachment));
                    }
                  },
                ),
                decoration: InputDecoration(
                  hintText: 'Add a progress note…',
                  suffixIcon: SpeechInputButton(controller: note),
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: () async {
                      final attachment = await AttachmentPicker.choose(
                        imageOnly: true,
                      );
                      if (attachment != null) {
                        setSheetState(() => attachments.add(attachment));
                      }
                    },
                    icon: const Icon(Icons.image_outlined),
                    label: const Text('Photo'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () async {
                      final attachment = await AttachmentPicker.choose();
                      if (attachment != null) {
                        setSheetState(() => attachments.add(attachment));
                      }
                    },
                    icon: const Icon(Icons.attach_file_rounded),
                    label: const Text('File'),
                  ),
                  for (final attachment in attachments)
                    InputChip(
                      label: Text(
                        attachment.name,
                        overflow: TextOverflow.ellipsis,
                      ),
                      avatar: Icon(
                        attachment.kind == LifeAttachmentKind.image
                            ? Icons.image_outlined
                            : Icons.description_outlined,
                        size: 18,
                      ),
                      onSelected: (_) => AttachmentPicker.open(attachment),
                      onDeleted: () {
                        setSheetState(() => attachments.remove(attachment));
                      },
                    ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        store.completeTaskForDate(task, day);
                        Navigator.pop(context, true);
                      },
                      child: const Text('Done without note'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton(
                      onPressed: () {
                        store.completeTaskForDate(
                          task,
                          day,
                          note: note.text,
                          attachments: attachments,
                        );
                        Navigator.pop(context, true);
                      },
                      child: const Text('Save note'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
  );
  await Future<void>.delayed(const Duration(milliseconds: 300));
  note.dispose();
  return completed ?? false;
}
