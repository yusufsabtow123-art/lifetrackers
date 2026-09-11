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
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 28),
              children: [
                _ReferenceSettingsGroup(
                  children: [
                    _ReferenceSettingRow(
                      icon: Icons.light_mode_outlined,
                      iconColor: context.isDarkMode
                          ? null
                          : const Color(0xFFF4AD00),
                      title: 'Appearance',
                      value: settings.appearance == AppAppearance.system
                          ? 'System'
                          : settings.appearance.label,
                      onTap: entries[0].onTap,
                    ),
                    _ReferenceSettingRow(
                      icon: Icons.notifications_rounded,
                      iconColor: context.isDarkMode ? null : AppColors.coral,
                      title: 'Notifications',
                      value: settings.notificationsEnabled ? 'On' : 'Off',
                      onTap: entries[4].onTap,
                    ),
                    _ReferenceSettingRow(
                      icon: Icons.mosque_outlined,
                      iconColor: context.isDarkMode
                          ? null
                          : AppColors.lightGreen,
                      title: 'Calendar',
                      value: settings.salahEnabled ? 'Salah on' : 'Salah off',
                      onTap: entries[1].onTap,
                    ),
                    _ReferenceSettingRow(
                      icon: Icons.storage_rounded,
                      iconColor: context.isDarkMode ? null : AppColors.blue,
                      title: 'Data',
                      value: 'On this device',
                      onTap: entries[7].onTap,
                    ),
                    _ReferenceSettingRow(
                      icon: Icons.accessibility_new_rounded,
                      iconColor: context.isDarkMode ? null : context.appMuted,
                      title: 'Accessibility',
                      value: 'Uses device settings',
                      onTap: () => _open(
                        context,
                        'Accessibility',
                        const _AccessibilitySettings(),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                _ReferenceSettingsGroup(
                  header: 'Goals & device',
                  children: [
                    _ReferenceSettingRow(
                      icon: Icons.track_changes_rounded,
                      title: 'Board and categories',
                      value: 'Customize your goals',
                      onTap: entries[2].onTap,
                    ),
                    _ReferenceSettingRow(
                      icon: Icons.bar_chart_rounded,
                      title: 'Opened goals',
                      value: 'See your progress',
                      onTap: entries[3].onTap,
                    ),
                    _ReferenceSettingRow(
                      icon: Icons.grid_view_outlined,
                      title: 'Android widgets',
                      value: 'Add to your home screen',
                      onTap: entries[6].onTap,
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                _InfoPanel(
                  icon: Icons.shield_outlined,
                  text: 'Private by default · Saved automatically',
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
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 28),
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

class _ReferenceSettingsGroup extends StatelessWidget {
  const _ReferenceSettingsGroup({required this.children, this.header});
  final List<Widget> children;
  final String? header;

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: context.appPanel,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: context.appBorder),
    ),
    clipBehavior: Clip.antiAlias,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (header != null)
          Container(
            padding: const EdgeInsets.fromLTRB(12, 9, 12, 8),
            color: context.appRaised.withValues(alpha: .7),
            child: Text(
              header!,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
            ),
          ),
        for (var index = 0; index < children.length; index++) ...[
          children[index],
          if (index != children.length - 1)
            Divider(height: 1, color: context.appBorder),
        ],
      ],
    ),
  );
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
  Widget build(BuildContext context) => Material(
    color: Colors.transparent,
    child: InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
        child: Row(
          children: [
            Icon(icon, size: 23, color: iconColor ?? context.appMuted),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (value.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      value,
                      style: TextStyle(fontSize: 11.5, color: context.appMuted),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              Icons.chevron_right_rounded,
              size: 20,
              color: context.appMuted,
            ),
          ],
        ),
      ),
    ),
  );
}

class _InfoPanel extends StatelessWidget {
  const _InfoPanel({required this.icon, required this.text, this.color});
  final IconData icon;
  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final resolved = color ?? context.appMuted;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      decoration: BoxDecoration(
        color: context.appRaised.withValues(alpha: .64),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.appBorder),
      ),
      child: Row(
        children: [
          Icon(icon, size: 22, color: resolved),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontSize: 11.5, color: resolved),
            ),
          ),
        ],
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

