import 'package:flutter_test/flutter_test.dart';
import 'package:goal_tracker_poc/domain/natural_task_parser.dart';

void main() {
  final now = DateTime(2026, 9, 10, 14, 15);

  test('extracts tomorrow and explicit time', () {
    final result = parseNaturalTask('Tomorrow at 6 PM take the trash out', now);
    expect(result.title, 'Take the trash out');
    expect(result.dueAt, DateTime(2026, 9, 11, 18));
  });

  test('extracts weekday and time', () {
    final result = parseNaturalTask('Gym Friday at 5', now);
    expect(result.title, 'Gym');
    expect(result.dueAt, DateTime(2026, 9, 11, 17));
  });

  test('extracts named date and time', () {
    final result = parseNaturalTask('Pay rent September 15 at 9 AM', now);
    expect(result.title, 'Pay rent');
    expect(result.dueAt, DateTime(2026, 9, 15, 9));
  });

  test('extracts relative duration', () {
    final result = parseNaturalTask('Take medicine in 2 hours', now);
    expect(result.title, 'Take medicine');
    expect(result.dueAt, DateTime(2026, 9, 10, 16, 15));
  });

  test('keeps unknown language in title', () {
    final result = parseNaturalTask('Review chapter after lunch', now);
    expect(result.title, 'Review chapter after lunch');
    expect(result.dueAt, isNull);
  });
}
