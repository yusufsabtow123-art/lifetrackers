import 'package:flutter/material.dart';

import '../app/goal_store.dart';
import '../app/theme_controller.dart';
import '../domain/goal.dart';
import '../platform/goal_notification_service.dart';
import '../platform/goal_widget_service.dart';
import 'app_theme.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({
    super.key,
    required this.store,
    required this.settings,
    this.notificationService,
  });

  final GoalStore store;
  final AppSettingsController settings;
  final GoalNotificationService? notificationService;

  @override
  Widget build(BuildContext context) {
    final entries = <_SettingsEntry>[
      _SettingsEntry(
        'Appearance',
        'Light or dark mode, your accent, and its automatic matching color.',
        Icons.palette_outlined,
        () => _open(context, 'Appearance', _AppearanceSettings(settings)),
      ),
      _SettingsEntry(
        'Board and categories',
        'Category movement and visibility, progress labels, and Abandoned.',
        Icons.view_kanban_outlined,
        () => _open(context, 'Board and categories', _BoardSettings(settings)),
      ),
      _SettingsEntry(
        'Opened goals',
        'Simple or Detailed defaults, remembered views, and milestones.',
        Icons.view_agenda_outlined,
        () => _open(context, 'Opened goals', _OpenedGoalSettings(settings)),
      ),
      _SettingsEntry(
        'Notifications and check-ins',
        'Default timing, frequency, quiet hours, and end-of-day review.',
        Icons.notifications_outlined,
        () => _open(
          context,
          'Notifications and check-ins',
          _NotificationSettings(settings, notificationService),
        ),
      ),
      _SettingsEntry(
        'Plans and adaptation',
        'Automatic starts, connected goals, and schedule-warning behavior.',
        Icons.route_outlined,
        () => _open(context, 'Plans and adaptation', _PlanSettings(settings)),
      ),
      _SettingsEntry(
        'Android widgets',
        'Choose which actions, cards, categories, and progress appear.',
        Icons.widgets_outlined,
        () =>
            _open(context, 'Android widgets', _WidgetSettings(settings, store)),
      ),
      _SettingsEntry(
        'Local data',
        'Readable Markdown files and the folder containing your goals.',
        Icons.folder_outlined,
        () => _open(context, 'Local data', _LocalDataSettings(store)),
      ),
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 36),
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Settings', style: Theme.of(context).textTheme.displaySmall),
              const SizedBox(height: 7),
              Text(
                'Everything saves automatically on this device. Open only the '
                'section you need.',
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: context.appMuted),
              ),
              const SizedBox(height: 22),
              Text(
                'Preferences',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 10),
              Container(
                decoration: BoxDecoration(
                  color: context.appPanel,
                  border: Border.all(color: context.appBorder),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    for (var index = 0; index < entries.length; index++) ...[
                      _SettingsTile(entry: entries[index]),
                      if (index < entries.length - 1)
                        Divider(color: context.appBorder),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _open(BuildContext context, String title, Widget child) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => Scaffold(
          appBar: AppBar(title: Text(title)),
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 36),
              child: Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 760),
                  child: child,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SettingsEntry {
  const _SettingsEntry(this.title, this.description, this.icon, this.onTap);
  final String title;
  final String description;
  final IconData icon;
  final VoidCallback onTap;
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({required this.entry});
  final _SettingsEntry entry;

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.transparent,
    child: InkWell(
      borderRadius: BorderRadius.circular(7),
      onTap: entry.onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(entry.icon, size: 18, color: context.appMuted),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.title,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    entry.description,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded),
          ],
        ),
      ),
    ),
  );
}

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    ),
  );
}

class _AppearanceSettings extends StatelessWidget {
  const _AppearanceSettings(this.settings);
  final AppSettingsController settings;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: settings,
    builder: (context, _) => _SettingsCard(
      children: [
        Text('Color mode', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final appearance in AppAppearance.values)
              ChoiceChip(
                key: Key('appearance-${appearance.name}'),
                selected: settings.appearance == appearance,
                avatar: Icon(appearance.icon, size: 18),
                label: Text(appearance.label),
                onSelected: (_) => settings.setAppearance(appearance),
              ),
          ],
        ),
        const SizedBox(height: 24),
        Text('Accent color', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 6),
        const Text(
          'The app automatically creates a complementary second color for '
          'reminders and secondary actions.',
        ),
        const SizedBox(height: 14),
        for (final group in AppAccentGroup.values) ...[
          Text(group.label, style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 8),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final accent in AppAccentColor.values.where(
                (item) => item.group == group,
              ))
                _AccentSwatch(
                  accent: accent,
                  selected: settings.accentColor == accent,
                  onTap: () => settings.setAccentColor(accent),
                ),
            ],
          ),
          const SizedBox(height: 16),
        ],
        Row(
          children: [
            Expanded(
              child: _ColorPreview(
                label: 'Main color',
                color: settings.accentColor.color,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _ColorPreview(
                label: 'Matching color',
                color: settings.accentColor.complementaryColor,
              ),
            ),
          ],
        ),
      ],
    ),
  );
}

