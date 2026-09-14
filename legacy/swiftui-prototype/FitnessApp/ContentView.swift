import MapKit
import SwiftUI

struct ContentView: View {
    @State private var selectedTab: AppTab = .home
    @StateObject private var locationManager = LocationManager()
    @StateObject private var routeStore = RouteStore()
    @StateObject private var workoutStore = WorkoutStore()
    @StateObject private var healthKit = HealthKitManager()
    @State private var selectedActivity: ActivityType = .run

    var body: some View {
        VStack(spacing: 0) {
            Group {
                switch selectedTab {
                case .home: HomeView(onStart: openActivity, routeStore: routeStore, workoutStore: workoutStore, healthKit: healthKit)
                case .activity: ActivityView(selectedActivity: $selectedActivity, locationManager: locationManager, routeStore: routeStore, workoutStore: workoutStore, onStart: startSelectedActivity)
                case .health: HealthView(healthKit: healthKit)
                case .routes: RoutesView(routeStore: routeStore, onFollow: { startActivity(.run) })
                case .learn: LearnView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            Divider().overlay(Color.black.opacity(0.06))
            BottomBar(selectedTab: $selectedTab)
        }
        .background(Color.appPaper.ignoresSafeArea())
        .tint(Color.appCoral)
    }

    private func openActivity() {
        selectedTab = .activity
    }

    private func startSelectedActivity() {
        startActivity(selectedActivity)
    }

    private func startActivity(_ activity: ActivityType) {
        selectedActivity = activity
        locationManager.start()
    }
}

struct BottomBar: View {
    @Binding var selectedTab: AppTab

    var body: some View {
        HStack {
            ForEach(AppTab.allCases) { tab in
                Button {
                    selectedTab = tab
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: tab.icon)
                            .font(.system(size: 17, weight: .semibold))
                        Text(tab.title)
                            .font(.system(size: 11, weight: .medium))
                    }
                    .foregroundStyle(selectedTab == tab ? Color.appCoral : Color.appSecondary)
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.top, 10)
        .padding(.bottom, 7)
        .background(.white.opacity(0.95))
    }
}

struct HomeView: View {
    let onStart: () -> Void
    @ObservedObject var routeStore: RouteStore
    @ObservedObject var workoutStore: WorkoutStore
    @ObservedObject var healthKit: HealthKitManager

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 22) {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 5) {
                            Text("今天想动一动吗？")
                                .font(.system(size: 29, weight: .bold, design: .rounded))
                            Text("更健康的你，从今天开始")
                                .foregroundStyle(Color.appSecondary)
                        }
                        Spacer()
                        NavigationLink(destination: SyncView(routeStore: routeStore, healthKit: healthKit)) {
                            Image(systemName: "lock.shield.fill")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundStyle(Color.appInk)
                                .padding(11)
                                .background(Color.appLemon.opacity(0.5), in: Circle())
                        }
                    }

