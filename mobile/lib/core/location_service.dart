import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

class LocationService {
  Future<Position> getCurrentPosition() async {
    await _ensurePermission();

    return Geolocator.getCurrentPosition(
      locationSettings: _getSettings(),
    );
  }

  Stream<Position> positionStream() async* {
    await _ensurePermission();

    yield* Geolocator.getPositionStream(
      locationSettings: _getSettings(),
    );
  }

  LocationSettings _getSettings() {
    // ✅ WEB
    if (kIsWeb) {
      return const LocationSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 2,
      );
    }

    // ✅ MOBILE
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return AndroidSettings(
          accuracy: LocationAccuracy.bestForNavigation,
          distanceFilter: 2,
          intervalDuration: const Duration(seconds: 1),
          foregroundNotificationConfig: const ForegroundNotificationConfig(
            notificationText: "Tracking location",
            notificationTitle: "GPS Active",
            enableWakeLock: true,
          ),
        );

      case TargetPlatform.iOS:
        return AppleSettings(
          accuracy: LocationAccuracy.bestForNavigation,
          distanceFilter: 2,
          activityType: ActivityType.fitness,
          showBackgroundLocationIndicator: true,
          pauseLocationUpdatesAutomatically: false,
        );

      default:
        return const LocationSettings(
          accuracy: LocationAccuracy.bestForNavigation,
          distanceFilter: 2,
        );
    }
  }

  Future<void> _ensurePermission() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw const LocationServiceException(
        'Location services are disabled.',
      );
    }

    var permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied) {
      throw const LocationServiceException(
        'Location permission was denied.',
      );
    }

    if (permission == LocationPermission.deniedForever) {
      throw const LocationServiceException(
        'Location permission is permanently denied.',
      );
    }
  }
}

class LocationServiceException implements Exception {
  final String message;
  const LocationServiceException(this.message);

  @override
  String toString() => message;
}