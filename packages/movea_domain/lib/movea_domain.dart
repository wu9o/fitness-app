import 'dart:math' as math;

enum ActivityType { run, ride, stretch, strength }

enum WorkoutEffort { easy, moderate, hard, maximum }

extension WorkoutEffortLabel on WorkoutEffort {
  String get label {
    switch (this) {
      case WorkoutEffort.easy:
        return '轻松';
      case WorkoutEffort.moderate:
        return '适中';
      case WorkoutEffort.hard:
        return '吃力';
      case WorkoutEffort.maximum:
        return '极限';
    }
  }

  int get score {
    switch (this) {
      case WorkoutEffort.easy:
        return 2;
      case WorkoutEffort.moderate:
        return 4;
      case WorkoutEffort.hard:
        return 7;
      case WorkoutEffort.maximum:
        return 9;
    }
  }
}

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
    this.routePoints = const [],
    this.sourceDevice = 'iPhone',
    this.trainingPlanId,
    this.completedActions = 0,
    this.plannedActions = 0,
    this.discardedLocationSamples = 0,
    this.perceivedEffort,
  });

  final String id;
  final ActivityType activity;
  final DateTime startedAt;
  final Duration duration;
  final double distanceMeters;
  final List<LocationPoint> routePoints;
  final String sourceDevice;
  final String? trainingPlanId;
  final int completedActions;
  final int plannedActions;
  final int discardedLocationSamples;
  final WorkoutEffort? perceivedEffort;

  bool get isTrainingPlanRecord => trainingPlanId != null;

  double get planCompletion {
    if (plannedActions <= 0) return 0;
    return (completedActions / plannedActions).clamp(0, 1).toDouble();
  }

  String get distanceLabel => activity.usesLocation
      ? '${(distanceMeters / 1000).toStringAsFixed(2)} km'
      : '室内训练';

  double get averageSpeedMetersPerSecond {
    final seconds = duration.inMilliseconds / 1000;
    return seconds > 0 ? distanceMeters / seconds : 0;
  }

  double get elevationGainMeters {
    var gain = 0.0;
    for (var index = 1; index < routePoints.length; index++) {
      final previous = routePoints[index - 1].altitudeMeters;
      final current = routePoints[index].altitudeMeters;
      if (previous == null || current == null) continue;
      final delta = current - previous;
      // Ignore isolated altitude spikes from consumer GPS sensors.
      if (delta > 0 && delta < 100) gain += delta;
    }
    return gain;
  }

  double get averageAccuracyMeters {
    final samples = routePoints
        .map((point) => point.accuracy)
        .whereType<double>()
        .where((accuracy) => accuracy.isFinite && accuracy > 0)
        .toList(growable: false);
    if (samples.isEmpty) return 0;
    return samples.reduce((total, value) => total + value) / samples.length;
  }

  String get gpsQualityLabel {
    if (!activity.usesLocation || routePoints.length < 2) return '无轨迹';
    final accuracy = averageAccuracyMeters;
    if (accuracy == 0) return '未提供精度';
    if (accuracy <= 10) return '优秀';
    if (accuracy <= 25) return '良好';
    if (accuracy <= 50) return '一般';
    return '较差';
  }

  int? get subjectiveTrainingLoad {
    final effort = perceivedEffort;
    if (effort == null) return null;
    final activeMinutes = duration.inMilliseconds <= 0
        ? 0
        : math.max(1, (duration.inMilliseconds / 60000).ceil());
    return activeMinutes * effort.score;
  }

  WorkoutRecord copyWith({WorkoutEffort? perceivedEffort}) => WorkoutRecord(
        id: id,
        activity: activity,
        startedAt: startedAt,
        duration: duration,
        distanceMeters: distanceMeters,
        routePoints: routePoints,
        sourceDevice: sourceDevice,
        trainingPlanId: trainingPlanId,
        completedActions: completedActions,
        plannedActions: plannedActions,
        discardedLocationSamples: discardedLocationSamples,
        perceivedEffort: perceivedEffort ?? this.perceivedEffort,
      );
}

