import SwiftUI

@main
struct MoveaWatchApp: App {
    @StateObject private var workout = WatchWorkoutCoordinator()

    var body: some Scene {
        WindowGroup {
            WatchWorkoutView(workout: workout)
        }
    }
}

private struct WatchWorkoutView: View {
    @ObservedObject var workout: WatchWorkoutCoordinator

    var body: some View {
        VStack(spacing: 12) {
            Text(workout.activityTitle)
                .font(.headline)
            Text(workout.elapsedLabel)
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .monospacedDigit()

            Button(workout.isRunning ? "结束" : "开始跑步") {
                workout.isRunning ? workout.finish() : workout.startRun()
            }
            .tint(.orange)

            if workout.isRunning {
                Button(workout.isPaused ? "继续" : "暂停") {
                    workout.isPaused ? workout.resume() : workout.pause()
                }
                .buttonStyle(.bordered)
            }
        }
        .padding()
    }
}
