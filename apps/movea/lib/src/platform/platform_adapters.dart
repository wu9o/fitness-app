import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart' hide ActivityType;
import 'package:geolocator_apple/geolocator_apple.dart' as geo_apple;
import 'package:movea_data/movea_data.dart';
import 'package:movea_domain/movea_domain.dart';

/// Flutter-facing contracts. Native implementations will be registered per platform.
/// Apple Watch uses a separate watchOS target and Watch Connectivity bridge.
class UnsupportedHealthRepository implements HealthRepository {
  @override
  Future<HealthSnapshot> readSnapshot() async => HealthSnapshot.demo;
}

class UnsupportedDeviceWorkoutRepository implements DeviceWorkoutRepository {
  @override
  Future<List<WorkoutRecord>> readRecentWorkouts({int days = 30}) async =>
      const [];
}

/// Health bridge used by Apple platforms today and Health Connect later on
/// Android. The UI only consumes the shared [HealthSnapshot] model; a missing
/// native bridge remains an explicit demo state instead of silently mixing
/// placeholder values with device data.
class PlatformHealthRepository implements HealthRepository {
  static const _channel = MethodChannel('movea/health');

  @override
  Future<HealthSnapshot> readSnapshot() async {
    try {
      final raw = await _channel.invokeMethod<Map<dynamic, dynamic>>(
        'readHealthSnapshot',
      );
      if (raw == null) return HealthSnapshot.demo;
      return _decodeSnapshot(Map<String, dynamic>.from(raw));
    } on MissingPluginException {
      return HealthSnapshot.demo;
    } on PlatformException catch (error) {
      // Authorization is intentionally non-fatal during this phase. The
      // health screen will keep showing a clearly labelled demo state until
      // the user grants access in the system dialog.
      if (error.code == 'unavailable' || error.code == 'authorizationDenied') {
        return HealthSnapshot.demo;
      }
      rethrow;
    }
  }

  static HealthSnapshot _decodeSnapshot(Map<String, dynamic> json) {
    final source = switch (json['source'] as String?) {
      'healthKit' => HealthDataSource.healthKit,
      'healthConnect' => HealthDataSource.healthConnect,
      'manual' => HealthDataSource.manual,
      _ => HealthDataSource.demo,
    };
    final sleepJson = json['sleep'] is Map
        ? Map<String, dynamic>.from(json['sleep'] as Map)
        : const <String, dynamic>{};
    final segments = (sleepJson['segments'] as List<dynamic>? ?? const [])
        .whereType<Map>()
        .map((value) => SleepSegment(
              startMinute: (value['startMinute'] as num?)?.toInt() ?? 0,
              endMinute: (value['endMinute'] as num?)?.toInt() ?? 0,
              stage: _decodeSleepStage(value['stage'] as String?),
            ))
        .where((segment) => segment.endMinute > segment.startMinute)
        .toList(growable: false);
    return HealthSnapshot(
      sleep: SleepSummary(
        duration: Duration(
          minutes: (sleepJson['durationMinutes'] as num?)?.toInt() ?? 0,
        ),
        quality: sleepJson['quality'] as String? ?? '暂无数据',
        bedtime: sleepJson['bedtime'] as String? ?? '--:--',
        wakeTime: sleepJson['wakeTime'] as String? ?? '--:--',
        awakeMinutes: (sleepJson['awakeMinutes'] as num?)?.toInt() ?? 0,
        deepMinutes: (sleepJson['deepMinutes'] as num?)?.toInt() ?? 0,
        remMinutes: (sleepJson['remMinutes'] as num?)?.toInt() ?? 0,
        segments: segments,
      ),
      weightKg: (json['weightKg'] as num?)?.toDouble() ?? 0,
      weightChangeKg: (json['weightChangeKg'] as num?)?.toDouble() ?? 0,
      restingHeartRate: (json['restingHeartRate'] as num?)?.toInt() ?? 0,
      steps: (json['steps'] as num?)?.toInt() ?? 0,
      source: source,
      lastSyncedAt: DateTime.tryParse(json['lastSyncedAt'] as String? ?? ''),
    );
  }

  static SleepStage _decodeSleepStage(String? value) {
    switch (value) {
      case 'awake':
        return SleepStage.awake;
      case 'rem':
        return SleepStage.rem;
      case 'deep':
        return SleepStage.deep;
      default:
        return SleepStage.core;
    }
  }
}

class PlatformDeviceWorkoutRepository implements DeviceWorkoutRepository {
  static const _channel = MethodChannel('movea/health');

  @override
  Future<List<WorkoutRecord>> readRecentWorkouts({int days = 30}) async {
    try {
      final raw = await _channel.invokeListMethod<dynamic>(
        'readRecentWorkouts',
        {'days': days},
      );
      return (raw ?? const [])
          .whereType<Map>()
          .map((value) => _decodeWorkout(Map<String, dynamic>.from(value)))
          .whereType<WorkoutRecord>()
          .toList(growable: false);
    } on MissingPluginException {
      return const [];
    }
  }

