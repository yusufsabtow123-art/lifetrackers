import 'dart:io';

Future<bool> openLocalFolder(String path) async {
  final directory = Directory(path);
  if (!await directory.exists()) {
    await directory.create(recursive: true);
  }

  try {
    if (Platform.isWindows) {
      await Process.start('explorer.exe', [
        path,
      ], mode: ProcessStartMode.detached);
      return true;
    }
    if (Platform.isMacOS) {
      await Process.start('open', [path], mode: ProcessStartMode.detached);
      return true;
    }
    if (Platform.isLinux) {
      await Process.start('xdg-open', [path], mode: ProcessStartMode.detached);
      return true;
    }
  } on ProcessException {
    return false;
  }
  return false;
}
