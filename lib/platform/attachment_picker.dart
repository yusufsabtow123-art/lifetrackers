import 'package:flutter/services.dart';

import '../domain/life_data.dart';

abstract final class AttachmentPicker {
  static const _channel = MethodChannel('life_tracker/files');

  static Future<LifeAttachment?> choose({bool imageOnly = false}) async {
    final result = await _channel.invokeMapMethod<String, Object?>(
      'chooseAttachment',
      {'imageOnly': imageOnly},
    );
    return _fromResult(result);
  }

  static Future<LifeAttachment?> importKeyboardContent(
    KeyboardInsertedContent content,
  ) async {
    final result = await _channel.invokeMapMethod<String, Object?>(
      'importKeyboardContent',
      {'uri': content.uri, 'mimeType': content.mimeType},
    );
    return _fromResult(result);
  }

  static Future<bool> open(LifeAttachment attachment) async =>
      await _channel.invokeMethod<bool>('openAttachment', {
        'path': attachment.path,
        'mimeType': attachment.mimeType,
      }) ??
      false;

  static LifeAttachment? _fromResult(Map<String, Object?>? result) {
    if (result == null) return null;
    final path = result['path'] as String? ?? '';
    if (path.isEmpty) return null;
    final mimeType = result['mimeType'] as String? ?? '';
    return LifeAttachment(
      id: 'attachment-${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}',
      name: result['name'] as String? ?? 'Attachment',
      path: path,
      mimeType: mimeType,
      sizeBytes: (result['sizeBytes'] as num?)?.toInt() ?? 0,
      kind: mimeType.startsWith('image/')
          ? LifeAttachmentKind.image
          : LifeAttachmentKind.file,
    );
  }
}