  static WorkoutRecord? _decodeWorkout(Map<String, dynamic> json) {
    final sourceId = json['sourceWorkoutId'] as String?;
    final startedAt = DateTime.tryParse(json['startedAt'] as String? ?? '');
    final activity = switch (json['activity'] as String?) {
      'run' => ActivityType.run,
      'ride' => ActivityType.ride,
      'stretch' => ActivityType.stretch,
      'strength' => ActivityType.strength,
      _ => null,
    };
    if (sourceId == null || startedAt == null || activity == null) return null;
    return WorkoutRecord(
      id: 'healthkit-$sourceId',
      activity: activity,
      startedAt: startedAt,
      duration: Duration(
        seconds: (json['durationSeconds'] as num?)?.round() ?? 0,
      ),
      distanceMeters: (json['distanceMeters'] as num?)?.toDouble() ?? 0,
      sourceDevice: json['sourceDevice'] as String? ?? 'Apple 健康',
      dataSource: WorkoutDataSource.healthKit,
      sourceWorkoutId: sourceId,
      averageHeartRateBpm: (json['averageHeartRateBpm'] as num?)?.toDouble(),
      maximumHeartRateBpm: (json['maximumHeartRateBpm'] as num?)?.toDouble(),
      activeEnergyKilocalories:
          (json['activeEnergyKilocalories'] as num?)?.toDouble(),
      heartRateSamples: (json['heartRateSamples'] as List<dynamic>? ?? const [])
          .whereType<Map>()
          .map((value) => Map<String, dynamic>.from(value))
          .map(
            (value) => HeartRateSample(
              offset: Duration(
                milliseconds:
                    (value['offsetMilliseconds'] as num?)?.toInt() ?? 0,
              ),
              bpm: (value['bpm'] as num?)?.toDouble() ?? 0,
            ),
          )
          .where((sample) => sample.bpm > 0)
          .toList(growable: false),
    );
  }
}

class UnsupportedLocationRepository implements LocationRepository {
  @override
  int get rejectedSampleCount => 0;

  @override
  void resetRejectedSampleCount() {}

  @override
  Stream<LocationPoint> get points => const Stream.empty();

  @override
  Future<void> start() async {}

  @override
  Future<void> stop() async {}
}

/// Deterministic location source for simulator and widget tests.
///
/// The replay never invents distance or pace. Tests provide timestamped
/// [LocationPoint] samples, then call [emitNext] or [emitAll] after the
/// activity session has started. This exercises the same stream consumed by
/// [ActivityPage] as the geolocator adapter, while keeping the test clock and
/// route data fully reproducible.
class ReplayLocationRepository implements LocationRepository {
  ReplayLocationRepository({required Iterable<LocationPoint> samples})
      : _samples = List.unmodifiable(samples);

  final List<LocationPoint> _samples;
  final StreamController<LocationPoint> _points =
      StreamController<LocationPoint>.broadcast();
  bool _started = false;
  int _nextIndex = 0;

  @override
  int get rejectedSampleCount => 0;

  @override
  void resetRejectedSampleCount() {}

  @override
  Stream<LocationPoint> get points => _points.stream;

  @override
  Future<void> start() async {
    _started = true;
    _nextIndex = 0;
  }

  /// Emits one sample from the fixture and returns whether a sample was sent.
  bool emitNext() {
    if (!_started || _nextIndex >= _samples.length) return false;
    _points.add(_samples[_nextIndex++]);
    return true;
  }

  /// Emits the remaining fixture samples in their original order.
  void emitAll() {
    while (emitNext()) {
      // The test controls stream delivery with WidgetTester.pump.
    }
  }

  @override
  Future<void> stop() async {
    _started = false;
  }

  Future<void> dispose() async {
    await stop();
    await _points.close();
  }
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
  int _rejectedSampleCount = 0;

  @override
  int get rejectedSampleCount => _rejectedSampleCount;

  @override
  void resetRejectedSampleCount() => _rejectedSampleCount = 0;

  @override
  Stream<LocationPoint> get points => _points.stream;

  LocationSettings get _settings {
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      return geo_apple.AppleSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        activityType: geo_apple.ActivityType.fitness,
        distanceFilter: 5,
        pauseLocationUpdatesAutomatically: false,
        showBackgroundLocationIndicator: true,
        allowBackgroundLocationUpdates: true,
      );
    }
    return const LocationSettings(
      accuracy: LocationAccuracy.bestForNavigation,
      distanceFilter: 5,
    );
  }

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
    if (position.accuracy.isFinite && position.accuracy > 80) {
      _rejectedSampleCount++;
      return;
    }
    final point = LocationPoint(
      latitude: position.latitude,
      longitude: position.longitude,
      timestamp: position.timestamp,
      accuracy: position.accuracy,
      speedMetersPerSecond: position.speed.isFinite && position.speed >= 0
          ? position.speed
          : null,
      altitudeMeters: position.altitude.isFinite ? position.altitude : null,
    );
    // iOS Simulator and a cold GPS can briefly report Null Island before a
    // usable fix arrives. Letting that sample into a track would make every
    // following real point look like an impossible multi-thousand-kilometre
    // jump and permanently poison route guidance.
    if (!point.hasUsableCoordinate) {
      _rejectedSampleCount++;
      return;
    }
    _points.add(point);
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
