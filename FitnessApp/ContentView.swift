import MapKit
import SwiftUI

struct ContentView: View {
    @State private var selectedTab: AppTab = .home

    var body: some View {
        VStack(spacing: 0) {
            Group {
                switch selectedTab {
                case .home: HomeView()
                case .activity: ActivityView()
                case .health: HealthView()
                case .routes: RoutesView()
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
                        NavigationLink(destination: SyncView()) {
                            Image(systemName: "lock.shield.fill")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundStyle(Color.appInk)
                                .padding(11)
                                .background(Color.appLemon.opacity(0.5), in: Circle())
                        }
                    }

                    Button {} label: {
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
                        HomeMetric(title: "本周运动", value: "18.4 km", note: "比上周 +12%", color: Color.appLemon.opacity(0.65))
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
    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                Map(initialPosition: .region(DemoRoute.region), interactionModes: []) {
                    MapPolyline(coordinates: DemoRoute.coordinates)
                        .stroke(Color.appBlue, lineWidth: 6)
                    Annotation("当前位置", coordinate: DemoRoute.coordinates[3]) {
                        Circle().fill(Color.appBlue).frame(width: 18, height: 18).overlay(Circle().stroke(.white, lineWidth: 4))
                    }
                }
                .ignoresSafeArea(edges: .top)

                VStack(spacing: 14) {
                    HStack {
                        Label("GPS 良好", systemImage: "location.fill")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Color.appInk)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 9)
                            .background(.white.opacity(0.94), in: Capsule())
                        Spacer()
                        Text("跑步")
                            .font(.system(size: 13, weight: .bold))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 9)
                            .background(.white.opacity(0.94), in: Capsule())
                    }

                    VStack(spacing: 18) {
                        Text("5.24 km")
                            .font(.system(size: 50, weight: .bold, design: .rounded))
                            .foregroundStyle(Color.appInk)
                        HStack {
                            ActivityMetric(title: "用时", value: "32:18")
                            ActivityMetric(title: "平均配速", value: "6'09''")
                            ActivityMetric(title: "心率", value: "142")
                        }
                        HStack(spacing: 12) {
                            Button {} label: {
                                Label("暂停", systemImage: "pause.fill")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundStyle(.white)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 52)
                                    .background(Color.appCoral, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                            }
                            Button {} label: {
                                Text("结束")
                                    .font(.system(size: 15, weight: .bold))
                                    .foregroundStyle(Color.appInk)
                                    .frame(width: 76, height: 52)
                                    .background(Color.black.opacity(0.06), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
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
                        Text("7h 32m")
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
        }
    }
}

struct RoutesView: View {
    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    ScreenHeader(title: "路线", subtitle: "把喜欢的路线留给下一次")
                    HStack {
                        Text("推荐").fontWeight(.bold).foregroundStyle(Color.appBlue)
                        Text("附近").foregroundStyle(Color.appSecondary)
                        Text("我的").foregroundStyle(Color.appSecondary)
                        Spacer()
                        Image(systemName: "magnifyingglass")
                    }
                    .font(.system(size: 14))

                    RouteCard(title: "公园环线", distance: "5.2 km", detail: "约 32 分钟  ·  爬升 80 m", tags: ["环线", "简单", "补水点"])
                    RouteCard(title: "河岸风景线", distance: "8.1 km", detail: "约 54 分钟  ·  爬升 120 m", tags: ["环线", "中等", "风景优美"])
                }
                .padding(20)
            }
            .background(Color.appPaper)
        }
    }
}

struct RouteCard: View {
    let title: String
    let distance: String
    let detail: String
    let tags: [String]

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
                Button {} label: {
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
    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    ScreenHeader(title: "学习", subtitle: "简单有效，陪你一直跑下去")
                    HStack(spacing: 8) {
                        ForEach(["跑步", "骑行", "拉伸", "力量"], id: \.self) { item in
                            Text(item)
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(item == "跑步" ? Color.appInk : Color.appSecondary)
                                .padding(.horizontal, 13)
                                .padding(.vertical, 8)
                                .background(item == "跑步" ? Color.appLavender.opacity(0.55) : Color.black.opacity(0.05), in: Capsule())
                        }
                    }
                    LessonCard(title: "跑前热身", detail: "8 分钟  ·  初级", description: "激活身体，跑得更轻松", icon: "figure.flexibility", color: Color.appLavender.opacity(0.35))
                    LessonCard(title: "跑后拉伸", detail: "10 分钟  ·  初级", description: "放松肌肉，恢复更轻松", icon: "figure.cooldown", color: Color.appMint.opacity(0.35))
                    LessonCard(title: "核心训练", detail: "12 分钟  ·  进阶", description: "更强的核心，让你跑得更稳", icon: "figure.core.training", color: Color.appLemon.opacity(0.35))
                }
                .padding(20)
            }
            .background(Color.appPaper)
        }
    }
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
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                ScreenHeader(title: "数据同步", subtitle: "你的数据，由你掌控")
                VStack(spacing: 10) {
                    Image(systemName: "lock.icloud.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(Color.appBlue)
                    Text("已连接私密仓库")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                    Text("数据在上传前加密")
                        .font(.system(size: 13))
                        .foregroundStyle(Color.appSecondary)
                }
                .frame(maxWidth: .infinity)
                .padding(24)
                .appCard(fill: Color.appBlue.opacity(0.10))

                SyncRow(icon: "lock.fill", title: "加密备份", detail: "运动、路线、睡眠与健康数据", value: "已开启")
                SyncRow(icon: "clock.fill", title: "最近同步", detail: "所有数据均已保存", value: "今天 08:24")
                SyncRow(icon: "arrow.clockwise", title: "恢复数据", detail: "从私密仓库恢复历史数据", value: "")

                Button {} label: {
                    Text("管理 GitHub 连接")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(Color.appCoral, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
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
