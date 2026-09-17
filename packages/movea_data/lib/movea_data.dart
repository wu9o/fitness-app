import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:movea_domain/movea_domain.dart';
import 'package:shared_preferences/shared_preferences.dart';

export 'src/encrypted_backup.dart';

/// Version envelope for JSON-backed local records.
///
/// Older preview builds stored route, plan and active-workout payloads as raw
/// JSON arrays/maps. [decode] intentionally accepts that legacy shape, while
/// every new write uses an explicit schema version so future migrations can be
/// staged without guessing which fields a payload contains.
class MoveaLocalJsonCodec {
  const MoveaLocalJsonCodec._();

  static const currentSchemaVersion = 1;

  static String encode(Object value) =>
      jsonEncode({'schemaVersion': currentSchemaVersion, 'data': value});

  static dynamic decode(String payload) {
    final decoded = jsonDecode(payload);
    if (decoded is! Map || !decoded.containsKey('schemaVersion')) {
      return decoded;
    }
    final version = (decoded['schemaVersion'] as num?)?.toInt();
    if (version != currentSchemaVersion) {
      throw FormatException('unsupported local schema: $version');
    }
    return decoded['data'];
  }
}

abstract interface class WorkoutPersistence {
  Future<List<WorkoutRecord>> read();
  Future<void> write(List<WorkoutRecord> records);
}

enum WorkoutDataIntegrityStatus { empty, healthy, recoverable, corrupt }

class WorkoutDataIntegrityReport {
  const WorkoutDataIntegrityReport({
    required this.status,
    required this.primaryRecordCount,
    required this.invalidPrimaryRecordCount,
    required this.recoveryRecordCount,
  });

  final WorkoutDataIntegrityStatus status;
  final int primaryRecordCount;
  final int invalidPrimaryRecordCount;
  final int recoveryRecordCount;

  bool get canRecover => status == WorkoutDataIntegrityStatus.recoverable;
}

class WorkoutArchiveDecodeResult {
  const WorkoutArchiveDecodeResult({
    required this.isValid,
    required this.records,
    this.error,
  });

  final bool isValid;
  final List<WorkoutRecord> records;
  final String? error;
}

class WorkoutArchiveCodec {
  const WorkoutArchiveCodec();

  static const schemaVersion = 1;

  String encode(List<WorkoutRecord> records, {DateTime? createdAt}) {
    final payload = jsonEncode({
      'schemaVersion': schemaVersion,
      'records': records
          .map(SharedPreferencesWorkoutPersistence._encodeRecord)
          .toList(growable: false),
    });
    return jsonEncode({
      'schemaVersion': schemaVersion,
      'createdAt': (createdAt ?? DateTime.now()).toUtc().toIso8601String(),
      'checksum': sha256.convert(utf8.encode(payload)).toString(),
      'payload': base64Encode(utf8.encode(payload)),
    });
  }

  WorkoutArchiveDecodeResult decode(String? archive) {
    if (archive == null || archive.isEmpty) {
      return const WorkoutArchiveDecodeResult(
        isValid: false,
        records: [],
        error: 'missing archive',
      );
    }
    try {
      final envelope = jsonDecode(archive) as Map<String, dynamic>;
      if (envelope['schemaVersion'] != schemaVersion) {
        return const WorkoutArchiveDecodeResult(
          isValid: false,
          records: [],
          error: 'unsupported schema',
        );
      }
      final payload = utf8.decode(base64Decode(envelope['payload'] as String));
      final checksum = sha256.convert(utf8.encode(payload)).toString();
      if (checksum != envelope['checksum']) {
        return const WorkoutArchiveDecodeResult(
          isValid: false,
          records: [],
          error: 'checksum mismatch',
        );
      }
      final decoded = jsonDecode(payload) as Map<String, dynamic>;
      final rawRecords = decoded['records'] as List<dynamic>? ?? const [];
      final records = rawRecords
          .whereType<Map>()
          .map((value) => jsonEncode(Map<String, dynamic>.from(value)))
          .map(SharedPreferencesWorkoutPersistence._decodeRecord)
          .whereType<WorkoutRecord>()
          .toList(growable: false);
      if (records.length != rawRecords.length) {
        return const WorkoutArchiveDecodeResult(
          isValid: false,
          records: [],
          error: 'invalid record payload',
        );
      }
      return WorkoutArchiveDecodeResult(isValid: true, records: records);
    } on Object {
      return const WorkoutArchiveDecodeResult(
        isValid: false,
        records: [],
        error: 'malformed archive',
      );
    }
  }
}

abstract interface class WorkoutRecoveryPersistence {
  Future<WorkoutDataIntegrityReport> inspectIntegrity();
  Future<List<WorkoutRecord>?> readRecoverySnapshot();
}

