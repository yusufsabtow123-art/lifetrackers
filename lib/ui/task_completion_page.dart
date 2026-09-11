import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app/goal_store.dart';
import '../app/life_store.dart';
import '../domain/goal.dart';
import '../domain/life_data.dart';
import '../platform/attachment_picker.dart';
import '../platform/external_link_service.dart';
import 'app_theme.dart';
import 'speech_input_button.dart';

class TaskCompletionPage extends StatefulWidget {
  const TaskCompletionPage({
    super.key,
    required this.store,
    required this.task,
    required this.day,
  }) : goalStore = null,
       goal = null;

  const TaskCompletionPage.forGoal({
    super.key,
    required this.goalStore,
    required this.goal,
    required this.day,
  }) : store = null,
       task = null;

  final LifeStore? store;
  final LifeTask? task;
  final GoalStore? goalStore;
  final Goal? goal;
  final DateTime day;

  @override
  State<TaskCompletionPage> createState() => _TaskCompletionPageState();
}

class _TaskCompletionPageState extends State<TaskCompletionPage> {
  late final TextEditingController _notes;
  late final TextEditingController _amountCompleted;
  final _scrollController = ScrollController();
  final _notesKey = GlobalKey();
  final _amountKey = GlobalKey();
  late TaskCompletionNote _record;
  late List<LifeAttachment> _attachments;
  late List<CompletionPerson> _people;
  bool _saving = false;
  bool _notesError = false;
  bool _amountError = false;
  String? _validationMessage;

  @override
  void initState() {
    super.initState();
    final goalCompletion = widget.goal?.completionFor(widget.day);
    final existing =
        widget.task?.completionNoteFor(widget.day) ?? goalCompletion?.record;
    final completedAt = widget.task == null
        ? goalCompletion?.completedAt
        : widget.task!.repeat == TaskRepeat.none
        ? widget.task!.completedAt
        : null;
    final completionTime =
        existing?.actualEndAt ??
        existing?.recordedAt ??
        completedAt ??
        DateTime.now();
    final scheduledStart = existing?.scheduledStartAt ?? _scheduledOnDay();
    _record =
        existing ??
        TaskCompletionNote(
          day: DateTime(widget.day.year, widget.day.month, widget.day.day),
          recordedAt: completionTime,
          text: goalCompletion?.note ?? '',
          actualEndAt: completionTime,
          scheduledStartAt: scheduledStart,
          scheduledEndAt: scheduledStart?.add(const Duration(hours: 1)),
          locationName: widget.task?.location ?? '',
        );
    _notes = TextEditingController(text: _record.text);
    _amountCompleted = TextEditingController(
      text: _record.amountCompleted == null
          ? ''
          : _editableNumber(_record.amountCompleted!),
    );
    _attachments = _record.attachments.toList();
    _people = _record.people.toList();
  }

  DateTime? _scheduledOnDay() {
    final due = widget.task?.dueAt;
    final reminder = widget.goal?.reminder;
    if (due == null && reminder == null) return null;
    return DateTime(
      widget.day.year,
      widget.day.month,
      widget.day.day,
      due?.hour ?? reminder!.hour,
      due?.minute ?? reminder!.minute,
    );
  }

  String get _title => widget.task?.title ?? widget.goal!.name;

  double? get _plannedAmount {
    final goal = widget.goal;
    if (goal?.plan == null) return null;
    final amount = widget.goalStore!.calculator.actionForDate(
      goal!,
      widget.day,
    );
    return amount > 0 ? amount : null;
  }

  String get _progressUnit => widget.goal?.plan?.unit ?? 'units';

