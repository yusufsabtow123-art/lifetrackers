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
  if (_normalized(left) == _normalized(right) ||
      _normalized(left).endsWith(_normalized(right))) {
    return left;
  }

  final leftWords = left.split(RegExp(r'\s+'));
  final rightWords = right.split(RegExp(r'\s+'));
  final possibleOverlap = leftWords.length < rightWords.length
      ? leftWords.length
      : rightWords.length;
  for (var overlap = possibleOverlap; overlap >= 2; overlap -= 1) {
    final leftTail = leftWords.sublist(leftWords.length - overlap);
    final rightHead = rightWords.sublist(0, overlap);
    if (_normalized(leftTail.join(' ')) == _normalized(rightHead.join(' '))) {
      final remainder = rightWords.sublist(overlap).join(' ');
      return remainder.isEmpty ? left : '$left $remainder';
    }
  }
  return '$left $right';
}

String _normalized(String value) =>
    value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), ' ').trim();
