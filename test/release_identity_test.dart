import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('v0.15.0 advances beyond every published preview build', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final gradle = File('android/app/build.gradle.kts').readAsStringSync();

    expect(pubspec, contains('version: 0.15.0+2030'));
    expect(
      gradle,
      contains('applicationId = "app.localfirst.goal_tracker_poc"'),
    );
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