class _ReferenceSection extends StatelessWidget {
  const _ReferenceSection({required this.children, this.title, this.tint});
  final List<Widget> children;
  final String? title;
  final Color? tint;

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: tint ?? context.appPanel,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: context.appBorder),
    ),
    clipBehavior: Clip.antiAlias,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (title != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 7),
            child: Text(
              title!,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
            ),
          ),
        for (var index = 0; index < children.length; index++) ...[
          children[index],
          if (index != children.length - 1)
            Divider(height: 1, color: context.appBorder),
        ],
      ],
    ),
  );
}

class _ReferenceActionRow extends StatelessWidget {
  const _ReferenceActionRow({
    required this.icon,
    required this.title,
    this.subtitle,
    this.value,
    this.onTap,
    this.trailing,
    this.iconColor,
    this.enabled = true,
  });
  final IconData icon;
  final String title;
  final String? subtitle;
  final String? value;
  final VoidCallback? onTap;
  final Widget? trailing;
  final Color? iconColor;
  final bool enabled;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: enabled ? onTap : null,
    child: Opacity(
      opacity: enabled ? 1 : .45,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
        child: Row(
          children: [
            Icon(icon, size: 23, color: iconColor ?? context.appBlueText),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      style: TextStyle(
                        fontSize: 11,
                        height: 1.2,
                        color: context.appMuted,
                      ),
                    ),
                  ],
                  if (value != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      value!,
                      style: TextStyle(
                        fontSize: 11.5,
                        color: context.appBlueText,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            trailing ??
                Icon(
                  Icons.chevron_right_rounded,
                  size: 20,
                  color: context.appBlueText,
                ),
          ],
        ),
      ),
    ),
  );
}

class _ReferenceToggleRow extends StatelessWidget {
  const _ReferenceToggleRow({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
    this.iconColor,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) => _ReferenceActionRow(
    icon: icon,
    iconColor: iconColor,
    title: title,
    subtitle: subtitle,
    enabled: onChanged != null,
    trailing: Switch(value: value, onChanged: onChanged),
    onTap: onChanged == null ? null : () => onChanged!(!value),
  );
}

class _ReferenceChoiceBox extends StatelessWidget {
  const _ReferenceChoiceBox({
    super.key,
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
    this.iconBackground,
  });
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color? iconBackground;

  @override
  Widget build(BuildContext context) => Expanded(
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(9),
      child: AnimatedContainer(
        duration: LifeMotion.quick,
        height: 132,
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 11),
        decoration: BoxDecoration(
          color: selected ? context.appSoftRed : context.appPanel,
          borderRadius: BorderRadius.circular(9),
          border: Border.all(
            color: selected ? AppColors.coral : context.appBorder,
            width: selected ? 1.4 : 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 48,
              height: 42,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: iconBackground ?? Colors.transparent,
                borderRadius: BorderRadius.circular(7),
              ),
              child: Icon(
                icon,
                size: 30,
                color: selected ? AppColors.coral : context.appText,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 7),
            Icon(
              selected ? Icons.radio_button_checked : Icons.radio_button_off,
              size: 24,
              color: selected ? AppColors.coral : context.appBlueText,
            ),
          ],
        ),
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
    builder: (context, _) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ReferenceSection(
          title: 'Color mode',
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(9, 4, 9, 10),
              child: Row(
                children: [
                  _ReferenceChoiceBox(
                    key: const Key('appearance-light'),
                    icon: Icons.light_mode_rounded,
                    label: 'Light',
                    selected: settings.appearance == AppAppearance.light,
                    onTap: () => settings.setAppearance(AppAppearance.light),
                  ),
                  const SizedBox(width: 8),
                  _ReferenceChoiceBox(
                    key: const Key('appearance-dark'),
                    icon: Icons.dark_mode_rounded,
                    label: 'Dark',
                    selected: settings.appearance == AppAppearance.dark,
                    iconBackground: const Color(0xFF0B1731),
                    onTap: () => settings.setAppearance(AppAppearance.dark),
                  ),
                  const SizedBox(width: 8),
                  _ReferenceChoiceBox(
                    key: const Key('appearance-system'),
                    icon: Icons.desktop_windows_outlined,
                    label: 'System',
                    selected: settings.appearance == AppAppearance.system,
                    onTap: () => settings.setAppearance(AppAppearance.system),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _ReferenceSection(
          title: 'Theme preview',
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 4, 10, 10),
              child: _ThemePreviewCard(),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _ReferenceSection(
          children: [
            _ReferenceToggleRow(
              icon: Icons.palette_outlined,
              title: 'Use system theme colors',
              subtitle: "Match Android's dynamic colors where available.",
              value: settings.useSystemThemeColors,
              onChanged: settings.setUseSystemThemeColors,
            ),
          ],
        ),
        const SizedBox(height: 12),
        const _InfoPanel(
          icon: Icons.info_outline_rounded,
          color: AppColors.blueText,
          text:
              "You can change your theme at any time. This affects the app's colors and appearance across all screens.",
        ),
      ],
    ),
  );
}

class _ThemePreviewCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      color: context.appPanel,
      borderRadius: BorderRadius.circular(9),
      border: Border.all(color: context.appBorder),
    ),
    child: Column(
      children: [
        Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: context.appSoftBlue,
                borderRadius: BorderRadius.circular(9),
              ),
              child: const Icon(Icons.eco_rounded, color: AppColors.blue),
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Life Tracker',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Track progress, build a better you',
                    style: TextStyle(fontSize: 11, color: AppColors.blueText),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: AppColors.blueText),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            _PreviewTag(
              color: AppColors.softBlue,
              icon: Icons.track_changes_rounded,
              title: 'Goal',
              subtitle: 'On track',
              foreground: AppColors.blueText,
            ),
            const SizedBox(width: 7),
            _PreviewTag(
              color: AppColors.softRed,
              icon: Icons.check_box_rounded,
              title: 'Task',
              subtitle: 'Due today',
              foreground: AppColors.coralText,
            ),
            const SizedBox(width: 7),
            _PreviewTag(
              color: AppColors.softGreen,
              icon: Icons.mosque_outlined,
              title: 'Salah',
              subtitle: 'Protected',
              foreground: AppColors.greenText,
            ),
          ],
        ),
        const SizedBox(height: 9),
        const _PreviewBanner(),
      ],
    ),
  );
}

