import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:goal_tracker_poc/app/goal_store.dart';
import 'package:goal_tracker_poc/app/theme_controller.dart';
import 'package:goal_tracker_poc/data/app_settings_repository.dart';
import 'package:goal_tracker_poc/data/goal_repository.dart';
import 'package:goal_tracker_poc/domain/goal.dart';
import 'package:goal_tracker_poc/platform/goal_notification_service.dart';
import 'package:goal_tracker_poc/platform/goal_widget_service.dart';
import 'package:goal_tracker_poc/ui/goal_app.dart';

void main() {
  testWidgets('board survives optional Android startup failures', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(800, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final notifications = _FailingNotificationService();
    final widgets = _FailingWidgetService();

    await tester.pumpWidget(
      GoalApp(
        store: GoalStore(repository: MemoryGoalRepository()),
        notificationService: notifications,
        widgetService: widgets,
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('Goals'), findsWidgets);
    expect(notifications.initializeCalled, isTrue);
    expect(widgets.initializeCalled, isTrue);
    expect(tester.takeException(), isNull);
  });
}

class _FailingNotificationService extends GoalNotificationService {
  bool initializeCalled = false;

  @override
  Future<void> initialize() async {
    initializeCalled = true;
    throw StateError('invalid notification icon');
  }

  @override
  Future<void> sync(Iterable<Goal> goals, AppSettingsData settings) async {}
}

class _FailingWidgetService extends GoalWidgetService {
  bool initializeCalled = false;

  @override
  Stream<Uri?> get clicks => const Stream<Uri?>.empty();

  @override
  Future<void> initialize() async {
    initializeCalled = true;
    throw StateError('widget service unavailable');
  }

  @override
  Future<Uri?> initialUri() async => null;

  @override
  Future<void> sync(
    Iterable<Goal> goals,
    GoalStore store,
    AppSettingsController settings,
  ) async {}
}