class SharedPreferencesWorkoutPersistence
    implements WorkoutPersistence, WorkoutRecoveryPersistence {
  static const storageKey = 'movea.workouts.v1';
  static const recoveryKey = 'movea.workouts.recovery.v1';
  static const _archiveCodec = WorkoutArchiveCodec();

  @override
  Future<List<WorkoutRecord>> read() async {
    final preferences = await SharedPreferences.getInstance();
    final payloads = preferences.getStringList(storageKey) ?? const [];
    final records = payloads
        .map(_decodeRecord)
        .whereType<WorkoutRecord>()
        .toList(growable: false);
    if (records.length == payloads.length) return records;
    final recovery = _archiveCodec.decode(preferences.getString(recoveryKey));
    return recovery.isValid ? recovery.records : records;
  }

  @override
  Future<void> write(List<WorkoutRecord> records) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setStringList(
      storageKey,
      records.map((record) => jsonEncode(_encodeRecord(record))).toList(),
    );
    await preferences.setString(recoveryKey, _archiveCodec.encode(records));
  }

  @override
  Future<WorkoutDataIntegrityReport> inspectIntegrity() async {
    final preferences = await SharedPreferences.getInstance();
    final payloads = preferences.getStringList(storageKey) ?? const [];
    final validPrimary = payloads.map(_decodeRecord).whereType<WorkoutRecord>();
    final validPrimaryCount = validPrimary.length;
    final invalidCount = payloads.length - validPrimaryCount;
    final recovery = _archiveCodec.decode(preferences.getString(recoveryKey));
    final status =
        payloads.isEmpty && (!recovery.isValid || recovery.records.isEmpty)
        ? WorkoutDataIntegrityStatus.empty
        : invalidCount == 0
        ? WorkoutDataIntegrityStatus.healthy
        : recovery.isValid
        ? WorkoutDataIntegrityStatus.recoverable
        : WorkoutDataIntegrityStatus.corrupt;
    return WorkoutDataIntegrityReport(
      status: status,
      primaryRecordCount: validPrimaryCount,
      invalidPrimaryRecordCount: invalidCount,
      recoveryRecordCount: recovery.isValid ? recovery.records.length : 0,
    );
  }

  @override
  Future<List<WorkoutRecord>?> readRecoverySnapshot() async {
    final preferences = await SharedPreferences.getInstance();
    final result = _archiveCodec.decode(preferences.getString(recoveryKey));
    return result.isValid ? result.records : null;
  }

  static Map<String, dynamic> _encodeRecord(WorkoutRecord record) => {
    'id': record.id,
    'activity': record.activity.name,
    'startedAt': record.startedAt.toIso8601String(),
    'durationSeconds': record.duration.inSeconds,
    'distanceMeters': record.distanceMeters,
    'routePoints': record.routePoints.map(_encodePoint).toList(growable: false),
    'sourceDevice': record.sourceDevice,
    if (record.trainingPlanId != null) 'trainingPlanId': record.trainingPlanId,
    'completedActions': record.completedActions,
    'plannedActions': record.plannedActions,
    'discardedLocationSamples': record.discardedLocationSamples,
    if (record.perceivedEffort != null)
      'perceivedEffort': record.perceivedEffort!.name,
    'dataSource': record.dataSource.name,
    if (record.sourceWorkoutId != null)
      'sourceWorkoutId': record.sourceWorkoutId,
    if (record.averageHeartRateBpm != null)
      'averageHeartRateBpm': record.averageHeartRateBpm,
    if (record.maximumHeartRateBpm != null)
      'maximumHeartRateBpm': record.maximumHeartRateBpm,
    if (record.activeEnergyKilocalories != null)
      'activeEnergyKilocalories': record.activeEnergyKilocalories,
    if (record.heartRateSamples.isNotEmpty)
      'heartRateSamples': record.heartRateSamples
          .map(
            (sample) => {
              'offsetMilliseconds': sample.offset.inMilliseconds,
              'bpm': sample.bpm,
            },
          )
          .toList(growable: false),
  };

  static Map<String, dynamic> _encodePoint(LocationPoint point) => {
    'latitude': point.latitude,
    'longitude': point.longitude,
    if (point.timestamp != null)
      'timestamp': point.timestamp!.toIso8601String(),
    if (point.accuracy != null) 'accuracy': point.accuracy,
    if (point.speedMetersPerSecond != null)
      'speedMetersPerSecond': point.speedMetersPerSecond,
    if (point.altitudeMeters != null) 'altitudeMeters': point.altitudeMeters,
  };

  static LocationPoint? _decodePoint(dynamic value) {
    if (value is! Map<String, dynamic>) return null;
    final latitude = (value['latitude'] as num?)?.toDouble();
    final longitude = (value['longitude'] as num?)?.toDouble();
    if (latitude == null || longitude == null) return null;
    return LocationPoint(
      latitude: latitude,
      longitude: longitude,
      timestamp: DateTime.tryParse(value['timestamp'] as String? ?? ''),
      accuracy: (value['accuracy'] as num?)?.toDouble(),
      speedMetersPerSecond: (value['speedMetersPerSecond'] as num?)?.toDouble(),
      altitudeMeters: (value['altitudeMeters'] as num?)?.toDouble(),
    );
  }

  static WorkoutRecord? _decodeRecord(String payload) {
    try {
      final json = jsonDecode(payload) as Map<String, dynamic>;
      final activityName = json['activity'] as String? ?? 'run';
      final activity = ActivityType.values.firstWhere(
        (type) => type.name == activityName,
        orElse: () => ActivityType.run,
      );
      final effortName = json['perceivedEffort'] as String?;
      WorkoutEffort? perceivedEffort;
      for (final effort in WorkoutEffort.values) {
        if (effort.name == effortName) perceivedEffort = effort;
      }
      final dataSourceName = json['dataSource'] as String?;
      final dataSource = WorkoutDataSource.values.firstWhere(
        (source) => source.name == dataSourceName,
        orElse: () => WorkoutDataSource.localGps,
      );
      return WorkoutRecord(
        id:
            json['id'] as String? ??
            DateTime.now().microsecondsSinceEpoch.toString(),
        activity: activity,
        startedAt: DateTime.parse(json['startedAt'] as String),
        duration: Duration(
          seconds: (json['durationSeconds'] as num?)?.toInt() ?? 0,
        ),
        distanceMeters: (json['distanceMeters'] as num?)?.toDouble() ?? 0,
        routePoints: (json['routePoints'] as List<dynamic>? ?? const [])
            .map(_decodePoint)
            .whereType<LocationPoint>()
            .toList(growable: false),
        sourceDevice: json['sourceDevice'] as String? ?? 'iPhone',
        trainingPlanId: json['trainingPlanId'] as String?,
        completedActions: (json['completedActions'] as num?)?.toInt() ?? 0,
        plannedActions: (json['plannedActions'] as num?)?.toInt() ?? 0,
        discardedLocationSamples:
            (json['discardedLocationSamples'] as num?)?.toInt() ?? 0,
        perceivedEffort: perceivedEffort,
        dataSource: dataSource,
        sourceWorkoutId: json['sourceWorkoutId'] as String?,
        averageHeartRateBpm: (json['averageHeartRateBpm'] as num?)?.toDouble(),
        maximumHeartRateBpm: (json['maximumHeartRateBpm'] as num?)?.toDouble(),
        activeEnergyKilocalories: (json['activeEnergyKilocalories'] as num?)
            ?.toDouble(),
        heartRateSamples:
            (json['heartRateSamples'] as List<dynamic>? ?? const [])
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
    } on Object {
      return null;
    }
  }
}

