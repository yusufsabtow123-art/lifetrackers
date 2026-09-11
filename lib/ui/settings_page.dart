import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app/goal_store.dart';
import '../app/life_store.dart';
import '../app/theme_controller.dart';
import '../domain/goal.dart';
import '../platform/goal_notification_service.dart';
import '../platform/goal_widget_service.dart';
import '../platform/salah_location_service.dart';
import 'app_theme.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({
    super.key,
    required this.store,
    required this.settings,
    this.lifeStore,
    this.notificationService,
  });

  final GoalStore store;
  final AppSettingsController settings;
  final LifeStore? lifeStore;
  final GoalNotificationService? notificationService;

  @override
  Widget build(BuildContext context) {
    final entries = <_SettingsEntry>[
      _SettingsEntry(
        'Appearance',
        'Choose Light or Dark. Life Tracker keeps one consistent identity.',
        Icons.contrast_rounded,
        () => _open(context, 'Appearance', _AppearanceSettings(settings)),
      ),
      _SettingsEntry(
        'Calendar and Salah',
        'Protected prayer times, location, calculation, and block duration.',
        Icons.calendar_month_outlined,
        () => _open(
          context,
          'Calendar and Salah',
          _CalendarSettings(settings, lifeStore),
        ),
      ),
      _SettingsEntry(
        'Board and categories',
        'Category movement and visibility, progress labels, and Abandoned.',
        Icons.view_kanban_outlined,
        () => _open(context, 'Board and categories', _BoardSettings(settings)),
      ),
      _SettingsEntry(
        'Opened goals',
        'Simple or Detailed defaults and remembered views.',
        Icons.view_agenda_outlined,
        () => _open(context, 'Opened goals', _OpenedGoalSettings(settings)),
      ),
      _SettingsEntry(
        'Notifications',
        'Default timing, frequency, quiet hours, and end-of-day review.',
        Icons.notifications_outlined,
        () => _open(
          context,
          'Notifications',
          _NotificationSettings(settings, notificationService),
        ),
      ),
      _SettingsEntry(
        'Goal scheduling',
        'Control when planned goals begin.',
        Icons.route_outlined,
        () => _open(context, 'Goal scheduling', _PlanSettings(settings)),
      ),
      _SettingsEntry(
        'Android widgets',
        'Choose which actions, cards, categories, and progress appear.',
        Icons.widgets_outlined,
        () => _open(
          context,
          'Android widgets',
          _WidgetSettings(settings, store, lifeStore),
        ),
      ),
      _SettingsEntry(
        'Local data',
        lifeStore == null
            ? 'Readable Markdown files stored on this device.'
            : 'Goals, tasks, and calendar stay readable and on this device.',
        Icons.folder_outlined,
        () => _open(context, 'Local data', _LocalDataSettings(store)),
      ),
    ];

    return AnimatedBuilder(
      animation: settings,
      builder: (context, _) => MediaQuery.sizeOf(context).width >= 820
          ? _desktopSettings(context, entries)
          : ListView(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 32),
              children: [
                _ReferenceSettingRow(
                  icon: Icons.light_mode_outlined,
                  iconColor: context.isDarkMode ? null : AppColors.goldText,
                  title: 'Appearance',
                  value: settings.appearance.name,
                  onTap: entries[0].onTap,
                ),
                _ReferenceSettingRow(
                  icon: Icons.notifications_outlined,
                  iconColor: context.isDarkMode ? null : AppColors.coralText,
                  title: 'Notifications',
                  value: settings.notificationsEnabled ? 'On' : 'Off',
                  onTap: entries[4].onTap,
                ),
                _ReferenceSettingRow(
                  icon: Icons.calendar_today_outlined,
                  iconColor: context.isDarkMode ? null : AppColors.greenText,
                  title: 'Calendar',
                  value: settings.salahEnabled ? 'Salah on' : 'Salah off',
                  onTap: entries[1].onTap,
                ),
                _ReferenceSettingRow(
                  icon: Icons.folder_outlined,
                  iconColor: context.isDarkMode ? null : AppColors.blueText,
                  title: 'Data',
                  value: 'On this device',
                  onTap: entries[7].onTap,
                ),
                _ReferenceSettingRow(
                  icon: Icons.accessibility_new_rounded,
                  iconColor: context.isDarkMode ? null : AppColors.blueText,
                  title: 'Accessibility',
                  value: 'Uses device settings',
                  onTap: () => _open(
                    context,
                    'Accessibility',
                    const _AccessibilitySettings(),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Goals & device',
                  style: TextStyle(fontSize: 12, color: context.appMuted),
                ),
                const SizedBox(height: 8),
                _ReferenceSettingRow(
                  icon: entries[2].icon,
                  iconColor: context.isDarkMode ? null : AppColors.coralText,
                  title: 'Board and categories',
                  value: '',
                  onTap: entries[2].onTap,
                ),
                _ReferenceSettingRow(
                  icon: entries[3].icon,
                  iconColor: context.isDarkMode ? null : AppColors.blueText,
                  title: 'Opened goals',
                  value: '',
                  onTap: entries[3].onTap,
                ),
                _ReferenceSettingRow(
                  icon: entries[6].icon,
                  iconColor: context.isDarkMode ? null : AppColors.blueText,
                  title: 'Android widgets',
                  value: '',
                  onTap: entries[6].onTap,
                ),
                const SizedBox(height: 28),
                Text(
                  'Private by default · Saved automatically',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 11, color: context.appMuted),
                ),
              ],
            ),
    );
  }

  Widget _desktopSettings(BuildContext context, List<_SettingsEntry> entries) =>
      ListView(
        padding: const EdgeInsets.fromLTRB(32, 26, 32, 40),
        children: [
          Text('Settings', style: Theme.of(context).textTheme.displaySmall),
          const SizedBox(height: 4),
          Text(
            'Make Life Tracker work for you.',
            style: TextStyle(color: context.appMuted),
          ),
          const SizedBox(height: 24),
          _InlineSettingsGroup(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(15, 14, 15, 13),
                child: Row(
                  children: [
                    const Icon(Icons.contrast_rounded, size: 19),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Appearance',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                    _AppearancePreview(
                      appearance: AppAppearance.light,
                      selected: settings.appearance == AppAppearance.light,
                      onTap: () => settings.setAppearance(AppAppearance.light),
                    ),
                    const SizedBox(width: 8),
                    _AppearancePreview(
                      appearance: AppAppearance.dark,
                      selected: settings.appearance == AppAppearance.dark,
                      onTap: () => settings.setAppearance(AppAppearance.dark),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _InlineSettingsGroup(
            children: [
              _InlineSettingsRow(
                icon: Icons.notifications_none_rounded,
                title: 'Notifications',
                subtitle: 'Daily reminders and quiet hours',
                onTap: entries[4].onTap,
                trailing: Switch(
                  value: settings.notificationsEnabled,
                  onChanged: settings.setNotificationsEnabled,
                ),
              ),
              _InlineSettingsRow(
                icon: Icons.calendar_today_outlined,
                title: 'Calendar',
                subtitle: 'Scheduling, recurrence, and plan warnings',
                onTap: entries[1].onTap,
                trailing: const Icon(Icons.chevron_right_rounded, size: 18),
              ),
              _InlineSettingsRow(
                icon: Icons.storage_outlined,
                title: 'Data',
                subtitle: 'Goals, tasks, and calendar stay on this device',
                onTap: entries[7].onTap,
                trailing: const Icon(Icons.chevron_right_rounded, size: 18),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _InlineSettingsGroup(
            children: [
              _InlineSettingsRow(
                icon: Icons.accessibility_new_rounded,
                title: 'Accessibility',
                subtitle: 'System text and motion settings are respected',
                onTap: () => _open(
                  context,
                  'Accessibility',
                  const _AccessibilitySettings(),
                ),
                trailing: const Icon(Icons.chevron_right_rounded, size: 18),
              ),
              _InlineSettingsRow(
                icon: entries[2].icon,
                title: 'Goals and board',
                subtitle: 'Categories, progress labels, and board behavior',
                onTap: entries[2].onTap,
                trailing: const Icon(Icons.chevron_right_rounded, size: 18),
              ),
              _InlineSettingsRow(
                icon: entries[6].icon,
                title: 'Android widgets',
                subtitle: 'Choose which actions and progress appear',
                onTap: entries[6].onTap,
                trailing: const Icon(Icons.chevron_right_rounded, size: 18),
              ),
            ],
          ),
        ],
      );

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

class _ReferenceSettingRow extends StatelessWidget {
  const _ReferenceSettingRow({
    required this.icon,
    required this.title,
    required this.value,
    required this.onTap,
    this.iconColor,
  });
  final IconData icon;
  final String title;
  final String value;
  final VoidCallback onTap;
  final Color? iconColor;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 2),
    child: Material(
      color: context.appPanel,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          child: Row(
            children: [
              Icon(icon, size: 19, color: iconColor ?? context.appText),
              const SizedBox(width: 12),
              Expanded(
                child: Text(title, style: const TextStyle(fontSize: 14)),
              ),
              if (value.isNotEmpty)
                Text(
                  value[0].toUpperCase() + value.substring(1),
                  style: TextStyle(fontSize: 12, color: context.appMuted),
                ),
              const SizedBox(width: 8),
              Icon(Icons.chevron_right, size: 16, color: context.appMuted),
            ],
          ),
        ),
      ),
    ),
  );
}

class _SettingsEntry {
  const _SettingsEntry(this.title, this.description, this.icon, this.onTap);
  final String title;
  final String description;
  final IconData icon;
  final VoidCallback onTap;
}

class _InlineSettingsGroup extends StatelessWidget {
  const _InlineSettingsGroup({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Container(
    constraints: const BoxConstraints(maxWidth: 880),
    decoration: BoxDecoration(
      color: context.appPanel,
      borderRadius: BorderRadius.circular(9),
      border: Border.all(color: context.appBorder),
    ),
    clipBehavior: Clip.antiAlias,
    child: Column(
      children: [
        for (var index = 0; index < children.length; index++) ...[
          children[index],
          if (index != children.length - 1)
            Divider(height: 1, color: context.appBorder),
        ],
      ],
    ),
  );
}

class _InlineSettingsRow extends StatelessWidget {
  const _InlineSettingsRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    required this.trailing,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final Widget trailing;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
      child: Row(
        children: [
          Icon(icon, size: 19),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(fontSize: 11, color: context.appMuted),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          trailing,
        ],
      ),
    ),
  );
}

class _AppearancePreview extends StatelessWidget {
  const _AppearancePreview({
    required this.appearance,
    required this.selected,
    required this.onTap,
  });

  final AppAppearance appearance;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    key: Key('appearance-${appearance.name}'),
    onTap: onTap,
    borderRadius: BorderRadius.circular(7),
    child: Container(
      width: 84,
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: appearance == AppAppearance.dark
            ? const Color(0xFF101518)
            : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(7),
        border: Border.all(
          color: selected ? AppColors.coral : context.appBorder,
          width: selected ? 1.5 : 1,
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 16,
                height: 22,
                color: appearance == AppAppearance.dark
                    ? const Color(0xFF1B2226)
                    : AppColors.softBlue,
              ),
              const SizedBox(width: 3),
              Expanded(
                child: Container(
                  height: 22,
                  color: appearance == AppAppearance.dark
                      ? const Color(0xFF242B2F)
                      : Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            appearance.label,
            style: TextStyle(
              fontSize: 9,
              color: appearance == AppAppearance.dark
                  ? Colors.white
                  : Colors.black87,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
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
            for (final appearance in const [
              AppAppearance.light,
              AppAppearance.dark,
            ])
              ChoiceChip(
                key: Key('appearance-${appearance.name}'),
                selected: settings.appearance == appearance,
                avatar: Icon(appearance.icon, size: 18),
                label: Text(appearance.label),
                onSelected: (_) => settings.setAppearance(appearance),
              ),
          ],
        ),
      ],
    ),
  );
}

class _AccessibilitySettings extends StatelessWidget {
  const _AccessibilitySettings();

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final scale = media.textScaler.scale(1);
    return _SettingsCard(
      children: [
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.text_fields_rounded),
          title: const Text('Text size'),
          subtitle: const Text(
            'Life Tracker follows the text size selected on this device.',
          ),
          trailing: Text('${(scale * 100).round()}%'),
        ),
        const Divider(),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.motion_photos_off_outlined),
          title: const Text('Reduced motion'),
          subtitle: const Text(
            'Animations become simpler when the device requests reduced motion.',
          ),
          trailing: Text(media.disableAnimations ? 'On' : 'Off'),
        ),
      ],
    );
  }
}