                    Button(action: onStart) {
                        HStack {
                            Image(systemName: "figure.run")
                                .font(.system(size: 22, weight: .bold))
                            Text("开始运动")
                                .font(.system(size: 18, weight: .bold, design: .rounded))
                            Spacer()
                            Image(systemName: "arrow.right")
                                .font(.system(size: 17, weight: .bold))
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, 20)
                        .frame(height: 62)
                        .background(Color.appCoral, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                    }
                    .buttonStyle(.plain)

                    HStack(spacing: 12) {
                        HomeMetric(title: "昨晚睡眠", value: "7h 32m", note: "睡得不错", color: Color.appMint)
                        NavigationLink {
                            WorkoutHistoryView(store: workoutStore)
                        } label: {
                            HomeMetric(title: "本周运动", value: "18.4 km", note: "查看全部记录", color: Color.appLemon.opacity(0.65))
                        }
                        .buttonStyle(.plain)
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        SectionTitle("本周进度", action: "4 / 7 天")
                        HStack(spacing: 12) {
                            ForEach(0..<7, id: \.self) { index in
                                VStack(spacing: 7) {
                                    Circle()
                                        .fill(index < 4 ? Color.appCoral.opacity(index == 3 ? 1 : 0.55) : Color.black.opacity(0.08))
                                        .frame(width: 22, height: 22)
                                    Text(["一", "二", "三", "四", "五", "六", "日"][index])
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundStyle(Color.appSecondary)
                                }
                                .frame(maxWidth: .infinity)
                            }
                        }
                        .padding(16)
                        .appCard()
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        SectionTitle("为你推荐")
                        HStack(spacing: 14) {
                            Image(systemName: "figure.run.circle.fill")
                                .font(.system(size: 42))
                                .foregroundStyle(Color.appCoral)
                            VStack(alignment: .leading, spacing: 4) {
                                Text("轻松跑 30 分钟")
                                    .font(.system(size: 17, weight: .bold, design: .rounded))
                                Text("放松身体，保持节奏")
                                    .font(.system(size: 13))
                                    .foregroundStyle(Color.appSecondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundStyle(Color.appSecondary)
                        }
                        .padding(16)
                        .appCard(fill: Color.appLemon.opacity(0.22))
                    }
                }
                .padding(20)
            }
            .background(Color.appPaper)
        }
    }
}

struct HomeMetric: View {
    let title: String
    let value: String
    let note: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.appSecondary)
            Text(value)
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundStyle(Color.appInk)
            Text(note)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color.appInk.opacity(0.65))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .appCard(fill: color.opacity(0.28))
    }
}

struct ActivityView: View {
    @Binding var selectedActivity: ActivityType
    @ObservedObject var locationManager: LocationManager
    @ObservedObject var routeStore: RouteStore
    @ObservedObject var workoutStore: WorkoutStore
    let onStart: () -> Void

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                if selectedActivity.usesLocation {
                    Map(initialPosition: .region(DemoRoute.region), interactionModes: []) {
                        if !locationManager.isRecording || !locationManager.route.isEmpty {
                            MapPolyline(coordinates: locationManager.route.isEmpty ? DemoRoute.coordinates : locationManager.route)
                                .stroke(Color.appBlue, lineWidth: 6)
                        }
                        Annotation("当前位置", coordinate: locationManager.route.last ?? DemoRoute.coordinates[3]) {
                            Circle().fill(Color.appBlue).frame(width: 18, height: 18).overlay(Circle().stroke(.white, lineWidth: 4))
                        }
                    }
                    .ignoresSafeArea(edges: .top)
                } else {
                    Color.appPaper.ignoresSafeArea()
                }