/// Recoverable snapshot of a workout that has started but has not finished.
///
/// This is intentionally separate from [WorkoutRecord]: drafts can be updated
/// frequently and are only promoted to permanent history after the user ends
/// the workout.
class ActiveWorkoutDraft {
  const ActiveWorkoutDraft({
    required this.activity,
    required this.startedAt,
    required this.updatedAt,
    required this.pausedDuration,
    required this.distanceMeters,
    this.pausedAt,
    this.routeId,
    this.routePoints = const [],
    this.discardedLocationSamples = 0,
  });

  final ActivityType activity;
  final DateTime startedAt;
  final DateTime updatedAt;
  final DateTime? pausedAt;
  final Duration pausedDuration;
  final double distanceMeters;
  final String? routeId;
  final List<LocationPoint> routePoints;
  final int discardedLocationSamples;

  bool get isPaused => pausedAt != null;

  /// Elapsed active time represented by the saved snapshot. When an app is
  /// relaunched, time after [updatedAt] is not counted automatically.
  Duration get savedElapsed {
    final activeEnd = pausedAt ?? updatedAt;
    final value = activeEnd.difference(startedAt) - pausedDuration;
    return value.isNegative ? Duration.zero : value;
  }
}

/// A location sample captured during an outdoor workout.
///
/// Route plans also reuse this value object, with [timestamp] and [accuracy]
/// omitted. Keeping the same shape means a recorded track can be persisted
/// and rendered by every client without coupling the domain to a map SDK.
class LocationPoint {
  const LocationPoint({
    required this.latitude,
    required this.longitude,
    this.timestamp,
    this.accuracy,
    this.speedMetersPerSecond,
    this.altitudeMeters,
  });

  final double latitude;
  final double longitude;
  final DateTime? timestamp;
  final double? accuracy;
  final double? speedMetersPerSecond;
  final double? altitudeMeters;

  bool get hasUsableCoordinate =>
      latitude.isFinite &&
      longitude.isFinite &&
      latitude >= -90 &&
      latitude <= 90 &&
      longitude >= -180 &&
      longitude <= 180 &&
      !(latitude.abs() < .0001 && longitude.abs() < .0001);
}

enum RouteManeuver { straight, left, right, arrive }

/// Navigation-friendly progress derived from a position and a planned route.
///
/// The calculation stays in the shared domain layer so iPhone, Android and
/// Watch clients can present the same progress and turn hint without depending
/// on a particular map SDK or navigation service.
class RouteGuidance {
  const RouteGuidance({
    required this.distanceToRouteMeters,
    required this.progress,
    required this.remainingMeters,
    required this.distanceToManeuverMeters,
    required this.maneuver,
    required this.segmentIndex,
  });

  final double distanceToRouteMeters;
  final double progress;
  final double remainingMeters;
  final double distanceToManeuverMeters;
  final RouteManeuver maneuver;
  final int segmentIndex;

  bool get isOffRoute => distanceToRouteMeters > 80;
}

