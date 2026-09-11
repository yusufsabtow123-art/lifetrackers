import 'package:flutter_test/flutter_test.dart';
import 'package:goal_tracker_poc/ui/activity_icon_catalog.dart';

void main() {
  test('activity catalog contains exactly 200 useful choices', () {
    expect(ActivityIconCatalog.choices, hasLength(200));
    expect(
      ActivityIconCatalog.choices.map((choice) => choice.id).toSet(),
      hasLength(200),
    );
  });

  test('activity catalog covers common life scheduling categories', () {
    for (final query in ['masjid', 'cat', 'dog', 'zoo', 'work', 'quran']) {
      expect(
        ActivityIconCatalog.choices.any(
          (choice) =>
              choice.id.contains(query) ||
              choice.label.toLowerCase().contains(query),
        ),
        isTrue,
        reason: 'Missing searchable icon for $query',
      );
    }
  });

  test('activity icon guessing recognizes prayer and pets', () {
    expect(ActivityIconCatalog.guess('Maghrib at the masjid').id, 'masjid');
    expect(ActivityIconCatalog.guess('Take the dog to the vet').id, 'dog');
  });
}
