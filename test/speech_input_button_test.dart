import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:goal_tracker_poc/platform/continuous_speech_service.dart';
import 'package:goal_tracker_poc/ui/speech_input_button.dart';

void main() {
  testWidgets('dictation keeps every utterance until explicit Stop', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final text = TextEditingController(text: 'Earlier note.');
    addTearDown(text.dispose);
    final speech = _FakeSpeechService();
    speech.finalTextOnStop = 'and wrote a short reflection';
    addTearDown(speech.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SpeechInputButton(controller: text, service: speech),
          ),
        ),
      ),
    );
    await tester.tap(find.byIcon(Icons.mic_none_rounded));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(speech.startCalls, 1);
    speech.emit(
      const SpeechEvent(type: SpeechEventType.partial, text: 'I read'),
    );
    speech.emit(
      const SpeechEvent(
        type: SpeechEventType.finalText,
        text: 'I read two pages',
      ),
    );
    speech.emit(
      const SpeechEvent(type: SpeechEventType.status, status: 'reconnecting'),
    );
    speech.emit(
      const SpeechEvent(
        type: SpeechEventType.finalText,
        text: "and reviewed yesterday's page",
      ),
    );
    await tester.pump();

    expect(
      find.text("Earlier note. I read two pages and reviewed yesterday's page"),
      findsOneWidget,
    );
    expect(text.text, 'Earlier note.');

    await tester.tap(find.byKey(const Key('continuous-speech-stop')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(speech.stopCalls, 1);
    expect(
      text.text,
      "Earlier note. I read two pages and reviewed yesterday's page and wrote a short reflection",
    );
  });
}

class _FakeSpeechService implements SpeechRecognitionService {
  final _events = StreamController<SpeechEvent>.broadcast();
  int startCalls = 0;
  int stopCalls = 0;
  int cancelCalls = 0;
  String? finalTextOnStop;

  @override
  Stream<SpeechEvent> get events => _events.stream;

  void emit(SpeechEvent event) => _events.add(event);

  @override
  Future<bool> start() async {
    startCalls += 1;
    return true;
  }

  @override
  Future<void> stop() async {
    stopCalls += 1;
    final finalText = finalTextOnStop;
    if (finalText != null) {
      _events.add(
        SpeechEvent(type: SpeechEventType.finalText, text: finalText),
      );
      await Future<void>.delayed(Duration.zero);
    }
  }

  @override
  Future<void> cancel() async {
    cancelCalls += 1;
  }

  void dispose() => _events.close();
}
