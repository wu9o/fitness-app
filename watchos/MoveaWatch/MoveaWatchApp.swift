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
        ScrollView {
            VStack(spacing: 12) {
                if workout.isRunning {
                    activeWorkout
                } else {
                    activityPicker
                }
            }
            .padding(.horizontal, 8)
        }
        .alert(
            "无法开始运动",
            isPresented: Binding(
                get: { workout.errorMessage != nil },
                set: { visible in
                    if !visible { workout.dismissError() }
                }
            )
        ) {
            Button("知道了", role: .cancel) {
                workout.dismissError()
            }
        } message: {
            Text(workout.errorMessage ?? "未知错误")
        }
    }

    private var activityPicker: some View {
        VStack(spacing: 10) {
            Text("开始运动")
                .font(.headline)
            ForEach(WatchActivity.allCases) { activity in
                Button {
                    workout.selectedActivity = activity
                } label: {
                    Label(activity.title, systemImage: activity.icon)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.bordered)
                .tint(workout.selectedActivity == activity ? .orange : .gray)
            }
            Button {
                workout.startSelectedWorkout()
            } label: {
                if workout.isStarting {
                    ProgressView()
                } else {
                    Label("开始", systemImage: "play.fill")
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(.orange)
            .disabled(workout.isStarting)
        }
    }

    private var activeWorkout: some View {
        VStack(spacing: 10) {
            Text(workout.activityTitle)
                .font(.headline)
            Text(workout.elapsedLabel)
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .monospacedDigit()
            HStack {
                metric(workout.heartRateLabel, icon: "heart.fill")
                metric(workout.distanceLabel, icon: "location.fill")
            }
            Button(workout.isPaused ? "继续" : "暂停") {
                workout.isPaused ? workout.resume() : workout.pause()
            }
            .buttonStyle(.borderedProminent)
            .tint(workout.isPaused ? .green : .orange)
            Button("结束", role: .destructive) {
                workout.finish()
            }
            .buttonStyle(.bordered)
        }
    }

    private func metric(_ value: String, icon: String) -> some View {
        VStack(spacing: 3) {
            Image(systemName: icon)
                .foregroundStyle(.orange)
            Text(value)
                .font(.caption)
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity)
    }
}