class _AccentSwatch extends StatelessWidget {
  const _AccentSwatch({
    required this.accent,
    required this.selected,
    required this.onTap,
  });
  final AppAccentColor accent;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: accent.label,
    child: InkWell(
      key: Key('accent-${accent.name}'),
      onTap: onTap,
      borderRadius: BorderRadius.circular(13),
      child: Container(
        width: 46,
        height: 46,
        decoration: BoxDecoration(
          color: accent.color,
          borderRadius: BorderRadius.circular(13),
          border: Border.all(
            color: selected ? context.appText : context.appBorder,
            width: selected ? 3 : 1,
          ),
        ),
        child: selected
            ? Icon(Icons.check_rounded, color: accent.foregroundColor)
            : null,
      ),
    ),
  );
}

class _ColorPreview extends StatelessWidget {
  const _ColorPreview({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(13),
    decoration: BoxDecoration(
      color: Color.alphaBlend(
        color.withValues(alpha: context.isDarkMode ? .24 : .13),
        context.appPanel,
      ),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: color.withValues(alpha: .5)),
    ),
    child: Text(
      label,
      style: TextStyle(color: color, fontWeight: FontWeight.w700),
    ),
  );
}

class _BoardSettings extends StatelessWidget {
  const _BoardSettings(this.settings);
  final AppSettingsController settings;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: settings,
    builder: (context, _) => _SettingsCard(
      children: [
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Use categories'),
          subtitle: const Text(
            'Master switch for Faith, Health, Mind, Body, Finances, and other areas.',
          ),
          secondary: const Icon(Icons.category_outlined),
          value: settings.categoriesEnabled,
          onChanged: settings.setCategoriesEnabled,
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Move between categories by dragging'),
          subtitle: const Text(
            'Drop a card on a category at the top. Its workflow column stays the same.',
          ),
          secondary: const Icon(Icons.drag_indicator_rounded),
          value: settings.categoryDragEnabled,
          onChanged: settings.categoriesEnabled
              ? settings.setCategoryDragEnabled
              : null,
        ),
        const Divider(),
        Text(
          'Categories shown',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 6),
        for (final category in GoalCategories.builtIn)
          CheckboxListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            title: Text(category),
            value: settings.data.enabledCategories.contains(category),
            onChanged: settings.categoriesEnabled
                ? (value) =>
                      settings.setCategoryEnabled(category, value ?? false)
                : null,
          ),
        const Divider(),
        Text(
          'Progress display',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 9),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final format in AppProgressFormat.values)
              ChoiceChip(
                key: Key('progress-format-${format.name}'),
                selected: settings.progressFormat == format,
                label: Text(format.label),
                onSelected: (_) => settings.setProgressFormat(format),
              ),
          ],
        ),
        const SizedBox(height: 12),
        SwitchListTile(
          key: const Key('show-abandoned-switch'),
          contentPadding: EdgeInsets.zero,
          title: const Text('Show Abandoned'),
          subtitle: const Text(
            'Off by default. Regular columns are hidden from their eye icon.',
          ),
          secondary: const Icon(Icons.archive_outlined),
          value: settings.showAbandoned,
          onChanged: settings.setShowAbandoned,
        ),
      ],
    ),
  );
}