class _PreviewTag extends StatelessWidget {
  const _PreviewTag({
    required this.color,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.foreground,
  });
  final Color color;
  final IconData icon;
  final String title;
  final String subtitle;
  final Color foreground;
  @override
  Widget build(BuildContext context) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 8),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(7),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: foreground),
          const SizedBox(width: 5),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 11,
                    color: foreground,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(fontSize: 9.5, color: foreground),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class _PreviewBanner extends StatelessWidget {
  const _PreviewBanner();
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      color: context.appSoftAmber,
      borderRadius: BorderRadius.circular(8),
    ),
    child: const Row(
      children: [
        Icon(Icons.description_outlined, color: AppColors.goldText),
        SizedBox(width: 9),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'A calmer, more consistent you',
                style: TextStyle(fontSize: 11.5, color: AppColors.goldText),
              ),
              Text(
                'Small steps make big progress.',
                style: TextStyle(fontSize: 10.5, color: AppColors.blueText),
              ),
            ],
          ),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ReferenceSection(
          children: [
            _ReferenceActionRow(
              icon: Icons.text_fields_rounded,
              title: 'Text size',
              value: '${(scale * 100).round()}%',
              subtitle: "Life Tracker follows your device's text size setting.",
            ),
          ],
        ),
        const SizedBox(height: 12),
        _ReferenceSection(
          children: [
            _ReferenceActionRow(
              icon: Icons.motion_photos_off_outlined,
              title: 'Reduced motion',
              value: media.disableAnimations ? 'On' : 'Off',
              subtitle:
                  'Animations will be simplified when Android requests reduced motion.',
            ),
          ],
        ),
        const SizedBox(height: 12),
        const _InfoPanel(
          icon: Icons.info_outline_rounded,
          color: AppColors.blueText,
          text:
              'These accessibility settings help make Life Tracker more comfortable to use for everyone.',
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
    builder: (context, _) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ReferenceSection(
          children: [
            _ReferenceToggleRow(
              icon: Icons.format_list_bulleted_rounded,
              title: 'Use categories',
              subtitle: 'Organize your goals by category on the Home screen.',
              value: settings.categoriesEnabled,
              onChanged: settings.setCategoriesEnabled,
            ),
            _ReferenceToggleRow(
              icon: Icons.swap_vert_rounded,
              title: 'Move between categories by dragging',
              subtitle: 'Reorder goals by dragging them between categories.',
              value: settings.categoryDragEnabled,
              onChanged: settings.categoriesEnabled
                  ? settings.setCategoryDragEnabled
                  : null,
            ),
          ],
        ),
        const SizedBox(height: 12),
        _ReferenceSection(
          title: 'Categories',
          children: [
            for (final category in GoalCategories.builtIn.take(5))
              _CategoryRow(
                category: category,
                value: settings.data.enabledCategories.contains(category),
                onChanged: settings.categoriesEnabled
                    ? (value) => settings.setCategoryEnabled(category, value)
                    : null,
              ),
          ],
        ),
        const SizedBox(height: 12),
        _ReferenceSection(
          title: 'Progress display',
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 2, 8, 9),
              child: Row(
                children: [
                  for (
                    var index = 0;
                    index < AppProgressFormat.values.length;
                    index++
                  ) ...[
                    Expanded(
                      child: _CompactChoice(
                        key: Key(
                          'progress-format-${AppProgressFormat.values[index].name}',
                        ),
                        icon: switch (AppProgressFormat.values[index]) {
                          AppProgressFormat.percentage => Icons.percent_rounded,
                          AppProgressFormat.amount => Icons.bar_chart_rounded,
                          AppProgressFormat.both => Icons.query_stats_rounded,
                        },
                        label: AppProgressFormat.values[index].label,
                        selected:
                            settings.progressFormat ==
                            AppProgressFormat.values[index],
                        onTap: () => settings.setProgressFormat(
                          AppProgressFormat.values[index],
                        ),
                      ),
                    ),
                    if (index != AppProgressFormat.values.length - 1)
                      const SizedBox(width: 6),
                  ],
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _ReferenceSection(
          children: [
            _ReferenceToggleRow(
              key: const Key('show-abandoned-switch'),
              icon: Icons.inventory_2_outlined,
              title: 'Show abandoned goals',
              subtitle: "Display goals you've abandoned in your lists.",
              value: settings.showAbandoned,
              onChanged: settings.setShowAbandoned,
            ),
          ],
        ),
      ],
    ),
  );
}

