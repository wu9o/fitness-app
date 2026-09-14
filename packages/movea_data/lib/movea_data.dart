import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:movea_domain/movea_domain.dart';
import 'package:shared_preferences/shared_preferences.dart';

abstract interface class WorkoutPersistence {
  Future<List<WorkoutRecord>> read();
  Future<void> write(List<WorkoutRecord> records);
}

class SharedPreferencesWorkoutPersistence implements WorkoutPersistence {
  static const storageKey = 'movea.workouts.v1';

  @override
  Future<List<WorkoutRecord>> read() async {
    final preferences = await SharedPreferences.getInstance();
    final payloads = preferences.getStringList(storageKey) ?? const [];
    return payloads
        .map(_decodeRecord)
        .whereType<WorkoutRecord>()
        .toList(growable: false);
  }

  @override
  Future<void> write(List<WorkoutRecord> records) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setStringList(
      storageKey,
      records.map((record) => jsonEncode(_encodeRecord(record))).toList(),
    );
  }

  static Map<String, dynamic> _encodeRecord(WorkoutRecord record) => {
        'id': record.id,
        'activity': record.activity.name,
        'startedAt': record.startedAt.toIso8601String(),
        'durationSeconds': record.duration.inSeconds,
        'distanceMeters': record.distanceMeters,
        'sourceDevice': record.sourceDevice,
      };

  static WorkoutRecord? _decodeRecord(String payload) {
    try {
      final json = jsonDecode(payload) as Map<String, dynamic>;
      final activityName = json['activity'] as String? ?? 'run';
      final activity = ActivityType.values.firstWhere(
        (type) => type.name == activityName,
        orElse: () => ActivityType.run,
      );
      return WorkoutRecord(
        id: json['id'] as String? ??
            DateTime.now().microsecondsSinceEpoch.toString(),
        activity: activity,
        startedAt: DateTime.parse(json['startedAt'] as String),
        duration: Duration(
          seconds: (json['durationSeconds'] as num?)?.toInt() ?? 0,
        ),
        distanceMeters: (json['distanceMeters'] as num?)?.toDouble() ?? 0,
        sourceDevice: json['sourceDevice'] as String? ?? 'iPhone',
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

  Future<void> restore() async {
    if (_isRestored) return;
    final records = await _persistence.read();
    final localIds = _records.map((record) => record.id).toSet();
    _records..addAll(records.where((record) => !localIds.contains(record.id)));
    _isRestored = true;
    notifyListeners();
    await _persistence.write(_records);
  }
}

abstract interface class HealthRepository {
  Future<SleepSummary> readSleep();
}

abstract interface class LocationRepository {
  Stream<List<({double latitude, double longitude})>> get points;
  Future<void> start();
  Future<void> stop();
}

abstract interface class BackupRepository {
  Future<void> uploadEncryptedBackup(List<WorkoutRecord> records);
}