  @override
  void dispose() {
    _notes.dispose();
    _amountCompleted.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final late = _record.isLate;
    return Scaffold(
      backgroundColor: context.isDarkMode
          ? const Color(0xFF0B1013)
          : Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Stack(
          children: [
            if (context.isDarkMode)
              const Positioned.fill(
                child: IgnorePointer(child: _ContourBackdrop()),
              ),
            Column(
              children: [
                _CompletionAppBar(onCopy: _copySummary),
                Expanded(
                  child: CustomScrollView(
                    controller: _scrollController,
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    slivers: [
                      SliverToBoxAdapter(child: _buildHeader(late)),
                      SliverPadding(
                        padding: EdgeInsets.fromLTRB(
                          context.isDarkMode ? 22 : 12,
                          0,
                          context.isDarkMode ? 22 : 12,
                          24,
                        ),
                        sliver: SliverList.list(
                          children: [
                            _OutcomeSection(
                              value: _record.outcome,
                              onChanged: (value) => setState(() {
                                _record = _record.copyWith(outcome: value);
                                _notesError = false;
                                _amountError = false;
                                _validationMessage = null;
                              }),
                            ),
                            if (_record.outcome ==
                                TaskCompletionOutcome.partiallyCompleted)
                              _PartialProgressSection(
                                key: _amountKey,
                                controller: _amountCompleted,
                                plannedAmount: _plannedAmount,
                                unit: _progressUnit,
                                hasError: _amountError,
                              ),
                            if (_validationMessage != null)
                              Padding(
                                padding: const EdgeInsets.only(
                                  left: 44,
                                  right: 4,
                                  bottom: 10,
                                ),
                                child: Text(
                                  _validationMessage!,
                                  style: TextStyle(
                                    color: Theme.of(context).colorScheme.error,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            _RecordDivider(),
                            _RecordRow(
                              icon: Icons.calendar_today_outlined,
                              label: 'When',
                              trailing: const Icon(Icons.expand_more_rounded),
                              onTap: _editWhen,
                              child: Text(
                                _longDateTime(
                                  _record.actualEndAt ?? _record.recordedAt,
                                ),
                                style: const TextStyle(fontSize: 15.5),
                              ),
                            ),
                            _RecordDivider(),
                            _TimeSection(record: _record, onTap: _editTimes),
                            _RecordDivider(),
                            _NotesSection(
                              key: _notesKey,
                              controller: _notes,
                              hasError: _notesError,
                              onAddLink: _addLink,
                              onAddImage: () => _addAttachment(imageOnly: true),
                              onAddFile: _addAttachment,
                            ),
                            _RecordDivider(),
                            _LocationSection(
                              record: _record,
                              onEdit: _editLocation,
                              onOpenMaps: _openMaps,
                            ),
                            _RecordDivider(),
                            _AttachmentsSection(
                              attachments: _attachments,
                              onOpen: AttachmentPicker.open,
                              onAdd: _addAttachment,
                              onRemove: (item) => setState(
                                () => _attachments.removeWhere(
                                  (attachment) => attachment.id == item.id,
                                ),
                              ),
                            ),
                            _RecordDivider(),
                            _PeopleSection(
                              people: _people,
                              onAdd: _addPerson,
                              onRemove: (person) => setState(
                                () => _people.removeWhere(
                                  (item) => item.id == person.id,
                                ),
                              ),
                            ),
                            _RecordDivider(),
                            _EffortSection(
                              value: _record.effort,
                              onChanged: (value) => setState(
                                () => _record = _record.copyWith(effort: value),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                _SaveBar(saving: _saving, onSave: _save),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(bool late) {
    if (context.isDarkMode) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(22, 10, 22, 22),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: context.appBorder.withValues(alpha: .72)),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _title,
              style: const TextStyle(
                fontSize: 25,
                height: 1.15,
                fontWeight: FontWeight.w700,
                letterSpacing: -.45,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 8,
              children: [
                _StatusPill(
                  icon: Icons.check_rounded,
                  label: _record.outcome.label,
                  color: _record.outcome == TaskCompletionOutcome.skipped
                      ? context.appMuted
                      : const Color(0xFF73DA90),
                ),
                if (late)
                  const _StatusPill(
                    icon: Icons.schedule_rounded,
                    label: 'Late',
                    color: AppColors.coral,
                  ),
              ],
            ),
          ],
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 7),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: context.appPanel,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: context.appBorder),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: const BoxDecoration(
                color: AppColors.softAmber,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.menu_book_outlined,
                color: AppColors.goldText,
                size: 23,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Wrap(
                    spacing: 7,
                    runSpacing: 5,
                    children: [
                      _CompactStatusPill(
                        icon: Icons.check_circle_rounded,
                        label: _record.outcome.label,
                        color: _record.outcome == TaskCompletionOutcome.skipped
                            ? context.appMuted
                            : AppColors.greenText,
                        background: context.appSoftGreen,
                      ),
                      if (late)
                        _CompactStatusPill(
                          icon: Icons.schedule_rounded,
                          label: 'Late',
                          color: AppColors.coralText,
                          background: context.appSoftRed,
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (_saving) return;
    final partial = _record.outcome == TaskCompletionOutcome.partiallyCompleted;
    final enteredAmount = double.tryParse(_amountCompleted.text.trim());
    final plannedAmount = _plannedAmount;
    if (partial && plannedAmount != null) {
      final invalid =
          enteredAmount == null ||
          enteredAmount <= 0 ||
          enteredAmount >= plannedAmount;
      if (invalid) {
        setState(() {
          _amountError = true;
          _notesError = false;
          _validationMessage =
              'Not completed — enter an amount greater than 0 and less than ${_editableNumber(plannedAmount)} $_progressUnit.';
        });
        await _reveal(_amountKey);
        return;
      }
    } else if (partial && _notes.text.trim().isEmpty) {
      setState(() {
        _notesError = true;
        _amountError = false;
        _validationMessage =
            'Not completed — add a note explaining what was completed.';
      });
      await _reveal(_notesKey);
      return;
    }
    setState(() => _saving = true);
    final updated = _record.copyWith(
      text: _notes.text.trim(),
      attachments: _attachments,
      people: _people,
      amountCompleted: partial && plannedAmount != null ? enteredAmount : null,
      clearAmountCompleted: !partial || plannedAmount == null,
    );
    if (widget.task != null) {
      await widget.store!.saveTaskCompletionRecord(widget.task!, updated);
    } else {
      await widget.goalStore!.saveTodayActionCompletionRecord(
        widget.goal!.id,
        updated,
      );
    }
    if (!mounted) return;
    HapticFeedback.lightImpact();
    Navigator.pop(context, true);
  }

  Future<void> _reveal(GlobalKey key) async {
    await Future<void>.delayed(Duration.zero);
    final target = key.currentContext;
    if (target == null || !target.mounted) return;
    await Scrollable.ensureVisible(
      target,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
      alignment: .18,
    );
  }

  Future<void> _copySummary() async {
    final text =
        '$_title\n${_record.outcome.label} · '
        '${_longDateTime(_record.actualEndAt ?? _record.recordedAt)}\n'
        '${_notes.text.trim()}';
    await Clipboard.setData(ClipboardData(text: text.trim()));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Completion summary copied.')),
      );
    }
  }

  Future<void> _editWhen() async {
    final current = _record.actualEndAt ?? _record.recordedAt;
    final date = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(current),
    );
    if (time == null) return;
    final value = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );
    setState(
      () => _record = _record.copyWith(actualEndAt: value, recordedAt: value),
    );
  }

  Future<void> _editTimes() async {
    final result = await showModalBottomSheet<_TimeEditResult>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      builder: (context) => _TimeEditor(record: _record),
    );
    if (result == null) return;
    setState(
      () => _record = _record.copyWith(
        actualStartAt: result.actualStart,
        clearActualStart: result.actualStart == null,
        actualEndAt: result.actualEnd,
        clearActualEnd: result.actualEnd == null,
        scheduledStartAt: result.scheduledStart,
        clearScheduledStart: result.scheduledStart == null,
        scheduledEndAt: result.scheduledEnd,
        clearScheduledEnd: result.scheduledEnd == null,
      ),
    );
  }

  Future<void> _addLink() async {
    final controller = TextEditingController(text: 'https://');
    final link = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add link'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.url,
          decoration: const InputDecoration(hintText: 'https://example.com'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Add'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (link == null || link.isEmpty) return;
    final prefix = _notes.text.isEmpty || RegExp(r'\s$').hasMatch(_notes.text)
        ? ''
        : ' ';
    _notes.text = '${_notes.text}$prefix$link';
    _notes.selection = TextSelection.collapsed(offset: _notes.text.length);
  }

  Future<void> _addAttachment({bool imageOnly = false}) async {
    final item = await AttachmentPicker.choose(imageOnly: imageOnly);
    if (item != null && mounted) setState(() => _attachments.add(item));
  }

  Future<void> _editLocation() async {
    final name = TextEditingController(text: _record.locationName);
    final address = TextEditingController(text: _record.locationAddress);
    final result = await showDialog<(String, String)>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Completion location'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: name,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'Place name'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: address,
              decoration: const InputDecoration(labelText: 'Street address'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(context, (name.text.trim(), address.text.trim())),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    name.dispose();
    address.dispose();
    if (result != null) {
      setState(
        () => _record = _record.copyWith(
          locationName: result.$1,
          locationAddress: result.$2,
        ),
      );
    }
  }

  Future<void> _openMaps() async {
    final query = _record.locationAddress.isNotEmpty
        ? _record.locationAddress
        : _record.locationName;
    if (query.isEmpty) {
      await _editLocation();
      return;
    }
    await ExternalLinkService.open(
      'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(query)}',
    );
  }

  Future<void> _addPerson() async {
    final name = TextEditingController();
    final phone = TextEditingController();
    LifeAttachment? photo;
    final person = await showDialog<CompletionPerson>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Add person'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: name,
                autofocus: true,
                decoration: const InputDecoration(labelText: 'Name'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: phone,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: 'Phone number'),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: () async {
                  final item = await AttachmentPicker.choose(imageOnly: true);
                  if (item != null) setDialogState(() => photo = item);
                },
                icon: const Icon(Icons.add_a_photo_outlined),
                label: Text(photo == null ? 'Add contact photo' : photo!.name),
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
                if (name.text.trim().isEmpty) return;
                Navigator.pop(
                  context,
                  CompletionPerson(
                    id: 'person-${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}',
                    name: name.text.trim(),
                    phone: phone.text.trim(),
                    imagePath: photo?.path ?? '',
                  ),
                );
              },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
    name.dispose();
    phone.dispose();
    if (person != null && mounted) setState(() => _people.add(person));
  }
}

class _CompletionAppBar extends StatelessWidget {
  const _CompletionAppBar({required this.onCopy});
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: context.isDarkMode ? 62 : 52,
    child: Row(
      children: [
        const SizedBox(width: 6),
        IconButton(
          tooltip: 'Back',
          onPressed: () => Navigator.maybePop(context),
          icon: const Icon(Icons.arrow_back_rounded, size: 28),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            'Completion record',
            style: TextStyle(
              fontSize: context.isDarkMode ? 22 : 20,
              fontWeight: FontWeight.w700,
              letterSpacing: -.35,
            ),
          ),
        ),
        PopupMenuButton<String>(
          tooltip: 'More options',
          onSelected: (value) {
            if (value == 'copy') onCopy();
          },
          itemBuilder: (_) => const [
            PopupMenuItem(value: 'copy', child: Text('Copy summary')),
          ],
        ),
        const SizedBox(width: 6),
      ],
    ),
  );
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({
    required this.icon,
    required this.label,
    required this.color,
  });
  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(12, 7, 14, 7),
    decoration: BoxDecoration(
      color: color.withValues(alpha: .11),
      borderRadius: BorderRadius.circular(30),
      border: Border.all(color: color.withValues(alpha: .88)),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          child: Icon(icon, color: Colors.black, size: 17),
        ),
        const SizedBox(width: 9),
        Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 15.5,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    ),
  );
}

class _CompactStatusPill extends StatelessWidget {
  const _CompactStatusPill({
    required this.icon,
    required this.label,
    required this.color,
    required this.background,
  });
  final IconData icon;
  final String label;
  final Color color;
  final Color background;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
    decoration: BoxDecoration(
      color: background,
      borderRadius: BorderRadius.circular(30),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 5),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: color,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    ),
  );
}

class _OutcomeSection extends StatelessWidget {
  const _OutcomeSection({required this.value, required this.onChanged});
  final TaskCompletionOutcome value;
  final ValueChanged<TaskCompletionOutcome> onChanged;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.symmetric(vertical: context.isDarkMode ? 14 : 9),
    child: Column(
      children: [
        const _RowHeading(icon: Icons.outlined_flag_rounded, label: 'Outcome'),
        SizedBox(height: context.isDarkMode ? 11 : 6),
        Padding(
          padding: const EdgeInsets.only(left: 44),
          child: _Segmented<TaskCompletionOutcome>(
            values: TaskCompletionOutcome.values,
            selected: value,
            label: (item) => item.label,
            itemKey: (item) => Key('completion-outcome-${item.name}'),
            icon: (item) => switch (item) {
              TaskCompletionOutcome.completed => Icons.check_circle_rounded,
              TaskCompletionOutcome.partiallyCompleted => Icons.circle_outlined,
              TaskCompletionOutcome.skipped => Icons.cancel_outlined,
            },
            activeColor: context.isDarkMode
                ? const Color(0xFF73DA90)
                : AppColors.greenText,
            onChanged: onChanged,
          ),
        ),
      ],
    ),
  );
}

class _RecordRow extends StatelessWidget {
  const _RecordRow({
    required this.icon,
    required this.label,
    required this.child,
    this.trailing,
    this.onTap,
  });
  final IconData icon;
  final String label;
  final Widget child;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    child: Padding(
      padding: EdgeInsets.symmetric(vertical: context.isDarkMode ? 14 : 9),
      child: Row(
        children: [
          Icon(icon, size: 23, color: context.appText),
          const SizedBox(width: 15),
          SizedBox(
            width: 70,
            child: Text(label, style: const TextStyle(fontSize: 15)),
          ),
          Expanded(child: child),
          if (trailing != null) ...[
            const SizedBox(width: 8),
            IconTheme(
              data: IconThemeData(color: context.appMuted, size: 22),
              child: trailing!,
            ),
          ],
        ],
      ),
    ),
  );
}

class _TimeSection extends StatelessWidget {
  const _TimeSection({required this.record, required this.onTap});
  final TaskCompletionNote record;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final actual = _duration(record.actualStartAt, record.actualEndAt);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: context.isDarkMode ? 14 : 9),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.timer_outlined, size: 24),
            const SizedBox(width: 15),
            const SizedBox(
              width: 70,
              child: Padding(
                padding: EdgeInsets.only(top: 3),
                child: Text('Time', style: TextStyle(fontSize: 15)),
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    actual == null
                        ? 'Not tracked'
                        : '${actual.inMinutes} min actual',
                    style: TextStyle(
                      fontSize: context.isDarkMode ? 21 : 17,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    _timeComparison(record),
                    style: TextStyle(fontSize: 12.5, color: context.appMuted),
                  ),
                  const SizedBox(height: 5),
                  Row(
                    children: [
                      Icon(
                        Icons.bar_chart_rounded,
                        size: 17,
                        color: context.appMuted,
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          actual == null
                              ? 'Add the actual start and finish time'
                              : 'Tracked automatically (Start → Finish)',
                          style: TextStyle(
                            fontSize: 11.5,
                            color: context.appMuted,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Icon(Icons.expand_more_rounded, color: context.appMuted),
          ],
        ),
      ),
    );
  }
}

class _PartialProgressSection extends StatelessWidget {
  const _PartialProgressSection({
    super.key,
    required this.controller,
    required this.plannedAmount,
    required this.unit,
    required this.hasError,
  });

  final TextEditingController controller;
  final double? plannedAmount;
  final String unit;
  final bool hasError;

  @override
  Widget build(BuildContext context) {
    if (plannedAmount == null) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(44, 0, 4, 12),
        child: Text(
          'This task has no numeric amount, so add a note describing the part you completed.',
          style: TextStyle(fontSize: 12, color: context.appMuted, height: 1.3),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(44, 0, 4, 12),
      child: TextField(
        key: const Key('completion-partial-amount'),
        controller: controller,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(
          labelText: 'Amount completed',
          hintText: 'Less than ${_editableNumber(plannedAmount!)}',
          suffixText: unit,
          errorText: hasError ? 'Enter the partial amount.' : null,
        ),
      ),
    );
  }
}

class _NotesSection extends StatelessWidget {
  const _NotesSection({
    super.key,
    required this.controller,
    required this.hasError,
    required this.onAddLink,
    required this.onAddImage,
    required this.onAddFile,
  });
  final TextEditingController controller;
  final bool hasError;
  final VoidCallback onAddLink;
  final VoidCallback onAddImage;
  final VoidCallback onAddFile;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.symmetric(vertical: context.isDarkMode ? 14 : 9),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(top: 7),
          child: Icon(Icons.article_outlined, size: 23),
        ),
        const SizedBox(width: 15),
        const SizedBox(
          width: 70,
          child: Padding(
            padding: EdgeInsets.only(top: 7),
            child: Text('Notes', style: TextStyle(fontSize: 15)),
          ),
        ),
        Expanded(
          child: Container(
            padding: const EdgeInsets.fromLTRB(12, 3, 8, 8),
            decoration: BoxDecoration(
              color: context.appRaised.withValues(alpha: .55),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: hasError
                    ? Theme.of(context).colorScheme.error
                    : context.appBorder,
                width: hasError ? 1.5 : 1,
              ),
            ),
            child: Column(
              children: [
                TextField(
                  key: const Key('completion-record-notes'),
                  controller: controller,
                  minLines: context.isDarkMode ? 3 : 2,
                  maxLines: 7,
                  style: const TextStyle(fontSize: 14, height: 1.4),
                  decoration: const InputDecoration(
                    filled: false,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    hintText: 'What happened? What did you learn?',
                  ),
                ),
                if (hasError)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(4, 0, 4, 7),
                      child: Text(
                        'Not completed — A note is required when this task has no numeric amount.',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _ToolbarButton(
                      icon: Icons.link_rounded,
                      tooltip: 'Add link',
                      onPressed: onAddLink,
                    ),
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: context.appRaised,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: context.appBorder),
                      ),
                      child: Center(
                        child: SpeechInputButton(controller: controller),
                      ),
                    ),
                    _ToolbarButton(
                      icon: Icons.image_outlined,
                      tooltip: 'Add image',
                      onPressed: onAddImage,
                    ),
                    _ToolbarButton(
                      icon: Icons.attach_file_rounded,
                      tooltip: 'Add file',
                      onPressed: onAddFile,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}

class _ToolbarButton extends StatelessWidget {
  const _ToolbarButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  @override
  Widget build(BuildContext context) => Container(
    width: 38,
    height: 38,
    decoration: BoxDecoration(
      color: context.appRaised,
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: context.appBorder),
    ),
    child: IconButton(
      tooltip: tooltip,
      padding: EdgeInsets.zero,
      onPressed: onPressed,
      icon: Icon(icon, size: 22),
    ),
  );
}

class _LocationSection extends StatelessWidget {
  const _LocationSection({
    required this.record,
    required this.onEdit,
    required this.onOpenMaps,
  });
  final TaskCompletionNote record;
  final VoidCallback onEdit;
  final VoidCallback onOpenMaps;
  @override
  Widget build(BuildContext context) {
    final empty = record.locationName.isEmpty && record.locationAddress.isEmpty;
    return _RecordRow(
      icon: Icons.location_on_outlined,
      label: 'Location',
      onTap: onEdit,
      trailing: const Icon(Icons.expand_more_rounded),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  empty ? 'Add location' : record.locationName,
                  style: TextStyle(
                    fontSize: 15.5,
                    color: empty ? context.appMuted : context.appText,
                  ),
                ),
                if (record.locationAddress.isNotEmpty)
                  Text(
                    record.locationAddress,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12.5, color: context.appMuted),
                  ),
              ],
            ),
          ),
          if (!empty)
            TextButton.icon(
              onPressed: onOpenMaps,
              icon: const Icon(Icons.open_in_new_rounded, size: 18),
              label: const Text(
                'Open\nin Maps',
                style: TextStyle(fontSize: 11.5),
              ),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.coral,
                padding: const EdgeInsets.symmetric(horizontal: 6),
              ),
            ),
        ],
      ),
    );
  }
}