class WorkoutStore extends ChangeNotifier {
  WorkoutStore({WorkoutPersistence? persistence})
    : _persistence = persistence ?? SharedPreferencesWorkoutPersistence();

  final WorkoutPersistence _persistence;
  final List<WorkoutRecord> _records = [];
  bool _isRestored = false;

  List<WorkoutRecord> get records => List.unmodifiable(_records);
  bool get isRestored => _isRestored;

  int get recordCount => _records.length;

  double get outdoorDistanceMeters => _records
      .where((record) => record.activity.usesLocation)
      .fold(0, (total, record) => total + record.distanceMeters);

  void add(WorkoutRecord record) {
    _records.insert(0, record);
    notifyListeners();
    if (_isRestored) unawaited(_persistence.write(_records));
  }

  Future<void> addAndPersist(WorkoutRecord record) async {
    if (!_isRestored) await restore();
    if (_records.every((item) => item.id != record.id)) {
      _records.insert(0, record);
      notifyListeners();
    }
    await _persistence.write(_records);
  }

  Future<int> importAndPersist(Iterable<WorkoutRecord> records) async {
    if (!_isRestored) await restore();
    var changed = 0;
    for (final record in records) {
      final sourceId = record.sourceWorkoutId;
      final existingIndex = _records.indexWhere(
        (item) =>
            item.id == record.id ||
            (sourceId != null && item.sourceWorkoutId == sourceId),
      );
      if (existingIndex >= 0) {
        final existing = _records[existingIndex];
        if (!_deviceWorkoutChanged(existing, record)) continue;
        _records[existingIndex] = record.copyWith(
          perceivedEffort: existing.perceivedEffort,
        );
        changed++;
        continue;
      }
      _records.add(record);
      changed++;
    }
    if (changed > 0) {
      _records.sort((a, b) => b.startedAt.compareTo(a.startedAt));
      notifyListeners();
      await _persistence.write(_records);
    }
    return changed;
  }

