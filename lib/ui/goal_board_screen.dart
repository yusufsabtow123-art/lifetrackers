import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../app/goal_store.dart';
import '../data/goal_repository.dart';
import '../domain/goal.dart';
import '../app/theme_controller.dart';
import '../domain/plan_calculator.dart';
import '../platform/goal_notification_service.dart';
import 'app_theme.dart';
import 'create_goal_dialog.dart';
import 'goal_details_sheet.dart';
import 'progress_format.dart';
import 'settings_page.dart';
import 'start_notice.dart';

bool get _canOpenLocalFolder =>
    !kIsWeb &&
    switch (defaultTargetPlatform) {
      TargetPlatform.windows ||
      TargetPlatform.macOS ||
      TargetPlatform.linux => true,
      _ => false,
    };

class GoalBoardScreen extends StatefulWidget {
  const GoalBoardScreen({
    super.key,
    required this.store,
    required this.settings,
    this.notificationService,
    this.embedded = false,
    this.embeddedDesktop = false,
  });

  final GoalStore store;
  final AppSettingsController settings;
  final GoalNotificationService? notificationService;
  final bool embedded;
  final bool embeddedDesktop;

  @override
  State<GoalBoardScreen> createState() => _GoalBoardScreenState();
}

class _GoalBoardScreenState extends State<GoalBoardScreen> {
  bool _showingSettings = false;

  @override
  Widget build(BuildContext context) {
    final store = widget.store;
    final settings = widget.settings;
    return AnimatedBuilder(
      animation: Listenable.merge([store, settings]),
      builder: (context, _) {
        final width = MediaQuery.sizeOf(context).width;
        final desktop = widget.embedded ? widget.embeddedDesktop : width >= 760;
        final touchSafeDrag = switch (defaultTargetPlatform) {
          TargetPlatform.android || TargetPlatform.iOS => true,
          _ => false,
        };
        return Scaffold(
          appBar: desktop
              ? null
              : AppBar(
                  backgroundColor: context.appPanel,
                  surfaceTintColor: Colors.transparent,
                  leading: _showingSettings
                      ? IconButton(
                          tooltip: 'Back to goals',
                          onPressed: () => setState(() {
                            _showingSettings = false;
                            store.setShowingTrash(false);
                          }),
                          icon: const Icon(Icons.arrow_back_rounded),
                        )
                      : null,
                  title: Text(
                    _showingSettings
                        ? 'Settings'
                        : store.showingTrash
                        ? 'Trash'
                        : 'Goals',
                  ),
                  actions: [
                    if (!_showingSettings) ...[
                      if (store.canUndo)
                        IconButton(
                          tooltip: store.undoDescription ?? 'Undo last change',
                          onPressed: store.undoLastChange,
                          icon: const Icon(Icons.undo_rounded),
                        ),
                      _AppearanceMenu(settings: settings),
                      IconButton(
                        key: const Key('settings-button'),
                        tooltip: 'Settings',
                        onPressed: () => setState(() {
                          _showingSettings = true;
                        }),
                        icon: const Icon(Icons.settings_outlined),
                      ),
                      IconButton(
                        tooltip: store.showingTrash ? 'All goals' : 'Trash',
                        onPressed: () =>
                            store.setShowingTrash(!store.showingTrash),
                        icon: Icon(
                          store.showingTrash
                              ? Icons.dashboard_outlined
                              : Icons.delete_outline_rounded,
                        ),
                      ),
                      const SizedBox(width: 6),
                    ],
                  ],
                ),
          body: SafeArea(
            child: Row(
              children: [
                if (desktop && !widget.embedded)
                  _DesktopSidebar(
                    store: store,
                    settings: settings,
                    showingSettings: _showingSettings,
                    onShowGoals: () => setState(() {
                      _showingSettings = false;
                      store.setShowingTrash(false);
                    }),
                    onShowTrash: () => setState(() {
                      _showingSettings = false;
                      store.setShowingTrash(true);
                    }),
                    onShowSettings: () => setState(() {
                      _showingSettings = true;
                    }),
                  ),
                Expanded(
                  child: _showingSettings
                      ? SettingsPage(
                          store: store,
                          settings: settings,
                          notificationService: widget.notificationService,
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (desktop)
                              store.showingTrash
                                  ? _TrashHeader(store: store)
                                  : _DesktopHeader(
                                      store: store,
                                      settings: settings,
                                    ),
                            if (store.errorMessage != null)
                              _ErrorBanner(
                                message: store.errorMessage!,
                                onRetry: store.isLoading ? null : store.load,
                              ),
                            if (store.loadIssues.isNotEmpty)
                              _LoadIssuesBanner(
                                store.loadIssues,
                                onRetry: store.load,
                              ),
                            if (!store.showingTrash)
                              if (store.pendingStartNotice case final goal?)
                                StartNotice(
                                  store: store,
                                  goal: goal,
                                  showAbandoned: settings.showAbandoned,
                                  progressFormat: settings.progressFormat,
                                  settings: settings,
                                ),
                            Expanded(
                              child: store.isLoading
                                  ? const Center(
                                      child: CircularProgressIndicator(),
                                    )
                                  : store.showingTrash
                                  ? _TrashView(store: store)
                                  : _GoalBoard(
                                      store: store,
                                      desktop: desktop,
                                      touchSafeDrag: touchSafeDrag,
                                      settings: settings,
                                    ),
                            ),
                          ],
                        ),
                ),
              ],
            ),
          ),
          floatingActionButton:
              desktop || store.showingTrash || _showingSettings
              ? null
              : FloatingActionButton.extended(
                  onPressed: () => showCreateGoalDialog(context, store),
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Capture idea'),
                ),
        );
      },
    );
  }
}

class _DesktopSidebar extends StatelessWidget {
  const _DesktopSidebar({
    required this.store,
    required this.settings,
    required this.showingSettings,
    required this.onShowGoals,
    required this.onShowTrash,
    required this.onShowSettings,
  });