class _CategoryRow extends StatelessWidget {
  const _CategoryRow({
    required this.category,
    required this.value,
    required this.onChanged,
  });
  final String category;
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final (icon, color) = switch (category) {
      'Faith' => (Icons.dark_mode_outlined, AppColors.blueText),
      'Health' => (Icons.favorite_outline_rounded, AppColors.coral),
      'Mind' => (Icons.psychology_outlined, const Color(0xFFE2A200)),
      'Body' => (Icons.fitness_center_rounded, AppColors.lightGreen),
      'Finances' => (Icons.monetization_on_outlined, AppColors.blue),
      _ => (Icons.label_outline_rounded, AppColors.blueText),
    };
    return InkWell(
      onTap: onChanged == null ? null : () => onChanged!(!value),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        child: Row(
          children: [
            Icon(icon, color: color, size: 21),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                category,
                style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Checkbox(
              value: value,
              onChanged: onChanged == null
                  ? null
                  : (checked) => onChanged!(checked ?? false),
            ),
          ],
        ),
      ),
    );
  }
}

class _CompactChoice extends StatelessWidget {
  const _CompactChoice({
    super.key,
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(8),
    child: AnimatedContainer(
      duration: LifeMotion.quick,
      height: 94,
      decoration: BoxDecoration(
        color: selected ? context.appSoftRed : context.appPanel,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: selected ? AppColors.coral : context.appBorder,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            color: selected ? AppColors.coral : context.appBlueText,
            size: 25,
          ),
          const SizedBox(height: 5),
          Text(
            label,
            maxLines: 2,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 10.5, height: 1.05),
          ),
          const SizedBox(height: 5),
          Icon(
            selected ? Icons.radio_button_checked : Icons.radio_button_off,
            color: selected ? AppColors.coral : context.appBlueText,
            size: 21,
          ),
        ],
      ),
    ),
  );
}

