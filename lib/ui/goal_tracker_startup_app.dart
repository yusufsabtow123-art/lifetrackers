import 'dart:async';

import 'package:flutter/material.dart';

import '../app/goal_store.dart';
import '../app/life_store.dart';
import '../app/theme_controller.dart';
import '../data/app_settings_repository.dart';
import '../data/goal_repository.dart';
import '../data/life_repository.dart';
import '../platform/goal_notification_service.dart';
import '../platform/goal_widget_service.dart';
import '../platform/local_folder_opener.dart';
import 'goal_app.dart';

typedef GoalTrackerBootstrap = Future<GoalTrackerDependencies> Function();

class GoalTrackerDependencies {
  const GoalTrackerDependencies({
    required this.store,
    required this.settings,
    required this.notifications,
    required this.widgets,
    required this.lifeStore,
  });

  final GoalStore store;
  final AppSettingsController settings;
  final GoalNotificationService notifications;
  final GoalWidgetService widgets;
  final LifeStore lifeStore;
}

Future<GoalTrackerDependencies> createGoalTrackerDependencies() async {
  final repository = await MarkdownGoalRepository.createDefault();
  final lifeRepository = await MarkdownLifeRepository.createDefault();
  final settingsRepository = await FileAppSettingsRepository.createDefault();
  final settings = AppSettingsController(settingsRepository);
  await settings.load();
  return GoalTrackerDependencies(
    store: GoalStore(repository: repository, openLocalFolder: openLocalFolder),
    settings: settings,
    notifications: GoalNotificationService(),
    widgets: GoalWidgetService(),
    lifeStore: LifeStore(lifeRepository),
  );
}

/// Starts a visible Flutter shell before filesystem or platform services load.
/// A failed bootstrap can be retried without retaining duplicate subscriptions.
class GoalTrackerStartupApp extends StatefulWidget {
  const GoalTrackerStartupApp({
    super.key,
    this.bootstrap = createGoalTrackerDependencies,
  });

  final GoalTrackerBootstrap bootstrap;

  @override
  State<GoalTrackerStartupApp> createState() => _GoalTrackerStartupAppState();
}

class _GoalTrackerStartupAppState extends State<GoalTrackerStartupApp> {
  GoalTrackerDependencies? _dependencies;
  Object? _error;
  int _attempt = 0;

  @override
  void initState() {
    super.initState();
    unawaited(_start());
  }

  Future<void> _start() async {
    final attempt = ++_attempt;
    setState(() {
      _dependencies = null;
      _error = null;
    });
    try {
      final dependencies = await widget.bootstrap();
      if (!mounted || attempt != _attempt) return;
      setState(() => _dependencies = dependencies);
    } on Object catch (error) {
      if (!mounted || attempt != _attempt) return;
      setState(() => _error = error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dependencies = _dependencies;
    if (dependencies != null) {
      return GoalApp(
        store: dependencies.store,
        settingsController: dependencies.settings,
        notificationService: dependencies.notifications,
        widgetService: dependencies.widgets,
        lifeStore: dependencies.lifeStore,
      );
    }

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Life Tracker',
      home: Scaffold(
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: _error == null
                    ? const Column(
                        key: Key('startup-loading'),
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.flag_circle_rounded, size: 52),
                          SizedBox(height: 22),
                          CircularProgressIndicator(),
                          SizedBox(height: 18),
                          Text('Opening your goals…'),
                        ],
                      )
                    : Column(
                        key: const Key('startup-error'),
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.error_outline_rounded, size: 52),
                          const SizedBox(height: 18),
                          Text(
                            'Goal Tracker could not open its local settings.',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Your goal files were not changed. Try opening the app again.',
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 20),
                          FilledButton.icon(
                            key: const Key('startup-retry'),
                            onPressed: _start,
                            icon: const Icon(Icons.refresh_rounded),
                            label: const Text('Try again'),
                          ),
                        ],
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
