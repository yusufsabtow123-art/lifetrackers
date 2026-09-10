import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../domain/speech_transcript.dart';
import '../platform/continuous_speech_service.dart';
import 'app_theme.dart';

/// Opens a deliberate dictation session that remains active until the user
/// presses Stop. Speech is applied to the field only after confirmation.
class SpeechInputButton extends StatelessWidget {
  const SpeechInputButton({
    super.key,
    required this.controller,
    this.tooltip = 'Speak instead of typing',
    this.service,
  });

  final TextEditingController controller;
  final String tooltip;
  final SpeechRecognitionService? service;

  Future<void> _open(BuildContext context) async {
    FocusManager.instance.primaryFocus?.unfocus();
    final text = await showModalBottomSheet<String>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      useSafeArea: true,
      builder: (_) => _ContinuousDictationSheet(
        initialText: controller.text,
        service: service ?? ContinuousSpeechService.instance,
      ),
    );
    if (text == null || !context.mounted) return;
    controller.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: tooltip,
    onPressed: () => _open(context),
    icon: Icon(Icons.mic_none_rounded, color: context.appMuted),
  );
}

class _ContinuousDictationSheet extends StatefulWidget {
  const _ContinuousDictationSheet({
    required this.initialText,
    required this.service,
  });

  final String initialText;
  final SpeechRecognitionService service;

  @override
  State<_ContinuousDictationSheet> createState() =>
      _ContinuousDictationSheetState();
}

