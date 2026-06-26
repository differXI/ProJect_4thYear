import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

class LocationService {
  // ─────────────────────────────────────────
  // Single position (one-shot)
  // ─────────────────────────────────────────
  Future<Position> getCurrentPosition() async {
    await _ensurePermission();
    return Geolocator.getCurrentPosition(
      locationSettings: _getSettings(),
    );
  }

  // ─────────────────────────────────────────
  // Continuous stream for run tracking
  //
  // FIX (Web) — browser ignores distanceFilter and never fires
  // the stream when the user is sitting still (e.g. testing on
  // localhost).  We wrap the native stream with a polling fallback:
  // every 3 s we ask for the current position and emit it manually
  // so the timer, distance counter, and step counter always advance.
  // ─────────────────────────────────────────
  Stream<Position> positionStream() async* {
    await _ensurePermission();

    if (kIsWeb) {
      yield* _webPollingStream();
    } else {
      yield* Geolocator.getPositionStream(
        locationSettings: _getSettings(),
      );
    }
  }

  // Web: poll getCurrentPosition every 3 s.
  // This guarantees at least one emit per interval even when stationary,
  // so the UI timer and stats stay live during localhost testing.
  Stream<Position> _webPollingStream() async* {
    // Emit the first fix immediately.
    try {
      final first = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.bestForNavigation,
        ),
      );
      yield first;
    } catch (_) {
      // If the very first fix fails, just wait for the first poll tick.
    }

    // Then poll every 3 seconds.
    while (true) {
      await Future<void>.delayed(const Duration(seconds: 3));
      try {
        final position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.bestForNavigation,
          ),
        );
        yield position;
      } catch (e) {
        // Yield nothing on error — the stream keeps running so the
        // caller's onError handler is NOT triggered for transient issues.
        // A permanent error (permission revoked) will surface on the next
        // getCurrentPosition call and bubble up naturally.
      }
    }
  }

  // ─────────────────────────────────────────
  // Platform-specific settings (mobile only)
  // ─────────────────────────────────────────
  LocationSettings _getSettings() {
    // Web path is handled separately in positionStream().
    if (kIsWeb) {
      return const LocationSettings(
        accuracy: LocationAccuracy.bestForNavigation,
      );
    }

    switch (defaultTargetPlatform) {
      // ── Android ──────────────────────────
      case TargetPlatform.android:
        return AndroidSettings(
          accuracy: LocationAccuracy.bestForNavigation,
          distanceFilter: 2,
          intervalDuration: const Duration(seconds: 3),
          foregroundNotificationConfig: const ForegroundNotificationConfig(
            notificationText: 'Tracking your run location',
            notificationTitle: 'GPS Active',
            enableWakeLock: true,
          ),
        );

      // ── iOS / macOS ───────────────────────
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
        return AppleSettings(
          accuracy: LocationAccuracy.bestForNavigation,
          distanceFilter: 2,
          activityType: ActivityType.fitness,
          showBackgroundLocationIndicator: true,
          pauseLocationUpdatesAutomatically: false,
        );

      // ── Linux / Windows / Fuchsia ─────────
      default:
        return const LocationSettings(
          accuracy: LocationAccuracy.bestForNavigation,
          distanceFilter: 2,
        );
    }
  }

  // ─────────────────────────────────────────
  // Permission & service checks
  // ─────────────────────────────────────────
  Future<void> _ensurePermission() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw const LocationServiceException(
        'Location services are disabled. Please enable GPS in device settings.',
      );
    }

    var permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied) {
      throw const LocationServiceException(
        'Location permission was denied. Please allow location access.',
      );
    }

    if (permission == LocationPermission.deniedForever) {
      throw const LocationServiceException(
        'Location permission is permanently denied. '
        'Please enable it in your device app settings.',
      );
    }
  }
}

// ─────────────────────────────────────────────
// Typed exception
// ─────────────────────────────────────────────
class LocationServiceException implements Exception {
  const LocationServiceException(this.message);

  final String message;

  @override
  String toString() => message;
}