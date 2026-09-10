import 'package:flutter/services.dart';

class SalahLocation {
  const SalahLocation({
    required this.latitude,
    required this.longitude,
    required this.timeZone,
  });

  final double latitude;
  final double longitude;
  final String timeZone;
}

abstract final class SalahLocationService {
  static const _channel = MethodChannel('life_tracker/files');

  static Future<SalahLocation> current() async {
    final value = await _channel.invokeMapMethod<String, Object?>(
      'currentLocation',
    );
    if (value == null) {
      throw PlatformException(
        code: 'location_unavailable',
        message: 'The device did not return a location.',
      );
    }
    return SalahLocation(
      latitude: (value['latitude'] as num).toDouble(),
      longitude: (value['longitude'] as num).toDouble(),
      timeZone: value['timeZone'] as String? ?? 'America/Chicago',
    );
  }
}