class _AttachmentsSection extends StatelessWidget {
  const _AttachmentsSection({
    required this.attachments,
    required this.onOpen,
    required this.onAdd,
    required this.onRemove,
  });
  final List<LifeAttachment> attachments;
  final ValueChanged<LifeAttachment> onOpen;
  final VoidCallback onAdd;
  final ValueChanged<LifeAttachment> onRemove;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.symmetric(vertical: context.isDarkMode ? 14 : 9),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Icon(Icons.attach_file_rounded, size: 24),
            const SizedBox(width: 15),
            const Expanded(
              child: Text('Attachments', style: TextStyle(fontSize: 15)),
            ),
            Icon(Icons.expand_more_rounded, color: context.appMuted),
          ],
        ),
        SizedBox(height: context.isDarkMode ? 10 : 6),
        Padding(
          padding: const EdgeInsets.only(left: 39, right: 30),
          child: Wrap(
            spacing: 9,
            runSpacing: 9,
            children: [
              for (final item in attachments)
                _AttachmentCard(
                  item: item,
                  onOpen: () => onOpen(item),
                  onRemove: () => onRemove(item),
                ),
              _AddCard(onTap: onAdd),
            ],
          ),
        ),
      ],
    ),
  );
}

class _AttachmentCard extends StatelessWidget {
  const _AttachmentCard({
    required this.item,
    required this.onOpen,
    required this.onRemove,
  });
  final LifeAttachment item;
  final VoidCallback onOpen;
  final VoidCallback onRemove;
  @override
  Widget build(BuildContext context) {
    final isImage =
        item.kind == LifeAttachmentKind.image && File(item.path).existsSync();
    return Tooltip(
      message: 'Tap to open · Hold to remove',
      child: InkWell(
        onTap: onOpen,
        onLongPress: onRemove,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          constraints: const BoxConstraints(minWidth: 92, maxWidth: 180),
          height: 70,
          decoration: BoxDecoration(
            color: context.appRaised,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: context.appBorder),
          ),
          clipBehavior: Clip.antiAlias,
          child: isImage
              ? Image.file(
                  File(item.path),
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) =>
                      const Icon(Icons.broken_image_outlined),
                )
              : Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.picture_as_pdf_rounded,
                        color: AppColors.coral,
                        size: 28,
                      ),
                      const SizedBox(width: 9),
                      Flexible(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 12.5),
                            ),
                            Text(
                              _fileSize(item.sizeBytes),
                              style: TextStyle(
                                fontSize: 10.5,
                                color: context.appMuted,
                              ),
                            ),
                          ],
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

