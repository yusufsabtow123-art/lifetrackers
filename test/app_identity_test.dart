import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Android and Windows ship Life Tracker app icon resources', () {
    final adaptive = File(
      'android/app/src/main/res/mipmap-anydpi-v26/ic_launcher.xml',
    );
    final foreground = File(
      'android/app/src/main/res/drawable/ic_launcher_foreground.xml',
    );
    final legacy = File(
      'android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png',
    );
    final windows = File('windows/runner/resources/app_icon.ico');

    expect(adaptive.existsSync(), isTrue);
    expect(adaptive.readAsStringSync(), contains('ic_launcher_foreground'));
    expect(foreground.readAsStringSync(), contains('#FFF1F0EC'));
    expect(foreground.readAsStringSync(), contains('#FFC25547'));
    expect(legacy.lengthSync(), greaterThan(1000));
    expect(windows.lengthSync(), greaterThan(1000));
  });
}