class _ContinuousDictationSheetState extends State<_ContinuousDictationSheet>
    with WidgetsBindingObserver {
  late final SpeechTranscriptAccumulator _transcript;
  StreamSubscription<SpeechEvent>? _subscription;
  Timer? _clock;
  DateTime? _startedAt;
  Duration _elapsed = Duration.zero;
  String _status = 'Preparing microphone…';
  String? _error;
  double _soundLevel = 0;
  bool _closing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _transcript = SpeechTranscriptAccumulator(widget.initialText);
    _subscription = widget.service.events.listen(
      _handleEvent,
      onError: (_) =>
          _showError('Speech recognition could not start. Please try again.'),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => _start());
  }

  Future<void> _start() async {
    try {
      final started = await widget.service.start();
      if (!mounted) return;
      if (!started) {
        _showError(
          'Speech recognition is not available on this phone. Check that the Google speech service is enabled.',
        );
        return;
      }
      _startedAt = DateTime.now();
      _clock = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted || _startedAt == null) return;
        setState(() => _elapsed = DateTime.now().difference(_startedAt!));
      });
    } on PlatformException catch (error) {
      if (!mounted) return;
      _showError(
        error.code == 'microphone_denied'
            ? 'Microphone access was denied. Allow it in Android Settings, then try again.'
            : error.message ?? 'Speech recognition could not start.',
      );
    } on Object {
      if (mounted) {
        _showError('Speech recognition could not start. Please try again.');
      }
    }
  }

  void _handleEvent(SpeechEvent event) {
    if (!mounted) return;
    switch (event.type) {
      case SpeechEventType.partial:
        _transcript.update(event.text, isFinal: false);
        setState(() {});
        break;
      case SpeechEventType.finalText:
        _transcript.update(event.text, isFinal: true);
        setState(() {});
        break;
      case SpeechEventType.soundLevel:
        if (!_closing) setState(() => _soundLevel = event.soundLevel);
        break;
      case SpeechEventType.error:
        _transcript.commitPartial();
        if (!_closing) _showError(event.message);
        break;
      case SpeechEventType.status:
        if (!_closing || event.status == 'stopping') {
          setState(() {
            _status = switch (event.status) {
              'hearing' => 'Listening · keep speaking',
              'processing' => 'Listening · finishing that thought',
              'reconnecting' => 'Still listening · keep going',
              'stopping' => 'Finishing transcription…',
              _ => 'Listening · press Stop when finished',
            };
          });
        }
        break;
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    _clock?.cancel();
    setState(() {
      _error = message;
      _status = 'Microphone stopped';
    });
  }

  Future<void> _stopAndUse() async {
    if (_closing) return;
    setState(() {
      _closing = true;
      _status = 'Finishing transcription…';
    });
    _clock?.cancel();
    try {
      await widget.service.stop();
    } on Object {
      // Preserve everything already recognized even if the platform fails to
      // deliver one last result while stopping.
    }
    _transcript.commitPartial();
    if (mounted) Navigator.pop(context, _transcript.text);
  }

  Future<void> _cancel() async {
    if (_closing) return;
    _closing = true;
    _clock?.cancel();
    try {
      await widget.service.cancel();
    } on Object {
      // Closing the sheet remains safe even if the recognizer already ended.
    }
    if (mounted) Navigator.pop(context);
  }

  Future<void> _retry() async {
    setState(() {
      _error = null;
      _status = 'Preparing microphone…';
      _soundLevel = 0;
    });
    try {
      await widget.service.cancel();
    } on Object {
      // A failed session may already have released its platform resources.
    }
    await _start();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed || _closing) return;
    unawaited(_cancel());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _clock?.cancel();
    _subscription?.cancel();
    if (!_closing) unawaited(widget.service.cancel());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final minutes = _elapsed.inMinutes.toString().padLeft(2, '0');
    final seconds = (_elapsed.inSeconds % 60).toString().padLeft(2, '0');
    final transcript = _transcript.text;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) unawaited(_cancel());
      },
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          22,
          12,
          22,
          MediaQuery.viewPaddingOf(context).bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Voice typing',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                ),
                Text(
                  '$minutes:$seconds',
                  style: Theme.of(
                    context,
                  ).textTheme.labelLarge?.copyWith(color: context.appMuted),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(_status, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 20),
            Center(
              child: _ListeningIndicator(
                active: _error == null && !_closing,
                soundLevel: _soundLevel,
              ),
            ),
            const SizedBox(height: 20),
            Container(
              constraints: const BoxConstraints(minHeight: 112, maxHeight: 230),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: context.appPanel,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: context.appBorder),
              ),
              child: SingleChildScrollView(
                reverse: true,
                child: Text(
                  transcript.isEmpty
                      ? 'Your words will appear here…'
                      : transcript,
                  key: const Key('continuous-speech-transcript'),
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: transcript.isEmpty ? context.appMuted : null,
                    height: 1.45,
                  ),
                ),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                _error!,
                key: const Key('continuous-speech-error'),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
            ],
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _closing ? null : _cancel,
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: _error == null
                      ? FilledButton.icon(
                          key: const Key('continuous-speech-stop'),
                          onPressed: _closing ? null : _stopAndUse,
                          icon: const Icon(Icons.stop_rounded),
                          label: const Text('Stop and use text'),
                        )
                      : FilledButton.icon(
                          onPressed: _retry,
                          icon: const Icon(Icons.refresh_rounded),
                          label: const Text('Try again'),
                        ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ListeningIndicator extends StatelessWidget {
  const _ListeningIndicator({required this.active, required this.soundLevel});

  final bool active;
  final double soundLevel;

  @override
  Widget build(BuildContext context) {
    final strength = ((soundLevel + 2) / 12).clamp(0.08, 1.0);
    return Semantics(
      label: active ? 'Microphone listening' : 'Microphone stopped',
      child: AnimatedContainer(
        duration: LifeMotion.quick,
        width: 78,
        height: 78,
        decoration: BoxDecoration(
          color: active
              ? Theme.of(context).colorScheme.primary.withValues(alpha: .15)
              : context.appPanel,
          shape: BoxShape.circle,
          border: Border.all(
            color: active
                ? Theme.of(context).colorScheme.primary
                : context.appBorder,
            width: 1.5 + strength,
          ),
        ),
        child: Icon(
          active ? Icons.mic_rounded : Icons.mic_off_rounded,
          size: 34,
          color: active
              ? Theme.of(context).colorScheme.primary
              : context.appMuted,
        ),
      ),
    );
  }
}