                VStack(spacing: 14) {
                    HStack {
                        if selectedActivity.usesLocation {
                            Label("GPS 良好", systemImage: "location.fill")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(Color.appInk)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 9)
                                .background(.white.opacity(0.94), in: Capsule())
                        } else {
                            Label("室内训练", systemImage: "figure.strengthtraining.functional")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(Color.appInk)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 9)
                                .background(.white.opacity(0.94), in: Capsule())
                        }
                        Spacer()
                        Text(selectedActivity.title)
                            .font(.system(size: 13, weight: .bold))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 9)
                            .background(.white.opacity(0.94), in: Capsule())
                    }

                    if !locationManager.isRecording {
                        ActivityTypePicker(selection: $selectedActivity)
                    }

                    Group {
                        if locationManager.isRecording {
                            VStack(spacing: 18) {
                                if selectedActivity.usesLocation {
                                    Text(String(format: "%.2f km", locationManager.distance / 1000))
                                        .font(.system(size: 50, weight: .bold, design: .rounded))
                                        .foregroundStyle(Color.appInk)
                                } else {
                                    Image(systemName: selectedActivity.icon)
                                        .font(.system(size: 44))
                                        .foregroundStyle(Color.appCoral)
                                }
                                HStack {
                                    TimelineView(.periodic(from: .now, by: 1)) { context in
                                        ActivityMetric(title: "用时", value: durationText(for: locationManager.currentElapsedTime(at: context.date)))
                                    }
                                    if selectedActivity.usesLocation {
                                        ActivityMetric(title: "平均配速", value: "—")
                                    } else {
                                        ActivityMetric(title: "类型", value: selectedActivity.title)
                                    }
                                    ActivityMetric(title: "心率", value: "—")
                                }
                                HStack(spacing: 12) {
                                    Button { locationManager.togglePause() } label: {
                                        Label(locationManager.isPaused ? "继续" : "暂停", systemImage: locationManager.isPaused ? "play.fill" : "pause.fill")
                                            .font(.system(size: 16, weight: .bold))
                                            .foregroundStyle(.white)
                                            .frame(maxWidth: .infinity)
                                            .frame(height: 52)
                                            .background(Color.appCoral, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                                    }
                                    Button {
                                        let duration = locationManager.currentElapsedTime()
                                        if selectedActivity.usesLocation {
                                            routeStore.save(points: locationManager.route, distance: locationManager.distance)
                                        }
                                        workoutStore.save(activity: selectedActivity, duration: duration, distance: locationManager.distance)
                                        locationManager.finish()
                                    } label: {
                                        Text("结束")
                                            .font(.system(size: 15, weight: .bold))
                                            .foregroundStyle(Color.appInk)
                                            .frame(width: 76, height: 52)
                                            .background(Color.black.opacity(0.06), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                                    }
                                }
                            }
                        } else {
                            VStack(spacing: 14) {
                                Image(systemName: selectedActivity.icon)
                                    .font(.system(size: 48))
                                    .foregroundStyle(Color.appCoral)
                                Text("准备好了吗？")
                                    .font(.system(size: 24, weight: .bold, design: .rounded))
                                Text(selectedActivity.usesLocation ? "开始后将记录你的路线和运动数据" : "开始后将记录你的训练时长")
                                    .font(.system(size: 13))
                                    .foregroundStyle(Color.appSecondary)
                                Button(action: onStart) {
                                    Label("开始\(selectedActivity.title)", systemImage: "play.fill")
                                        .font(.system(size: 16, weight: .bold))
                                        .foregroundStyle(.white)
                                        .frame(maxWidth: .infinity)
                                        .frame(height: 52)
                                        .background(Color.appCoral, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                                }
                                .buttonStyle(.plain)
                                NavigationLink {
                                    WorkoutHistoryView(store: workoutStore)
                                } label: {
                                    Label("查看全部运动记录", systemImage: "list.bullet.clipboard")
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundStyle(Color.appBlue)
                                }
                            }
                        }
                    }
                    .padding(20)
                    .appCard()
                }
                .padding(16)
            }
            .toolbar(.hidden, for: .navigationBar)
        }
    }

    private func durationText(for duration: TimeInterval) -> String {
        let totalSeconds = max(0, Int(duration.rounded()))
        return String(format: "%02d:%02d", totalSeconds / 60, totalSeconds % 60)
    }
}

struct ActivityTypePicker: View {
    @Binding var selection: ActivityType

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(ActivityType.allCases) { activity in
                    Button {
                        selection = activity
                    } label: {
                        Label(activity.title, systemImage: activity.icon)
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(selection == activity ? Color.appInk : Color.appSecondary)
                            .padding(.horizontal, 13)
                            .padding(.vertical, 9)
                            .background(selection == activity ? Color.appLavender.opacity(0.7) : Color.black.opacity(0.06), in: Capsule())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(activity.title)
                }
            }
        }
    }
}

struct WorkoutHistoryView: View {
    @ObservedObject var store: WorkoutStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if store.records.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "figure.run.circle")
                            .font(.system(size: 44))
                            .foregroundStyle(Color.appSecondary)
                        Text("还没有运动记录")
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                        Text("完成一次运动后，记录会显示在这里")
                            .font(.system(size: 13))
                            .foregroundStyle(Color.appSecondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 90)
                } else {
                    ForEach(store.records) { record in
                        WorkoutRecordRow(record: record)
                    }
                }
            }
            .padding(20)
        }
        .background(Color.appPaper)
        .navigationTitle("全部运动记录")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct WorkoutRecordRow: View {
    let record: WorkoutRecord

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: record.activity.icon)
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(Color.appCoral)
                .frame(width: 48, height: 48)
                .background(Color.appCoral.opacity(0.12), in: Circle())
            VStack(alignment: .leading, spacing: 5) {
                Text(record.activity.title)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                Text(record.date, format: .dateTime.month().day().hour().minute())
                    .font(.system(size: 12))
                    .foregroundStyle(Color.appSecondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 5) {
                Text(record.durationText)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                Text(record.distanceText)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.appSecondary)
            }
        }
        .padding(16)
        .appCard()
    }
}