class _OpenedGoalSettings extends StatelessWidget {
  const _OpenedGoalSettings(this.settings);
  final AppSettingsController settings;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: settings,
    builder: (context, _) => _SettingsCard(
      children: [
        Text(
          'Default view inside a goal',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 5),
        const Text(
          'Simple shows today, progress, and reminders. Detailed also shows '
          'the amount target, checklist, schedule health, and history.',
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          children: [
            for (final view in GoalDetailView.values)
              ChoiceChip(
                selected: settings.defaultGoalDetailView == view,
                label: Text(view.label),
                onSelected: (_) => settings.setDefaultGoalDetailView(view),
              ),
          ],
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Remember each goal’s view'),
          subtitle: const Text(
            'One goal can remain Detailed without changing all other goals.',
          ),
          value: settings.rememberGoalDetailView,
          onChanged: settings.setRememberGoalDetailView,
        ),
        const Divider(),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Milestones'),
          subtitle: const Text('Optional and off by default.'),
          value: settings.milestonesEnabled,
          onChanged: settings.setMilestonesEnabled,
        ),
        const ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(Icons.lock_clock_outlined),
          title: Text('Milestone effort estimates'),
          subtitle: Text(
            'Not available until the optional local AI can explain each estimate.',
          ),
          trailing: Chip(label: Text('Later')),
        ),
      ],
    ),
  );
}

class _NotificationSettings extends StatefulWidget {
  const _NotificationSettings(this.settings, this.notifications);
  final AppSettingsController settings;
  final GoalNotificationService? notifications;

  @override
  State<_NotificationSettings> createState() => _NotificationSettingsState();
}

class _NotificationSettingsState extends State<_NotificationSettings> {
  NotificationStatus? _status;
  bool _working = false;

  AppSettingsController get settings => widget.settings;

  @override
  void initState() {
    super.initState();
    if (widget.notifications != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _refresh());
    }
  }

  Future<void> _refresh() async {
    final notifications = widget.notifications;
    if (notifications == null || _working) return;
    setState(() => _working = true);
    final status = await notifications.notificationStatus();
    if (!mounted) return;
    setState(() {
      _status = status;
      _working = false;
    });
  }

  Future<void> _run(
    Future<void> Function(GoalNotificationService service) action,
    String success,
  ) async {
    final notifications = widget.notifications;
    if (notifications == null || _working) return;
    setState(() => _working = true);
    try {
      await action(notifications);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(success)));
    } on Object catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    } finally {
      if (mounted) setState(() => _working = false);
    }
    await _refresh();
  }

  Future<void> _setEnabled(bool value) async {
    if (value && widget.notifications != null) {
      final allowed = await widget.notifications!.requestPermissions(
        force: true,
      );
      if (!allowed) {
        await _refresh();
        return;
      }
    }
    await settings.setNotificationsEnabled(value);
    await _refresh();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: settings,
    builder: (context, _) => _SettingsCard(
      children: [
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Allow reminders'),
          subtitle: const Text('Master control for every goal notification.'),
          secondary: const Icon(Icons.notifications_active_outlined),
          value: settings.notificationsEnabled,
          onChanged: _working ? null : _setEnabled,
        ),
        if (widget.notifications != null) ...[
          _NotificationStatusTile(status: _status, loading: _working),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: _working ? null : _refresh,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Refresh status'),
              ),
              FilledButton.tonalIcon(
                onPressed: _working
                    ? null
                    : () => _run(
                        (service) => service.sendTestNotification(),
                        'Test notification sent.',
                      ),
                icon: const Icon(Icons.notifications_active_outlined),
                label: const Text('Send test now'),
              ),
              OutlinedButton.icon(
                onPressed: _working
                    ? null
                    : () => _run(
                        (service) => service.scheduleTestNotification(),
                        'Test scheduled for one minute from now.',
                      ),
                icon: const Icon(Icons.schedule_send_outlined),
                label: const Text('Test in 1 minute'),
              ),
              if (_status?.allowed == false)
                TextButton.icon(
                  onPressed: _working
                      ? null
                      : () => _run((service) async {
                          await service.openNotificationSettings();
                        }, 'Device notification settings opened.'),
                  icon: const Icon(Icons.settings_outlined),
                  label: const Text('Device settings'),
                ),
            ],
          ),
          const Divider(height: 28),
        ],
        DropdownButtonFormField<DefaultReminderFrequency>(
          initialValue: settings.defaultReminderFrequency,
          decoration: const InputDecoration(labelText: 'Default frequency'),
          items: [
            for (final item in DefaultReminderFrequency.values)
              DropdownMenuItem(value: item, child: Text(item.label)),
          ],
          onChanged: settings.notificationsEnabled
              ? (value) {
                  if (value != null) {
                    settings.setDefaultReminderFrequency(value);
                  }
                }
              : null,
        ),
        const SizedBox(height: 10),
        _TimeSettingTile(
          title: 'Default reminder time',
          value: settings.defaultReminderTime,
          enabled: settings.notificationsEnabled,
          onChanged: settings.setDefaultReminderTime,
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('End-of-day review'),
          subtitle: const Text(
            'One optional reminder for all unfinished actions.',
          ),
          value: settings.endOfDayReview,
          onChanged: settings.notificationsEnabled
              ? settings.setEndOfDayReview
              : null,
        ),
        if (settings.endOfDayReview)
          _TimeSettingTile(
            title: 'Review time',
            value: settings.endOfDayTime,
            enabled: settings.notificationsEnabled,
            onChanged: settings.setEndOfDayTime,
          ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Quiet hours'),
          subtitle: const Text(
            'Delay reminders between your usual sleep and wake time.',
          ),
          value: settings.quietHoursEnabled,
          onChanged: settings.notificationsEnabled
              ? settings.setQuietHoursEnabled
              : null,
        ),
        if (settings.quietHoursEnabled)
          Row(
            children: [
              Expanded(
                child: _TimeSettingTile(
                  title: 'From',
                  value: settings.quietStart,
                  enabled: settings.notificationsEnabled,
                  onChanged: settings.setQuietStart,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _TimeSettingTile(
                  title: 'Until',
                  value: settings.quietEnd,
                  enabled: settings.notificationsEnabled,
                  onChanged: settings.setQuietEnd,
                ),
              ),
            ],
          ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.info_outline_rounded),
          title: const Text('First reminder explanation'),
          subtitle: const Text(
            'Explains that reminders can be disabled for one goal or for everything.',
          ),
          trailing: OutlinedButton(
            onPressed: () => settings.setFirstReminderEducationSeen(false),
            child: const Text('Show again'),
          ),
        ),
      ],
    ),
  );
}