class _AddCard extends StatelessWidget {
  const _AddCard({required this.onTap});
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(8),
    child: CustomPaint(
      painter: _DashedBorderPainter(color: context.appMuted, radius: 8),
      child: SizedBox(
        width: 70,
        height: 70,
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_rounded, size: 25),
            SizedBox(height: 2),
            Text('Add', style: TextStyle(fontSize: 11)),
          ],
        ),
      ),
    ),
  );
}

class _PeopleSection extends StatelessWidget {
  const _PeopleSection({
    required this.people,
    required this.onAdd,
    required this.onRemove,
  });
  final List<CompletionPerson> people;
  final VoidCallback onAdd;
  final ValueChanged<CompletionPerson> onRemove;
  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.symmetric(vertical: context.isDarkMode ? 14 : 9),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Icon(Icons.people_outline_rounded, size: 24),
            const SizedBox(width: 15),
            const Expanded(
              child: Text('People involved', style: TextStyle(fontSize: 15)),
            ),
            Icon(Icons.expand_more_rounded, color: context.appMuted),
          ],
        ),
        SizedBox(height: context.isDarkMode ? 10 : 6),
        Padding(
          padding: const EdgeInsets.only(left: 39, right: 30),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final person in people)
                InputChip(
                  avatar: _PersonAvatar(person: person),
                  label: Text(person.name),
                  deleteIcon: const Icon(Icons.close_rounded, size: 18),
                  onDeleted: () => onRemove(person),
                  onPressed: person.phone.isEmpty
                      ? null
                      : () => Clipboard.setData(
                          ClipboardData(text: person.phone),
                        ),
                ),
              InkWell(
                onTap: onAdd,
                borderRadius: BorderRadius.circular(22),
                child: CustomPaint(
                  painter: _DashedBorderPainter(
                    color: context.appMuted,
                    radius: 22,
                  ),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 11),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.add_rounded, size: 18),
                        SizedBox(width: 7),
                        Text('Add person'),
                      ],
                    ),
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

