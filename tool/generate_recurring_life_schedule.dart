import 'dart:io';

import 'package:adhan/adhan.dart';

const _home = 'Saint Paul, Minnesota';
const _work = 'Boston Scientific, 10700 Bren Rd W, Minnetonka, MN 55343';
const _masjid = 'Masjid Dawah, 605 Fairview Ave N, Saint Paul, MN 55104';
final _scheduleStart = DateTime(2026, 9, 1);
final _scheduleEnd = DateTime(2027, 12, 31);

class ScheduleRow {
  const ScheduleRow({
    required this.date,
    required this.start,
    required this.end,
    required this.title,
    required this.color,
    this.location = '',
    this.repeat = 'none',
    this.kind = 'event',
  });

  final DateTime date;
  final String start;
  final String end;
  final String title;
  final String location;
  final String color;
  final String repeat;
  final String kind;

  String get key => '${_ymd(date)}|$start|$end|$title|$repeat';
  String get tsv =>
      [_ymd(date), start, end, title, location, color, repeat, kind].join('\t');
}

Future<void> main(List<String> arguments) async {
  final workoutAnchorArgument = arguments
      .where((argument) => argument.startsWith('--workout-anchor='))
      .firstOrNull;
  final workoutAnchor = workoutAnchorArgument == null
      ? null
      : DateTime.tryParse(workoutAnchorArgument.split('=').last);
  if (workoutAnchorArgument != null && workoutAnchor == null) {
    throw ArgumentError('Workout anchor must be YYYY-MM-DD.');
  }

  final rows = <ScheduleRow>[];
  void add(ScheduleRow row) => rows.add(row);
  void once(
    DateTime date,
    String start,
    String end,
    String title,
    String color, {
    String location = '',
    String kind = 'event',
  }) => add(
    ScheduleRow(
      date: date,
      start: start,
      end: end,
      title: title,
      color: color,
      location: location,
      kind: kind,
    ),
  );
  void weekly(
    int weekday,
    String start,
    String end,
    String title,
    String color, {
    String location = '',
    DateTime? notBefore,
  }) => add(
    ScheduleRow(
      date: _nextWeekday(notBefore ?? _scheduleStart, weekday),
      start: start,
      end: end,
      title: title,
      color: color,
      location: location,
      repeat: 'weekly',
    ),
  );

  // Work and weekday commute. Each overnight work series starts in the week
  // containing September 1 so the early-morning tail is visible that day.
  for (final weekday in const [
    DateTime.sunday,
    DateTime.monday,
    DateTime.tuesday,
    DateTime.wednesday,
    DateTime.thursday,
  ]) {
    add(
      ScheduleRow(
        date: _weekdayOnOrBefore(_scheduleStart, weekday),
        start: '23:00',
        end: '07:00',
        title: 'Work — Boston Scientific',
        location: _work,
        color: 'red',
        repeat: 'weekly',
      ),
    );
  }
  add(
    ScheduleRow(
      date: _scheduleStart,
      start: '07:00',
      end: '07:30',
      title: 'Commute Home from Work',
      location: 'Boston Scientific → Saint Paul, Minnesota',
      color: 'purple',
      repeat: 'weekdays',
    ),
  );

  // September 1–30 temporary Monday–Thursday routine. These are dated rows so
  // they cannot continue into October in an app without recurrence end dates.
  for (
    var day = _scheduleStart;
    !day.isAfter(DateTime(2026, 9, 30));
    day = DateTime(day.year, day.month, day.day + 1)
  ) {
    if (day.weekday > DateTime.thursday) continue;
    once(day, '07:30', '15:00', 'Sleep / Recovery', 'gray', location: _home);
    once(day, '15:00', '17:00', 'Dugsi', 'cyan');
    once(
      day,
      '17:00',
      '17:30',
      'Business — Daily Focus',
      'yellow',
      location: _home,
    );
    once(day, '17:30', '18:30', "Qur'an Revision", 'cyan', location: _home);
    if (day.weekday == DateTime.thursday) {
      once(
        day,
        '18:30',
        '18:45',
        'Clean Clothes + Room',
        'purple',
        location: _home,
      );
      once(day, '19:45', '21:45', 'Business Focus', 'yellow', location: _home);
      once(day, '21:45', '22:15', 'WGU Degree Study', 'blue', location: _home);
    }
  }

  // The normal Monday–Thursday routine begins exactly October 1, 2026.
  final normalStart = DateTime(2026, 10, 1);
  for (final weekday in const [
    DateTime.monday,
    DateTime.tuesday,
    DateTime.wednesday,
    DateTime.thursday,
  ]) {
    weekly(
      weekday,
      '07:30',
      '15:00',
      'Sleep / Recovery',
      'gray',
      location: _home,
      notBefore: normalStart,
    );
    weekly(
      weekday,
      '15:00',
      '15:15',
      'Clean Clothes + Room',
      'purple',
      location: _home,
      notBefore: normalStart,
    );
    weekly(
      weekday,
      '15:15',
      '16:15',
      "Qur'an Revision",
      'cyan',
      location: _home,
      notBefore: normalStart,
    );
    weekly(
      weekday,
      '16:15',
      '16:45',
      'Business — Daily Focus',
      'yellow',
      location: _home,
      notBefore: normalStart,
    );
  }

  // Monday–Wednesday class commute is the same before and after October.
  for (final weekday in const [
    DateTime.monday,
    DateTime.tuesday,
    DateTime.wednesday,
  ]) {
    weekly(
      weekday,
      '22:30',
      '23:00',
      'Commute Masjid Dawah → Work',
      'purple',
      location: 'Masjid Dawah → Boston Scientific',
    );
  }
  weekly(
    DateTime.thursday,
    '22:30',
    '23:00',
    'Commute Home → Work',
    'purple',
    location: 'Saint Paul, Minnesota → Boston Scientific',
  );
  weekly(
    DateTime.thursday,
    '17:45',
    '19:45',
    'Business Focus',
    'yellow',
    location: _home,
    notBefore: normalStart,
  );
  weekly(
    DateTime.thursday,
    '19:45',
    '22:15',
    'WGU Degree Study',
    'blue',
    location: _home,
    notBefore: normalStart,
  );

  // Friday.
  weekly(
    DateTime.friday,
    '07:30',
    '13:30',
    'Sleep / Recovery',
    'gray',
    location: _home,
  );
  weekly(
    DateTime.friday,
    '13:30',
    '14:30',
    "Jumu'ah Salah",
    'green',
    location: _home,
  );
  weekly(
    DateTime.friday,
    '14:30',
    '14:45',
    'Clean Clothes + Room',
    'purple',
    location: _home,
  );
  weekly(
    DateTime.friday,
    '14:45',
    '15:45',
    "Qur'an Revision",
    'cyan',
    location: _home,
  );
  weekly(
    DateTime.friday,
    '15:45',
    '16:15',
    'Business — Daily Focus',
    'yellow',
    location: _home,
  );
  weekly(
    DateTime.friday,
    '17:45',
    '19:45',
    'Business Focus',
    'yellow',
    location: _home,
  );
  weekly(
    DateTime.friday,
    '19:45',
    '23:00',
    'WGU Degree Study',
    'blue',
    location: _home,
  );
  weekly(
    DateTime.friday,
    '23:30',
    '06:00',
    'Weekend Night Sleep',
    'gray',
    location: _home,
  );

  // Saturday.
  weekly(
    DateTime.saturday,
    '06:00',
    '06:30',
    'Business — Daily Focus',
    'yellow',
    location: _home,
  );
  weekly(
    DateTime.saturday,
    '07:30',
    '08:30',
    "Qur'an Revision",
    'cyan',
    location: _home,
  );
  weekly(DateTime.saturday, '09:00', '14:00', 'Dugsi', 'cyan');
  weekly(DateTime.saturday, '14:30', '17:00', 'Basketball', 'coral');
  weekly(
    DateTime.saturday,
    '17:30',
    '19:30',
    'Saturday Recovery Nap',
    'gray',
    location: _home,
  );
  weekly(
    DateTime.saturday,
    '19:30',
    '21:30',
    'Business Focus',
    'yellow',
    location: _home,
  );
  weekly(
    DateTime.saturday,
    '21:30',
    '23:30',
    'WGU Degree Study',
    'blue',
    location: _home,
  );
  weekly(
    DateTime.saturday,
    '23:30',
    '06:00',
    'Weekend Night Sleep',
    'gray',
    location: _home,
  );

  // Sunday.
  weekly(
    DateTime.sunday,
    '06:00',
    '06:30',
    'Business — Daily Focus',
    'yellow',
    location: _home,
  );
  weekly(
    DateTime.sunday,
    '07:30',
    '08:30',
    "Qur'an Revision",
    'cyan',
    location: _home,
  );
  weekly(DateTime.sunday, '09:00', '14:00', 'Dugsi', 'cyan');
  weekly(DateTime.sunday, '14:30', '17:00', 'Basketball', 'coral');
  weekly(
    DateTime.sunday,
    '17:30',
    '20:30',
    'Sunday Pre-Work Nap',
    'gray',
    location: _home,
  );
  weekly(DateTime.sunday, '21:00', '22:30', 'Sunday Basketball', 'coral');
  weekly(
    DateTime.sunday,
    '22:30',
    '23:00',
    'Commute to Work',
    'purple',
    location: 'Saint Paul, Minnesota → Boston Scientific',
  );

  final prayerTimes = await _loadPrayerTimes();
  for (final entry in prayerTimes.entries) {
    final day = entry.key;
    final times = entry.value;
    for (final prayer in const ['Fajr', 'Dhuhr', 'Asr', 'Maghrib', 'Isha']) {
      if (prayer == 'Dhuhr' && day.weekday == DateTime.friday) continue;
      final start = times[prayer]!;
      once(
        day,
        start,
        _addMinutes(start, 30),
        prayer,
        'green',
        location: _home,
        kind: 'blockedTime',
      );
    }
    if (day.weekday <= DateTime.wednesday) {
      once(
        day,
        times['Maghrib']!,
        '22:30',
        "Qur'an Class",
        'cyan',
        location: _masjid,
      );
    }
  }

  if (workoutAnchor != null) {
    for (
      var day = _scheduleStart;
      !day.isAfter(_scheduleEnd);
      day = DateTime(day.year, day.month, day.day + 1)
    ) {
      final workoutDay = day.difference(workoutAnchor).inDays.abs().isEven;
      if (day.weekday == DateTime.saturday || day.weekday == DateTime.sunday) {
        once(
          day,
          '06:30',
          '07:30',
          workoutDay ? 'Workout' : 'WGU Degree Study',
          workoutDay ? 'coral' : 'blue',
          location: _home,
        );
      } else if (workoutDay) {
        if (day.isBefore(normalStart) && day.weekday <= DateTime.wednesday) {
          continue;
        }
        final start =
            day.isBefore(normalStart) && day.weekday == DateTime.thursday
            ? '18:45'
            : '16:45';
        once(
          day,
          start,
          _addMinutes(start, 60),
          'Workout',
          'coral',
          location: _home,
        );
      }
    }
  }

  final unique =
      <String, ScheduleRow>{
        for (final row in rows) row.key: row,
      }.values.toList()..sort((a, b) {
        final date = a.date.compareTo(b.date);
        if (date != 0) return date;
        final time = a.start.compareTo(b.start);
        if (time != 0) return time;
        return a.title.compareTo(b.title);
      });
  final output = File('releases/life-schedule-2026-09-to-2027-12.tsv');
  await output.writeAsString('${unique.map((row) => row.tsv).join('\n')}\n');
  stdout.writeln('Generated ${unique.length} unique calendar rows.');
  stdout.writeln('Prayer days: ${prayerTimes.length}.');
  stdout.writeln(
    workoutAnchor == null
        ? 'Workout rotation omitted: no anchor date supplied.'
        : 'Workout rotation anchored on ${_ymd(workoutAnchor)}.',
  );
  stdout.writeln('Output: ${output.absolute.path}');
}