class _NotificationStatusTile extends StatelessWidget {
  const _NotificationStatusTile({required this.status, required this.loading});

  final NotificationStatus? status;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final current = status;
    final icon = current == null
        ? Icons.hourglass_empty_rounded
        : current.allowed
        ? Icons.check_circle_outline_rounded
        : Icons.error_outline_rounded;
    final title = current == null
        ? 'Checking notification delivery…'
        : !current.available
        ? 'Notification service unavailable'
        : current.allowed
        ? 'System notifications allowed'
        : 'System notifications blocked';
    final subtitle =
        current?.message ??
        (current == null
            ? 'Reading device permission and scheduled reminders.'
            : '${current.pendingCount} scheduled · '
                  '${current.exactTimingAvailable ? 'exact timing available' : 'battery-friendly timing'}');
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: loading
          ? const SizedBox.square(
              dimension: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Icon(icon),
      title: Text(title),
      subtitle: Text(subtitle),
    );
  }
}

class _PlanSettings extends StatelessWidget {
  const _PlanSettings(this.settings);
  final AppSettingsController settings;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: settings,
    builder: (context, _) => _SettingsCard(
      children: [
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Start goals automatically'),
          subtitle: const Text(
            'Move a planned goal to Active when its start date arrives.',
          ),
          value: settings.automaticStarts,
          onChanged: settings.setAutomaticStarts,
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<ConnectedGoalBehavior>(
          initialValue: settings.connectedGoalBehavior,
          decoration: const InputDecoration(
            labelText: 'When a connected goal becomes available',
          ),
          items: [
            for (final item in ConnectedGoalBehavior.values)
              DropdownMenuItem(value: item, child: Text(item.label)),
          ],
          onChanged: (value) {
            if (value != null) settings.setConnectedGoalBehavior(value);
          },
        ),
        const SizedBox(height: 16),
        Text(
          'Schedule adaptation',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 5),
        const Text(
          'Natural is recommended: small changes happen quietly, while '
          'meaningful pace or deadline changes show a warning first.',
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final mode in AdaptiveWarningMode.values)
              ChoiceChip(
                selected: settings.adaptiveWarningMode == mode,
                label: Text(mode.label),
                onSelected: (_) => settings.setAdaptiveWarningMode(mode),
              ),
          ],
        ),
        const SizedBox(height: 12),
        const Text(
          'Each goal can override the global choice from its own detailed view.',
        ),
      ],
    ),
  );
}

