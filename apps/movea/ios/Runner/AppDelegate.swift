import Flutter
import HealthKit
import UIKit
import WatchConnectivity

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private let healthStore = HKHealthStore()
  private static let watchWorkoutInboxKey = "movea.watch.workoutInbox.v1"

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    if WCSession.isSupported() {
      let session = WCSession.default
      session.delegate = self
      session.activate()
    }
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)

    let healthChannel = FlutterMethodChannel(
      name: "movea/health",
      binaryMessenger: engineBridge.applicationRegistrar.messenger()
    )
    healthChannel.setMethodCallHandler { [weak self] call, result in
      switch call.method {
      case "readHealthSnapshot":
        self?.readHealthSnapshot(result: result)
      case "readRecentWorkouts":
        let arguments = call.arguments as? [String: Any]
        let days = arguments?["days"] as? Int ?? 30
        self?.readRecentWorkouts(days: days, result: result)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  private func readRecentWorkouts(days: Int, result: @escaping FlutterResult) {
    guard HKHealthStore.isHealthDataAvailable() else {
      result(FlutterError(code: "unavailable", message: "HealthKit 在此设备不可用", details: nil))
      return
    }

    let workoutType = HKObjectType.workoutType()
    var readTypes: Set<HKObjectType> = [workoutType]
    let metricTypes = [
      HKObjectType.quantityType(forIdentifier: .heartRate),
      HKObjectType.quantityType(forIdentifier: .activeEnergyBurned),
      HKObjectType.quantityType(forIdentifier: .distanceWalkingRunning),
      HKObjectType.quantityType(forIdentifier: .distanceCycling),
    ].compactMap { $0 }
    readTypes.formUnion(metricTypes)

    healthStore.requestAuthorization(toShare: [], read: readTypes) { [weak self] granted, error in
      guard let self else { return }
      if let error {
        DispatchQueue.main.async {
          result(FlutterError(code: "authorizationDenied", message: error.localizedDescription, details: nil))
        }
        return
      }
      guard granted else {
        DispatchQueue.main.async {
          result(FlutterError(code: "authorizationDenied", message: "未获得运动数据读取授权", details: nil))
        }
        return
      }
      self.queryRecentWorkouts(days: max(1, min(days, 365)), result: result)
    }
  }

  private func queryRecentWorkouts(days: Int, result: @escaping FlutterResult) {
    let start = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date().addingTimeInterval(-2_592_000)
    let predicate = HKQuery.predicateForSamples(withStart: start, end: Date(), options: [])
    let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
    let query = HKSampleQuery(
      sampleType: HKObjectType.workoutType(),
      predicate: predicate,
      limit: 50,
      sortDescriptors: [sort]
    ) { [weak self] _, samples, error in
      guard let self else { return }
      if let error {
        DispatchQueue.main.async {
          result(FlutterError(code: "queryFailed", message: error.localizedDescription, details: nil))
        }
        return
      }
      let workouts = (samples as? [HKWorkout] ?? []).compactMap { workout -> (HKWorkout, [String: Any])? in
        guard let encoded = self.encodeWorkout(workout) else { return nil }
        return (workout, encoded)
      }
      guard !workouts.isEmpty else {
        DispatchQueue.main.async { result([]) }
        return
      }
      let group = DispatchGroup()
      let lock = NSLock()
      var encodedWorkouts: [[String: Any]] = []
      for (workout, base) in workouts {
        group.enter()
        self.readHeartRateSamples(for: workout) { samples in
          var encoded = base
          if !samples.isEmpty { encoded["heartRateSamples"] = samples }
          lock.lock()
          encodedWorkouts.append(encoded)
          lock.unlock()
          group.leave()
        }
      }
      group.notify(queue: .main) {
        encodedWorkouts.sort {
          ($0["startedAt"] as? String ?? "") > ($1["startedAt"] as? String ?? "")
        }
        let healthKitIds = Set(encodedWorkouts.compactMap { $0["sourceWorkoutId"] as? String })
        let pendingWatchWorkouts = self.readWatchWorkoutInbox().filter {
          guard let sourceId = $0["sourceWorkoutId"] as? String else { return false }
          return !healthKitIds.contains(sourceId)
        }
        result((encodedWorkouts + pendingWatchWorkouts).sorted {
          ($0["startedAt"] as? String ?? "") > ($1["startedAt"] as? String ?? "")
        })
      }
    }
    healthStore.execute(query)
  }

  private func readWatchWorkoutInbox() -> [[String: Any]] {
    UserDefaults.standard.array(forKey: Self.watchWorkoutInboxKey) as? [[String: Any]] ?? []
  }

  private func storeWatchWorkout(_ workout: [String: Any]) {
    guard workout["kind"] as? String == "movea.workout.v1",
          let sourceId = workout["sourceWorkoutId"] as? String,
          workout["startedAt"] as? String != nil
    else { return }
    var inbox = readWatchWorkoutInbox()
    inbox.removeAll { $0["sourceWorkoutId"] as? String == sourceId }
    inbox.insert(workout, at: 0)
    if inbox.count > 50 { inbox.removeLast(inbox.count - 50) }
    UserDefaults.standard.set(inbox, forKey: Self.watchWorkoutInboxKey)
  }

  private func readHeartRateSamples(
    for workout: HKWorkout,
    completion: @escaping ([[String: Any]]) -> Void
  ) {
    guard let heartRateType = HKObjectType.quantityType(forIdentifier: .heartRate) else {
      completion([])
      return
    }
    let predicate = HKQuery.predicateForObjects(from: workout)
    let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)
    let query = HKSampleQuery(
      sampleType: heartRateType,
      predicate: predicate,
      limit: 5000,
      sortDescriptors: [sort]
    ) { _, samples, _ in
      let values = (samples as? [HKQuantitySample] ?? []).map { sample in
        (
          offsetMilliseconds: max(0, Int(sample.startDate.timeIntervalSince(workout.startDate) * 1000)),
          bpm: sample.quantity.doubleValue(for: HKUnit.count().unitDivided(by: .minute()))
        )
      }.filter { $0.bpm > 0 }
      guard !values.isEmpty else {
        completion([])
        return
      }

      // Keep the curve lightweight while preserving its full time span.
      let sampleStride = max(1, Int(ceil(Double(values.count) / 360.0)))
      var encoded = values.enumerated().compactMap { index, value -> [String: Any]? in
        guard index % sampleStride == 0 else { return nil }
        return ["offsetMilliseconds": value.offsetMilliseconds, "bpm": value.bpm]
      }
      if let last = values.last,
         encoded.last?["offsetMilliseconds"] as? Int != last.offsetMilliseconds {
        encoded.append(["offsetMilliseconds": last.offsetMilliseconds, "bpm": last.bpm])
      }
      completion(encoded)
    }
    healthStore.execute(query)
  }

  private func encodeWorkout(_ workout: HKWorkout) -> [String: Any]? {
    guard let activity = moveaActivity(for: workout.workoutActivityType) else { return nil }
    var encoded: [String: Any] = [
      "sourceWorkoutId": workout.uuid.uuidString,
      "activity": activity,
      "startedAt": ISO8601DateFormatter().string(from: workout.startDate),
      "durationSeconds": workout.duration,
      "sourceDevice": workout.device?.name ?? workout.sourceRevision.source.name,
    ]

    let distanceIdentifier: HKQuantityTypeIdentifier? = switch workout.workoutActivityType {
    case .running:
      .distanceWalkingRunning
    case .cycling:
      .distanceCycling
    default:
      nil
    }
    if #available(iOS 16.0, *) {
      if let heartRateType = HKObjectType.quantityType(forIdentifier: .heartRate),
         let statistics = workout.statistics(for: heartRateType) {
        let unit = HKUnit.count().unitDivided(by: .minute())
        if let average = statistics.averageQuantity()?.doubleValue(for: unit), average > 0 {
          encoded["averageHeartRateBpm"] = average
        }
        if let maximum = statistics.maximumQuantity()?.doubleValue(for: unit), maximum > 0 {
          encoded["maximumHeartRateBpm"] = maximum
        }
      }

      if let energyType = HKObjectType.quantityType(forIdentifier: .activeEnergyBurned),
         let energy = workout.statistics(for: energyType)?.sumQuantity()?.doubleValue(for: .kilocalorie()),
         energy > 0 {
        encoded["activeEnergyKilocalories"] = energy
      }

      if let distanceIdentifier,
         let distanceType = HKObjectType.quantityType(forIdentifier: distanceIdentifier),
         let distance = workout.statistics(for: distanceType)?.sumQuantity()?.doubleValue(for: .meter()),
         distance > 0 {
        encoded["distanceMeters"] = distance
      }
    } else {
      if let energy = workout.totalEnergyBurned?.doubleValue(for: .kilocalorie()), energy > 0 {
        encoded["activeEnergyKilocalories"] = energy
      }
      if let distance = workout.totalDistance?.doubleValue(for: .meter()), distance > 0 {
        encoded["distanceMeters"] = distance
      }
    }
    return encoded
  }

  private func moveaActivity(for type: HKWorkoutActivityType) -> String? {
    switch type {
    case .running:
      return "run"
    case .cycling:
      return "ride"
    case .flexibility, .mindAndBody, .yoga:
      return "stretch"
    case .traditionalStrengthTraining, .functionalStrengthTraining, .coreTraining:
      return "strength"
    default:
      return nil
    }
  }

  private func readHealthSnapshot(result: @escaping FlutterResult) {
    guard HKHealthStore.isHealthDataAvailable() else {
      result(FlutterError(code: "unavailable", message: "HealthKit 在此设备不可用", details: nil))
      return
    }

    guard
      let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis),
      let bodyMassType = HKObjectType.quantityType(forIdentifier: .bodyMass),
      let stepType = HKObjectType.quantityType(forIdentifier: .stepCount),
      let restingHeartRateType = HKObjectType.quantityType(forIdentifier: .restingHeartRate)
    else {
      result(FlutterError(code: "unavailable", message: "健康数据类型不可用", details: nil))
      return
    }

    let readTypes: Set<HKObjectType> = [sleepType, bodyMassType, stepType, restingHeartRateType]
    healthStore.requestAuthorization(toShare: [], read: readTypes) { [weak self] granted, error in
      guard let self else { return }
      if let error {
        DispatchQueue.main.async {
          result(FlutterError(code: "authorizationDenied", message: error.localizedDescription, details: nil))
        }
        return
      }
      guard granted else {
        DispatchQueue.main.async {
          result(FlutterError(code: "authorizationDenied", message: "未获得健康数据读取授权", details: nil))
        }
        return
      }
      self.readHealthValues(
        sleepType: sleepType,
        bodyMassType: bodyMassType,
        stepType: stepType,
        restingHeartRateType: restingHeartRateType,
        result: result
      )
    }
  }

  private func readHealthValues(
    sleepType: HKCategoryType,
    bodyMassType: HKQuantityType,
    stepType: HKQuantityType,
    restingHeartRateType: HKQuantityType,
    result: @escaping FlutterResult
  ) {
    let group = DispatchGroup()
    let lock = NSLock()
    var snapshot: [String: Any] = ["source": "healthKit"]
    var sleep: [String: Any] = ["durationMinutes": 0, "quality": "暂无数据", "segments": []]

    group.enter()
    readSleep(type: sleepType) { value in
      lock.lock()
      sleep = value
      lock.unlock()
      group.leave()
    }

    group.enter()
    readWeight(type: bodyMassType) { latest, change in
      lock.lock()
      if let latest { snapshot["weightKg"] = latest }
      if let change { snapshot["weightChangeKg"] = change }
      lock.unlock()
      group.leave()
    }

    group.enter()
    readSteps(type: stepType) { steps in
      lock.lock()
      snapshot["steps"] = steps
      lock.unlock()
      group.leave()
    }

    group.enter()
    readRestingHeartRate(type: restingHeartRateType) { heartRate in
      lock.lock()
      snapshot["restingHeartRate"] = heartRate
      lock.unlock()
      group.leave()
    }

    group.notify(queue: .main) {
      snapshot["sleep"] = sleep
      snapshot["lastSyncedAt"] = ISO8601DateFormatter().string(from: Date())
      result(snapshot)
    }
  }

  private func readSleep(type: HKCategoryType, completion: @escaping ([String: Any]) -> Void) {
    let start = Calendar.current.date(byAdding: .hour, value: -36, to: Date()) ?? Date().addingTimeInterval(-129_600)
    let predicate = HKQuery.predicateForSamples(withStart: start, end: Date(), options: [])
    let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)
    let query = HKSampleQuery(sampleType: type, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: [sort]) { [weak self] _, samples, _ in
      guard self != nil else { return }
      let sleepSamples = (samples as? [HKCategorySample] ?? []).filter { sample in
        sample.value != 0
      }
      guard let first = sleepSamples.first, let last = sleepSamples.last else {
        completion(["durationMinutes": 0, "quality": "暂无数据", "segments": []])
        return
      }
      let bedtime = first.startDate
      let formatter = DateFormatter()
      formatter.dateFormat = "HH:mm"
      var asleepMinutes = 0
      var awakeMinutes = 0
      var deepMinutes = 0
      var remMinutes = 0
      var segments: [[String: Any]] = []
      for sample in sleepSamples {
        let minutesFromBedtime = max(0, Int(sample.startDate.timeIntervalSince(bedtime) / 60))
        let duration = max(1, Int(sample.endDate.timeIntervalSince(sample.startDate) / 60))
        let stage: String
        switch sample.value {
        case 2:
          stage = "awake"
          awakeMinutes += duration
        case 4:
          stage = "deep"
          deepMinutes += duration
          asleepMinutes += duration
        case 5:
          stage = "rem"
          remMinutes += duration
          asleepMinutes += duration
        default:
          stage = "core"
          asleepMinutes += duration
        }
        segments.append([
          "startMinute": minutesFromBedtime,
          "endMinute": minutesFromBedtime + duration,
          "stage": stage,
        ])
      }
      let quality = asleepMinutes >= 420 ? "良好" : asleepMinutes >= 360 ? "一般" : "偏短"
      completion([
        "durationMinutes": asleepMinutes,
        "quality": quality,
        "bedtime": formatter.string(from: bedtime),
        "wakeTime": formatter.string(from: last.endDate),
        "awakeMinutes": awakeMinutes,
        "deepMinutes": deepMinutes,
        "remMinutes": remMinutes,
        "segments": segments,
      ])
    }
    healthStore.execute(query)
  }

  private func readWeight(type: HKQuantityType, completion: @escaping (Double?, Double?) -> Void) {
    let start = Calendar.current.date(byAdding: .day, value: -14, to: Date()) ?? Date().addingTimeInterval(-1_209_600)
    let predicate = HKQuery.predicateForSamples(withStart: start, end: Date(), options: [])
    let sort = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
    let query = HKSampleQuery(sampleType: type, predicate: predicate, limit: 2, sortDescriptors: [sort]) { _, samples, _ in
      let values = (samples as? [HKQuantitySample] ?? []).map { sample in
        sample.quantity.doubleValue(for: HKUnit.gramUnit(with: .kilo))
      }
      let latest = values.first
      let change = values.count > 1 ? values[0] - values[1] : nil
      completion(latest, change)
    }
    healthStore.execute(query)
  }

  private func readSteps(type: HKQuantityType, completion: @escaping (Int) -> Void) {
    let start = Calendar.current.startOfDay(for: Date())
    let predicate = HKQuery.predicateForSamples(withStart: start, end: Date(), options: [])
    let query = HKStatisticsQuery(quantityType: type, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, statistics, _ in
      let count = statistics?.sumQuantity()?.doubleValue(for: HKUnit.count()) ?? 0
      completion(Int(count.rounded()))
    }
    healthStore.execute(query)
  }

  private func readRestingHeartRate(type: HKQuantityType, completion: @escaping (Int) -> Void) {
    let start = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date().addingTimeInterval(-604_800)
    let predicate = HKQuery.predicateForSamples(withStart: start, end: Date(), options: [])
    let sort = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
    let query = HKSampleQuery(sampleType: type, predicate: predicate, limit: 1, sortDescriptors: [sort]) { _, samples, _ in
      let sample = (samples as? [HKQuantitySample])?.first
      let value = sample?.quantity.doubleValue(for: HKUnit.count().unitDivided(by: HKUnit.minute())) ?? 0
      completion(Int(value.rounded()))
    }
    healthStore.execute(query)
  }
}

extension AppDelegate: WCSessionDelegate {
  nonisolated func session(
    _ session: WCSession,
    activationDidCompleteWith activationState: WCSessionActivationState,
    error: Error?
  ) {}

  nonisolated func sessionDidBecomeInactive(_ session: WCSession) {}

  nonisolated func sessionDidDeactivate(_ session: WCSession) {
    session.activate()
  }

  nonisolated func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any]) {
    Task { @MainActor [weak self] in
      self?.storeWatchWorkout(userInfo)
    }
  }
}
