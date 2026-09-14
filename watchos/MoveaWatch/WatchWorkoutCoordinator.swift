import Combine
import Foundation

/// Watch 端的最小运动生命周期骨架。
/// 正式接入时，这里替换为 HKWorkoutSession + HKLiveWorkoutBuilder，
/// 并通过 WatchConnectivity 将摘要回传给 iPhone。
final class WatchWorkoutCoordinator: ObservableObject {
    @Published private(set) var isRunning = false
    @Published private(set) var isPaused = false
    @Published private(set) var elapsed: TimeInterval = 0

    private var startedAt: Date?
    private var timer: Timer?

    var activityTitle: String { "跑步" }

    var elapsedLabel: String {
        let total = Int(elapsed)
        return String(format: "%02d:%02d", total / 60, total % 60)
    }

    func startRun() {
        startedAt = Date()
        elapsed = 0
        isRunning = true
        isPaused = false
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            guard let self, let startedAt, !self.isPaused else { return }
            self.elapsed = Date().timeIntervalSince(startedAt)
        }
    }

    func pause() { isPaused = true }
    func resume() { isPaused = false }

    func finish() {
        timer?.invalidate()
        timer = nil
        startedAt = nil
        elapsed = 0
        isRunning = false
        isPaused = false
    }
}
