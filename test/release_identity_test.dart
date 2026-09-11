import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('v0.16.8 uses the permanent collision-free Android identity', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final gradle = File('android/app/build.gradle.kts').readAsStringSync();

    expect(pubspec, contains('version: 0.16.8+4048'));
    final version = RegExp(r'version:\s*[^+]+\+(\d+)').firstMatch(pubspec);
    expect(version, isNotNull);
    expect(
      int.parse(version!.group(1)!),
      greaterThan(4047),
      reason: 'Android updates must exceed the published v0.16.7 build code.',
    );
    expect(gradle, contains('applicationId = "app.lifetracker.personal"'));
  });

  test(
    'optimized preview release preserves the installed preview identity',
    () {
      final gradle = File('android/app/build.gradle.kts').readAsStringSync();

      expect(gradle, contains('LIFE_TRACKER_PREVIEW_RELEASE'));
      expect(gradle, contains('applicationIdSuffix = ".dev"'));
      expect(gradle, contains('versionNameSuffix = "-dev"'));
    },
  );

  test('release build strips unused code and resources', () {
    final gradle = File('android/app/build.gradle.kts').readAsStringSync();

    expect(gradle, contains('isMinifyEnabled = true'));
    expect(gradle, contains('isShrinkResources = true'));
    expect(gradle, contains('proguard-android-optimize.txt'));
  });

  test('resource shrinking keeps the runtime notification icon', () {
    final keepFile = File(
      'android/app/src/main/res/raw/keep.xml',
    ).readAsStringSync();

    expect(keepFile, contains('@drawable/ic_stat_goal_tracker'));
  });
}
