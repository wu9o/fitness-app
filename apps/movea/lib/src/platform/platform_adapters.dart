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
  Stream<List<({double latitude, double longitude})>> get points =>
      const Stream.empty();

  @override
  Future<void> start() async {}

  @override
  Future<void> stop() async {}
}
