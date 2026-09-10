import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('production Android manifest supports local and online recognition', () {
    final manifest = File(
      'android/app/src/main/AndroidManifest.xml',
    ).readAsStringSync();

    expect(manifest, contains('android.permission.RECORD_AUDIO'));
    expect(manifest, contains('android.permission.INTERNET'));
    expect(manifest, contains('android.speech.RecognitionService'));
  });

  test('native dictation uses segmentation and user-controlled stopping', () {
    final bridge = File(
      'android/app/src/main/kotlin/app/localfirst/goal_tracker_poc/'
      'ContinuousSpeechBridge.kt',
    ).readAsStringSync();

    expect(bridge, contains('EXTRA_SEGMENTED_SESSION'));
    expect(bridge, contains('EXTRA_PARTIAL_RESULTS'));
    expect(bridge, contains('requestedActive'));
    expect(bridge, contains('scheduleRestart'));
    expect(bridge, contains('stopListening()'));
    expect(bridge, contains('destroy()'));
  });
}
