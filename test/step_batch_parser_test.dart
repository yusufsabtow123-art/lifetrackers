import 'package:flutter_test/flutter_test.dart';
import 'package:goal_tracker_poc/domain/step_batch_parser.dart';

void main() {
  const parser = StepBatchParser();

  test('spaced plus and equals produce saved preview items', () {
    final preview = parser.parse('Get pot + Add water + Cook = Rice ready');

    expect(preview.titles, ['Get pot', 'Add water', 'Cook', 'Rice ready']);
    expect(preview.items.last.isFinalResult, isTrue);
    expect(preview.canAdd, isTrue);
  });

  test('new lines are the primary batch separator', () {
    final preview = parser.parse('Wash rice\nAdd water\nCook');

    expect(preview.titles, ['Wash rice', 'Add water', 'Cook']);
    expect(preview.items.any((item) => item.isFinalResult), isFalse);
  });

  test('ordinary plus and equals characters stay inside a step', () {
    final preview = parser.parse('Review C++\nWalk 5+ miles\nUse x=4');

    expect(preview.titles, ['Review C++', 'Walk 5+ miles', 'Use x=4']);
  });

  test('duplicates remain visible and one item is not a batch', () {
    expect(parser.parse('Wash\nWash').titles, ['Wash', 'Wash']);
    expect(parser.parse('Wash').canAdd, isFalse);
  });
}