class _PersonAvatar extends StatelessWidget {
  const _PersonAvatar({required this.person});
  final CompletionPerson person;
  @override
  Widget build(BuildContext context) {
    final file = person.imagePath.isEmpty ? null : File(person.imagePath);
    if (file != null && file.existsSync()) {
      return CircleAvatar(backgroundImage: FileImage(file));
    }
    return CircleAvatar(
      child: Text(
        person.name.isEmpty ? '?' : person.name.characters.first.toUpperCase(),
      ),
    );
  }
}

class _EffortSection extends StatelessWidget {
  const _EffortSection({required this.value, required this.onChanged});
  final TaskCompletionEffort value;
  final ValueChanged<TaskCompletionEffort> onChanged;
  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.symmetric(vertical: context.isDarkMode ? 14 : 9),
    child: Row(
      children: [
        const Icon(Icons.bar_chart_rounded, size: 24),
        const SizedBox(width: 15),
        const SizedBox(
          width: 70,
          child: Text('Effort', style: TextStyle(fontSize: 15)),
        ),
        Expanded(
          child: _Segmented<TaskCompletionEffort>(
            values: TaskCompletionEffort.values,
            selected: value,
            label: (item) => item.label,
            activeColor: AppColors.coral,
            onChanged: onChanged,
          ),
        ),
      ],
    ),
  );
}