Future<Map<DateTime, Map<String, String>>> _loadPrayerTimes() async {
  final result = <DateTime, Map<String, String>>{};
  final coordinates = Coordinates(44.9537, -93.0900);
  final parameters = CalculationMethod.north_america.getParameters()
    ..madhab = Madhab.shafi;
  for (
    var day = _scheduleStart;
    !day.isAfter(_scheduleEnd);
    day = DateTime(day.year, day.month, day.day + 1)
  ) {
    final offset = DateTime(day.year, day.month, day.day, 12).timeZoneOffset;
    if (offset != const Duration(hours: -5) &&
        offset != const Duration(hours: -6)) {
      throw StateError(
        'Expected America/Chicago UTC offset for ${_ymd(day)}; found $offset.',
      );
    }
    final times = PrayerTimes(
      coordinates,
      DateComponents(day.year, day.month, day.day),
      parameters,
      utcOffset: offset,
    );
    result[day] = {
      'Fajr': _timeOf(times.fajr),
      'Dhuhr': _timeOf(times.dhuhr),
      'Asr': _timeOf(times.asr),
      'Maghrib': _timeOf(times.maghrib),
      'Isha': _timeOf(times.isha),
    };
  }
  final expectedDays = _scheduleEnd.difference(_scheduleStart).inDays + 1;
  if (result.length != expectedDays) {
    throw StateError(
      'Expected $expectedDays prayer days; received ${result.length}.',
    );
  }
  return result;
}

String _timeOf(DateTime value) =>
    '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';

String _addMinutes(String value, int minutes) {
  final parts = value.split(':').map(int.parse).toList();
  final total = parts[0] * 60 + parts[1] + minutes;
  return '${(total ~/ 60 % 24).toString().padLeft(2, '0')}:${(total % 60).toString().padLeft(2, '0')}';
}

DateTime _nextWeekday(DateTime start, int weekday) {
  var date = DateTime(start.year, start.month, start.day);
  while (date.weekday != weekday) {
    date = date.add(const Duration(days: 1));
  }
  return date;
}

DateTime _weekdayOnOrBefore(DateTime start, int weekday) {
  var date = DateTime(start.year, start.month, start.day);
  while (date.weekday != weekday) {
    date = date.subtract(const Duration(days: 1));
  }
  return date;
}

String _ymd(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

extension<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
