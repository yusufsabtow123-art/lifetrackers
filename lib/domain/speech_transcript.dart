/// Keeps finalized dictation safe while the recognizer replaces its current
/// partial hypothesis. A new recognition session can therefore start after a
/// thoughtful pause without erasing words that were already accepted.
class SpeechTranscriptAccumulator {
  SpeechTranscriptAccumulator([String initialText = ''])
    : _committed = initialText.trim();

  String _committed;
  String _partial = '';

  String get text => joinSpeechSegments(_committed, _partial);

  void reset(String initialText) {
    _committed = initialText.trim();
    _partial = '';
  }

  void update(String words, {required bool isFinal}) {
    _partial = words.trim();
    if (isFinal) commitPartial();
  }

  void commitPartial() {
    if (_partial.isEmpty) return;
    _committed = joinSpeechSegments(_committed, _partial);
    _partial = '';
  }
}

String joinSpeechSegments(String before, String spoken) {
  final left = before.trim();
  final right = spoken.trim();
  if (left.isEmpty) return right;
  if (right.isEmpty) return left;
  return '$left $right';
}