/// Projects [current] onto the closest route segment, then finds the next
/// meaningful turn. Small bends are treated as a continuous road so sparse GPS
/// points do not produce noisy left/right instructions.
RouteGuidance calculateRouteGuidance(
  LocationPoint current,
  List<LocationPoint> route,
) {
  if (route.length < 2) {
    return const RouteGuidance(
      distanceToRouteMeters: double.infinity,
      progress: 0,
      remainingMeters: 0,
      distanceToManeuverMeters: 0,
      maneuver: RouteManeuver.arrive,
      segmentIndex: 0,
    );
  }

  const latitudeScale = 111320.0;
  final longitudeScale =
      111320.0 * math.cos(_routeRadians(current.latitude)).abs();
  double xFor(LocationPoint point) =>
      (point.longitude - current.longitude) * longitudeScale;
  double yFor(LocationPoint point) =>
      (point.latitude - current.latitude) * latitudeScale;

  final segmentLengths = <double>[];
  var totalLength = 0.0;
  var distanceAlong = 0.0;
  var closestDistance = double.infinity;
  var closestSegment = 0;
  var closestProjection = 0.0;

  for (var index = 0; index < route.length - 1; index++) {
    final start = route[index];
    final end = route[index + 1];
    final ax = xFor(start);
    final ay = yFor(start);
    final bx = xFor(end);
    final by = yFor(end);
    final dx = bx - ax;
    final dy = by - ay;
    final segmentSquared = dx * dx + dy * dy;
    final segmentLength = _routeDistance(start, end);
    segmentLengths.add(segmentLength);
    final projection =
        segmentSquared == 0 ? 0.0 : ((-ax * dx) + (-ay * dy)) / segmentSquared;
    final t = projection.clamp(0.0, 1.0).toDouble();
    final projectedX = ax + dx * t;
    final projectedY = ay + dy * t;
    final distance = math.sqrt(
      projectedX * projectedX + projectedY * projectedY,
    );
    if (distance < closestDistance) {
      closestDistance = distance;
      closestSegment = index;
      closestProjection = t;
      distanceAlong = totalLength + segmentLength * t;
    }
    totalLength += segmentLength;
  }

  final remaining = math.max(0.0, totalLength - distanceAlong);
  final progress = totalLength == 0 ? 0.0 : distanceAlong / totalLength;
  if (remaining <= 25) {
    return RouteGuidance(
      distanceToRouteMeters: closestDistance,
      progress: progress.clamp(0.0, 1.0),
      remainingMeters: remaining,
      distanceToManeuverMeters: remaining,
      maneuver: RouteManeuver.arrive,
      segmentIndex: closestSegment,
    );
  }

  var distanceToTurn = segmentLengths[closestSegment] * (1 - closestProjection);
  var maneuver = RouteManeuver.straight;
  var maneuverDistance = remaining;
  for (var vertex = closestSegment + 1; vertex < route.length - 1; vertex++) {
    final incoming = _routeBearing(route[vertex - 1], route[vertex]);
    final outgoing = _routeBearing(route[vertex], route[vertex + 1]);
    final delta = _normalizeBearing(outgoing - incoming);
    if (delta.abs() >= 30) {
      maneuver = delta < 0 ? RouteManeuver.left : RouteManeuver.right;
      maneuverDistance = distanceToTurn;
      break;
    }
    distanceToTurn += segmentLengths[vertex];
  }

  return RouteGuidance(
    distanceToRouteMeters: closestDistance,
    progress: progress.clamp(0.0, 1.0),
    remainingMeters: remaining,
    distanceToManeuverMeters: maneuverDistance,
    maneuver: maneuver,
    segmentIndex: closestSegment,
  );
}

double _routeDistance(LocationPoint from, LocationPoint to) {
  const earthRadiusMeters = 6371000.0;
  final latitudeDelta = _routeRadians(to.latitude - from.latitude);
  final longitudeDelta = _routeRadians(to.longitude - from.longitude);
  final fromLatitude = _routeRadians(from.latitude);
  final toLatitude = _routeRadians(to.latitude);
  final haversine = math.sin(latitudeDelta / 2) * math.sin(latitudeDelta / 2) +
      math.cos(fromLatitude) *
          math.cos(toLatitude) *
          math.sin(longitudeDelta / 2) *
          math.sin(longitudeDelta / 2);
  return earthRadiusMeters *
      2 *
      math.atan2(math.sqrt(haversine), math.sqrt(1 - haversine));
}

double _routeBearing(LocationPoint from, LocationPoint to) {
  final fromLatitude = _routeRadians(from.latitude);
  final toLatitude = _routeRadians(to.latitude);
  final longitudeDelta = _routeRadians(to.longitude - from.longitude);
  final y = math.sin(longitudeDelta) * math.cos(toLatitude);
  final x = math.cos(fromLatitude) * math.sin(toLatitude) -
      math.sin(fromLatitude) * math.cos(toLatitude) * math.cos(longitudeDelta);
  return math.atan2(y, x) * 180 / math.pi;
}

