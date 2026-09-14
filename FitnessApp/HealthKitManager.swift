import HealthKit
import SwiftUI

@MainActor
final class HealthKitManager: ObservableObject {
    @Published private(set) var sleep = SleepSummary.demo
    @Published private(set) var status = "演示数据"

    private let store = HKHealthStore()

    func requestAndLoad() {
        guard HKHealthStore.isHealthDataAvailable() else {
            status = "当前设备不支持健康数据"
            return
        }

        guard let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else {
            status = "睡眠数据不可用"
            return
        }

        store.requestAuthorization(toShare: [], read: [sleepType]) { [weak self] success, error in
            Task { @MainActor in
                guard let self else { return }
                if success {
                    self.loadSleep()
                } else {
                    self.status = error?.localizedDescription ?? "未获得睡眠数据权限"
                }
            }
        }
    }

    private func loadSleep() {
        guard let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else { return }
        let start = Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date().addingTimeInterval(-86_400)
        let predicate = HKQuery.predicateForSamples(withStart: start, end: Date(), options: .strictStartDate)
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: true)

        let query = HKSampleQuery(sampleType: sleepType, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: [sort]) { [weak self] _, samples, error in
            Task { @MainActor in
                guard let self else { return }
                guard error == nil, let samples = samples as? [HKCategorySample], !samples.isEmpty else {
                    self.status = "暂无最近睡眠记录，保留演示数据"
                    return
                }

                var result = SleepSummary(durationMinutes: 0, deepMinutes: 0, remMinutes: 0, awakeMinutes: 0)
                for sample in samples {
                    let minutes = max(0, Int(sample.endDate.timeIntervalSince(sample.startDate) / 60))
                    switch sample.value {
                    case HKCategoryValueSleepAnalysis.asleepDeep.rawValue:
                        result.deepMinutes += minutes
                        result.durationMinutes += minutes
                    case HKCategoryValueSleepAnalysis.asleepREM.rawValue:
                        result.remMinutes += minutes
                        result.durationMinutes += minutes
                    case HKCategoryValueSleepAnalysis.asleepCore.rawValue,
                         HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue:
                        result.durationMinutes += minutes
                    case HKCategoryValueSleepAnalysis.awake.rawValue:
                        result.awakeMinutes += minutes
                    default:
                        break
                    }
                }
                if result.durationMinutes > 0 {
                    self.sleep = result
                    self.status = "来自 Apple 健康"
                }
            }
        }
        store.execute(query)
    }
}
