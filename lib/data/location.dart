// The device position through geolocator, behind a small interface so the
// map's permission flow can be tested without the plugin.
import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

/// Why there is no position.
enum LocateFailure {
  /// Location is switched off in the system settings.
  serviceDisabled,

  /// The user declined the permission this time; asking again may work.
  denied,

  /// Declined for good: only the app settings can grant it now.
  deniedForever,

  /// No fix in time or the plugin failed.
  unavailable,
}

/// A position (lat, lng) or why there is none.
class LocateResult {
  final (double, double)? position;
  final LocateFailure? failure;
  const LocateResult.at(double lat, double lng)
      : position = (lat, lng),
        failure = null;
  const LocateResult.failed(LocateFailure this.failure) : position = null;
}

abstract class LocationSource {
  /// Checks the service, asks for the permission if needed and gets a fix.
  Future<LocateResult> locate();

  /// Position updates (lat, lng) while listened to; only after [locate]
  /// succeeded.
  Stream<(double, double)> watch();

  Future<void> openAppSettings();
  Future<void> openLocationSettings();
}

class GeolocatorSource implements LocationSource {
  const GeolocatorSource();

  @override
  Future<LocateResult> locate() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        return const LocateResult.failed(LocateFailure.serviceDisabled);
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) permission = await Geolocator.requestPermission();
      switch (permission) {
        case LocationPermission.denied:
          return const LocateResult.failed(LocateFailure.denied);
        case LocationPermission.deniedForever:
          return const LocateResult.failed(LocateFailure.deniedForever);
        default:
      }
      // A recent known position answers instantly; the fresh fix follows
      // through [watch].
      final p = await Geolocator.getLastKnownPosition() ??
          await Geolocator.getCurrentPosition(
            locationSettings: const LocationSettings(timeLimit: Duration(seconds: 20)),
          );
      return LocateResult.at(p.latitude, p.longitude);
    } catch (_) {
      return const LocateResult.failed(LocateFailure.unavailable);
    }
  }

  @override
  Stream<(double, double)> watch() => Geolocator.getPositionStream(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: 15),
      ).map((p) => (p.latitude, p.longitude)).handleError((_) {});

  @override
  Future<void> openAppSettings() => Geolocator.openAppSettings();

  @override
  Future<void> openLocationSettings() => Geolocator.openLocationSettings();
}

final locationSourceProvider = Provider<LocationSource>((ref) => const GeolocatorSource());
