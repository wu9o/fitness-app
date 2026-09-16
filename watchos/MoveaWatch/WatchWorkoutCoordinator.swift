import Combine
import Foundation
import HealthKit
import WatchConnectivity

enum WatchActivity: String, CaseIterable, Identifiable {
    case run
    case ride
    case strength

    var id: String { rawValue }

    var title: String {
        switch self {
        case .run: return "户外跑"
        case .ride: return "户外骑行"
        case .strength: return "力量训练"
        }
    }

    var icon: String {
        switch self {
        case .run: return "figure.run"
        case .ride: return "bicycle"
        case .strength: return "dumbbell.fill"
        }
    }

    var healthKitType: HKWorkoutActivityType {
        switch self {
        case .run: return .running
        case .ride: return .cycling
        case .strength: return .traditionalStrengthTraining
        }
    }

    var locationType: HKWorkoutSessionLocationType {
        self == .strength ? .indoor : .outdoor
    }
}

@MainActor
final class WatchWorkoutCoordinator: NSObject, ObservableObject {
    @Published private(set) var isRunning = false
    @Published private(set) var isPaused = false
    @Published private(set) var isStarting = false
    @Published private(set) var elapsed: TimeInterval = 0
    @Published private(set) var heartRate: Double?
    @Published private(set) var averageHeartRate: Double?
    @Published private(set) var maximumHeartRate: Double?
    @Published private(set) var distanceMeters: Double = 0
    @Published private(set) var activeEnergyKilocalories: Double = 0
    @Published private(set) var errorMessage: String?
    @Published var selectedActivity: WatchActivity = .run

    private let healthStore: HKHealthStore
    private let connectivity: WCSession?
    private var workoutSession: HKWorkoutSession?
    private var workoutBuilder: HKLiveWorkoutBuilder?
    private var startedAt: Date?
    private var timer: Timer?

    init(
        healthStore: HKHealthStore = HKHealthStore(),
        connectivity: WCSession? = WCSession.isSupported() ? .default : nil
    ) {
        self.healthStore = healthStore
        self.connectivity = connectivity
        super.init()
        connectivity?.delegate = self
        connectivity?.activate()
    }

    var activityTitle: String { selectedActivity.title }

    var elapsedLabel: String {
        let total = Int(elapsed)
        if total >= 3600 {
            return String(
                format: "%02d:%02d:%02d",
                total / 3600,
                (total / 60) % 60,
                total % 60
            )
        }
        return String(format: "%02d:%02d", total / 60, total % 60)
    }

    var distanceLabel: String {
        String(format: "%.2f km", distanceMeters / 1_000)
    }

    var heartRateLabel: String {
        heartRate.map { "\(Int($0.rounded())) bpm" } ?? "-- bpm"
    }

    func startSelectedWorkout() {
        guard !isRunning, !isStarting else { return }
        isStarting = true
        errorMessage = nil
        Task {
            do {
                try await requestAuthorization()
                try startWorkout(activity: selectedActivity)
            } catch {
                isStarting = false
                errorMessage = error.localizedDescription
            }
        }
    }

    func pause() {
        guard isRunning, !isPaused else { return }
        workoutSession?.pause()
    }

    func resume() {
        guard isRunning, isPaused else { return }
        workoutSession?.resume()
    }

    func finish() {
        guard isRunning else { return }
        workoutSession?.end()
    }

    func dismissError() {
        errorMessage = nil
    }