struct ActivityMetric: View {
    let title: String
    let value: String

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 19, weight: .bold, design: .rounded))
            Text(title)
                .font(.system(size: 11))
                .foregroundStyle(Color.appSecondary)
        }
        .frame(maxWidth: .infinity)
    }
}

struct HealthView: View {
    @ObservedObject var healthKit: HealthKitManager

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    ScreenHeader(title: "健康", subtitle: "了解身体，跑得更远")

                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Label("昨晚睡眠", systemImage: "moon.fill")
                                .foregroundStyle(Color.appInk)
                            Spacer()
                            Text("今天恢复得不错")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(Color.green)
                        }
                        Text(healthKit.sleep.durationText)
                            .font(.system(size: 46, weight: .bold, design: .rounded))
                        HStack(spacing: 4) {
                            ForEach(0..<24, id: \.self) { index in
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(index % 5 == 0 ? Color.appLavender : Color.appMint)
                                    .frame(height: index % 5 == 0 ? 26 : 18)
                            }
                        }
                        HStack {
                        Text("23:10"); Spacer(); Text("06:42")
                        }
                        .font(.system(size: 11))
                        .foregroundStyle(Color.appSecondary)
                    }
                    .padding(18)
                    .appCard(fill: Color.appMint.opacity(0.25))

                    VStack(alignment: .leading, spacing: 14) {
                        SectionTitle("近 7 天睡眠时长", action: "平均 7h 12m")
                        HStack(alignment: .bottom, spacing: 12) {
                            ForEach([6.2, 6.8, 7.5, 6.7, 7.1, 7.4, 7.53], id: \.self) { hours in
                                VStack(spacing: 7) {
                                    RoundedRectangle(cornerRadius: 7)
                                        .fill(hours > 7.4 ? Color.appMint : Color.appMint.opacity(0.55))
                                        .frame(maxWidth: .infinity)
                                        .frame(height: CGFloat(hours * 22))
                                    Text(hours == 7.53 ? "今" : "·")
                                        .font(.system(size: 11, weight: .semibold))
                                        .foregroundStyle(Color.appSecondary)
                                }
                            }
                        }
                        .frame(height: 190, alignment: .bottom)
                        .padding(.top, 6)
                    }
                    .padding(18)
                    .appCard()

                    HStack(spacing: 14) {
                        Image(systemName: "figure.run.circle.fill")
                            .font(.system(size: 35))
                            .foregroundStyle(Color.appCoral)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("适合轻松运动")
                                .font(.system(size: 16, weight: .bold, design: .rounded))
                            Text("睡眠充足，今天可以动一动")
                                .font(.system(size: 13))
                                .foregroundStyle(Color.appSecondary)
                        }
                        Spacer()
                    }
                    .padding(16)
                    .appCard(fill: Color.appLemon.opacity(0.25))
                }
                .padding(20)
            }
            .background(Color.appPaper)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        healthKit.requestAndLoad()
                    } label: {
                        Image(systemName: "arrow.triangle.2.circlepath")
                    }
                    .accessibilityLabel("同步健康数据")
                }
            }
        }
    }
}

