import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('v0.12 retains the Android upgrade identity', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final gradle = File('android/app/build.gradle.kts').readAsStringSync();

    expect(pubspec, contains('version: 0.12.0+15'));
    expect(
      gradle,
      contains('applicationId = "app.localfirst.goal_tracker_poc"'),
    );
  });

  test('release build verifies the icon inside the packaged APK', () {
    final workflow = _workflowFile().readAsStringSync();

    expect(workflow, contains('Verify notification icon is packaged'));
    expect(workflow, contains('resources value'));
    expect(workflow, contains('--name ic_stat_goal_tracker'));
    expect(workflow, contains('--type drawable'));
  });

  test('candidate packages bypass temporary artifact storage safely', () {
    final workflow = _workflowFile().readAsStringSync();

    expect(workflow, contains('candidate_tag:'));
    expect(workflow, contains("if: inputs.candidate_tag == ''"));
    expect(workflow, contains("if: inputs.candidate_tag != ''"));
    expect(workflow, contains('gh release upload'));
    expect(workflow, contains('retention-days: 3'));
    expect(workflow, isNot(contains('continue-on-error: true')));
  });
}

File _workflowFile() {
  final candidates = [
    File('../../.github/workflows/build-apps.yml'),
    File('.github/workflows/build-apps.yml'),
    File('../../goal-tracker-poc-source/.github/workflows/build-apps.yml'),
  ];
  return candidates.firstWhere(
    (file) => file.existsSync(),
    orElse: () => throw StateError('The release workflow could not be found.'),
  );
}