Future<void> _useCurrentSalahLocation(
  BuildContext context,
  AppSettingsController settings,
) async {
  final messenger = ScaffoldMessenger.of(context);
  try {
    final location = await SalahLocationService.current();
    await settings.setSalahManualLocation(
      name: 'Current location',
      latitude: location.latitude,
      longitude: location.longitude,
      timeZone: location.timeZone,
    );
    messenger.showSnackBar(
      const SnackBar(content: Text('Prayer location updated.')),
    );
  } on PlatformException catch (error) {
    messenger.showSnackBar(
      SnackBar(
        content: Text(error.message ?? 'Location could not be updated.'),
      ),
    );
  }
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
      ],
    ),
  );
}

class _CalendarSettings extends StatelessWidget {
  const _CalendarSettings(this.settings, this.lifeStore);
  final AppSettingsController settings;
  final LifeStore? lifeStore;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: settings,
    builder: (context, _) => _SettingsCard(
      children: [
        SwitchListTile(
          key: const Key('salah-calendar-enabled'),
          secondary: const Icon(Icons.mosque_outlined),
          title: const Text('Protect Salah times'),
          subtitle: const Text(
            'Show Fajr, Dhuhr, Asr, Maghrib, and Isha as protected calendar blocks.',
          ),
          value: settings.salahEnabled,
          onChanged: (value) {
            if (value) lifeStore?.setShowBlockedTimes(true);
            settings.setSalahEnabled(value);
          },
        ),
        ListTile(
          enabled: settings.salahEnabled,
          leading: const Icon(Icons.location_on_outlined),
          title: const Text('Prayer location'),
          subtitle: Text(
            '${settings.data.salahLocationName}\n${settings.data.salahTimeZone}',
          ),
          isThreeLine: true,
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: settings.salahEnabled
              ? () => _editSalahLocation(context, settings)
              : null,
        ),
        ListTile(
          enabled: settings.salahEnabled,
          leading: const Icon(Icons.my_location_rounded),
          title: const Text('Use current location'),
          subtitle: const Text(
            'Ask Android once, then calculate prayer times locally.',
          ),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: settings.salahEnabled
              ? () => _useCurrentSalahLocation(context, settings)
              : null,
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: DropdownButtonFormField<SalahCalculationMethod>(
            isExpanded: true,
            initialValue: settings.salahCalculationMethod,
            decoration: const InputDecoration(
              labelText: 'Calculation method',
              prefixIcon: Icon(Icons.calculate_outlined),
            ),
            items: [
              for (final method in SalahCalculationMethod.values)
                DropdownMenuItem(value: method, child: Text(method.label)),
            ],
            onChanged: settings.salahEnabled
                ? (value) {
                    if (value != null) {
                      settings.setSalahCalculationMethod(value);
                    }
                  }
                : null,
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: DropdownButtonFormField<SalahAsrMethod>(
            isExpanded: true,
            initialValue: settings.salahAsrMethod,
            decoration: const InputDecoration(
              labelText: 'Asr convention',
              prefixIcon: Icon(Icons.schedule_outlined),
            ),
            items: [
              for (final method in SalahAsrMethod.values)
                DropdownMenuItem(value: method, child: Text(method.label)),
            ],
            onChanged: settings.salahEnabled
                ? (value) {
                    if (value != null) settings.setSalahAsrMethod(value);
                  }
                : null,
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: DropdownButtonFormField<int>(
            isExpanded: true,
            initialValue: settings.data.salahBlockMinutes,
            decoration: const InputDecoration(
              labelText: 'Protected block duration',
              prefixIcon: Icon(Icons.timelapse_outlined),
            ),
            items: const [
              DropdownMenuItem(value: 15, child: Text('15 minutes')),
              DropdownMenuItem(value: 30, child: Text('30 minutes')),
              DropdownMenuItem(value: 45, child: Text('45 minutes')),
              DropdownMenuItem(value: 60, child: Text('1 hour')),
            ],
            onChanged: settings.salahEnabled
                ? (value) {
                    if (value != null) settings.setSalahBlockMinutes(value);
                  }
                : null,
          ),
        ),
        ExpansionTile(
          leading: const Icon(Icons.tune_rounded),
          title: const Text('Advanced calculation'),
          subtitle: const Text('High-latitude rule and local minute offsets'),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
              child: DropdownButtonFormField<SalahHighLatitudeRule>(
                isExpanded: true,
                initialValue: settings.salahHighLatitudeRule,
                decoration: const InputDecoration(
                  labelText: 'High-latitude rule',
                ),
                items: [
                  for (final rule in SalahHighLatitudeRule.values)
                    DropdownMenuItem(value: rule, child: Text(rule.label)),
                ],
                onChanged: settings.salahEnabled
                    ? (value) {
                        if (value != null) {
                          settings.setSalahHighLatitudeRule(value);
                        }
                      }
                    : null,
              ),
            ),
            for (final prayer in const [
              'Fajr',
              'Dhuhr',
              'Asr',
              'Maghrib',
              'Isha',
            ])
              ListTile(
                enabled: settings.salahEnabled,
                title: Text('$prayer adjustment'),
                subtitle: const Text('Use only to match your local masjid'),
                trailing: DropdownButton<int>(
                  value: settings.data.salahAdjustments[prayer] ?? 0,
                  items: [
                    for (final value in const [-10, -5, 0, 5, 10])
                      DropdownMenuItem(
                        value: value,
                        child: Text(
                          value == 0
                              ? 'None'
                              : '${value > 0 ? '+' : ''}$value min',
                        ),
                      ),
                  ],
                  onChanged: settings.salahEnabled
                      ? (value) {
                          if (value != null) {
                            settings.setSalahAdjustment(prayer, value);
                          }
                        }
                      : null,
                ),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ],
    ),
  );
}

Future<void> _editSalahLocation(
  BuildContext context,
  AppSettingsController settings,
) async {
  final name = TextEditingController(text: settings.data.salahLocationName);
  final latitude = TextEditingController(
    text: settings.data.salahLatitude.toString(),
  );
  final longitude = TextEditingController(
    text: settings.data.salahLongitude.toString(),
  );
  final timeZone = TextEditingController(text: settings.data.salahTimeZone);
  await showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Manual prayer location'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: name,
              decoration: const InputDecoration(labelText: 'Place name'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: latitude,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
                signed: true,
              ),
              decoration: const InputDecoration(labelText: 'Latitude'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: longitude,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
                signed: true,
              ),
              decoration: const InputDecoration(labelText: 'Longitude'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: timeZone,
              decoration: const InputDecoration(
                labelText: 'IANA time zone',
                hintText: 'America/Chicago',
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () async {
            final lat = double.tryParse(latitude.text);
            final lon = double.tryParse(longitude.text);
            if (lat == null ||
                lon == null ||
                lat.abs() > 90 ||
                lon.abs() > 180) {
              return;
            }
            await settings.setSalahManualLocation(
              name: name.text.trim().isEmpty
                  ? 'Manual location'
                  : name.text.trim(),
              latitude: lat,
              longitude: lon,
              timeZone: timeZone.text.trim(),
            );
            if (dialogContext.mounted) Navigator.pop(dialogContext);
          },
          child: const Text('Save'),
        ),
      ],
    ),
  );
  name.dispose();
  latitude.dispose();
  longitude.dispose();
  timeZone.dispose();
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
      ],
    ),
  );
}

class _WidgetSettings extends StatelessWidget {
  const _WidgetSettings(this.settings, this.store, this.lifeStore);
  final AppSettingsController settings;
  final GoalStore store;
  final LifeStore? lifeStore;

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
            OutlinedButton.icon(
              onPressed: () => GoalWidgetService().requestPinCalendarWidget(),
              icon: const Icon(Icons.calendar_view_day_outlined),
              label: const Text('Add Calendar widget'),
            ),
            FilledButton.icon(
              onPressed: () => GoalWidgetService().sync(
                store.goals,
                store,
                lifeStore,
                settings,
              ),
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
