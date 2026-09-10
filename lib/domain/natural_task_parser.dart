class ParsedTaskInput {
  const ParsedTaskInput({required this.title, this.dueAt});

  final String title;
  final DateTime? dueAt;
}

/// A deliberately small, deterministic parser for the phrases people use most
/// often when quickly capturing a task. It stays offline and adds no APK-sized
/// NLP model. Unknown words remain in the title instead of being guessed away.
ParsedTaskInput parseNaturalTask(String input, DateTime now) {
  var working = input.trim();
  DateTime? date;
  int? hour;
  int minute = 0;

  final relative = RegExp(
    r'\bin\s+(\d+)\s+(minute|minutes|hour|hours)\b',
    caseSensitive: false,
  ).firstMatch(working);
  if (relative != null) {
    final amount = int.parse(relative.group(1)!);
    final duration = relative.group(2)!.toLowerCase().startsWith('hour')
        ? Duration(hours: amount)
        : Duration(minutes: amount);
    final due = now.add(duration);
    date = DateTime(due.year, due.month, due.day);
    hour = due.hour;
    minute = due.minute;
    working = _remove(working, relative);
  }

  if (date == null) {
    final lower = working.toLowerCase();
    final simpleDates = <String, DateTime>{
      'today': DateTime(now.year, now.month, now.day),
      'tomorrow': DateTime(now.year, now.month, now.day + 1),
      'tonight': DateTime(now.year, now.month, now.day),
      'this evening': DateTime(now.year, now.month, now.day),
    };
    for (final entry in simpleDates.entries) {
      final match = RegExp(
        '\\b${RegExp.escape(entry.key)}\\b',
        caseSensitive: false,
      ).firstMatch(working);
      if (match == null) continue;
      date = entry.value;
      if (entry.key == 'tonight' || entry.key == 'this evening') hour = 18;
      working = _remove(working, match);
      break;
    }

    if (date == null) {
      const weekdays = <String, int>{
        'monday': DateTime.monday,
        'tuesday': DateTime.tuesday,
        'wednesday': DateTime.wednesday,
        'thursday': DateTime.thursday,
        'friday': DateTime.friday,
        'saturday': DateTime.saturday,
        'sunday': DateTime.sunday,
      };
      final match = RegExp(
        r'\b(next\s+)?(monday|tuesday|wednesday|thursday|friday|saturday|sunday)\b',
        caseSensitive: false,
      ).firstMatch(lower);
      if (match != null) {
        final target = weekdays[match.group(2)]!;
        var days = (target - now.weekday) % 7;
        if (days == 0 || match.group(1) != null) days += 7;
        date = DateTime(now.year, now.month, now.day + days);
        working = _remove(working, match);
      }
    }

    if (date == null) {
      const months = <String, int>{
        'january': 1,
        'february': 2,
        'march': 3,
        'april': 4,
        'may': 5,
        'june': 6,
        'july': 7,
        'august': 8,
        'september': 9,
        'october': 10,
        'november': 11,
        'december': 12,
      };
      final match = RegExp(
        r'\b(january|february|march|april|may|june|july|august|september|october|november|december)\s+(\d{1,2})(?:,?\s+(\d{4}))?\b',
        caseSensitive: false,
      ).firstMatch(working);
      if (match != null) {
        final month = months[match.group(1)!.toLowerCase()]!;
        var year = int.tryParse(match.group(3) ?? '') ?? now.year;
        final day = int.parse(match.group(2)!);
        var candidate = DateTime(year, month, day);
        if (match.group(3) == null && candidate.isBefore(now)) {
          candidate = DateTime(++year, month, day);
        }
        if (candidate.month == month && candidate.day == day) date = candidate;
        working = _remove(working, match);
      }
    }
  }

  if (relative == null) {
    final timeMatch = RegExp(
      r'\b(?:at\s+)?(noon|midnight|(?:[01]?\d|2[0-3])(?::([0-5]\d))?\s*(?:a\.?m\.?|p\.?m\.?)?)\b',
      caseSensitive: false,
    ).allMatches(working).lastOrNull;
    if (timeMatch != null) {
      final raw = timeMatch.group(1)!.toLowerCase().replaceAll('.', '').trim();
      if (raw == 'noon') {
        hour = 12;
      } else if (raw == 'midnight') {
        hour = 0;
      } else {
        final parsed = RegExp(
          r'^(\d{1,2})(?::(\d{2}))?\s*(am|pm)?$',
        ).firstMatch(raw);
        if (parsed != null) {
          hour = int.parse(parsed.group(1)!);
          minute = int.tryParse(parsed.group(2) ?? '') ?? 0;
          final suffix = parsed.group(3);
          if (suffix == 'am' && hour == 12) hour = 0;
          if (suffix == 'pm' && hour < 12) hour = hour + 12;
          if (suffix == null && hour >= 1 && hour <= 7) hour = hour + 12;
        }
      }
      working = _remove(working, timeMatch);
    }
  }

  if (date == null && hour != null) {
    date = DateTime(now.year, now.month, now.day);
    if (!DateTime(date.year, date.month, date.day, hour, minute).isAfter(now)) {
      date = date.add(const Duration(days: 1));
    }
  }
  final dueAt = date == null
      ? null
      : DateTime(date.year, date.month, date.day, hour ?? 9, minute);
  final title = working.replaceAll(RegExp(r'\s+'), ' ').trim();
  return ParsedTaskInput(title: _sentenceCase(title), dueAt: dueAt);
}

String _remove(String source, Match match) =>
    source.replaceRange(match.start, match.end, ' ');

String _sentenceCase(String value) {
  if (value.isEmpty) return value;
  return '${value[0].toUpperCase()}${value.substring(1)}';
}

extension<T> on Iterable<T> {
  T? get lastOrNull => isEmpty ? null : last;
}