double _normalizeBearing(double value) => (value + 540) % 360 - 180;

double _routeRadians(double degrees) => degrees * math.pi / 180;

class RouteSummary {
  const RouteSummary({
    required this.id,
    required this.name,
    required this.distanceMeters,
    this.isSaved = false,
    this.estimatedMinutes = 30,
    this.elevationMeters = 0,
    this.tags = const [],
    this.points = const [],
  });

  final String id;
  final String name;
  final double distanceMeters;
  final bool isSaved;
  final int estimatedMinutes;
  final int elevationMeters;
  final List<String> tags;
  final List<LocationPoint> points;

  String get distanceLabel =>
      '${(distanceMeters / 1000).toStringAsFixed(1)} km';

  RouteSummary copyWith({
    String? id,
    String? name,
    double? distanceMeters,
    bool? isSaved,
    int? estimatedMinutes,
    int? elevationMeters,
    List<String>? tags,
    List<LocationPoint>? points,
  }) {
    return RouteSummary(
      id: id ?? this.id,
      name: name ?? this.name,
      distanceMeters: distanceMeters ?? this.distanceMeters,
      isSaved: isSaved ?? this.isSaved,
      estimatedMinutes: estimatedMinutes ?? this.estimatedMinutes,
      elevationMeters: elevationMeters ?? this.elevationMeters,
      tags: tags ?? this.tags,
      points: points ?? this.points,
    );
  }
}

enum SleepStage { awake, rem, core, deep }

extension SleepStageLabel on SleepStage {
  String get label {
    switch (this) {
      case SleepStage.awake:
        return '清醒';
      case SleepStage.rem:
        return '快速眼动';
      case SleepStage.core:
        return '核心睡眠';
      case SleepStage.deep:
        return '深度睡眠';
    }
  }
}

class SleepSegment {
  const SleepSegment({
    required this.startMinute,
    required this.endMinute,
    required this.stage,
  });

  final int startMinute;
  final int endMinute;
  final SleepStage stage;

  int get durationMinutes => endMinute - startMinute;
}

class SleepSummary {
  const SleepSummary({
    required this.duration,
    required this.quality,
    this.bedtime = '23:18',
    this.wakeTime = '06:50',
    this.awakeMinutes = 28,
    this.deepMinutes = 78,
    this.remMinutes = 102,
    this.segments = const [],
  });

  final Duration duration;
  final String quality;
  final String bedtime;
  final String wakeTime;
  final int awakeMinutes;
  final int deepMinutes;
  final int remMinutes;
  final List<SleepSegment> segments;
}

/// Where a health snapshot came from. Keeping this in the shared domain model
/// prevents the UI from presenting demo values as if they were device data.
enum HealthDataSource { demo, healthKit, healthConnect, manual }

extension HealthDataSourceLabel on HealthDataSource {
  String get label {
    switch (this) {
      case HealthDataSource.demo:
        return '演示数据';
      case HealthDataSource.healthKit:
        return 'HealthKit';
      case HealthDataSource.healthConnect:
        return 'Health Connect';
      case HealthDataSource.manual:
        return '手动记录';
    }
  }
}

class HealthSnapshot {
  const HealthSnapshot({
    required this.sleep,
    required this.weightKg,
    required this.weightChangeKg,
    required this.restingHeartRate,
    required this.steps,
    this.source = HealthDataSource.demo,
    this.lastSyncedAt,
  });

  final SleepSummary sleep;
  final double weightKg;
  final double weightChangeKg;
  final int restingHeartRate;
  final int steps;
  final HealthDataSource source;
  final DateTime? lastSyncedAt;

  bool get isDeviceSynced =>
      source == HealthDataSource.healthKit ||
      source == HealthDataSource.healthConnect;

  String get sourceLabel => source.label;

