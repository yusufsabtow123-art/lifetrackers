import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

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

class _SpeechInputButtonState extends State<SpeechInputButton> {
  static final SpeechToText _speech = SpeechToText();
  static Future<bool>? _initialization;

  bool _listening = false;
  String _textBeforeListening = '';

  Future<void> _toggle() async {
    try {
      if (_listening) {
        await _speech.stop();
        if (mounted) setState(() => _listening = false);
        return;
      }

      _initialization ??= _speech.initialize();
      final available = await _initialization!;
      if (!mounted) return;
      if (!available) {
        _showUnavailableMessage();
        return;
      }

      _textBeforeListening = widget.controller.text.trim();
      setState(() => _listening = true);
      await _speech.listen(
        onResult: _onResult,
        listenOptions: SpeechListenOptions(
          listenMode: ListenMode.dictation,
          partialResults: true,
          cancelOnError: true,
          onDevice: true,
          listenFor: const Duration(seconds: 45),
          pauseFor: const Duration(seconds: 4),
        ),
      );
      if (mounted && !_speech.isListening) {
        setState(() => _listening = false);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _listening = false);
        _showUnavailableMessage();
      }
    }
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
    final spoken = result.recognizedWords.trim();
    final separator = _textBeforeListening.isEmpty || spoken.isEmpty ? '' : ' ';
    widget.controller.value = TextEditingValue(
      text: '$_textBeforeListening$separator$spoken',
      selection: TextSelection.collapsed(
        offset: _textBeforeListening.length + separator.length + spoken.length,
      ),
    );
    if (result.finalResult && mounted) setState(() => _listening = false);
  }

  @override
  void dispose() {
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