  final GoalStore store;
  final AppSettingsController settings;
  final bool showingSettings;
  final VoidCallback onShowGoals;
  final VoidCallback onShowTrash;
  final VoidCallback onShowSettings;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 220,
      decoration: BoxDecoration(
        color: context.appRaised,
        border: Border(right: BorderSide(color: context.appBorder)),
      ),
      padding: const EdgeInsets.fromLTRB(18, 28, 18, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: context.isDarkMode
                      ? AppColors.greenDark
                      : AppColors.navy,
                  borderRadius: BorderRadius.circular(11),
                ),
                child: const Icon(
                  Icons.track_changes_rounded,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 12),
              Text('Goals', style: Theme.of(context).textTheme.titleLarge),
            ],
          ),
          const SizedBox(height: 34),
          _SidebarDestination(
            icon: Icons.dashboard_outlined,
            label: 'All goals',
            selected: !showingSettings && !store.showingTrash,
            onTap: onShowGoals,
          ),
          const SizedBox(height: 8),
          _SidebarDestination(
            icon: Icons.delete_outline_rounded,
            label: 'Trash',
            count: store.trashedGoals.length,
            selected: !showingSettings && store.showingTrash,
            onTap: onShowTrash,
          ),
          const SizedBox(height: 8),
          _SidebarDestination(
            icon: Icons.settings_outlined,
            label: 'Settings',
            selected: showingSettings,
            onTap: onShowSettings,
          ),
          const Spacer(),
          _AppearanceMenu(settings: settings, showLabel: true),
          const SizedBox(height: 12),
          Divider(color: context.appBorder),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.lock_outline_rounded,
                size: 18,
                color: context.appMuted,
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  'Local files only\nNo account or internet',
                  style: TextStyle(
                    fontSize: 12,
                    color: context.appMuted,
                    height: 1.45,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SidebarDestination extends StatelessWidget {
  const _SidebarDestination({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
    this.count,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final int? count;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? context.appPanel : Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? context.appBorder : Colors.transparent,
            ),
          ),
          child: Row(
            children: [
              Icon(icon, size: 21),
              const SizedBox(width: 11),
              Expanded(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                  ),
                ),
              ),
              if (count case final value?)
                Text('$value', style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
      ),
    );
  }
}

class _AppearanceMenu extends StatelessWidget {
  const _AppearanceMenu({required this.settings, this.showLabel = false});

  final AppSettingsController settings;
  final bool showLabel;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<AppAppearance>(
      key: const Key('appearance-menu'),
      tooltip: 'Appearance: ${settings.appearance.label}',
      onSelected: settings.setAppearance,
      itemBuilder: (context) => [
        for (final appearance in AppAppearance.values)
          CheckedPopupMenuItem(
            key: Key('appearance-${appearance.name}'),
            value: appearance,
            checked: settings.appearance == appearance,
            child: Row(
              children: [
                Icon(appearance.icon, size: 20),
                const SizedBox(width: 10),
                Text(appearance.label),
              ],
            ),
          ),
      ],
      child: showLabel
          ? Container(
              height: 46,
              padding: const EdgeInsets.symmetric(horizontal: 13),
              decoration: BoxDecoration(
                border: Border.all(color: context.appBorder),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(settings.appearance.icon, size: 20),
                  const SizedBox(width: 10),
                  Expanded(child: Text(settings.appearance.label)),
                  const Icon(Icons.expand_more_rounded, size: 19),
                ],
              ),
            )
          : SizedBox(
              width: 48,
              height: 48,
              child: Icon(settings.appearance.icon),
            ),
    );
  }
}

class _DesktopHeader extends StatelessWidget {
  const _DesktopHeader({required this.store, required this.settings});

  final GoalStore store;
  final AppSettingsController settings;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 24, 28, 18),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Goals', style: Theme.of(context).textTheme.displaySmall),
                const SizedBox(height: 6),
                Text(
                  store.isSaving
                      ? 'Saving changes...'
                      : 'All changes saved automatically to local Markdown.',
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: context.appMuted),
                ),
              ],
            ),
          ),
          IconButton.outlined(
            tooltip: 'How the columns work',
            onPressed: () => _showColumnsHelp(context, settings.showAbandoned),
            icon: const Icon(Icons.info_outline_rounded),
          ),
          const SizedBox(width: 8),
          IconButton.outlined(
            tooltip: _canOpenLocalFolder
                ? 'Open local Markdown folder\n${store.storagePath}'
                : 'Show local storage information',
            onPressed: () => _canOpenLocalFolder
                ? _openStorage(context, store)
                : _showStoragePath(context, store.storagePath),
            icon: Icon(
              _canOpenLocalFolder
                  ? Icons.folder_outlined
                  : Icons.info_outline_rounded,
            ),
          ),
          const SizedBox(width: 8),
          if (store.canUndo) ...[
            OutlinedButton.icon(
              onPressed: store.undoLastChange,
              icon: const Icon(Icons.undo_rounded),
              label: const Text('Undo'),
            ),
            const SizedBox(width: 8),
          ],
          FilledButton.icon(
            onPressed: () => showCreateGoalDialog(context, store),
            icon: const Icon(Icons.add_rounded),
            label: const Text('Capture idea'),
          ),
        ],
      ),
    );
  }
}

class _TrashHeader extends StatelessWidget {
  const _TrashHeader({required this.store});

  final GoalStore store;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 24, 28, 18),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Trash', style: Theme.of(context).textTheme.displaySmall),
                const SizedBox(height: 6),
                Text(
                  'Deleted goals stay here until you restore or delete them forever.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
          if (store.canUndo)
            OutlinedButton.icon(
              onPressed: store.undoLastChange,
              icon: const Icon(Icons.undo_rounded),
              label: const Text('Undo'),
            ),
        ],
      ),
    );
  }
}

class _TrashView extends StatelessWidget {
  const _TrashView({required this.store});

  final GoalStore store;