class _OpenedGoalSettings extends StatelessWidget {
  const _OpenedGoalSettings(this.settings);
  final AppSettingsController settings;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: settings,
    builder: (context, _) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ReferenceSection(
          title: 'Default view inside a goal',
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Choose how a goal opens. This affects what you see first when you tap a goal from your lists.',
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.3,
                      color: context.appMuted,
                    ),
                  ),
                  const SizedBox(height: 11),
                  Row(
                    children: [
                      _ReferenceChoiceBox(
                        icon: Icons.short_text_rounded,
                        label: 'Simple',
                        selected:
                            settings.defaultGoalDetailView ==
                            GoalDetailView.simple,
                        onTap: () => settings.setDefaultGoalDetailView(
                          GoalDetailView.simple,
                        ),
                      ),
                      const SizedBox(width: 10),
                      _ReferenceChoiceBox(
                        icon: Icons.format_list_bulleted_rounded,
                        label: 'Detailed',
                        selected:
                            settings.defaultGoalDetailView ==
                            GoalDetailView.detailed,
                        onTap: () => settings.setDefaultGoalDetailView(
                          GoalDetailView.detailed,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _ReferenceSection(
          children: [
            _ReferenceToggleRow(
              icon: Icons.history_rounded,
              title: "Remember each goal's view",
              subtitle:
                  'Life Tracker will open each goal in the same view you last used for that goal.',
              value: settings.rememberGoalDetailView,
              onChanged: settings.setRememberGoalDetailView,
            ),
          ],
        ),
        const SizedBox(height: 12),
        const _InfoPanel(
          icon: Icons.info_outline_rounded,
          color: AppColors.blueText,
          text: 'You can always switch views inside a goal at any time.',
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
    builder: (context, _) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ReferenceSection(
          title: 'Salah settings',
          children: [
            _ReferenceToggleRow(
              key: const Key('salah-calendar-enabled'),
              icon: Icons.shield_outlined,
              iconColor: AppColors.lightGreen,
              title: 'Protect Salah times',
              subtitle:
                  'Automatically block time for prayers in your calendar.',
              value: settings.salahEnabled,
              onChanged: (value) {
                if (value) lifeStore?.setShowBlockedTimes(true);
                settings.setSalahEnabled(value);
              },
            ),
            _ReferenceActionRow(
              icon: Icons.location_on_outlined,
              title: 'Prayer location',
              value: settings.data.salahLocationName,
              enabled: settings.salahEnabled,
              onTap: () => _editSalahLocation(context, settings),
            ),
            _ReferenceActionRow(
              icon: Icons.my_location_rounded,
              title: 'Use current location',
              subtitle: 'Update location from this device',
              enabled: settings.salahEnabled,
              onTap: () => _useCurrentSalahLocation(context, settings),
            ),
            _ReferenceActionRow(
              icon: Icons.calculate_outlined,
              title: 'Calculation method',
              value: _shortCalculationMethod(settings.salahCalculationMethod),
              enabled: settings.salahEnabled,
              onTap: () => _chooseSetting<SalahCalculationMethod>(
                context,
                title: 'Calculation method',
                values: SalahCalculationMethod.values,
                selected: settings.salahCalculationMethod,
                label: (value) => value.label,
                onSelected: settings.setSalahCalculationMethod,
              ),
            ),
            _ReferenceActionRow(
              icon: Icons.schedule_outlined,
              title: 'Asr method',
              value: settings.salahAsrMethod == SalahAsrMethod.shafi
                  ? 'Standard (Shafi‘i)'
                  : 'Hanafi',
              enabled: settings.salahEnabled,
              onTap: () => _chooseSetting<SalahAsrMethod>(
                context,
                title: 'Asr method',
                values: SalahAsrMethod.values,
                selected: settings.salahAsrMethod,
                label: (value) => value.label,
                onSelected: settings.setSalahAsrMethod,
              ),
            ),
            _ReferenceActionRow(
              icon: Icons.timer_outlined,
              title: 'Protected block duration',
              value: '${settings.data.salahBlockMinutes} minutes',
              enabled: settings.salahEnabled,
              onTap: () => _chooseSetting<int>(
                context,
                title: 'Protected block duration',
                values: const [15, 30, 45, 60],
                selected: settings.data.salahBlockMinutes,
                label: (value) => value == 60 ? '1 hour' : '$value minutes',
                onSelected: settings.setSalahBlockMinutes,
              ),
            ),
            _ReferenceActionRow(
              icon: Icons.settings_outlined,
              title: 'Advanced calculation',
              value: 'High-latitude rule and local minute offsets',
              enabled: settings.salahEnabled,
              onTap: () => _openAdvancedSalah(context, settings),
            ),
          ],
        ),
        const SizedBox(height: 12),
        const _InfoPanel(
          icon: Icons.info_outline_rounded,
          color: AppColors.blueText,
          text: 'Prayer blocks update daily and appear in Calendar.',
        ),
      ],
    ),
  );
}

String _shortCalculationMethod(SalahCalculationMethod method) =>
    switch (method) {
      SalahCalculationMethod.northAmerica => 'ISNA',
      SalahCalculationMethod.muslimWorldLeague => 'Muslim World League',
      SalahCalculationMethod.egyptian => 'Egyptian Authority',
      SalahCalculationMethod.karachi => 'Karachi',
      SalahCalculationMethod.ummAlQura => 'Umm al-Qura',
    };

Future<void> _chooseSetting<T>(
  BuildContext context, {
  required String title,
  required List<T> values,
  required T selected,
  required String Function(T value) label,
  required ValueChanged<T> onSelected,
}) async {
  final result = await showModalBottomSheet<T>(
    context: context,
    useSafeArea: true,
    showDragHandle: true,
    builder: (context) => Padding(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          for (final value in values)
            ListTile(
              leading: Icon(
                value == selected
                    ? Icons.radio_button_checked
                    : Icons.radio_button_off,
                color: value == selected
                    ? AppColors.coral
                    : context.appBlueText,
              ),
              title: Text(label(value)),
              onTap: () => Navigator.pop(context, value),
            ),
        ],
      ),
    ),
  );
  if (result != null) onSelected(result);
}

