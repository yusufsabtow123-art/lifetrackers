import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:goal_tracker_poc/app/goal_store.dart';
import 'package:goal_tracker_poc/app/theme_controller.dart';
import 'package:goal_tracker_poc/data/app_settings_repository.dart';
import 'package:goal_tracker_poc/data/goal_repository.dart';
import 'package:goal_tracker_poc/platform/goal_widget_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Windows never calls the Android home-screen widget plugin', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    final service = GoalWidgetService();
    final store = GoalStore(repository: MemoryGoalRepository());
    final settings = AppSettingsController(MemoryAppSettingsRepository());

    await service.initialize();
    expect(await service.initialUri(), isNull);
    expect(await service.clicks.toList(), isEmpty);
    await service.sync(store.goals, store, settings);
    await service.requestPinTodayWidget();
    await service.requestPinCardsWidget();
  });
}