struct RoutesView: View {
    @ObservedObject var routeStore: RouteStore
    let onFollow: () -> Void
    @State private var selectedFilter: RouteFilter = .recommended
    @State private var isSearchPresented = false

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    ScreenHeader(title: "路线", subtitle: "把喜欢的路线留给下一次")
                    HStack(spacing: 20) {
                        ForEach(RouteFilter.allCases) { filter in
                            Button {
                                selectedFilter = filter
                            } label: {
                                Text(filter.title)
                                    .fontWeight(selectedFilter == filter ? .bold : .regular)
                                    .foregroundStyle(selectedFilter == filter ? Color.appBlue : Color.appSecondary)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(filter.title)
                        }
                        Spacer()
                        Button {
                            isSearchPresented = true
                        } label: {
                            Image(systemName: "magnifyingglass")
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("搜索路线")
                    }
                    .font(.system(size: 14))

                    if selectedFilter == .mine {
                        if routeStore.routes.isEmpty {
                            EmptyRoutesView()
                        } else {
                            ForEach(routeStore.routes) { route in
                                RouteCard(title: route.name, distance: route.distanceText, detail: "已保存  ·  可再次跟随", tags: ["我的路线", "已保存"], onFollow: onFollow)
                            }
                        }
                    } else if selectedFilter == .nearby {
                        RouteCard(title: "附近公园环线", distance: "5.2 km", detail: "约 32 分钟  ·  爬升 80 m", tags: ["附近", "简单", "补水点"], onFollow: onFollow)
                        RouteCard(title: "滨江晨跑线", distance: "6.8 km", detail: "约 43 分钟  ·  平路为主", tags: ["附近", "平路", "风景优美"], onFollow: onFollow)
                    } else {
                        RouteCard(title: "公园环线", distance: "5.2 km", detail: "约 32 分钟  ·  爬升 80 m", tags: ["环线", "简单", "补水点"], onFollow: onFollow)
                        RouteCard(title: "河岸风景线", distance: "8.1 km", detail: "约 54 分钟  ·  爬升 120 m", tags: ["环线", "中等", "风景优美"], onFollow: onFollow)
                    }
                }
                .padding(20)
            }
            .background(Color.appPaper)
        }
        .sheet(isPresented: $isSearchPresented) {
            RouteSearchView(routeStore: routeStore, onFollow: onFollow)
        }
    }
}

struct EmptyRoutesView: View {
    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: "map")
                .font(.system(size: 36))
                .foregroundStyle(Color.appSecondary)
            Text("还没有保存的路线")
                .font(.system(size: 17, weight: .bold, design: .rounded))
            Text("完成一次户外运动后，可以在这里找到路线")
                .font(.system(size: 13))
                .foregroundStyle(Color.appSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 70)
    }
}

struct RouteSearchView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var routeStore: RouteStore
    let onFollow: () -> Void
    @State private var query = ""

    private var results: [RouteSearchResult] {
        let all = [
            RouteSearchResult(title: "公园环线", distance: "5.2 km", detail: "约 32 分钟  ·  爬升 80 m"),
            RouteSearchResult(title: "河岸风景线", distance: "8.1 km", detail: "约 54 分钟  ·  爬升 120 m"),
            RouteSearchResult(title: "附近公园环线", distance: "5.2 km", detail: "约 32 分钟  ·  附近路线")
        ] + routeStore.routes.map { RouteSearchResult(title: $0.name, distance: $0.distanceText, detail: "已保存路线") }
        guard !query.isEmpty else { return all }
        return all.filter { $0.title.localizedCaseInsensitiveContains(query) }
    }

    var body: some View {
        NavigationStack {
            List(results) { result in
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(result.title).font(.system(size: 16, weight: .semibold))
                        Text("\(result.distance)  ·  \(result.detail)")
                            .font(.system(size: 12))
                            .foregroundStyle(Color.appSecondary)
                    }
                    Spacer()
                    Button("跟随") {
                        dismiss()
                        onFollow()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Color.appBlue)
                }
                .padding(.vertical, 4)
            }
            .navigationTitle("搜索路线")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $query, prompt: "搜索路线")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完成") { dismiss() }
                }
            }
        }
    }
}

struct RouteSearchResult: Identifiable {
    let id = UUID()
    let title: String
    let distance: String
    let detail: String
}