class _Segmented<T> extends StatelessWidget {
  const _Segmented({
    required this.values,
    required this.selected,
    required this.label,
    required this.activeColor,
    required this.onChanged,
    this.icon,
    this.itemKey,
  });
  final List<T> values;
  final T selected;
  final String Function(T) label;
  final IconData Function(T)? icon;
  final Key Function(T)? itemKey;
  final Color activeColor;
  final ValueChanged<T> onChanged;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      for (var index = 0; index < values.length; index++)
        Expanded(
          child: InkWell(
            key: itemKey?.call(values[index]),
            onTap: () => onChanged(values[index]),
            borderRadius: BorderRadius.horizontal(
              left: index == 0 ? const Radius.circular(9) : Radius.zero,
              right: index == values.length - 1
                  ? const Radius.circular(9)
                  : Radius.zero,
            ),
            child: AnimatedContainer(
              duration: LifeMotion.quick,
              height: context.isDarkMode ? 46 : 38,
              decoration: BoxDecoration(
                color: values[index] == selected
                    ? activeColor.withValues(alpha: .12)
                    : context.appRaised.withValues(alpha: .35),
                borderRadius: BorderRadius.horizontal(
                  left: index == 0 ? const Radius.circular(9) : Radius.zero,
                  right: index == values.length - 1
                      ? const Radius.circular(9)
                      : Radius.zero,
                ),
                border: Border.all(
                  color: values[index] == selected
                      ? activeColor
                      : context.appBorder,
                  width: values[index] == selected ? 1.3 : 1,
                ),
              ),
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 5),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (icon != null) ...[
                          Icon(
                            icon!(values[index]),
                            size: 19,
                            color: values[index] == selected
                                ? activeColor
                                : context.appText,
                          ),
                          const SizedBox(width: 6),
                        ],
                        Text(
                          label(values[index]),
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          style: TextStyle(
                            fontSize: 13.2,
                            color: values[index] == selected
                                ? activeColor
                                : context.appText,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
    ],
  );
}

class _DashedBorderPainter extends CustomPainter {
  const _DashedBorderPainter({required this.color, required this.radius});

  final Color color;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(radius)),
      );
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        canvas.drawPath(
          metric.extractPath(distance, (distance + 5).clamp(0, metric.length)),
          paint,
        );
        distance += 9;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedBorderPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.radius != radius;
}