  bool _deviceWorkoutChanged(WorkoutRecord current, WorkoutRecord incoming) =>
      current.startedAt != incoming.startedAt ||
      current.duration != incoming.duration ||
      current.distanceMeters != incoming.distanceMeters ||
      current.sourceDevice != incoming.sourceDevice ||
      current.averageHeartRateBpm != incoming.averageHeartRateBpm ||
      current.maximumHeartRateBpm != incoming.maximumHeartRateBpm ||
      current.activeEnergyKilocalories != incoming.activeEnergyKilocalories ||
      current.heartRateSamples.length != incoming.heartRateSamples.length;

  Future<void> updateAndPersist(WorkoutRecord record) async {
    if (!_isRestored) await restore();
    final index = _records.indexWhere((item) => item.id == record.id);
    if (index < 0) return;
    _records[index] = record;
    notifyListeners();
    await _persistence.write(_records);
  }

  Future<void> restore() async {
    if (_isRestored) return;
    final hadLocalRecords = _records.isNotEmpty;
    final records = await _persistence.read();
    final localIds = _records.map((record) => record.id).toSet();
    _records..addAll(records.where((record) => !localIds.contains(record.id)));
    _isRestored = true;
    notifyListeners();
    if (hadLocalRecords) await _persistence.write(_records);
  }

  Future<WorkoutDataIntegrityReport> inspectIntegrity() async {
    final persistence = _persistence;
    if (persistence is WorkoutRecoveryPersistence) {
      return (persistence as WorkoutRecoveryPersistence).inspectIntegrity();
    }
    return WorkoutDataIntegrityReport(
      status: _records.isEmpty
          ? WorkoutDataIntegrityStatus.empty
          : WorkoutDataIntegrityStatus.healthy,
      primaryRecordCount: _records.length,
      invalidPrimaryRecordCount: 0,
      recoveryRecordCount: 0,
    );
  }

  Future<bool> repairFromRecoverySnapshot() async {
    final persistence = _persistence;
    if (persistence is! WorkoutRecoveryPersistence) return false;
    final recovered = await (persistence as WorkoutRecoveryPersistence)
        .readRecoverySnapshot();
    if (recovered == null) return false;
    _records
      ..clear()
      ..addAll(recovered);
    _isRestored = true;
    notifyListeners();
    await _persistence.write(_records);
    return true;
  }

  Future<void> refreshRecoverySnapshot() async {
    if (!_isRestored) await restore();
    await _persistence.write(_records);
  }
}

abstract interface class TrainingProfilePersistence {
  Future<TrainingProfile> read();
  Future<void> write(TrainingProfile profile);
}

class SharedPreferencesTrainingProfilePersistence
    implements TrainingProfilePersistence {
  static const storageKey = 'movea.training_profile.v1';

  @override
  Future<TrainingProfile> read() async {
    final preferences = await SharedPreferences.getInstance();
    final maximum = preferences.getInt(storageKey);
    if (maximum == null || maximum < 100 || maximum > 240) {
      return const TrainingProfile();
    }
    return TrainingProfile(maximumHeartRateBpm: maximum);
  }

  @override
  Future<void> write(TrainingProfile profile) async {
    final preferences = await SharedPreferences.getInstance();
    final maximum = profile.maximumHeartRateBpm;
    if (maximum == null) {
      await preferences.remove(storageKey);
    } else {
      await preferences.setInt(storageKey, maximum);
    }
  }
}

class TrainingProfileStore extends ChangeNotifier {
  TrainingProfileStore({TrainingProfilePersistence? persistence})
    : _persistence =
          persistence ?? SharedPreferencesTrainingProfilePersistence();

  final TrainingProfilePersistence _persistence;
  TrainingProfile _profile = const TrainingProfile();
  bool _isRestored = false;

  TrainingProfile get profile => _profile;
  bool get isRestored => _isRestored;

  Future<void> restore({bool force = false}) async {
    if (_isRestored && !force) return;
    _profile = await _persistence.read();
    _isRestored = true;
    notifyListeners();
  }

  Future<void> setMaximumHeartRate(int? bpm) async {
    if (bpm != null && (bpm < 100 || bpm > 240)) {
      throw ArgumentError.value(bpm, 'bpm', 'must be between 100 and 240');
    }
    _profile = bpm == null
        ? _profile.copyWith(clearMaximum: true)
        : _profile.copyWith(maximumHeartRateBpm: bpm);
    _isRestored = true;
    notifyListeners();
    await _persistence.write(_profile);
  }
}

class RouteGuidancePreferences {
  const RouteGuidancePreferences({
    this.hapticsEnabled = true,
    this.voiceEnabled = false,
  });

  final bool hapticsEnabled;
  final bool voiceEnabled;
}