struct RouteCard: View {
    let title: String
    let distance: String
    let detail: String
    let tags: [String]
    let onFollow: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Map(initialPosition: .region(DemoRoute.region), interactionModes: []) {
                MapPolyline(coordinates: DemoRoute.coordinates).stroke(Color.appBlue, lineWidth: 5)
            }
            .frame(height: 160)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .firstTextBaseline) {
                    Text(title).font(.system(size: 19, weight: .bold, design: .rounded))
                    Spacer()
                    Text(distance).font(.system(size: 19, weight: .bold, design: .rounded))
                }
                Text(detail).font(.system(size: 12)).foregroundStyle(Color.appSecondary)
                HStack {
                    ForEach(tags, id: \.self) { tag in
                        Text(tag)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(Color.appBlue)
                            .padding(.horizontal, 9)
                            .padding(.vertical, 6)
                            .background(Color.appBlue.opacity(0.10), in: Capsule())
                    }
                }
                Button(action: onFollow) {
                    Label("跟随路线", systemImage: "location.north.fill")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 46)
                        .background(Color.appBlue, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .buttonStyle(.plain)
            }
            .padding(16)
        }
        .appCard()
    }
}

struct LearnView: View {
    @State private var selectedCategory: LearnCategory = .run

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    ScreenHeader(title: "学习", subtitle: "简单有效，陪你一直跑下去")
                    HStack(spacing: 8) {
                        ForEach(LearnCategory.allCases) { category in
                            Button {
                                selectedCategory = category
                            } label: {
                                Text(category.title)
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(selectedCategory == category ? Color.appInk : Color.appSecondary)
                                    .padding(.horizontal, 13)
                                    .padding(.vertical, 8)
                                    .background(selectedCategory == category ? Color.appLavender.opacity(0.55) : Color.black.opacity(0.05), in: Capsule())
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(category.title)
                        }
                    }
                    ForEach(Array(lessons.enumerated()), id: \.offset) { _, lesson in
                        LessonCard(title: lesson.title, detail: lesson.detail, description: lesson.description, icon: lesson.icon, color: lesson.color)
                    }
                }
                .padding(20)
            }
            .background(Color.appPaper)
        }
    }

    private var lessons: [LessonData] {
        switch selectedCategory {
        case .run:
            [
                LessonData(title: "跑前热身", detail: "8 分钟  ·  初级", description: "激活身体，跑得更轻松", icon: "figure.flexibility", color: Color.appLavender.opacity(0.35)),
                LessonData(title: "跑后拉伸", detail: "10 分钟  ·  初级", description: "放松肌肉，恢复更轻松", icon: "figure.cooldown", color: Color.appMint.opacity(0.35)),
                LessonData(title: "核心训练", detail: "12 分钟  ·  进阶", description: "更强的核心，让你跑得更稳", icon: "figure.core.training", color: Color.appLemon.opacity(0.35))
            ]
        case .ride:
            [
                LessonData(title: "骑行前检查", detail: "6 分钟  ·  初级", description: "调整座高，检查刹车和胎压", icon: "bicycle", color: Color.appLavender.opacity(0.35)),
                LessonData(title: "骑行节奏", detail: "15 分钟  ·  初级", description: "找到适合自己的踏频", icon: "figure.outdoor.cycle", color: Color.appMint.opacity(0.35)),
                LessonData(title: "爬坡技巧", detail: "18 分钟  ·  进阶", description: "用更少的力气完成爬坡", icon: "mountain.2", color: Color.appLemon.opacity(0.35))
            ]
        case .stretch:
            [
                LessonData(title: "全身唤醒", detail: "8 分钟  ·  初级", description: "从肩颈到髋部逐步活动开", icon: "figure.flexibility", color: Color.appLavender.opacity(0.35)),
                LessonData(title: "跑后拉伸", detail: "10 分钟  ·  初级", description: "放松腿部肌肉，缓解紧绷", icon: "figure.cooldown", color: Color.appMint.opacity(0.35)),
                LessonData(title: "髋部灵活性", detail: "12 分钟  ·  进阶", description: "提升步幅和日常活动舒适度", icon: "figure.mind.and.body", color: Color.appLemon.opacity(0.35))
            ]
        case .strength:
            [
                LessonData(title: "核心训练", detail: "12 分钟  ·  初级", description: "增强核心，让动作更稳定", icon: "figure.core.training", color: Color.appLavender.opacity(0.35)),
                LessonData(title: "下肢力量", detail: "15 分钟  ·  初级", description: "循序渐进训练臀腿力量", icon: "figure.strengthtraining.traditional", color: Color.appMint.opacity(0.35)),
                LessonData(title: "全身力量", detail: "20 分钟  ·  进阶", description: "用简单动作覆盖主要肌群", icon: "figure.strengthtraining.functional", color: Color.appLemon.opacity(0.35))
            ]
        }
    }
}

