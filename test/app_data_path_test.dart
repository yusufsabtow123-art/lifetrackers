import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:goal_tracker_poc/data/app_data_path.dart';

void main() {
  test('default data root remains the Goals POC documents folder', () async {
    final result = await resolveGoalTrackerDataRoot(
      environment: const {},
      documentsDirectory: () async => Directory('test-documents').absolute,
    );

    expect(
      result,
      '${Directory('test-documents').absolute.path}'
      '${Platform.pathSeparator}Goals POC',
    );
  });

  test(
    'an explicit data root isolates manual and automated walkthroughs',
    () async {
      final isolated = Directory('isolated-goal-tracker-data').absolute.path;
      final result = await resolveGoalTrackerDataRoot(
        environment: {goalTrackerDataRootEnvironment: isolated},
        documentsDirectory: () async => throw StateError('must not be read'),
      );

      expect(result, isolated);
    },
  );
}