  @override
  Widget build(BuildContext context) {
    final goals = store.trashedGoals;
    if (goals.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.delete_sweep_outlined,
                size: 48,
                color: context.appMuted,
              ),
              const SizedBox(height: 14),
              Text(
                'Trash is empty',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 8),
              Text(
                'Goals you delete will remain recoverable here.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 18),
              OutlinedButton.icon(
                onPressed: () => store.setShowingTrash(false),
                icon: const Icon(Icons.dashboard_outlined),
                label: const Text('Return to all goals'),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(28, 4, 28, 28),
      itemCount: goals.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final goal = goals[index];
        return Card(
          key: Key('trash-goal-${goal.id}'),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: context.appSoftRed,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.delete_outline_rounded,
                        color: context.appDangerText,
                      ),
                    ),
                    const SizedBox(width: 13),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            goal.name,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Was in ${goal.status.label} - deleted ${_dateLabel(goal.trashedAt!)}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.end,
                  children: [
                    OutlinedButton.icon(
                      key: Key('restore-goal-${goal.id}'),
                      onPressed: () => store.restoreGoal(goal.id),
                      icon: const Icon(Icons.restore_rounded),
                      label: const Text('Restore'),
                    ),
                    TextButton.icon(
                      key: Key('delete-forever-${goal.id}'),
                      onPressed: () =>
                          _confirmDeleteForever(context, store, goal),
                      icon: Icon(
                        Icons.delete_forever_outlined,
                        color: Theme.of(context).colorScheme.error,
                      ),
                      label: Text(
                        'Delete forever',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _GoalBoard extends StatefulWidget {
  const _GoalBoard({
    required this.store,
    required this.desktop,
    required this.touchSafeDrag,
    required this.settings,
  });

  final GoalStore store;
  final bool desktop;
  final bool touchSafeDrag;
  final AppSettingsController settings;

  @override
  State<_GoalBoard> createState() => _GoalBoardState();
}

class _GoalBoardState extends State<_GoalBoard> {
  final _scrollController = ScrollController();
  final _boardViewportKey = GlobalKey();
  String? _selectedCategory;

  void _scrollBoardNearEdge(Offset globalPosition) {
    if (!_scrollController.hasClients) return;
    final box = _boardViewportKey.currentContext?.findRenderObject();
    if (box is! RenderBox) return;
    final local = box.globalToLocal(globalPosition);
    const edge = 72.0;
    final delta = local.dx < edge
        ? -14.0
        : local.dx > box.size.width - edge
        ? 14.0
        : 0.0;
    if (delta == 0) return;
    final position = _scrollController.position;
    _scrollController.jumpTo(
      (position.pixels + delta)
          .clamp(position.minScrollExtent, position.maxScrollExtent)
          .toDouble(),
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final categoryBar = widget.settings.categoriesEnabled
        ? _CategoryFilterBar(
            categories: widget.settings.visibleCategories(
              widget.store.availableCategories,
            ),
            selected: _selectedCategory,
            onSelected: (category) =>
                setState(() => _selectedCategory = category),
            onGoalDropped: widget.settings.categoryDragEnabled
                ? widget.store.setCategory
                : null,
          )
        : const SizedBox.shrink();
    if (!widget.desktop) {
      return Column(
        children: [
          categoryBar,
          _HiddenColumnsControl(
            settings: widget.settings,
            showAbandoned: widget.settings.showAbandoned,
          ),
          Expanded(
            child: _MobileMiniBoard(
              store: widget.store,
              touchSafeDrag: widget.touchSafeDrag,
              showAbandoned: widget.settings.showAbandoned,
              progressFormat: widget.settings.progressFormat,
              category: _selectedCategory,
              settings: widget.settings,
            ),
          ),
        ],
      );
    }

    final viewportWidth =
        MediaQuery.sizeOf(context).width - (widget.desktop ? 220 : 0);
    final columnWidth = widget.desktop
        ? 286.0
        : (viewportWidth - 36).clamp(280.0, 420.0);
    final statuses = _visibleGoalStatuses(
      widget.settings,
      showAbandoned: widget.settings.showAbandoned,
    );
    return Column(
      children: [
        categoryBar,
        _HiddenColumnsControl(
          settings: widget.settings,
          showAbandoned: widget.settings.showAbandoned,
        ),
        Expanded(
          child: Scrollbar(
            controller: _scrollController,
            thumbVisibility: widget.desktop,
            child: ListView.separated(
              key: _boardViewportKey,
              controller: _scrollController,
              padding: EdgeInsets.fromLTRB(
                widget.desktop ? 28 : 16,
                4,
                widget.desktop ? 28 : 16,
                24,
              ),
              scrollDirection: Axis.horizontal,
              itemCount: statuses.length,
              separatorBuilder: (_, _) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                final status = statuses[index];
                return SizedBox(
                  width: columnWidth,
                  child: _BoardColumn(
                    status: status,
                    settings: widget.settings,
                    goals: widget.store.goalsFor(
                      status,
                      category: _selectedCategory,
                    ),
                    store: widget.store,
                    touchSafeDrag: widget.touchSafeDrag,
                    showAbandoned: widget.settings.showAbandoned,
                    progressFormat: widget.settings.progressFormat,
                    onDragMove: _scrollBoardNearEdge,
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

class _CategoryFilterBar extends StatefulWidget {
  const _CategoryFilterBar({
    required this.categories,
    required this.selected,
    required this.onSelected,
    required this.onGoalDropped,
  });

  final List<String> categories;
  final String? selected;
  final ValueChanged<String?> onSelected;
  final Future<void> Function(String goalId, String category)? onGoalDropped;

  @override
  State<_CategoryFilterBar> createState() => _CategoryFilterBarState();
}

class _CategoryFilterBarState extends State<_CategoryFilterBar> {
  final _controller = ScrollController();
  final _viewportKey = GlobalKey();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _scrollNearEdge(Offset globalPosition) {
    if (!_controller.hasClients) return;
    final box = _viewportKey.currentContext?.findRenderObject();
    if (box is! RenderBox) return;
    final local = box.globalToLocal(globalPosition);
    final delta = local.dx < 56
        ? -10.0
        : local.dx > box.size.width - 56
        ? 10.0
        : 0.0;
    if (delta == 0) return;
    final position = _controller.position;
    _controller.jumpTo(
      (position.pixels + delta)
          .clamp(position.minScrollExtent, position.maxScrollExtent)
          .toDouble(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      key: const Key('category-filter-bar'),
      height: 54,
      child: ListView(
        key: _viewportKey,
        controller: _controller,
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 7, 16, 7),
        children: [
          _CategoryFilterChip(
            label: 'All',
            selected: widget.selected == null,
            onTap: () => widget.onSelected(null),
          ),
          for (final category in widget.categories) ...[
            const SizedBox(width: 8),
            _CategoryFilterChip(
              label: category,
              selected: widget.selected == category,
              onTap: () => widget.onSelected(category),
              onGoalDropped: widget.onGoalDropped == null
                  ? null
                  : (goalId) => widget.onGoalDropped!(goalId, category),
              onDragMove: _scrollNearEdge,
            ),
          ],
        ],
      ),
    );
  }
}

class _HiddenColumnsControl extends StatelessWidget {
  const _HiddenColumnsControl({
    required this.settings,
    required this.showAbandoned,
  });

  final AppSettingsController settings;
  final bool showAbandoned;

  @override
  Widget build(BuildContext context) {
    final hidden = GoalStatus.visibleValues(showAbandoned: showAbandoned)
        .where((status) => settings.isGoalStatusHidden(status.name))
        .toList(growable: false);
    if (hidden.isEmpty) return const SizedBox.shrink();
    return Align(
      alignment: Alignment.centerRight,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
        child: PopupMenuButton<GoalStatus>(
          key: const Key('hidden-columns-control'),
          tooltip: 'Restore a hidden column',
          onSelected: (status) =>
              settings.setGoalStatusHidden(status.name, false),
          itemBuilder: (context) => [
            for (final status in hidden)
              PopupMenuItem(
                value: status,
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(_statusIcon(status)),
                  title: Text('Restore ${status.label}'),
                ),
              ),
          ],
          child: Chip(
            avatar: const Icon(Icons.visibility_off_outlined, size: 18),
            label: Text(
              'Hidden columns (${hidden.length})',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ),
      ),
    );
  }
}

class _CategoryFilterChip extends StatelessWidget {
  const _CategoryFilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.onGoalDropped,
    this.onDragMove,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final ValueChanged<String>? onGoalDropped;
  final ValueChanged<Offset>? onDragMove;

  @override
  Widget build(BuildContext context) {
    final chip = FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
    );
    if (onGoalDropped == null) return chip;
    return DragTarget<String>(
      onWillAcceptWithDetails: (_) => true,
      onMove: (details) => onDragMove?.call(details.offset),
      onAcceptWithDetails: (details) => onGoalDropped!(details.data),
      builder: (context, candidates, _) => AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(30),
          boxShadow: candidates.isEmpty
              ? const []
              : [
                  BoxShadow(
                    color: Theme.of(
                      context,
                    ).colorScheme.secondary.withValues(alpha: .28),
                    blurRadius: 10,
                    spreadRadius: 2,
                  ),
                ],
        ),
        child: chip,
      ),
    );
  }
}

class _MobileMiniBoard extends StatefulWidget {
  const _MobileMiniBoard({
    required this.category,
    required this.settings,
    required this.store,
    required this.touchSafeDrag,
    required this.showAbandoned,
    required this.progressFormat,
  });

  final GoalStore store;
  final String? category;
  final AppSettingsController settings;
  final bool touchSafeDrag;
  final bool showAbandoned;
  final AppProgressFormat progressFormat;

  @override
  State<_MobileMiniBoard> createState() => _MobileMiniBoardState();
}

class _MobileMiniBoardState extends State<_MobileMiniBoard> {
  late GoalStatus _selectedStatus = _initialStatus();

  GoalStatus _initialStatus() {
    if (!widget.settings.isGoalStatusHidden(GoalStatus.active.name) &&
        widget.store
            .goalsFor(GoalStatus.active, category: widget.category)
            .isNotEmpty) {
      return GoalStatus.active;
    }
    return _visibleGoalStatuses(
      widget.settings,
      showAbandoned: widget.showAbandoned,
    ).firstWhere(
      (status) =>
          widget.store.goalsFor(status, category: widget.category).isNotEmpty,
      orElse: () => GoalStatus.ideas,
    );
  }

  @override
  void didUpdateWidget(covariant _MobileMiniBoard oldWidget) {
    super.didUpdateWidget(oldWidget);
    final statuses = _visibleGoalStatuses(
      widget.settings,
      showAbandoned: widget.showAbandoned,
    );
    if (!statuses.contains(_selectedStatus)) {
      _selectedStatus = statuses.first;
    }
  }

  void _selectStatus(GoalStatus status) {
    if (_selectedStatus == status) return;
    setState(() => _selectedStatus = status);
  }

  void _moveGoal(String goalId, GoalStatus status) {
    widget.store.moveGoal(goalId, status);
    _selectStatus(status);
  }

  void _openFullBoard() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => _FullBoardScreen(
          store: widget.store,
          touchSafeDrag: widget.touchSafeDrag,
          showAbandoned: widget.showAbandoned,
          progressFormat: widget.progressFormat,
          category: widget.category,
          settings: widget.settings,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final statuses = _visibleGoalStatuses(
      widget.settings,
      showAbandoned: widget.showAbandoned,
    );
    final selectedIndex = statuses.indexOf(_selectedStatus);
    final selectedStatus = selectedIndex < 0 ? statuses.first : _selectedStatus;
    final currentIndex = statuses.indexOf(selectedStatus);
    final goals = widget.store.goalsFor(
      selectedStatus,
      category: widget.category,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final compactHeight = constraints.maxHeight < 520;
        return CustomScrollView(
          key: const Key('mobile-board-scroll'),
          slivers: [
            SliverPersistentHeader(
              pinned: true,
              delegate: _MiniBoardMapHeader(
                statuses: statuses,
                selectedStatus: selectedStatus,
                store: widget.store,
                onOpenFullBoard: _openFullBoard,
                category: widget.category,
                onGoalMoved: _moveGoal,
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _AdjacentStatusButton(
                      key: const Key('mobile-previous-status'),
                      icon: Icons.arrow_back_rounded,
                      label: currentIndex > 0
                          ? statuses[currentIndex - 1].label
                          : 'First',
                      tooltip: currentIndex > 0
                          ? 'Previous: ${statuses[currentIndex - 1].label}'
                          : 'This is the first column',
                      onPressed: currentIndex > 0
                          ? () => _selectStatus(statuses[currentIndex - 1])
                          : null,
                    ),
                    Expanded(
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                _statusIcon(selectedStatus),
                                color: context.appGreenText,
                              ),
                              const SizedBox(width: 8),
                              Flexible(
                                child: Text(
                                  selectedStatus.label,
                                  key: const Key('mobile-selected-status'),
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.titleLarge,
                                ),
                              ),
                              const SizedBox(width: 8),
                              _GoalCount(value: goals.length),
                              if (statuses.length > 1)
                                IconButton(
                                  key: const Key('hide-mobile-column'),
                                  tooltip: 'Hide ${selectedStatus.label}',
                                  visualDensity: VisualDensity.compact,
                                  onPressed: () =>
                                      widget.settings.setGoalStatusHidden(
                                        selectedStatus.name,
                                        true,
                                      ),
                                  icon: const Icon(
                                    Icons.visibility_off_outlined,
                                    size: 19,
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            selectedStatus.description,
                            key: const Key('mobile-selected-description'),
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    _AdjacentStatusButton(
                      key: const Key('mobile-next-status'),
                      icon: Icons.arrow_forward_rounded,
                      label: currentIndex < statuses.length - 1
                          ? statuses[currentIndex + 1].label
                          : 'Last',
                      tooltip: currentIndex < statuses.length - 1
                          ? 'Next: ${statuses[currentIndex + 1].label}'
                          : 'This is the last column',
                      onPressed: currentIndex < statuses.length - 1
                          ? () => _selectStatus(statuses[currentIndex + 1])
                          : null,
                    ),
                  ],
                ),
              ),
            ),
            if (goals.isEmpty)
              SliverToBoxAdapter(
                child: SizedBox(
                  key: Key('mobile-column-${selectedStatus.name}'),
                  height: compactHeight ? 120 : 220,
                  child: _EmptyColumn(status: selectedStatus),
                ),
              )
            else
              SliverPadding(
                key: Key('mobile-column-${selectedStatus.name}'),
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
                sliver: SliverList.separated(
                  itemCount: goals.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, index) => _DraggableGoalCard(
                    goal: goals[index],
                    store: widget.store,
                    touchSafeDrag: widget.touchSafeDrag,
                    settings: widget.settings,
                    showAbandoned: widget.showAbandoned,
                    progressFormat: widget.progressFormat,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _MiniBoardMapHeader extends SliverPersistentHeaderDelegate {
  _MiniBoardMapHeader({
    required this.statuses,
    required this.selectedStatus,
    required this.store,
    required this.onOpenFullBoard,
    required this.onGoalMoved,
    required this.category,
  });

  static const double _extent = 212;

  final List<GoalStatus> statuses;
  final GoalStatus selectedStatus;
  final GoalStore store;
  final VoidCallback onOpenFullBoard;
  final void Function(String goalId, GoalStatus status) onGoalMoved;
  final String? category;

  @override
  double get minExtent => _extent;

  @override
  double get maxExtent => _extent;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return ColoredBox(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: _MiniBoardMap(
        height: 190,
        statuses: statuses,
        selectedStatus: selectedStatus,
        store: store,
        onOpenFullBoard: onOpenFullBoard,
        onGoalMoved: onGoalMoved,
        category: category,
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _MiniBoardMapHeader oldDelegate) => true;
}

class _MiniBoardMap extends StatelessWidget {
  const _MiniBoardMap({
    required this.height,
    required this.statuses,
    required this.selectedStatus,
    required this.store,
    required this.onOpenFullBoard,
    required this.onGoalMoved,
    required this.category,
  });

  final double height;
  final List<GoalStatus> statuses;
  final GoalStatus selectedStatus;
  final GoalStore store;
  final VoidCallback onOpenFullBoard;
  final void Function(String goalId, GoalStatus status) onGoalMoved;
  final String? category;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('mobile-mini-board-map'),
      height: height,
      margin: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      decoration: BoxDecoration(
        color: context.appRaised,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: context.appBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Material(
            color: Colors.transparent,
            child: InkWell(
              key: const Key('open-full-board'),
              onTap: onOpenFullBoard,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(18),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 10, 8),
                child: Row(
                  children: [
                    Icon(
                      Icons.view_kanban_outlined,
                      size: 18,
                      color: context.appGreenText,
                    ),
                    const SizedBox(width: 7),
                    Expanded(
                      child: Text(
                        'Board map',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    Text(
                      'Open full board',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(width: 5),
                    Icon(
                      Icons.open_in_full_rounded,
                      size: 17,
                      color: context.appGreenText,
                    ),
                  ],
                ),
              ),
            ),
          ),
          Divider(height: 1, color: context.appBorder),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var index = 0; index < statuses.length; index++) ...[
                  Expanded(
                    child: _MiniMapLane(
                      status: statuses[index],
                      goals: store.goalsFor(
                        statuses[index],
                        category: category,
                      ),
                      selected: statuses[index] == selectedStatus,
                      onTap: onOpenFullBoard,
                      onGoalMoved: (goalId) =>
                          onGoalMoved(goalId, statuses[index]),
                    ),
                  ),
                  if (index != statuses.length - 1)
                    VerticalDivider(
                      width: 1,
                      thickness: 1,
                      color: context.appBorder,
                    ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniMapLane extends StatelessWidget {
  const _MiniMapLane({
    required this.status,
    required this.goals,
    required this.selected,
    required this.onTap,
    required this.onGoalMoved,
  });

  final GoalStatus status;
  final List<Goal> goals;
  final bool selected;
  final VoidCallback onTap;
  final ValueChanged<String> onGoalMoved;

  @override
  Widget build(BuildContext context) {
    return DragTarget<String>(
      key: Key('mini-map-lane-${status.name}'),
      onWillAcceptWithDetails: (_) => true,
      onAcceptWithDetails: (details) => onGoalMoved(details.data),
      builder: (context, candidates, _) {
        final highlighted = candidates.isNotEmpty;
        return Semantics(
          button: true,
          selected: selected,
          label: '${status.label}, ${goals.length} goals',
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                padding: const EdgeInsets.fromLTRB(3, 8, 3, 8),
                decoration: BoxDecoration(
                  color: highlighted || selected
                      ? context.appSoftGreen
                      : Colors.transparent,
                  border: Border.all(
                    color: highlighted || selected
                        ? Theme.of(context).colorScheme.primary
                        : Colors.transparent,
                    width: highlighted ? 2 : 1.5,
                  ),
                ),
                child: Column(
                  children: [
                    Icon(
                      _statusIcon(status),
                      size: 17,
                      color: selected ? context.appGreenText : context.appMuted,
                    ),
                    const SizedBox(height: 3),
                    SizedBox(
                      height: 16,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          status.label,
                          maxLines: 1,
                          style: TextStyle(
                            color: selected
                                ? context.appGreenText
                                : context.appText,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    _GoalCount(value: goals.length, compact: true),
                    const SizedBox(height: 7),
                    Expanded(
                      child: Column(
                        children: [
                          for (
                            var index = 0;
                            index < goals.length.clamp(0, 3);
                            index++
                          ) ...[
                            _MiniGoalMark(
                              selected: selected,
                              planned: goals[index].plan != null,
                            ),
                            if (index < goals.length.clamp(0, 3) - 1)
                              const SizedBox(height: 2),
                          ],
                          if (goals.isEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 5),
                              child: Container(
                                width: 18,
                                height: 2,
                                color: context.appBorder,
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
      },
    );
  }
}

class _FullBoardScreen extends StatefulWidget {
  const _FullBoardScreen({
    required this.store,
    required this.touchSafeDrag,
    required this.showAbandoned,
    required this.progressFormat,
    required this.category,
    required this.settings,
  });

  final GoalStore store;
  final bool touchSafeDrag;
  final bool showAbandoned;
  final AppProgressFormat progressFormat;
  final String? category;
  final AppSettingsController settings;

  @override
  State<_FullBoardScreen> createState() => _FullBoardScreenState();
}

class _FullBoardScreenState extends State<_FullBoardScreen> {
  final _scrollController = ScrollController();
  final _viewportKey = GlobalKey();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollNearEdge(Offset globalPosition) {
    if (!_scrollController.hasClients) return;
    final box = _viewportKey.currentContext?.findRenderObject();
    if (box is! RenderBox) return;
    final local = box.globalToLocal(globalPosition);
    final delta = local.dx < 72
        ? -14.0
        : local.dx > box.size.width - 72
        ? 14.0
        : 0.0;
    if (delta == 0) return;
    final position = _scrollController.position;
    _scrollController.jumpTo(
      (position.pixels + delta)
          .clamp(position.minScrollExtent, position.maxScrollExtent)
          .toDouble(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final store = widget.store;
    final settings = widget.settings;
    final showAbandoned = widget.showAbandoned;
    final category = widget.category;
    final touchSafeDrag = widget.touchSafeDrag;
    final progressFormat = widget.progressFormat;
    return AnimatedBuilder(
      animation: Listenable.merge([store, settings]),
      builder: (context, _) {
        final statuses = _visibleGoalStatuses(
          settings,
          showAbandoned: showAbandoned,
        );
        return Scaffold(
          key: const Key('full-board-view'),
          body: SafeArea(
            child: Stack(
              children: [
                Positioned.fill(
                  child: LayoutBuilder(
                    key: const Key('full-board-horizontal-scroll'),
                    builder: (context, constraints) {
                      final columnWidth = (constraints.maxWidth - 36)
                          .clamp(274.0, 320.0)
                          .toDouble();
                      return ListView.separated(
                        key: _viewportKey,
                        controller: _scrollController,
                        padding: const EdgeInsets.fromLTRB(12, 58, 12, 12),
                        scrollDirection: Axis.horizontal,
                        itemCount: statuses.length,
                        separatorBuilder: (_, _) => const SizedBox(width: 12),
                        itemBuilder: (context, index) {
                          final status = statuses[index];
                          return SizedBox(
                            key: Key('full-board-column-${status.name}'),
                            width: columnWidth,
                            child: _BoardColumn(
                              status: status,
                              goals: store.goalsFor(status, category: category),
                              store: store,
                              touchSafeDrag: touchSafeDrag,
                              showAbandoned: showAbandoned,
                              progressFormat: progressFormat,
                              settings: settings,
                              onDragMove: _scrollNearEdge,
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
                Positioned(
                  top: 8,
                  left: 10,
                  child: IconButton.filledTonal(
                    key: const Key('close-full-board'),
                    tooltip: 'Back to goals',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back_rounded),
                  ),
                ),
                Positioned(
                  top: 4,
                  right: 0,
                  child: _HiddenColumnsControl(
                    settings: settings,
                    showAbandoned: showAbandoned,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _MiniGoalMark extends StatelessWidget {
  const _MiniGoalMark({required this.selected, required this.planned});

  final bool selected;
  final bool planned;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 9,
      margin: const EdgeInsets.symmetric(horizontal: 3),
      padding: const EdgeInsets.symmetric(horizontal: 3),
      decoration: BoxDecoration(
        color: context.appPanel,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: selected
              ? Theme.of(context).colorScheme.primary
              : context.appBorder,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 2,
              color: planned ? context.appGreenText : context.appMuted,
            ),
          ),
          const SizedBox(width: 3),
          Container(
            width: 4,
            height: 4,
            decoration: BoxDecoration(
              color: selected
                  ? Theme.of(context).colorScheme.primary
                  : context.appMuted,
              shape: BoxShape.circle,
            ),
          ),
        ],
      ),
    );
  }
}

class _GoalCount extends StatelessWidget {
  const _GoalCount({required this.value, this.compact = false});

  final int value;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        minWidth: compact ? 22 : 26,
        minHeight: compact ? 22 : 26,
      ),
      alignment: Alignment.center,
      padding: EdgeInsets.symmetric(horizontal: compact ? 5 : 7),
      decoration: BoxDecoration(
        color: context.appPanel,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: context.appBorder),
      ),
      child: Text(
        '$value',
        style: TextStyle(
          color: context.appText,
          fontSize: compact ? 11 : 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _AdjacentStatusButton extends StatelessWidget {
  const _AdjacentStatusButton({
    super.key,
    required this.icon,
    required this.label,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final String tooltip;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 60,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton.outlined(
            tooltip: tooltip,
            visualDensity: VisualDensity.compact,
            onPressed: onPressed,
            icon: Icon(icon, size: 20),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(fontSize: 10),
          ),
        ],
      ),
    );
  }
}

IconData _statusIcon(GoalStatus status) => switch (status) {
  GoalStatus.ideas => Icons.lightbulb_outline_rounded,
  GoalStatus.planned => Icons.event_outlined,
  GoalStatus.active => Icons.play_circle_outline_rounded,
  GoalStatus.paused => Icons.pause_circle_outline_rounded,
  GoalStatus.completed => Icons.check_circle_outline_rounded,
  GoalStatus.abandoned => Icons.archive_outlined,
};

List<GoalStatus> _visibleGoalStatuses(
  AppSettingsController settings, {
  required bool showAbandoned,
}) {
  final available = GoalStatus.visibleValues(showAbandoned: showAbandoned);
  final visible = available
      .where((status) => !settings.isGoalStatusHidden(status.name))
      .toList(growable: false);
  return visible.isEmpty ? [available.first] : visible;
}

class _BoardColumn extends StatelessWidget {
  const _BoardColumn({
    required this.status,
    required this.goals,
    required this.store,
    required this.touchSafeDrag,
    required this.showAbandoned,
    required this.progressFormat,
    required this.settings,
    this.onDragMove,
  });

  final GoalStatus status;
  final List<Goal> goals;
  final GoalStore store;
  final bool touchSafeDrag;
  final bool showAbandoned;
  final AppProgressFormat progressFormat;

  final AppSettingsController settings;
  final ValueChanged<Offset>? onDragMove;
  @override
  Widget build(BuildContext context) {
    return DragTarget<String>(
      key: Key('column-${status.name}'),
      onWillAcceptWithDetails: (_) => true,
      onMove: (details) => onDragMove?.call(details.offset),
      onAcceptWithDetails: (details) => store.moveGoal(details.data, status),
      builder: (context, candidates, _) {
        final highlighted = candidates.isNotEmpty;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          decoration: BoxDecoration(
            color: highlighted ? context.appSoftGreen : context.appRaised,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: highlighted
                  ? Theme.of(context).colorScheme.primary
                  : context.appBorder,
              width: highlighted ? 1.5 : 1,
            ),
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 12, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        status.label,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    if (_visibleGoalStatuses(
                          settings,
                          showAbandoned: showAbandoned,
                        ).length >
                        1)
                      IconButton(
                        key: Key('hide-column-${status.name}'),
                        tooltip: 'Hide ${status.label}',
                        visualDensity: VisualDensity.compact,
                        onPressed: () =>
                            settings.setGoalStatusHidden(status.name, true),
                        icon: const Icon(
                          Icons.visibility_off_outlined,
                          size: 18,
                        ),
                      ),
                    IconButton(
                      tooltip: status.description,
                      visualDensity: VisualDensity.compact,
                      onPressed: () => _showColumnHelp(context, status),
                      icon: const Icon(Icons.info_outline_rounded, size: 18),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: context.appRaised,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: context.appBorder),
                      ),
                      child: Text(
                        '${goals.length}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
              ),
              Divider(height: 1, color: context.appBorder),
              Expanded(
                child: goals.isEmpty
                    ? _EmptyColumn(status: status)
                    : ListView.separated(
                        padding: const EdgeInsets.all(10),
                        itemCount: goals.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 10),
                        itemBuilder: (context, index) => _DraggableGoalCard(
                          goal: goals[index],
                          store: store,
                          touchSafeDrag: touchSafeDrag,
                          showAbandoned: showAbandoned,
                          progressFormat: progressFormat,
                          settings: settings,
                        ),
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _EmptyColumn extends StatelessWidget {
  const _EmptyColumn({required this.status});

  final GoalStatus status;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              status == GoalStatus.ideas
                  ? Icons.lightbulb_outline_rounded
                  : Icons.drag_indicator_rounded,
              color: context.appMuted,
            ),
            const SizedBox(height: 8),
            Text(
              status == GoalStatus.ideas
                  ? 'Capture a goal in one step.'
                  : 'Move a goal here.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _DraggableGoalCard extends StatelessWidget {
  const _DraggableGoalCard({
    required this.goal,
    required this.store,
    required this.touchSafeDrag,
    required this.showAbandoned,
    required this.progressFormat,
    required this.settings,
  });

  final Goal goal;
  final GoalStore store;
  final bool touchSafeDrag;
  final bool showAbandoned;
  final AppProgressFormat progressFormat;
  final AppSettingsController settings;

  @override
  Widget build(BuildContext context) {
    final card = _GoalCard(
      goal: goal,
      store: store,
      showAbandoned: showAbandoned,
      progressFormat: progressFormat,
      settings: settings,
    );
    final feedback = Material(
      color: Colors.transparent,
      child: SizedBox(width: 266, child: Opacity(opacity: 0.94, child: card)),
    );
    if (touchSafeDrag) {
      return LongPressDraggable<String>(
        key: Key('goal-drag-${goal.id}'),
        data: goal.id,
        feedback: feedback,
        childWhenDragging: Opacity(opacity: 0.32, child: card),
        child: card,
      );
    }
    return MouseRegion(
      cursor: SystemMouseCursors.grab,
      child: Draggable<String>(
        key: Key('goal-drag-${goal.id}'),
        data: goal.id,
        feedback: feedback,
        childWhenDragging: Opacity(opacity: 0.32, child: card),
        child: card,
      ),
    );
  }
}

class _GoalCard extends StatelessWidget {
  const _GoalCard({
    required this.goal,
    required this.store,
    required this.showAbandoned,
    required this.progressFormat,
    required this.settings,
  });

  final Goal goal;
  final GoalStore store;
  final bool showAbandoned;
  final AppProgressFormat progressFormat;
  final AppSettingsController settings;

  @override
  Widget build(BuildContext context) {
    final plan = goal.plan;
    final health = store.calculator.healthFor(goal, store.today);
    final todayAction = store.calculator.actionForDate(goal, store.today);
    return _UrgentCardFrame(
      goal: goal,
      child: Card(
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => showGoalDetailsSheet(
            context,
            store,
            goal.id,
            showAbandoned: showAbandoned,
            progressFormat: progressFormat,
            settings: settings,
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: plan == null
                            ? context.appSoftBlue
                            : context.appSoftGreen,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        plan == null
                            ? Icons.lightbulb_outline_rounded
                            : Icons.flag_outlined,
                        size: 20,
                        color: plan == null
                            ? context.appBlueText
                            : context.appGreenText,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 5),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              goal.name,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 6),
                            Wrap(
                              spacing: 5,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                if (settings.categoriesEnabled &&
                                    settings.isCategoryEnabled(goal.category))
                                  _GoalCategoryChip(category: goal.category),
                                if (goal.isUrgent)
                                  _UrgencyMarker(style: goal.urgencyStyle),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    _MoveMenu(
                      goal: goal,
                      store: store,
                      showAbandoned: showAbandoned,
                    ),
                  ],
                ),
                if (plan != null) ...[
                  const SizedBox(height: 14),
                  Text(
                    formatGoalProgress(goal, progressFormat),
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 8),
                  LinearProgressIndicator(
                    value: goal.progress,
                    minHeight: 7,
                    borderRadius: BorderRadius.circular(20),
                    color: Theme.of(context).colorScheme.primary,
                    backgroundColor: context.appRaised,
                  ),
                  if (todayAction > 0) ...[
                    const SizedBox(height: 13),
                    Row(
                      children: [
                        Icon(
                          Icons.today_outlined,
                          size: 18,
                          color: context.appGreenText,
                        ),
                        const SizedBox(width: 7),
                        Expanded(
                          child: Text(
                            'Today: ${formatAmount(todayAction)} ${pluralize(plan.unit, todayAction)}',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: context.appText,
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                        ),
                      ],
                    ),
                  ],
                  if (health.health != GoalHealth.none) ...[
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: _HealthChip(health: health.health),
                    ),
                  ],
                ] else if (goal.steps.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  Text(
                    formatGoalProgress(goal, progressFormat),
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 8),
                  LinearProgressIndicator(
                    value: goal.progress,
                    minHeight: 7,
                    borderRadius: BorderRadius.circular(20),
                    color: Theme.of(context).colorScheme.primary,
                    backgroundColor: context.appRaised,
                  ),
                  const SizedBox(height: 9),
                  Text(
                    'Small steps · no separate cards',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ] else ...[
                  const SizedBox(height: 8),
                  Text(
                    'Unplanned · move anytime',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _GoalCategoryChip extends StatelessWidget {
  const _GoalCategoryChip({required this.category});

  final String category;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
    decoration: BoxDecoration(
      color: context.appRaised,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: context.appBorder),
    ),
    child: Text(
      category,
      style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 11),
    ),
  );
}

class _UrgencyMarker extends StatelessWidget {
  const _UrgencyMarker({required this.style});

  final UrgencyStyle style;

  @override
  Widget build(BuildContext context) {
    final icon = switch (style) {
      UrgencyStyle.fireRing => Icons.local_fire_department_rounded,
      UrgencyStyle.policeSiren => Icons.local_police_rounded,
    };
    return Tooltip(
      message: 'Urgent ? ${style.label}',
      child: Icon(icon, size: 17, color: context.appDangerText),
    );
  }
}

class _UrgentCardFrame extends StatefulWidget {
  const _UrgentCardFrame({required this.goal, required this.child});

  final Goal goal;
  final Widget child;

  @override
  State<_UrgentCardFrame> createState() => _UrgentCardFrameState();
}

class _UrgentCardFrameState extends State<_UrgentCardFrame>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1300),
  );

  @override
  void initState() {
    super.initState();
    _syncAnimation();
  }

  @override
  void didUpdateWidget(covariant _UrgentCardFrame oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.goal.isUrgent != widget.goal.isUrgent ||
        oldWidget.goal.urgencyStyle != widget.goal.urgencyStyle) {
      _syncAnimation();
    }
  }

  void _syncAnimation() {
    if (widget.goal.isUrgent) {
      _controller.repeat(reverse: true);
    } else {
      _controller.stop();
      _controller.value = 0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Color _warningColor(double value) => switch (widget.goal.urgencyStyle) {
    UrgencyStyle.fireRing => Color.lerp(
      const Color(0xFFE43D30),
      const Color(0xFFFF9B32),
      value,
    )!,
    UrgencyStyle.policeSiren => Color.lerp(
      const Color(0xFFE23030),
      const Color(0xFF2878E8),
      value,
    )!,
  };

  @override
  Widget build(BuildContext context) {
    if (!widget.goal.isUrgent) return widget.child;
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    return TickerMode(
      enabled: !reduceMotion,
      child: AnimatedBuilder(
        animation: _controller,
        child: widget.child,
        builder: (context, child) {
          final value = reduceMotion ? .45 : _controller.value;
          final warningColor = _warningColor(value);
          return Container(
            key: Key('urgent-card-frame-${widget.goal.id}'),
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: warningColor, width: 2),
              boxShadow: [
                BoxShadow(
                  color: warningColor.withValues(
                    alpha: reduceMotion ? .18 : .12 + (.16 * value),
                  ),
                  blurRadius: reduceMotion ? 5 : 5 + (5 * value),
                  spreadRadius: reduceMotion ? 0 : value,
                ),
              ],
            ),
            child: child,
          );
        },
      ),
    );
  }
}

class _MoveMenu extends StatelessWidget {
  const _MoveMenu({
    required this.goal,
    required this.store,
    required this.showAbandoned,
  });

  final Goal goal;
  final GoalStore store;
  final bool showAbandoned;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<GoalStatus>(
      tooltip: 'Move goal',
      icon: const Icon(Icons.more_horiz_rounded, size: 20),
      onSelected: (status) => store.moveGoal(goal.id, status),
      itemBuilder: (context) => [
        for (final status in GoalStatus.visibleValues(
          showAbandoned: showAbandoned,
        ))
          PopupMenuItem(
            value: status,
            enabled: status != goal.status,
            child: Text(
              status == goal.status
                  ? '${status.label} (current)'
                  : 'Move to ${status.label}',
            ),
          ),
      ],
    );
  }
}

class _HealthChip extends StatelessWidget {
  const _HealthChip({required this.health});

  final GoalHealth health;

  @override
  Widget build(BuildContext context) {
    final (background, foreground, icon) = switch (health) {
      GoalHealth.onTrack => (
        context.appSoftGreen,
        context.appGreenText,
        Icons.check_circle_outline_rounded,
      ),
      GoalHealth.atRisk => (
        context.appSoftAmber,
        context.appWarningText,
        Icons.warning_amber_rounded,
      ),
      GoalHealth.behind => (
        context.appSoftRed,
        context.appDangerText,
        Icons.trending_down_rounded,
      ),
      GoalHealth.none => (
        context.appSoftBlue,
        context.appMuted,
        Icons.remove_circle_outline,
      ),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(9),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 17, color: foreground),
          const SizedBox(width: 6),
          Text(
            health.label,
            style: TextStyle(
              color: foreground,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message, this.onRetry});

  final String message;
  final Future<void> Function()? onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.appSoftRed,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline_rounded, color: context.appDangerText),
          const SizedBox(width: 10),
          Expanded(child: Text(message)),
          if (onRetry != null)
            TextButton.icon(
              key: const Key('retry-goal-load'),
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Try again'),
            ),
        ],
      ),
    );
  }
}

class _LoadIssuesBanner extends StatelessWidget {
  const _LoadIssuesBanner(this.issues, {required this.onRetry});

  final List<GoalLoadIssue> issues;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    final names = issues
        .map((issue) => issue.path.split(RegExp(r'[\\/]')).last)
        .join(', ');
    return Container(
      key: const Key('goal-load-issues'),
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.appSoftAmber,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.warning_amber_rounded),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Some goal files could not be read: $names. They were left '
              'unchanged. Fix or restore those files, then choose Try again.',
            ),
          ),
          TextButton(onPressed: onRetry, child: const Text('Try again')),
        ],
      ),
    );
  }
}

Future<void> _confirmDeleteForever(
  BuildContext context,
  GoalStore store,
  Goal goal,
) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      icon: Icon(
        Icons.delete_forever_outlined,
        color: Theme.of(context).colorScheme.error,
      ),
      title: const Text('Delete this goal forever?'),
      content: Text(
        '${goal.name} and its local Markdown file will be permanently '
        'deleted. This cannot be undone.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: const Key('confirm-delete-forever'),
          style: FilledButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.error,
            foregroundColor: Theme.of(context).colorScheme.onError,
          ),
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Delete forever'),
        ),
      ],
    ),
  );
  if (confirmed == true) await store.deleteForever(goal.id);
}

String _dateLabel(DateTime value) {
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
  return '${months[value.month - 1]} ${value.day}, ${value.year}';
}

Future<void> _openStorage(BuildContext context, GoalStore store) async {
  final opened = await store.openStorageFolder();
  if (!context.mounted) return;
  if (opened) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Opened the local Markdown folder.')),
    );
    return;
  }
  await _showStoragePath(context, store.storagePath);
}

Future<void> _showColumnHelp(BuildContext context, GoalStatus status) =>
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(status.label),
        content: Text(status.description),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Got it'),
          ),
        ],
      ),
    );

Future<void> _showColumnsHelp(
  BuildContext context,
  bool showAbandoned,
) => showDialog<void>(
  context: context,
  builder: (context) => AlertDialog(
    icon: const Icon(Icons.view_kanban_outlined),
    title: const Text('How the goal columns work'),
    content: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 480),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final status in GoalStatus.visibleValues(
            showAbandoned: showAbandoned,
          ))
            ListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: Text(status.label),
              subtitle: Text(status.description),
            ),
          const SizedBox(height: 8),
          const Text(
            'Move a card to change its workflow state. Adding or removing '
            'planning details is a separate action inside the goal.',
          ),
          if (!showAbandoned)
            const Text(
              'Abandoned is optional and currently hidden. You can enable it in Settings.',
            ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Got it'),
      ),
    ],
  ),
);

Future<void> _showStoragePath(
  BuildContext context,
  String path,
) => showDialog<void>(
  context: context,
  builder: (context) => AlertDialog(
    icon: const Icon(Icons.folder_outlined),
    title: const Text('Local Markdown files'),
    content: SelectableText(
      '$path\n\nEach goal is a readable .md file. The app loads these files '
      'automatically when it starts.',
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Close'),
      ),
    ],
  ),
);