class _WidgetSettings extends StatelessWidget {
  const _WidgetSettings(this.settings, this.store);
  final AppSettingsController settings;
  final GoalStore store;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: settings,
    builder: (context, _) => _SettingsCard(
      children: [
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Show today’s actions'),
          subtitle: const Text(
            'Includes a Done button when the widget has room.',
          ),
          value: settings.widgetShowTodayActions,
          onChanged: settings.setWidgetShowTodayActions,
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Show progress'),
          subtitle: const Text(
            'Follows Percentage, Amount completed, or Both.',
          ),
          value: settings.widgetShowProgress,
          onChanged: settings.setWidgetShowProgress,
        ),
        DropdownButtonFormField<WidgetGoalScope>(
          initialValue: settings.widgetGoalScope,
          decoration: const InputDecoration(labelText: 'Cards shown'),
          items: [
            for (final item in WidgetGoalScope.values)
              DropdownMenuItem(value: item, child: Text(item.label)),
          ],
          onChanged: (value) {
            if (value != null) settings.setWidgetGoalScope(value);
          },
        ),
        const SizedBox(height: 10),
        DropdownButtonFormField<String>(
          initialValue: settings.widgetCategory,
          decoration: const InputDecoration(labelText: 'Category'),
          items: [
            const DropdownMenuItem(
              value: '',
              child: Text('All visible categories'),
            ),
            for (final category in settings.visibleCategories(
              store.availableCategories,
            ))
              DropdownMenuItem(value: category, child: Text(category)),
          ],
          onChanged: (value) {
            if (value != null) settings.setWidgetCategory(value);
          },
        ),
        const SizedBox(height: 10),
        DropdownButtonFormField<int>(
          initialValue: settings.widgetMaxCards,
          decoration: const InputDecoration(labelText: 'Maximum cards'),
          items: const [
            DropdownMenuItem(value: 3, child: Text('3')),
            DropdownMenuItem(value: 5, child: Text('5')),
            DropdownMenuItem(value: 8, child: Text('8')),
          ],
          onChanged: (value) {
            if (value != null) settings.setWidgetMaxCards(value);
          },
        ),
        const SizedBox(height: 14),
        const Text(
          'The Android home-screen widgets refresh automatically after goal '
          'or Settings changes.',
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            OutlinedButton.icon(
              onPressed: () => GoalWidgetService().requestPinTodayWidget(),
              icon: const Icon(Icons.task_alt_rounded),
              label: const Text('Add Today widget'),
            ),
            OutlinedButton.icon(
              onPressed: () => GoalWidgetService().requestPinCardsWidget(),
              icon: const Icon(Icons.view_kanban_outlined),
              label: const Text('Add Goal Cards widget'),
            ),
            FilledButton.icon(
              onPressed: () =>
                  GoalWidgetService().sync(store.goals, store, settings),
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Refresh widgets'),
            ),
          ],
        ),
      ],
    ),
  );
}

class _LocalDataSettings extends StatelessWidget {
  const _LocalDataSettings(this.store);
  final GoalStore store;

  @override
  Widget build(BuildContext context) => _SettingsCard(
    children: [
      const ListTile(
        contentPadding: EdgeInsets.zero,
        leading: Icon(Icons.save_outlined),
        title: Text('Automatic saving is on'),
        subtitle: Text(
          'Goals, checklist steps, progress, reminders, and Settings save as soon as they change.',
        ),
      ),
      const Divider(),
      SelectableText(store.storagePath),
      const SizedBox(height: 12),
      OutlinedButton.icon(
        key: const Key('open-local-folder-setting'),
        onPressed: () async {
          final opened = await store.openStorageFolder();
          if (!opened && context.mounted) {
            await showDialog<void>(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('Local Markdown files'),
                content: SelectableText(store.storagePath),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Close'),
                  ),
                ],
              ),
            );
          }
        },
        icon: const Icon(Icons.folder_open_outlined),
        label: const Text('Open local Markdown folder'),
      ),
    ],
  );
}

class _TimeSettingTile extends StatelessWidget {
  const _TimeSettingTile({
    required this.title,
    required this.value,
    required this.enabled,
    required this.onChanged,
  });
  final String title;
  final TimeOfDay value;
  final bool enabled;
  final ValueChanged<TimeOfDay> onChanged;

  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: EdgeInsets.zero,
    title: Text(title),
    subtitle: Text(value.format(context)),
    trailing: const Icon(Icons.schedule_rounded),
    enabled: enabled,
    onTap: !enabled
        ? null
        : () async {
            final chosen = await showTimePicker(
              context: context,
              initialTime: value,
            );
            if (chosen != null) onChanged(chosen);
          },
  );
}