class _RowHeading extends StatelessWidget {
  const _RowHeading({required this.icon, required this.label});
  final IconData icon;
  final String label;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(icon, size: 23),
      const SizedBox(width: 15),
      Text(label, style: const TextStyle(fontSize: 15)),
    ],
  );
}

class _RecordDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) =>
      Divider(color: context.appBorder.withValues(alpha: .74), height: 1);
}

class _SaveBar extends StatelessWidget {
  const _SaveBar({required this.saving, required this.onSave});
  final bool saving;
  final VoidCallback onSave;
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: EdgeInsets.fromLTRB(
      context.isDarkMode ? 22 : 12,
      context.isDarkMode ? 10 : 7,
      context.isDarkMode ? 22 : 12,
      context.isDarkMode ? 12 : 8,
    ),
    decoration: BoxDecoration(
      color: (context.isDarkMode ? const Color(0xFF0B1013) : context.appPanel)
          .withValues(alpha: .97),
      border: Border(
        top: BorderSide(color: context.appBorder.withValues(alpha: .6)),
      ),
    ),
    child: SizedBox(
      height: context.isDarkMode ? 50 : 46,
      child: FilledButton(
        key: const Key('save-completion-record'),
        onPressed: saving ? null : onSave,
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.coral,
          foregroundColor: context.isDarkMode ? Colors.black : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        child: saving
            ? const SizedBox.square(
                dimension: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Text(
                'Save completion',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
              ),
      ),
    ),
  );
}

class _ContourBackdrop extends StatelessWidget {
  const _ContourBackdrop();
  @override
  Widget build(BuildContext context) => CustomPaint(
    painter: _ContourPainter(
      color: context.appBorder.withValues(
        alpha: context.isDarkMode ? .18 : .08,
      ),
    ),
  );
}

