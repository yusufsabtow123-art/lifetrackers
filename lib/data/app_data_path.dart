import 'dart:io';

import 'package:path_provider/path_provider.dart';

const goalTrackerDataRootEnvironment = 'GOAL_TRACKER_DATA_ROOT';

Future<String> resolveGoalTrackerDataRoot({
  Map<String, String>? environment,
  Future<Directory> Function()? documentsDirectory,
}) async {
  final variables = environment ?? Platform.environment;
  final override = variables[goalTrackerDataRootEnvironment]?.trim();
  if (override != null && override.isNotEmpty) {
    return Directory(override).absolute.path;
  }
  final documents =
      await (documentsDirectory ?? getApplicationDocumentsDirectory)();
  return '${documents.path}${Platform.pathSeparator}Goals POC';
}