  static const demo = HealthSnapshot(
    sleep: SleepSummary(
      duration: Duration(hours: 7, minutes: 32),
      quality: '不错',
      segments: [
        SleepSegment(startMinute: 0, endMinute: 22, stage: SleepStage.awake),
        SleepSegment(startMinute: 22, endMinute: 76, stage: SleepStage.core),
        SleepSegment(startMinute: 76, endMinute: 118, stage: SleepStage.deep),
        SleepSegment(startMinute: 118, endMinute: 188, stage: SleepStage.core),
        SleepSegment(startMinute: 188, endMinute: 238, stage: SleepStage.rem),
        SleepSegment(startMinute: 238, endMinute: 286, stage: SleepStage.core),
        SleepSegment(startMinute: 286, endMinute: 328, stage: SleepStage.deep),
        SleepSegment(startMinute: 328, endMinute: 392, stage: SleepStage.rem),
        SleepSegment(startMinute: 392, endMinute: 452, stage: SleepStage.core),
      ],
    ),
    weightKg: 68.4,
    weightChangeKg: -0.6,
    restingHeartRate: 58,
    steps: 8240,
  );
}

class ExerciseDefinition {
  const ExerciseDefinition({
    required this.id,
    required this.slug,
    required this.name,
    required this.displayName,
    required this.exerciseType,
    required this.equipment,
    required this.primaryMuscle,
    required this.secondaryMuscles,
    required this.isStretch,
    required this.framePaths,
    required this.steps,
    required this.breathing,
    required this.commonMistakes,
    required this.safety,
    this.easierVariant,
    this.harderVariant,
  });

  final String id;
  final String slug;
  final String name;
  final String displayName;
  final String exerciseType;
  final String equipment;
  final String primaryMuscle;
  final List<String> secondaryMuscles;
  final bool isStretch;
  final List<String> framePaths;
  final List<String> steps;
  final String breathing;
  final List<String> commonMistakes;
  final String safety;
  final String? easierVariant;
  final String? harderVariant;
}

class TrainingAction {
  const TrainingAction({
    required this.id,
    required this.name,
    required this.muscle,
    required this.workSeconds,
    required this.restSeconds,
    this.exerciseId,
  });

  final String id;

  /// Stable reference to the exercise catalog. Legacy plans may omit this
  /// value and use [id] as the catalog identifier instead.
  final String? exerciseId;
  final String name;
  final String muscle;
  final int workSeconds;
  final int restSeconds;

  String get catalogId => exerciseId ?? id;

  TrainingAction copyWith({
    String? id,
    String? exerciseId,
    String? name,
    String? muscle,
    int? workSeconds,
    int? restSeconds,
  }) {
    return TrainingAction(
      id: id ?? this.id,
      exerciseId: exerciseId ?? this.exerciseId,
      name: name ?? this.name,
      muscle: muscle ?? this.muscle,
      workSeconds: workSeconds ?? this.workSeconds,
      restSeconds: restSeconds ?? this.restSeconds,
    );
  }
}

class TrainingPlan {
  const TrainingPlan({
    required this.id,
    required this.name,
    required this.description,
    required this.rounds,
    required this.restBetweenRoundsSeconds,
    required this.difficulty,
    required this.actions,
    this.lastUsedAt,
    this.scheduledWeekdays = const [],
  });

  final String id;
  final String name;
  final String description;
  final int rounds;
  final int restBetweenRoundsSeconds;
  final String difficulty;
  final List<TrainingAction> actions;
  final DateTime? lastUsedAt;

  /// ISO weekday values: 1 = Monday ... 7 = Sunday.
  final List<int> scheduledWeekdays;

  bool isScheduledOn(DateTime date) => scheduledWeekdays.contains(date.weekday);

  String get scheduleLabel {
    if (scheduledWeekdays.isEmpty) return '未排期';
    const labels = ['一', '二', '三', '四', '五', '六', '日'];
    return scheduledWeekdays.map((day) => '周${labels[day - 1]}').join('、');
  }