struct LessonData {
    let title: String
    let detail: String
    let description: String
    let icon: String
    let color: Color
}

struct LessonCard: View {
    let title: String
    let detail: String
    let description: String
    let icon: String
    let color: Color

    var body: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text(title).font(.system(size: 20, weight: .bold, design: .rounded))
                Text(description).font(.system(size: 13)).foregroundStyle(Color.appSecondary)
                Text(detail).font(.system(size: 12, weight: .semibold)).foregroundStyle(Color.appInk.opacity(0.7))
            }
            Spacer()
            Image(systemName: icon)
                .font(.system(size: 42, weight: .medium))
                .foregroundStyle(Color.appInk)
            Image(systemName: "play.circle.fill")
                .font(.system(size: 30))
                .foregroundStyle(Color.appCoral)
        }
        .padding(18)
        .appCard(fill: color)
    }
}

struct ScreenHeader: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.system(size: 29, weight: .bold, design: .rounded))
            Text(subtitle).font(.system(size: 14)).foregroundStyle(Color.appSecondary)
        }
    }
}

struct SyncView: View {
    @ObservedObject private var sync = GitHubSyncManager.shared
    @ObservedObject var routeStore: RouteStore
    @ObservedObject var healthKit: HealthKitManager

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                ScreenHeader(title: "数据同步", subtitle: "你的数据，由你掌控")
                VStack(spacing: 10) {
                    Image(systemName: "lock.icloud.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(Color.appBlue)
                    Text(sync.username == nil ? "尚未连接私密仓库" : "已连接私密仓库")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                    Text(sync.status)
                        .font(.system(size: 13))
                        .foregroundStyle(Color.appSecondary)
                }
                .frame(maxWidth: .infinity)
                .padding(24)
                .appCard(fill: Color.appBlue.opacity(0.10))

                SyncRow(icon: "lock.fill", title: "加密备份", detail: sync.repository, value: "已开启")
                SyncRow(icon: "clock.fill", title: "最近同步", detail: "所有数据均已保存", value: "今天 08:24")
                SyncRow(icon: "arrow.clockwise", title: "恢复数据", detail: "从私密仓库恢复历史数据", value: "")

                Button { sync.connect() } label: {
                    Text(sync.username == nil ? "连接 GitHub" : "管理 GitHub 连接")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(Color.appCoral, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                Button {
                    Task { await sync.uploadEncryptedBackup(sleep: healthKit.sleep, routes: routeStore.routes) }
                } label: {
                    Text("立即备份当前数据")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(Color.appCoral)
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .background(Color.appCoral.opacity(0.10), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
            }
            .padding(20)
        }
        .background(Color.appPaper)
        .navigationTitle("数据同步")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct SyncRow: View {
    let icon: String
    let title: String
    let detail: String
    let value: String

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .foregroundStyle(Color.appBlue)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.system(size: 15, weight: .semibold))
                Text(detail).font(.system(size: 12)).foregroundStyle(Color.appSecondary)
            }
            Spacer()
            if !value.isEmpty {
                Text(value).font(.system(size: 12, weight: .semibold)).foregroundStyle(Color.appSecondary)
            }
            Image(systemName: "chevron.right").font(.system(size: 12, weight: .bold)).foregroundStyle(Color.appSecondary)
        }
        .padding(16)
        .appCard()
    }
}

#Preview {
    ContentView()
}