abstract interface class RouteGuidancePreferencesPersistence {
  Future<RouteGuidancePreferences> read();
  Future<void> write(RouteGuidancePreferences preferences);
}

class SharedPreferencesRouteGuidancePreferencesPersistence
    implements RouteGuidancePreferencesPersistence {
  static const hapticsKey = 'movea.route_guidance.haptics.v1';
  static const voiceKey = 'movea.route_guidance.voice.v1';

  @override
  Future<RouteGuidancePreferences> read() async {
    final preferences = await SharedPreferences.getInstance();
    return RouteGuidancePreferences(
      hapticsEnabled: preferences.getBool(hapticsKey) ?? true,
      voiceEnabled: preferences.getBool(voiceKey) ?? false,
    );
  }

  @override
  Future<void> write(RouteGuidancePreferences value) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(hapticsKey, value.hapticsEnabled);
    await preferences.setBool(voiceKey, value.voiceEnabled);
  }
}

class RouteGuidancePreferencesStore extends ChangeNotifier {
  RouteGuidancePreferencesStore({
    RouteGuidancePreferencesPersistence? persistence,
  }) : _persistence =
           persistence ??
           SharedPreferencesRouteGuidancePreferencesPersistence();

  final RouteGuidancePreferencesPersistence _persistence;
  RouteGuidancePreferences _preferences = const RouteGuidancePreferences();
  bool _isRestored = false;

  RouteGuidancePreferences get preferences => _preferences;
  bool get isRestored => _isRestored;

  Future<void> restore({bool force = false}) async {
    if (_isRestored && !force) return;
    _preferences = await _persistence.read();
    _isRestored = true;
    notifyListeners();
  }

  Future<void> setHapticsEnabled(bool enabled) async {
    _preferences = RouteGuidancePreferences(
      hapticsEnabled: enabled,
      voiceEnabled: _preferences.voiceEnabled,
    );
    _isRestored = true;
    notifyListeners();
    await _persistence.write(_preferences);
  }

  Future<void> setVoiceEnabled(bool enabled) async {
    _preferences = RouteGuidancePreferences(
      hapticsEnabled: _preferences.hapticsEnabled,
      voiceEnabled: enabled,
    );
    _isRestored = true;
    notifyListeners();
    await _persistence.write(_preferences);
  }
}

abstract interface class ActiveWorkoutPersistence {
  Future<ActiveWorkoutDraft?> read();
  Future<void> write(ActiveWorkoutDraft draft);
  Future<void> clear();
}

class SharedPreferencesActiveWorkoutPersistence
    implements ActiveWorkoutPersistence {
  static const storageKey = 'movea.activeWorkout.v1';

  @override
  Future<ActiveWorkoutDraft?> read() async {
    final preferences = await SharedPreferences.getInstance();
    final payload = preferences.getString(storageKey);
    if (payload == null) return null;
    try {
      final json = Map<String, dynamic>.from(
        MoveaLocalJsonCodec.decode(payload) as Map,
      );
      final activityName = json['activity'] as String? ?? 'run';
      final activity = ActivityType.values.firstWhere(
        (type) => type.name == activityName,
        orElse: () => ActivityType.run,
      );
      return ActiveWorkoutDraft(
        activity: activity,
        startedAt: DateTime.parse(json['startedAt'] as String),
        updatedAt: DateTime.parse(json['updatedAt'] as String),
        pausedAt: DateTime.tryParse(json['pausedAt'] as String? ?? ''),
        pausedDuration: Duration(
          seconds: (json['pausedDurationSeconds'] as num?)?.toInt() ?? 0,
        ),
        distanceMeters: (json['distanceMeters'] as num?)?.toDouble() ?? 0,
        routeId: json['routeId'] as String?,
        discardedLocationSamples:
            (json['discardedLocationSamples'] as num?)?.toInt() ?? 0,
        routePoints: (json['routePoints'] as List<dynamic>? ?? const [])
            .map(SharedPreferencesWorkoutPersistence._decodePoint)
            .whereType<LocationPoint>()
            .toList(growable: false),
      );
    } on Object {
      return null;
    }
  }

  @override
  Future<void> write(ActiveWorkoutDraft draft) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      storageKey,
      MoveaLocalJsonCodec.encode({
        'activity': draft.activity.name,
        'startedAt': draft.startedAt.toIso8601String(),
        'updatedAt': draft.updatedAt.toIso8601String(),
        if (draft.pausedAt != null)
          'pausedAt': draft.pausedAt!.toIso8601String(),
        'pausedDurationSeconds': draft.pausedDuration.inSeconds,
        'distanceMeters': draft.distanceMeters,
        if (draft.routeId != null) 'routeId': draft.routeId,
        'discardedLocationSamples': draft.discardedLocationSamples,
        'routePoints': draft.routePoints
            .map(SharedPreferencesWorkoutPersistence._encodePoint)
            .toList(growable: false),
      }),
    );
  }

  @override
  Future<void> clear() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(storageKey);
  }
}

