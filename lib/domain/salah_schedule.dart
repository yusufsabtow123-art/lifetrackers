import 'package:adhan/adhan.dart';
import 'package:timezone/data/latest.dart' as timezone_data;
import 'package:timezone/timezone.dart' as tz;

import '../data/app_settings_repository.dart';
import 'life_data.dart';

class SalahSchedule {
  SalahSchedule() {
    if (!_timeZonesReady) {
      timezone_data.initializeTimeZones();
      _timeZonesReady = true;
    }
  }

  static bool _timeZonesReady = false;

  final Map<String, List<CalendarEntry>> _cache = {};

  List<CalendarEntry> entriesFor(DateTime day, AppSettingsData settings) {
    if (!settings.salahEnabled) return const [];
    final key = [
      day.year,
      day.month,
      day.day,
      settings.salahLatitude,
      settings.salahLongitude,
      settings.salahTimeZone,
      settings.salahCalculationMethod,
      settings.salahAsrMethod,
      settings.salahHighLatitudeRule,
      settings.salahBlockMinutes,
      settings.salahAdjustments,
    ].join('|');
    return _cache.putIfAbsent(key, () => _calculate(day, settings));
  }

  void clear() => _cache.clear();

  List<CalendarEntry> _calculate(DateTime day, AppSettingsData settings) {
    final coordinates = Coordinates(
      settings.salahLatitude,
      settings.salahLongitude,
    );
    final parameters =
        switch (settings.salahCalculationMethod) {
            'muslimWorldLeague' =>
              CalculationMethod.muslim_world_league.getParameters(),
            'egyptian' => CalculationMethod.egyptian.getParameters(),
            'karachi' => CalculationMethod.karachi.getParameters(),
            'ummAlQura' => CalculationMethod.umm_al_qura.getParameters(),
            _ => CalculationMethod.north_america.getParameters(),
          }
          ..madhab = settings.salahAsrMethod == 'hanafi'
              ? Madhab.hanafi
              : Madhab.shafi
          ..highLatitudeRule = _highLatitudeRule(settings);
    final location = _locationOrLocal(settings.salahTimeZone);
    final localNoon = tz.TZDateTime(location, day.year, day.month, day.day, 12);
    final times = PrayerTimes(
      coordinates,
      DateComponents(day.year, day.month, day.day),
      parameters,
      utcOffset: localNoon.timeZoneOffset,
    );
    final prayers = <String, DateTime>{
      'Fajr': times.fajr,
      'Dhuhr': times.dhuhr,
      'Asr': times.asr,
      'Maghrib': times.maghrib,
      'Isha': times.isha,
    };
    return prayers.entries
        .map((prayer) {
          final adjustment = settings.salahAdjustments[prayer.key] ?? 0;
          final adjusted = prayer.value.add(Duration(minutes: adjustment));
          final start = DateTime(
            day.year,
            day.month,
            day.day,
            adjusted.hour,
            adjusted.minute,
          );
          return CalendarEntry(
            id: 'salah-${day.year}-${day.month}-${day.day}-${prayer.key.toLowerCase()}',
            title: prayer.key,
            start: start,
            end: start.add(Duration(minutes: settings.salahBlockMinutes)),
            kind: CalendarEntryKind.blockedTime,
            location: settings.salahLocationName,
            colorValue: 0xFF4FA36C,
          );
        })
        .toList(growable: false);
  }

  HighLatitudeRule _highLatitudeRule(AppSettingsData settings) =>
      switch (settings.salahHighLatitudeRule) {
        'seventhOfNight' => HighLatitudeRule.seventh_of_the_night,
        'twilightAngle' => HighLatitudeRule.twilight_angle,
        'middleOfNight' => HighLatitudeRule.middle_of_the_night,
        _ =>
          settings.salahLatitude.abs() >= 48
              ? HighLatitudeRule.seventh_of_the_night
              : HighLatitudeRule.middle_of_the_night,
      };

  tz.Location _locationOrLocal(String name) {
    try {
      return tz.getLocation(name);
    } on ArgumentError {
      return tz.getLocation('America/Chicago');
    }
  }
}