class _ContourPainter extends CustomPainter {
  const _ContourPainter({required this.color});
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = .7;
    for (var line = 0; line < 6; line++) {
      final offset = line * 18.0;
      final path = Path()
        ..moveTo(size.width * .58, 36 + offset)
        ..cubicTo(
          size.width * .73,
          18 + offset,
          size.width * .73,
          95 + offset,
          size.width * .84,
          82 + offset,
        )
        ..cubicTo(
          size.width * .93,
          71 + offset,
          size.width * .89,
          135 + offset,
          size.width + 20,
          122 + offset,
        );
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(_ContourPainter oldDelegate) => oldDelegate.color != color;
}

String _editableNumber(double value) => value == value.roundToDouble()
    ? value.toInt().toString()
    : value
          .toStringAsFixed(2)
          .replaceFirst(RegExp(r'0+$'), '')
          .replaceFirst(RegExp(r'\.$'), '');

class _TimeEditResult {
  const _TimeEditResult({
    this.actualStart,
    this.actualEnd,
    this.scheduledStart,
    this.scheduledEnd,
  });
  final DateTime? actualStart;
  final DateTime? actualEnd;
  final DateTime? scheduledStart;
  final DateTime? scheduledEnd;
}

class _TimeEditor extends StatefulWidget {
  const _TimeEditor({required this.record});
  final TaskCompletionNote record;
  @override
  State<_TimeEditor> createState() => _TimeEditorState();
}

class _TimeEditorState extends State<_TimeEditor> {
  late DateTime? actualStart = widget.record.actualStartAt;
  late DateTime? actualEnd = widget.record.actualEndAt;
  late DateTime? scheduledStart = widget.record.scheduledStartAt;
  late DateTime? scheduledEnd = widget.record.scheduledEndAt;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.fromLTRB(
      20,
      8,
      20,
      MediaQuery.viewInsetsOf(context).bottom + 20,
    ),
    child: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Scheduled and actual time',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 14),
          _TimePickerRow(
            label: 'Planned start',
            value: scheduledStart,
            onChanged: (value) => setState(() => scheduledStart = value),
          ),
          _TimePickerRow(
            label: 'Planned finish',
            value: scheduledEnd,
            onChanged: (value) => setState(() => scheduledEnd = value),
          ),
          _TimePickerRow(
            label: 'Actual start',
            value: actualStart,
            onChanged: (value) => setState(() => actualStart = value),
          ),
          _TimePickerRow(
            label: 'Actual finish',
            value: actualEnd,
            onChanged: (value) => setState(() => actualEnd = value),
          ),
          const SizedBox(height: 14),
          FilledButton(
            onPressed: () => Navigator.pop(
              context,
              _TimeEditResult(
                actualStart: actualStart,
                actualEnd: actualEnd,
                scheduledStart: scheduledStart,
                scheduledEnd: scheduledEnd,
              ),
            ),
            child: const Text('Save time'),
          ),
        ],
      ),
    ),
  );
}

class _TimePickerRow extends StatelessWidget {
  const _TimePickerRow({
    required this.label,
    required this.value,
    required this.onChanged,
  });
  final String label;
  final DateTime? value;
  final ValueChanged<DateTime?> onChanged;
  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: EdgeInsets.zero,
    title: Text(label),
    subtitle: Text(value == null ? 'Not set' : _shortDateTime(value!)),
    trailing: Wrap(
      children: [
        if (value != null)
          IconButton(
            onPressed: () => onChanged(null),
            icon: const Icon(Icons.close_rounded),
          ),
        IconButton(
          onPressed: () async {
            final base = value ?? DateTime.now();
            final date = await showDatePicker(
              context: context,
              initialDate: base,
              firstDate: DateTime(2000),
              lastDate: DateTime(2100),
            );
            if (date == null || !context.mounted) return;
            final time = await showTimePicker(
              context: context,
              initialTime: TimeOfDay.fromDateTime(base),
            );
            if (time != null) {
              onChanged(
                DateTime(
                  date.year,
                  date.month,
                  date.day,
                  time.hour,
                  time.minute,
                ),
              );
            }
          },
          icon: const Icon(Icons.edit_calendar_outlined),
        ),
      ],
    ),
  );
}

Duration? _duration(DateTime? start, DateTime? end) =>
    start == null || end == null || !end.isAfter(start)
    ? null
    : end.difference(start);

String _timeComparison(TaskCompletionNote record) {
  final planned =
      record.scheduledStartAt == null || record.scheduledEndAt == null
      ? 'Planned: not set'
      : 'Planned ${_time(record.scheduledStartAt!)} – ${_time(record.scheduledEndAt!)}';
  final actual = record.actualStartAt == null || record.actualEndAt == null
      ? 'Actual: not tracked'
      : 'Actual ${_time(record.actualStartAt!)} – ${_time(record.actualEndAt!)}';
  return '$planned  |  $actual';
}

String _longDateTime(DateTime value) =>
    '${_weekdays[value.weekday - 1]}, ${_months[value.month - 1]} ${value.day} · ${_time(value)}';
String _shortDateTime(DateTime value) =>
    '${_months[value.month - 1]} ${value.day}, ${value.year} · ${_time(value)}';
String _time(DateTime value) {
  final hour = value.hour % 12 == 0 ? 12 : value.hour % 12;
  return '$hour:${value.minute.toString().padLeft(2, '0')} ${value.hour < 12 ? 'AM' : 'PM'}';
}

String _fileSize(int bytes) => bytes <= 0
    ? ''
    : bytes < 1024
    ? '$bytes B'
    : bytes < 1024 * 1024
    ? '${(bytes / 1024).round()} KB'
    : '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';

const _weekdays = [
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
  'Sunday',
];
const _months = [
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
];