class ActiveWorkoutStore extends ChangeNotifier {
  ActiveWorkoutStore({ActiveWorkoutPersistence? persistence})
    : _persistence = persistence ?? SharedPreferencesActiveWorkoutPersistence();

  final ActiveWorkoutPersistence _persistence;
  ActiveWorkoutDraft? _draft;
  bool _isRestored = false;
  Future<void> _pendingMutation = Future<void>.value();
  int _mutationGeneration = 0;

  ActiveWorkoutDraft? get draft => _draft;
  bool get isRestored => _isRestored;

  Future<void> restore() async {
    if (_isRestored) return;
    _draft = await _persistence.read();
    _isRestored = true;
    notifyListeners();
  }

  Future<void> save(ActiveWorkoutDraft draft) async {
    _draft = draft;
    _isRestored = true;
    notifyListeners();
    final generation = ++_mutationGeneration;
    final operation = _pendingMutation.then((_) async {
      // GPS samples may arrive much faster than SharedPreferences can write.
      // Only the newest queued draft needs to reach disk.
      if (generation != _mutationGeneration || _draft == null) return;
      await _persistence.write(draft);
    });
    _pendingMutation = operation.then<void>(
      (_) {},
      onError: (Object _, StackTrace __) {},
    );
    await operation;
  }

  Future<void> clear() async {
    _draft = null;
    _isRestored = true;
    notifyListeners();
    ++_mutationGeneration;
    final operation = _pendingMutation.then((_) => _persistence.clear());
    _pendingMutation = operation.then<void>(
      (_) {},
      onError: (Object _, StackTrace __) {},
    );
    await operation;
  }
}

abstract interface class RoutePersistence {
  Future<List<RouteSummary>> read();
  Future<void> write(List<RouteSummary> routes);
}

class SharedPreferencesRoutePersistence implements RoutePersistence {
  static const storageKey = 'movea.routes.v1';

  @override
  Future<List<RouteSummary>> read() async {
    final preferences = await SharedPreferences.getInstance();
    final payload = preferences.getString(storageKey);
    if (payload == null) return const [];
    try {
      final decoded = MoveaLocalJsonCodec.decode(payload) as List<dynamic>;
      return decoded
          .whereType<Map<String, dynamic>>()
          .map(_decodeRoute)
          .whereType<RouteSummary>()
          .toList(growable: false);
    } on Object {
      return const [];
    }
  }

  @override
  Future<void> write(List<RouteSummary> routes) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      storageKey,
      MoveaLocalJsonCodec.encode(
        routes.map(_encodeRoute).toList(growable: false),
      ),
    );
  }

  static Map<String, dynamic> _encodeRoute(RouteSummary route) => {
    'id': route.id,
    'name': route.name,
    'distanceMeters': route.distanceMeters,
    'isSaved': route.isSaved,
    'estimatedMinutes': route.estimatedMinutes,
    'elevationMeters': route.elevationMeters,
    'tags': route.tags,
    'points': route.points
        .map(SharedPreferencesWorkoutPersistence._encodePoint)
        .toList(growable: false),
  };

  static RouteSummary? _decodeRoute(Map<String, dynamic> json) {
    try {
      return RouteSummary(
        id: json['id'] as String,
        name: json['name'] as String,
        distanceMeters: (json['distanceMeters'] as num).toDouble(),
        isSaved: json['isSaved'] as bool? ?? false,
        estimatedMinutes: (json['estimatedMinutes'] as num?)?.toInt() ?? 30,
        elevationMeters: (json['elevationMeters'] as num?)?.toInt() ?? 0,
        tags: (json['tags'] as List<dynamic>? ?? const [])
            .whereType<String>()
            .toList(growable: false),
        points: (json['points'] as List<dynamic>? ?? const [])
            .map(SharedPreferencesWorkoutPersistence._decodePoint)
            .whereType<LocationPoint>()
            .toList(growable: false),
      );
    } on Object {
      return null;
    }
  }
}

class RouteStore extends ChangeNotifier {
  RouteStore({RoutePersistence? persistence})
    : _persistence = persistence ?? SharedPreferencesRoutePersistence() {
    _routes.addAll(defaultRoutes());
  }

  final RoutePersistence _persistence;
  final List<RouteSummary> _routes = [];
  bool _isRestored = false;
  Future<void>? _restoreFuture;

  List<RouteSummary> get routes => List.unmodifiable(_routes);
  bool get isRestored => _isRestored;

  Future<void> restore() => _restoreFuture ??= _restoreInternal();

