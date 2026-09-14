enum ActivityType { run, ride, stretch, strength }

extension ActivityTypeLabel on ActivityType {
  String get label {
    switch (this) {
      case ActivityType.run:
        return '跑步';
      case ActivityType.ride:
        return '骑行';
      case ActivityType.stretch:
        return '拉伸';
      case ActivityType.strength:
        return '力量';
    }
  }

  String get icon {
    switch (this) {
      case ActivityType.run:
        return '🏃';
      case ActivityType.ride:
        return '🚴';
      case ActivityType.stretch:
        return '🧘';
      case ActivityType.strength:
        return '💪';
    }
  }

  bool get usesLocation =>
      this == ActivityType.run || this == ActivityType.ride;
}

class WorkoutRecord {
  WorkoutRecord({
    required this.id,
    required this.activity,
    required this.startedAt,
    required this.duration,
    required this.distanceMeters,
    this.sourceDevice = 'iPhone',
  });

  final String id;
  final ActivityType activity;
  final DateTime startedAt;
  final Duration duration;
  final double distanceMeters;
  final String sourceDevice;

  String get distanceLabel => activity.usesLocation
      ? '${(distanceMeters / 1000).toStringAsFixed(2)} km'
      : '室内训练';
}

class RouteSummary {
  RouteSummary(
      {required this.id,
      required this.name,
      required this.distanceMeters,
      this.isSaved = false});

  final String id;
  final String name;
  final double distanceMeters;
  final bool isSaved;

  String get distanceLabel =>
      '${(distanceMeters / 1000).toStringAsFixed(1)} km';
}

class SleepSummary {
  const SleepSummary({required this.duration, required this.quality});

  final Duration duration;
  final String quality;
}
