import 'dart:async';

import 'package:geolocator/geolocator.dart';
import 'package:movea_data/movea_data.dart';
import 'package:movea_domain/movea_domain.dart';

/// Flutter-facing contracts. Native implementations will be registered per platform.
/// Apple Watch uses a separate watchOS target and Watch Connectivity bridge.
class UnsupportedHealthRepository implements HealthRepository {
  @override
  Future<SleepSummary> readSleep() async => const SleepSummary(
      duration: Duration(hours: 7, minutes: 32), quality: '不错');
}

class UnsupportedLocationRepository implements LocationRepository {
  @override
  Stream<LocationPoint> get points => const Stream.empty();

  @override
  Future<void> start() async {}

  @override
  Future<void> stop() async {}
}

/// Foreground GPS adapter for outdoor workouts.
///
/// The repository emits individual accepted samples instead of exposing the
/// geolocation plugin to the UI. That lets the activity screen own the active
/// track and pause/finish semantics while this adapter owns permissions,
/// service availability and sampling quality.
class GeolocatorLocationRepository implements LocationRepository {
  final StreamController<LocationPoint> _points =
      StreamController<LocationPoint>.broadcast();
  StreamSubscription<Position>? _subscription;

  @override
  Stream<LocationPoint> get points => _points.stream;

  LocationSettings get _settings => const LocationSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 5,
      );

  @override
  Future<void> start() async {
    await stop();

    if (!await Geolocator.isLocationServiceEnabled()) {
      throw StateError('请先打开系统定位服务');
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever ||
        permission == LocationPermission.unableToDetermine) {
      throw StateError('需要定位权限才能记录运动轨迹');
    }

    final current = await Geolocator.getCurrentPosition(
      locationSettings: _settings,
    );
    _emit(current);
    _subscription = Geolocator.getPositionStream(
      locationSettings: _settings,
    ).listen(_emit);
  }

  void _emit(Position position) {
    // Low-quality samples can create visibly false jumps in a running track.
    if (position.accuracy.isFinite && position.accuracy > 80) return;
    _points.add(LocationPoint(
      latitude: position.latitude,
      longitude: position.longitude,
      timestamp: position.timestamp,
      accuracy: position.accuracy,
      speedMetersPerSecond: position.speed.isFinite && position.speed >= 0
          ? position.speed
          : null,
      altitudeMeters: position.altitude.isFinite ? position.altitude : null,
    ));
  }

  @override
  Future<void> stop() async {
    await _subscription?.cancel();
    _subscription = null;
  }

  Future<void> dispose() async {
    await stop();
    await _points.close();
  }
}
