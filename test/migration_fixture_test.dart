import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:goal_tracker_poc/data/goal_markdown_codec.dart';
import 'package:goal_tracker_poc/domain/goal.dart';

void main() {
  const codec = GoalMarkdownCodec();

  test('v0.9.1 idea reminder receives stable compatible fields', () {
    final source = File('test/fixtures/v0_9_1_goal.md').readAsStringSync();
    final first = codec.decode(source);
    final second = codec.decode(source);

    expect(first.name, 'Legacy idea reminder');
    expect(first.reminder?.purpose, ReminderPurpose.goalCompletion);
    expect(first.reminder?.id, 'fixture-v091-reminder-main');
    expect(first.steps.single.id, 'legacy-step');
    expect(first.updates.single.id, second.updates.single.id);
    expect(first.updates.single.id, isNotEmpty);

    final roundTrip = codec.decode(codec.encode(first));
    expect(roundTrip.reminder?.purpose, ReminderPurpose.goalCompletion);
    expect(roundTrip.updates.single.text, 'Found the phone number');
  });

  test('v0.10.1 fields round-trip and removed urgency maps safely', () {
    final source = File('test/fixtures/v0_10_1_goal.md').readAsStringSync();
    final goal = codec.decode(source);

    expect(goal.plan?.totalAmount, 604);
    expect(goal.completedAmount, 2);
    expect(goal.reminder?.purpose, ReminderPurpose.dailyAction);
    expect(goal.reminder?.id, 'fixture-v0101-reminder-main');
    expect(goal.urgencyStyle, UrgencyStyle.fireRing);
    expect(goal.steps.single.details, 'Read it aloud twice.');
    expect(goal.updates.single.id, 'saved-update-id');
    expect(goal.updates.single.editedAt, isNotNull);

    final roundTrip = codec.decode(codec.encode(goal));
    expect(roundTrip.plan?.unit, 'pages');
    expect(roundTrip.steps.single.details, 'Read it aloud twice.');
    expect(roundTrip.updates.single.id, 'saved-update-id');
  });
}
