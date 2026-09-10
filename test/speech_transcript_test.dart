import 'package:flutter_test/flutter_test.dart';
import 'package:goal_tracker_poc/domain/speech_transcript.dart';

void main() {
  test('final speech survives a pause and later partial replacements', () {
    final transcript = SpeechTranscriptAccumulator('Earlier note.');

    transcript.update('I read', isFinal: false);
    transcript.update('I read two pages', isFinal: true);
    transcript.commitPartial(); // The recognizer pauses and closes a session.
    transcript.update('and reviewed', isFinal: false);
    transcript.update("and reviewed yesterday's page", isFinal: true);

    expect(
      transcript.text,
      "Earlier note. I read two pages and reviewed yesterday's page",
    );
  });

  test('changing partial hypotheses never duplicates committed speech', () {
    final transcript = SpeechTranscriptAccumulator();

    transcript.update('Take', isFinal: false);
    transcript.update('Take the trash', isFinal: false);
    transcript.update('Take the trash out', isFinal: true);

    expect(transcript.text, 'Take the trash out');
  });
}
