import 'package:flutter/services.dart';

abstract final class ExternalLinkService {
  static const _channel = MethodChannel('life_tracker/files');

  static Future<void> open(String url) async {
    await _channel.invokeMethod<void>('openUrl', {'url': url});
  }
}
