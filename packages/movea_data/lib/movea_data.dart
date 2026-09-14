import 'package:flutter/foundation.dart';
import 'package:movea_domain/movea_domain.dart';

class WorkoutStore extends ChangeNotifier {
  final List<WorkoutRecord> _records = [];

  List<WorkoutRecord> get records => List.unmodifiable(_records);

  void add(WorkoutRecord record) {
    _records.insert(0, record);
    notifyListeners();
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