  Future<void> _restoreInternal() async {
    if (_isRestored) return;
    final saved = await _persistence.read();
    final localRoutes = List<RouteSummary>.of(_routes);
    final localById = {for (final route in localRoutes) route.id: route};
    final normalizedSaved = saved
        .map((route) {
          final fallback = localById[route.id];
          return route.points.isEmpty && fallback != null
              ? route.copyWith(points: fallback.points)
              : route;
        })
        .toList(growable: false);
    final savedIds = normalizedSaved.map((route) => route.id).toSet();
    _routes
      ..clear()
      ..addAll(
        normalizedSaved.isEmpty
            ? localRoutes
            : [
                ...normalizedSaved,
                ...localRoutes.where((route) => !savedIds.contains(route.id)),
              ],
      );
    _isRestored = true;
    notifyListeners();
    unawaited(_persistence.write(_routes));
  }

  Future<void> toggleSaved(String id) async {
    final index = _routes.indexWhere((route) => route.id == id);
    if (index == -1) return;
    _routes[index] = _routes[index].copyWith(isSaved: !_routes[index].isSaved);
    notifyListeners();
    if (_isRestored) {
      await _persistence.write(_routes);
    } else {
      unawaited(restore().then((_) => _persistence.write(_routes)));
    }
  }

  /// Inserts or replaces a route created by the user, then persists it.
  ///
  /// Restoring first is important here: a just-created route must not be
  /// overwritten by an older snapshot that is still being loaded.
  Future<void> save(RouteSummary route) async {
    if (!_isRestored) await restore();
    final index = _routes.indexWhere((item) => item.id == route.id);
    if (index == -1) {
      _routes.insert(0, route);
    } else {
      _routes[index] = route;
    }
    notifyListeners();
    await _persistence.write(_routes);
  }
}

List<RouteSummary> defaultRoutes() => const [
  RouteSummary(
    id: 'park-loop',
    name: '公园环线',
    distanceMeters: 5200,
    estimatedMinutes: 32,
    elevationMeters: 80,
    tags: ['环线', '简单', '补水点'],
    points: [
      LocationPoint(latitude: 31.2304, longitude: 121.4737),
      LocationPoint(latitude: 31.2322, longitude: 121.4780),
      LocationPoint(latitude: 31.2290, longitude: 121.4835),
      LocationPoint(latitude: 31.2258, longitude: 121.4790),
      LocationPoint(latitude: 31.2244, longitude: 121.4720),
      LocationPoint(latitude: 31.2280, longitude: 121.4705),
      LocationPoint(latitude: 31.2304, longitude: 121.4737),
    ],
  ),
  RouteSummary(
    id: 'river-view',
    name: '河岸风景线',
    distanceMeters: 8100,
    estimatedMinutes: 54,
    elevationMeters: 120,
    tags: ['风景', '中等', '长距离'],
    points: [
      LocationPoint(latitude: 31.2288, longitude: 121.4690),
      LocationPoint(latitude: 31.2340, longitude: 121.4655),
      LocationPoint(latitude: 31.2390, longitude: 121.4700),
      LocationPoint(latitude: 31.2415, longitude: 121.4780),
      LocationPoint(latitude: 31.2360, longitude: 121.4850),
      LocationPoint(latitude: 31.2295, longitude: 121.4825),
      LocationPoint(latitude: 31.2288, longitude: 121.4690),
    ],
  ),
];

abstract interface class TrainingPlanPersistence {
  Future<List<TrainingPlan>> read();
  Future<void> write(List<TrainingPlan> plans);
}

