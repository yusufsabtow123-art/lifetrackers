import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../domain/speech_transcript.dart';
import 'app_theme.dart';

/// Short, deliberate dictation using the recognizer already provided by the
/// device. `onDevice` keeps the free experience local when an offline language
/// pack is installed and avoids bundling a large speech model in the app.
class SpeechInputButton extends StatefulWidget {
  const SpeechInputButton({
    super.key,
    required this.controller,
    this.tooltip = 'Speak instead of typing',
  });

  final TextEditingController controller;
  final String tooltip;

  @override
  State<SpeechInputButton> createState() => _SpeechInputButtonState();
}

class _SpeechInputButtonState extends State<SpeechInputButton>
    with WidgetsBindingObserver {
  final SpeechToText _speech = SpeechToText();

  bool _listening = false;
  bool _keepListening = false;
  bool _restarting = false;
  bool _preferOnDevice = true;
  final SpeechTranscriptAccumulator _transcript =
      SpeechTranscriptAccumulator();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed || !_keepListening) return;
    _keepListening = false;
    _commitCurrentSegment();
    _speech.cancel();
    if (mounted) setState(() => _listening = false);
  }

  Future<void> _toggle() async {
    try {
      if (_listening) {
        _keepListening = false;
        await _speech.stop();
        if (mounted) setState(() => _listening = false);
        return;
      }

      final available = await _speech.initialize(
        onStatus: _onStatus,
        onError: (_) => _finishListening(),
      );
      if (!mounted) return;
      if (!available) {
        _showUnavailableMessage();
        return;
      }

      _transcript.reset(widget.controller.text);
      _preferOnDevice = true;
      _keepListening = true;
      setState(() => _listening = true);
      await _startSegment();
    } catch (_) {
      if (mounted) {
        setState(() => _listening = false);
        _showUnavailableMessage();
      }
    }
  }

  Future<void> _startSegment() async {
    try {
      await _listen(onDevice: _preferOnDevice);
    } on Object {
      if (!_preferOnDevice) rethrow;
      // Not every Android speech service has an offline model installed. Keep
      // dictation available through the system service without bundling a
      // large model into Life Tracker.
      _preferOnDevice = false;
      await _listen(onDevice: false);
    }
  }

  Future<void> _listen({required bool onDevice}) => _speech.listen(
    onResult: _onResult,
    listenOptions: SpeechListenOptions(
      listenMode: ListenMode.dictation,
      partialResults: true,
      cancelOnError: false,
      onDevice: onDevice,
      listenFor: const Duration(minutes: 2),
      pauseFor: const Duration(seconds: 5),
    ),
  );

  void _onStatus(String status) {
    if (!_keepListening || !mounted) return;
    if (status != 'done' && status != 'notListening') return;
    _commitCurrentSegment();
    if (_restarting) return;
    _restarting = true;
    Future<void>.delayed(const Duration(milliseconds: 250), () async {
      _restarting = false;
      if (!_keepListening || !mounted || _speech.isListening) return;
      try {
        await _startSegment();
      } on Object {
        _finishListening();
      }
    });
  }

  void _finishListening() {
    _keepListening = false;
    _commitCurrentSegment();
    if (mounted) setState(() => _listening = false);
  }

  void _commitCurrentSegment() {
    _transcript.commitPartial();
    _writeText(_transcript.text);
  }

  void _showUnavailableMessage() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Speech is not available. Check microphone permission and your offline language pack.',
        ),
      ),
    );
  }

  void _onResult(SpeechRecognitionResult result) {
    if (!mounted) return;
    _transcript.update(
      result.recognizedWords,
      isFinal: result.finalResult,
    );
    _writeText(_transcript.text);
  }

  void _writeText(String text) {
    widget.controller.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _keepListening = false;
    if (_listening) _speech.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedContainer(
    duration: LifeMotion.quick,
    curve: LifeMotion.curve,
    decoration: BoxDecoration(
      color: _listening
          ? Theme.of(context).colorScheme.primary.withValues(alpha: .14)
          : Colors.transparent,
      shape: BoxShape.circle,
    ),
    child: IconButton(
      tooltip: _listening ? 'Stop listening' : widget.tooltip,
      onPressed: _toggle,
      icon: AnimatedSwitcher(
        duration: LifeMotion.quick,
        child: Icon(
          _listening ? Icons.stop_rounded : Icons.mic_none_rounded,
          key: ValueKey(_listening),
          color: _listening
              ? Theme.of(context).colorScheme.primary
              : context.appMuted,
        ),
      ),
    ),
  );
}
