import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Android notification initialization icon is a drawable resource', () {
    final service = File(
      'lib/platform/goal_notification_service.dart',
    ).readAsStringSync();
    final match = RegExp(
      r"AndroidInitializationSettings\('([^']+)'\)",
    ).firstMatch(service);

    expect(
      match,
      isNotNull,
      reason: 'An Android notification icon is required.',
    );
    final icon = match!.group(1)!;
    final resources = Directory('android/app/src/main/res')
        .listSync(recursive: true)
        .whereType<File>()
        .where(
          (file) =>
              file.parent.path
                  .split(Platform.pathSeparator)
                  .last
                  .startsWith('drawable') &&
              file.uri.pathSegments.last.split('.').first == icon,
        );

    expect(
      resources,
      isNotEmpty,
      reason:
          "flutter_local_notifications only accepts '$icon' from a drawable folder.",
    );

    final keepRules = File(
      'android/app/src/main/res/raw/keep.xml',
    ).readAsStringSync();
    expect(
      keepRules,
      contains('@drawable/$icon'),
      reason:
          "Release resource shrinking must preserve the dynamically loaded '$icon' drawable.",
    );
  });

  test('Android notification manifest includes runtime delivery support', () {
    final manifest = File(
      'android/app/src/main/AndroidManifest.xml',
    ).readAsStringSync();

    expect(manifest, contains('android.permission.POST_NOTIFICATIONS'));
    expect(manifest, contains('android.permission.VIBRATE'));
    expect(manifest, contains('ScheduledNotificationBootReceiver'));
    expect(manifest, contains('ActionBroadcastReceiver'));
  });

  test('routine notification sync never cancels unrelated notifications', () {
    final service = File(
      'lib/platform/goal_notification_service.dart',
    ).readAsStringSync();

    expect(service, isNot(contains('.cancelAll(')));
    expect(service, contains('pending.where(_isOwnedRequest)'));
  });
}
