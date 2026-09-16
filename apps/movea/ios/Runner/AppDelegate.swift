import Flutter
import HealthKit
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private let healthStore = HKHealthStore()

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)

    let healthChannel = FlutterMethodChannel(
      name: "movea/health",
      binaryMessenger: engineBridge.applicationRegistrar.messenger()
    )
    healthChannel.setMethodCallHandler { [weak self] call, result in
      guard call.method == "readHealthSnapshot" else {
        result(FlutterMethodNotImplemented)
        return
      }
      self?.readHealthSnapshot(result: result)
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