class SharedPreferencesTrainingPlanPersistence
    implements TrainingPlanPersistence {
  static const storageKey = 'movea.training_plans.v1';

  @override
  Future<List<TrainingPlan>> read() async {
    final preferences = await SharedPreferences.getInstance();
    final payload = preferences.getString(storageKey);
    if (payload == null) return const [];
    try {
      final decoded = MoveaLocalJsonCodec.decode(payload) as List<dynamic>;
      return decoded
          .whereType<Map<String, dynamic>>()
          .map(_decodePlan)
          .whereType<TrainingPlan>()
          .toList(growable: false);
    } on Object {
      return const [];
    }
  }

  @override
  Future<void> write(List<TrainingPlan> plans) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      storageKey,
      MoveaLocalJsonCodec.encode(
        plans.map(_encodePlan).toList(growable: false),
      ),
    );
  }

  static Map<String, dynamic> _encodePlan(TrainingPlan plan) => {
    'id': plan.id,
    'name': plan.name,
    'description': plan.description,
    'rounds': plan.rounds,
    'restBetweenRoundsSeconds': plan.restBetweenRoundsSeconds,
    'difficulty': plan.difficulty,
    'lastUsedAt': plan.lastUsedAt?.toIso8601String(),
    'scheduledWeekdays': plan.scheduledWeekdays,
    'actions': plan.actions
        .map(
          (action) => {
            'id': action.id,
            if (action.exerciseId != null) 'exerciseId': action.exerciseId,
            'name': action.name,
            'muscle': action.muscle,
            'workSeconds': action.workSeconds,
            'restSeconds': action.restSeconds,
          },
        )
        .toList(growable: false),
  };

  static TrainingPlan? _decodePlan(Map<String, dynamic> json) {
    try {
      final actions = (json['actions'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(
            (action) => TrainingAction(
              id: action['id'] as String,
              exerciseId: action['exerciseId'] as String?,
              name: action['name'] as String,
              muscle: action['muscle'] as String,
              workSeconds: (action['workSeconds'] as num).toInt(),
              restSeconds: (action['restSeconds'] as num).toInt(),
            ),
          )
          .toList(growable: false);
      return TrainingPlan(
        id: json['id'] as String,
        name: json['name'] as String,
        description: json['description'] as String,
        rounds: (json['rounds'] as num).toInt(),
        restBetweenRoundsSeconds: (json['restBetweenRoundsSeconds'] as num)
            .toInt(),
        difficulty: json['difficulty'] as String,
        actions: actions,
        lastUsedAt: json['lastUsedAt'] == null
            ? null
            : DateTime.parse(json['lastUsedAt'] as String),
        scheduledWeekdays:
            (json['scheduledWeekdays'] as List<dynamic>? ?? const [])
                .whereType<num>()
                .map((day) => day.toInt())
                .where((day) => day >= 1 && day <= 7)
                .toSet()
                .toList()
              ..sort(),
      );
    } on Object {
      return null;
    }
  }
}

class TrainingPlanStore extends ChangeNotifier {
  TrainingPlanStore({TrainingPlanPersistence? persistence})
    : _persistence = persistence ?? SharedPreferencesTrainingPlanPersistence() {
    _plans.addAll(defaultTrainingPlans());
  }

  final TrainingPlanPersistence _persistence;
  final List<TrainingPlan> _plans = [];
  bool _isRestored = false;
  Future<void>? _restoreFuture;

  List<TrainingPlan> get plans => List.unmodifiable(_plans);
  bool get isRestored => _isRestored;

  Future<void> restore() => _restoreFuture ??= _restoreInternal();

  Future<void> _restoreInternal() async {
    if (_isRestored) return;
    final saved = await _persistence.read();
    final localPlans = List<TrainingPlan>.of(_plans);
    final savedIds = saved.map((plan) => plan.id).toSet();
    _plans
      ..clear()
      ..addAll(
        saved.isEmpty
            ? localPlans
            : [
                ...saved,
                ...localPlans.where((plan) => !savedIds.contains(plan.id)),
              ],
      );
    _isRestored = true;
    notifyListeners();
    unawaited(_persistence.write(_plans));
  }

  Future<void> save(TrainingPlan plan) async {
    final index = _plans.indexWhere((item) => item.id == plan.id);
    if (index == -1) {
      _plans.insert(0, plan);
    } else {
      _plans[index] = plan;
    }
    notifyListeners();
    if (_isRestored) {
      await _persistence.write(_plans);
    } else {
      unawaited(restore().then((_) => _persistence.write(_plans)));
    }
  }

  Future<void> delete(String id) async {
    _plans.removeWhere((plan) => plan.id == id);
    notifyListeners();
    if (_isRestored) {
      await _persistence.write(_plans);
    } else {
      unawaited(restore().then((_) => _persistence.write(_plans)));
    }
  }

  Future<void> markUsed(TrainingPlan plan) async {
    await save(plan.copyWith(lastUsedAt: DateTime.now()));
  }
}

abstract interface class HealthRepository {
  Future<HealthSnapshot> readSnapshot();
}

abstract interface class DeviceWorkoutRepository {
  Future<List<WorkoutRecord>> readRecentWorkouts({int days = 30});
}

/// Owns health loading state so every surface can render the same source
/// status. A repository may later be backed by HealthKit, Health Connect, or
/// local manual entries without changing the screens.
class HealthStore extends ChangeNotifier {
  HealthStore({required HealthRepository repository})
    : _repository = repository;

  final HealthRepository _repository;
  HealthSnapshot _snapshot = HealthSnapshot.demo;
  bool _isLoading = true;
  Object? _error;

  HealthSnapshot get snapshot => _snapshot;
  bool get isLoading => _isLoading;
  Object? get error => _error;

  Future<void> restore() async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      _snapshot = await _repository.readSnapshot();
    } on Object catch (error) {
      _error = error;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> refresh() => restore();
}

abstract interface class LocationRepository {
  Stream<LocationPoint> get points;
  int get rejectedSampleCount;
  void resetRejectedSampleCount();
  Future<void> start();
  Future<void> stop();
}

abstract interface class BackupRepository {
  Future<void> uploadEncryptedBackup(List<WorkoutRecord> records);
}