  int get totalWorkSeconds => actions.fold(
        0,
        (total, action) => total + action.workSeconds + action.restSeconds,
      );

  int get estimatedMinutes {
    final seconds = (totalWorkSeconds * rounds) +
        ((rounds - 1).clamp(0, 99) * restBetweenRoundsSeconds);
    return (seconds / 60).ceil();
  }

  TrainingPlan copyWith({
    String? id,
    String? name,
    String? description,
    int? rounds,
    int? restBetweenRoundsSeconds,
    String? difficulty,
    List<TrainingAction>? actions,
    DateTime? lastUsedAt,
    List<int>? scheduledWeekdays,
  }) {
    return TrainingPlan(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      rounds: rounds ?? this.rounds,
      restBetweenRoundsSeconds:
          restBetweenRoundsSeconds ?? this.restBetweenRoundsSeconds,
      difficulty: difficulty ?? this.difficulty,
      actions: actions ?? this.actions,
      lastUsedAt: lastUsedAt ?? this.lastUsedAt,
      scheduledWeekdays: scheduledWeekdays ?? this.scheduledWeekdays,
    );
  }
}

List<TrainingPlan> defaultTrainingPlans() => [
      const TrainingPlan(
        id: 'morning-activation',
        name: '晨间全身激活',
        description: '适合开始一天的轻量训练。',
        rounds: 2,
        restBetweenRoundsSeconds: 45,
        difficulty: '初级',
        scheduledWeekdays: [1, 3, 5],
        actions: [
          TrainingAction(
            id: 'squat',
            name: '深蹲',
            muscle: '腿部与臀部',
            workSeconds: 40,
            restSeconds: 20,
          ),
          TrainingAction(
            id: 'push-up',
            name: '俯卧撑',
            muscle: '胸部与手臂',
            workSeconds: 30,
            restSeconds: 20,
          ),
          TrainingAction(
            id: 'bird-dog',
            name: '鸟狗式',
            muscle: '核心与稳定',
            workSeconds: 40,
            restSeconds: 20,
          ),
        ],
      ),
      const TrainingPlan(
        id: 'core-stability',
        name: '核心稳定',
        description: '跑步日之外，保持躯干稳定。',
        rounds: 3,
        restBetweenRoundsSeconds: 45,
        difficulty: '初级',
        scheduledWeekdays: [2, 4],
        actions: [
          TrainingAction(
            id: 'plank',
            name: '平板支撑',
            muscle: '核心稳定',
            workSeconds: 40,
            restSeconds: 20,
          ),
          TrainingAction(
            id: 'dead-bug',
            name: '死虫式',
            muscle: '核心控制',
            workSeconds: 40,
            restSeconds: 20,
          ),
          TrainingAction(
            id: 'glute-bridge',
            name: '臀桥',
            muscle: '臀部激活',
            workSeconds: 45,
            restSeconds: 20,
          ),
          TrainingAction(
            id: 'bird-dog-core',
            name: '鸟狗式',
            muscle: '稳定控制',
            workSeconds: 40,
            restSeconds: 20,
          ),
        ],
      ),
      const TrainingPlan(
        id: 'post-run-recovery',
        name: '跑后恢复',
        description: '轻松拉伸，给身体一点恢复时间。',
        rounds: 1,
        restBetweenRoundsSeconds: 20,
        difficulty: '初级',
        scheduledWeekdays: [6],
        actions: [
          TrainingAction(
            id: 'calf-stretch',
            name: '小腿拉伸',
            muscle: '小腿',
            workSeconds: 40,
            restSeconds: 20,
          ),
          TrainingAction(
            id: 'hip-stretch',
            name: '髋部拉伸',
            muscle: '髋部',
            workSeconds: 45,
            restSeconds: 20,
          ),
          TrainingAction(
            id: 'hamstring-stretch',
            name: '腿后侧拉伸',
            muscle: '腿后侧',
            workSeconds: 45,
            restSeconds: 20,
          ),
        ],
      ),
    ];
