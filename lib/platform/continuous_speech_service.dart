import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';

enum SpeechEventType { status, partial, finalText, soundLevel, error }

class SpeechEvent {
  const SpeechEvent({
    required this.type,
    this.text = '',
    this.status = '',
    this.errorCode = '',
    this.message = '',
    this.soundLevel = 0,
  });

  final SpeechEventType type;
  final String text;
  final String status;
  final String errorCode;
  final String message;
  final double soundLevel;

  factory SpeechEvent.fromMap(Map<Object?, Object?> map) {
    final rawType = map['type'] as String? ?? 'status';
    final type = switch (rawType) {
      'partial' => SpeechEventType.partial,
      'final' => SpeechEventType.finalText,
      'soundLevel' => SpeechEventType.soundLevel,
      'error' => SpeechEventType.error,
      _ => SpeechEventType.status,
    };
    return SpeechEvent(
      type: type,
      text: map['text'] as String? ?? '',
      status: map['status'] as String? ?? '',
      errorCode: map['code'] as String? ?? '',
      message: map['message'] as String? ?? '',
      soundLevel: (map['level'] as num?)?.toDouble() ?? 0,
    );
  }
}

abstract interface class SpeechRecognitionService {
  Stream<SpeechEvent> get events;

  Future<bool> start();

  Future<void> stop();

  Future<void> cancel();
}

/// Android's recognizer is driven by a native, user-controlled session.
/// Supported Android 13+ recognizers use segmented recognition; other devices
/// are restarted between utterances while the visible session remains active.
class ContinuousSpeechService implements SpeechRecognitionService {
  ContinuousSpeechService._();

  static final ContinuousSpeechService instance = ContinuousSpeechService._();

  static const _methods = MethodChannel('life_tracker/speech');
  static const _eventChannel = EventChannel('life_tracker/speech_events');

  Stream<SpeechEvent>? _events;

  @override
  Stream<SpeechEvent> get events => _events ??= _eventChannel
      .receiveBroadcastStream()
      .map((event) => SpeechEvent.fromMap(event as Map<Object?, Object?>))
      .asBroadcastStream();

  @override
  Future<bool> start() async {
    if (!Platform.isAndroid) return false;
    return await _methods.invokeMethod<bool>('start') ?? false;
  }

  @override
  Future<void> stop() async {
    if (!Platform.isAndroid) return;
    await _methods.invokeMethod<void>('stop');
  }

  @override
  Future<void> cancel() async {
    if (!Platform.isAndroid) return;
    await _methods.invokeMethod<void>('cancel');
  }
}