Future<void> _openAdvancedSalah(
  BuildContext context,
  AppSettingsController settings,
) => Navigator.of(context).push(
  MaterialPageRoute<void>(
    builder: (context) => Scaffold(
      appBar: AppBar(title: const Text('Advanced calculation')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(12),
          children: [
            _ReferenceSection(
              children: [
                _ReferenceActionRow(
                  icon: Icons.public_rounded,
                  title: 'High-latitude rule',
                  value: settings.salahHighLatitudeRule.label,
                  onTap: () => _chooseSetting<SalahHighLatitudeRule>(
                    context,
                    title: 'High-latitude rule',
                    values: SalahHighLatitudeRule.values,
                    selected: settings.salahHighLatitudeRule,
                    label: (value) => value.label,
                    onSelected: settings.setSalahHighLatitudeRule,
                  ),
                ),
                for (final prayer in const [
                  'Fajr',
                  'Dhuhr',
                  'Asr',
                  'Maghrib',
                  'Isha',
                ])
                  _ReferenceActionRow(
                    icon: Icons.schedule_rounded,
                    title: '$prayer adjustment',
                    value:
                        '${settings.data.salahAdjustments[prayer] ?? 0} minutes',
                    onTap: () => _chooseSetting<int>(
                      context,
                      title: '$prayer adjustment',
                      values: const [-10, -5, 0, 5, 10],
                      selected: settings.data.salahAdjustments[prayer] ?? 0,
                      label: (value) => value == 0
                          ? 'None'
                          : '${value > 0 ? '+' : ''}$value minutes',
                      onSelected: (value) =>
                          settings.setSalahAdjustment(prayer, value),
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
    builder: (context, _) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ReferenceSection(
          children: [
            _ReferenceToggleRow(
              icon: Icons.notifications_none_rounded,
              iconColor: AppColors.lightGreen,
              title: 'Allow reminders',
              subtitle:
                  'Get notified about your tasks, goals and daily review.',
              value: settings.notificationsEnabled,
              onChanged: _working ? null : _setEnabled,
            ),
            if (widget.notifications != null) ...[
              Padding(
                padding: const EdgeInsets.all(10),
                child: _NotificationStatusTile(
                  status: _status,
                  loading: _working,
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 2, 10, 10),
                child: Row(
                  children: [
                    Expanded(
                      child: FilledButton.tonalIcon(
                        style: FilledButton.styleFrom(
                          backgroundColor: context.appSoftRed,
                          foregroundColor: AppColors.coralText,
                        ),
                        onPressed: _working
                            ? null
                            : () => _run(
                                (service) => service.sendTestNotification(),
                                'Test notification sent.',
                              ),
                        icon: const Icon(Icons.send_outlined, size: 18),
                        label: const Text('Send test now'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _working
                            ? null
                            : () => _run((service) async {
                                await service.openNotificationSettings();
                              }, 'Device notification settings opened.'),
                        icon: const Icon(Icons.settings_outlined, size: 18),
                        label: const Text('Device settings'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            _ReferenceActionRow(
              icon: Icons.notifications_none_rounded,
              title: 'Default frequency',
              value:
                  settings.defaultReminderFrequency ==
                      DefaultReminderFrequency.daily
                  ? 'Daily'
                  : settings.defaultReminderFrequency.label,
              enabled: settings.notificationsEnabled,
              onTap: () => _chooseSetting<DefaultReminderFrequency>(
                context,
                title: 'Default frequency',
                values: DefaultReminderFrequency.values,
                selected: settings.defaultReminderFrequency,
                label: (value) => value.label,
                onSelected: settings.setDefaultReminderFrequency,
              ),
            ),
            _ReferenceActionRow(
              icon: Icons.schedule_outlined,
              title: 'Default reminder time',
              value: settings.defaultReminderTime.format(context),
              enabled: settings.notificationsEnabled,
              onTap: () => _selectTime(
                context,
                settings.defaultReminderTime,
                settings.setDefaultReminderTime,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _ReferenceSection(
          children: [
            _ReferenceToggleRow(
              icon: Icons.article_outlined,
              title: 'End-of-day review',
              subtitle: 'Get a reminder to review your day.',
              value: settings.endOfDayReview,
              onChanged: settings.notificationsEnabled
                  ? settings.setEndOfDayReview
                  : null,
            ),
            if (settings.endOfDayReview)
              _ReferenceActionRow(
                icon: Icons.schedule_outlined,
                title: 'Review time',
                value: settings.endOfDayTime.format(context),
                enabled: settings.notificationsEnabled,
                onTap: () => _selectTime(
                  context,
                  settings.endOfDayTime,
                  settings.setEndOfDayTime,
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        _ReferenceSection(
          tint: context.appSoftAmber.withValues(alpha: .5),
          children: [
            _ReferenceToggleRow(
              icon: Icons.dark_mode_outlined,
              iconColor: const Color(0xFFD29500),
              title: 'Quiet hours',
              subtitle: 'Pause non-essential notifications at night.',
              value: settings.quietHoursEnabled,
              onChanged: settings.notificationsEnabled
                  ? settings.setQuietHoursEnabled
                  : null,
            ),
            if (settings.quietHoursEnabled) ...[
              _ReferenceActionRow(
                icon: Icons.dark_mode_outlined,
                title: 'From',
                value: settings.quietStart.format(context),
                enabled: settings.notificationsEnabled,
                onTap: () => _selectTime(
                  context,
                  settings.quietStart,
                  settings.setQuietStart,
                ),
              ),
              _ReferenceActionRow(
                icon: Icons.dark_mode_outlined,
                title: 'Until',
                value: settings.quietEnd.format(context),
                enabled: settings.notificationsEnabled,
                onTap: () => _selectTime(
                  context,
                  settings.quietEnd,
                  settings.setQuietEnd,
                ),
              ),
            ],
          ],
        ),
      ],
    ),
  );
}

Future<void> _selectTime(
  BuildContext context,
  TimeOfDay initial,
  ValueChanged<TimeOfDay> onSelected,
) async {
  final selected = await showTimePicker(context: context, initialTime: initial);
  if (selected != null) onSelected(selected);
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: current?.allowed == false
            ? context.appSoftRed
            : context.appSoftGreen,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: current?.allowed == false
              ? AppColors.coral.withValues(alpha: .25)
              : AppColors.lightGreen.withValues(alpha: .25),
        ),
      ),
      child: Row(
        children: [
          loading
              ? const SizedBox.square(
                  dimension: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Icon(icon, color: context.appGreenText),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  current?.allowed == true ? 'Notifications available' : title,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: current?.allowed == false
                        ? context.appDangerText
                        : context.appGreenText,
                  ),
                ),
                Text(
                  current?.allowed == true
                      ? "You'll receive reminders on this device."
                      : subtitle,
                  style: TextStyle(fontSize: 10.5, color: context.appMuted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PlanSettings extends StatelessWidget {
  const _PlanSettings(this.settings);
  final AppSettingsController settings;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: settings,
    builder: (context, _) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ReferenceSection(
          tint: context.appSoftGreen,
          children: [
            _ReferenceToggleRow(
              icon: Icons.calendar_month_outlined,
              iconColor: AppColors.lightGreen,
              title: 'Start goals automatically',
              subtitle:
                  'Move a planned goal to Active when its start date arrives.',
              value: settings.automaticStarts,
              onChanged: settings.setAutomaticStarts,
            ),
          ],
        ),
        const SizedBox(height: 12),
        const _InfoPanel(
          icon: Icons.info_outline_rounded,
          color: AppColors.blueText,
          text: 'Existing start dates are respected.',
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
    builder: (context, _) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ReferenceSection(
          children: [
            _ReferenceToggleRow(
              icon: Icons.grid_view_outlined,
              title: "Show today's actions",
              subtitle: 'Display your next tasks on Home screen.',
              value: settings.widgetShowTodayActions,
              onChanged: settings.setWidgetShowTodayActions,
            ),
            _ReferenceToggleRow(
              icon: Icons.bar_chart_rounded,
              title: 'Show progress',
              subtitle: 'Show goal progress on Home screen.',
              value: settings.widgetShowProgress,
              onChanged: settings.setWidgetShowProgress,
            ),
          ],
        ),
        const SizedBox(height: 12),
        _ReferenceSection(
          title: 'Widget content',
          children: [
            _ReferenceActionRow(
              icon: Icons.track_changes_rounded,
              title: 'Goal scope',
              value: settings.widgetGoalScope.label,
              onTap: () => _chooseSetting<WidgetGoalScope>(
                context,
                title: 'Goal scope',
                values: WidgetGoalScope.values,
                selected: settings.widgetGoalScope,
                label: (value) => value.label,
                onSelected: settings.setWidgetGoalScope,
              ),
            ),
            _ReferenceActionRow(
              icon: Icons.format_list_bulleted_rounded,
              title: 'Categories',
              value: settings.widgetCategory.isEmpty
                  ? 'All visible categories'
                  : settings.widgetCategory,
              onTap: () {
                final values = <String>[
                  '',
                  ...settings.visibleCategories(store.availableCategories),
                ];
                _chooseSetting<String>(
                  context,
                  title: 'Categories',
                  values: values,
                  selected: settings.widgetCategory,
                  label: (value) =>
                      value.isEmpty ? 'All visible categories' : value,
                  onSelected: settings.setWidgetCategory,
                );
              },
            ),
            _ReferenceActionRow(
              icon: Icons.tag_rounded,
              title: 'Maximum goals',
              value: '${settings.widgetMaxCards}',
              onTap: () => _chooseSetting<int>(
                context,
                title: 'Maximum goals',
                values: const [3, 5, 8],
                selected: settings.widgetMaxCards,
                label: (value) => '$value',
                onSelected: settings.setWidgetMaxCards,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _ReferenceSection(
          title: 'Add widgets',
          children: [
            _WidgetAction(
              title: 'Add Today widget',
              subtitle: 'Your next actions',
              onTap: () => GoalWidgetService().requestPinTodayWidget(),
            ),
            _WidgetAction(
              title: 'Add Goal Cards widget',
              subtitle: 'Progress at a glance',
              onTap: () => GoalWidgetService().requestPinCardsWidget(),
            ),
            _WidgetAction(
              title: 'Add Calendar widget',
              subtitle: 'Upcoming events and Salah',
              onTap: () => GoalWidgetService().requestPinCalendarWidget(),
            ),
          ],
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(48),
            backgroundColor: context.appSoftRed,
            foregroundColor: AppColors.coralText,
          ),
          onPressed: () =>
              GoalWidgetService().sync(store.goals, store, lifeStore, settings),
          icon: const Icon(Icons.refresh_rounded),
          label: const Text('Refresh widgets'),
        ),
      ],
    ),
  );
}

class _WidgetAction extends StatelessWidget {
  const _WidgetAction({
    required this.title,
    required this.subtitle,
    required this.onTap,
  });
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.blue.withValues(alpha: .7)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: context.appSoftBlue,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.add_rounded, color: AppColors.blueText),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.blueText,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 10.5, color: context.appMuted),
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

class _LocalDataSettings extends StatelessWidget {
  const _LocalDataSettings(this.store);
  final GoalStore store;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _ReferenceSection(
        tint: context.appSoftGreen,
        children: const [
          _ReferenceActionRow(
            icon: Icons.check_circle_rounded,
            iconColor: AppColors.lightGreen,
            title: 'Automatic saving is on',
            subtitle:
                'Goals, checklist steps, progress, reminders, and Settings save as soon as they change.',
            trailing: SizedBox.shrink(),
          ),
        ],
      ),
      const SizedBox(height: 12),
      _ReferenceSection(
        title: 'Storage location',
        children: [
          _ReferenceActionRow(
            icon: Icons.folder_outlined,
            title: 'On this device',
            value: 'Life Tracker / Data',
            trailing: const SizedBox.shrink(),
          ),
        ],
      ),
      const SizedBox(height: 12),
      OutlinedButton.icon(
        key: const Key('open-local-folder-setting'),
        style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
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
      const SizedBox(height: 12),
      const _InfoPanel(
        icon: Icons.info_outline_rounded,
        color: AppColors.blueText,
        text:
            "Your data stays on this device. Files are saved in Markdown format so they're easy to back up and keep private.",
      ),
    ],
  );
}