    private func requestAuthorization() async throws {
        guard HKHealthStore.isHealthDataAvailable() else {
            throw WatchWorkoutError.healthDataUnavailable
        }
        let workout = HKObjectType.workoutType()
        let quantityTypes = [
            HKQuantityType.quantityType(forIdentifier: .heartRate),
            HKQuantityType.quantityType(forIdentifier: .distanceWalkingRunning),
            HKQuantityType.quantityType(forIdentifier: .distanceCycling),
            HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned),
        ].compactMap { $0 }
        let read = Set<HKObjectType>(quantityTypes + [workout])
        let share = Set<HKSampleType>(quantityTypes + [workout])
        try await healthStore.requestAuthorization(toShare: share, read: read)
    }

    private func startWorkout(activity: WatchActivity) throws {
        let configuration = HKWorkoutConfiguration()
        configuration.activityType = activity.healthKitType
        configuration.locationType = activity.locationType

        let session = try HKWorkoutSession(
            healthStore: healthStore,
            configuration: configuration
        )
        let builder = session.associatedWorkoutBuilder()
        builder.dataSource = HKLiveWorkoutDataSource(
            healthStore: healthStore,
            workoutConfiguration: configuration
        )
        session.delegate = self
        builder.delegate = self
        workoutSession = session
        workoutBuilder = builder

        let start = Date()
        startedAt = start
        heartRate = nil
        averageHeartRate = nil
        maximumHeartRate = nil
        distanceMeters = 0
        activeEnergyKilocalories = 0
        elapsed = 0
        session.startActivity(with: start)
        builder.beginCollection(withStart: start) { [weak self] success, error in
            Task { @MainActor in
                guard let self else { return }
                self.isStarting = false
                if !success {
                    self.errorMessage = error?.localizedDescription
                        ?? WatchWorkoutError.collectionFailed.localizedDescription
                    self.resetSession()
                    return
                }
                self.isRunning = true
                self.isPaused = false
                self.startTimer()
            }
        }
    }

    private func startTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) {
            [weak self] _ in
            Task { @MainActor [weak self] in
                self?.updateElapsed()
            }
        }
    }

    private func updateElapsed() {
        guard !isPaused else { return }
        if let workoutBuilder {
            elapsed = workoutBuilder.elapsedTime(at: Date())
        } else if let startedAt {
            elapsed = Date().timeIntervalSince(startedAt)
        }
    }

    private func updateStatistics(
        for types: Set<HKSampleType>,
        builder: HKLiveWorkoutBuilder
    ) {
        for sampleType in types {
            guard let quantityType = sampleType as? HKQuantityType,
                  let statistics = builder.statistics(for: quantityType)
            else { continue }
            switch quantityType.identifier {
            case HKQuantityTypeIdentifier.heartRate.rawValue:
                let unit = HKUnit.count().unitDivided(by: .minute())
                heartRate = statistics.mostRecentQuantity()?.doubleValue(for: unit)
                averageHeartRate = statistics.averageQuantity()?.doubleValue(for: unit)
                maximumHeartRate = statistics.maximumQuantity()?.doubleValue(for: unit)
            case HKQuantityTypeIdentifier.distanceWalkingRunning.rawValue,
                 HKQuantityTypeIdentifier.distanceCycling.rawValue:
                distanceMeters = statistics.sumQuantity()?.doubleValue(
                    for: .meter()
                ) ?? distanceMeters
            case HKQuantityTypeIdentifier.activeEnergyBurned.rawValue:
                activeEnergyKilocalories = statistics.sumQuantity()?.doubleValue(
                    for: .kilocalorie()
                ) ?? activeEnergyKilocalories
            default:
                break
            }
        }
    }

    private func completeWorkout(at end: Date) {
        guard let builder = workoutBuilder else {
            resetSession()
            return
        }
        builder.endCollection(withEnd: end) { [weak self] success, error in
            guard success else {
                Task { @MainActor in
                    self?.errorMessage = error?.localizedDescription
                        ?? WatchWorkoutError.collectionFailed.localizedDescription
                    self?.resetSession()
                }
                return
            }
            builder.finishWorkout { [weak self] workout, error in
                Task { @MainActor in
                    guard let self else { return }
                    if let error {
                        self.errorMessage = error.localizedDescription
                    } else if let workout {
                        self.queueSummary(workout)
                    }
                    self.resetSession()
                }
            }
        }
    }

    private func queueSummary(_ workout: HKWorkout) {
        guard let connectivity,
              connectivity.activationState == .activated
        else { return }
        var summary: [String: Any] = [
            "kind": "movea.workout.v1",
            "sourceWorkoutId": workout.uuid.uuidString,
            "activity": selectedActivity.rawValue,
            "startedAt": ISO8601DateFormatter().string(from: workout.startDate),
            "endedAt": ISO8601DateFormatter().string(from: workout.endDate),
            "durationSeconds": workout.duration,
            "distanceMeters": distanceMeters,
            "activeEnergyKilocalories": activeEnergyKilocalories,
            "sourceDevice": "Apple Watch",
        ]
        if let averageHeartRate, averageHeartRate > 0 {
            summary["averageHeartRateBpm"] = averageHeartRate
        }
        if let maximumHeartRate, maximumHeartRate > 0 {
            summary["maximumHeartRateBpm"] = maximumHeartRate
        }
        connectivity.transferUserInfo(summary)
    }

    private func resetSession() {
        timer?.invalidate()
        timer = nil
        workoutSession = nil
        workoutBuilder = nil
        startedAt = nil
        isStarting = false
        isRunning = false
        isPaused = false
    }
}

extension WatchWorkoutCoordinator: HKWorkoutSessionDelegate {
    nonisolated func workoutSession(
        _ workoutSession: HKWorkoutSession,
        didChangeTo toState: HKWorkoutSessionState,
        from fromState: HKWorkoutSessionState,
        date: Date
    ) {
        Task { @MainActor in
            switch toState {
            case .running:
                isRunning = true
                isPaused = false
            case .paused:
                isPaused = true
            case .ended:
                completeWorkout(at: date)
            default:
                break
            }
        }
    }

    nonisolated func workoutSession(
        _ workoutSession: HKWorkoutSession,
        didFailWithError error: Error
    ) {
        Task { @MainActor in
            errorMessage = error.localizedDescription
            resetSession()
        }
    }
}

extension WatchWorkoutCoordinator: HKLiveWorkoutBuilderDelegate {
    nonisolated func workoutBuilderDidCollectEvent(
        _ workoutBuilder: HKLiveWorkoutBuilder
    ) {}

    nonisolated func workoutBuilder(
        _ workoutBuilder: HKLiveWorkoutBuilder,
        didCollectDataOf collectedTypes: Set<HKSampleType>
    ) {
        Task { @MainActor in
            updateStatistics(for: collectedTypes, builder: workoutBuilder)
        }
    }
}

extension WatchWorkoutCoordinator: WCSessionDelegate {
    nonisolated func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        guard let error else { return }
        Task { @MainActor in
            errorMessage = "Watch 通信不可用：\(error.localizedDescription)"
        }
    }
}

private enum WatchWorkoutError: LocalizedError {
    case healthDataUnavailable
    case collectionFailed

    var errorDescription: String? {
        switch self {
        case .healthDataUnavailable:
            return "这台设备无法使用健康数据"
        case .collectionFailed:
            return "无法开始采集运动数据"
        }
    }
}
