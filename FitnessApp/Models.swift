import MapKit
import SwiftUI

struct SleepSummary: Codable {
    var durationMinutes: Int = 452
    var deepMinutes: Int = 78
    var remMinutes: Int = 72
    var awakeMinutes: Int = 32

    static let demo = SleepSummary()

    var durationText: String {
        "\(durationMinutes / 60)h \(durationMinutes % 60)m"
    }
}

struct TrackPoint: Codable, Hashable {
    let latitude: Double
    let longitude: Double

    init(_ coordinate: CLLocationCoordinate2D) {
        latitude = coordinate.latitude
        longitude = coordinate.longitude
    }

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}

struct SavedRoute: Codable, Identifiable {
    let id: UUID
    let name: String
    let createdAt: Date
    let points: [TrackPoint]
    let distance: Double

    var distanceText: String {
        String(format: "%.2f km", distance / 1000)
    }
}

@MainActor
final class RouteStore: ObservableObject {
    @Published private(set) var routes: [SavedRoute] = []

    private static let minimumDistanceMeters: CLLocationDistance = 10
    private let fileURL: URL

    init() {
        let directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("MoveLog", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        fileURL = directory.appendingPathComponent("routes.json")
        load()
    }

    func save(points: [CLLocationCoordinate2D], distance: Double) {
        guard points.count >= 2, distance >= Self.minimumDistanceMeters else { return }
        let route = SavedRoute(id: UUID(), name: "我的运动路线 \(routes.count + 1)", createdAt: Date(), points: points.map(TrackPoint.init), distance: distance)
        routes.insert(route, at: 0)
        persist()
    }

    private func load() {
        guard let data = try? Data(contentsOf: fileURL), let decoded = try? JSONDecoder().decode([SavedRoute].self, from: data) else { return }
        routes = decoded.filter { $0.points.count >= 2 && $0.distance >= Self.minimumDistanceMeters }
        if routes.count != decoded.count {
            persist()
        }
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(routes) else { return }
        try? data.write(to: fileURL, options: [.atomic])
    }
}

enum AppTab: String, CaseIterable, Identifiable {
    case home, activity, health, routes, learn

    var id: String { rawValue }

    var title: String {
        switch self {
        case .home: "首页"
        case .activity: "运动"
        case .health: "健康"
        case .routes: "路线"
        case .learn: "学习"
        }
    }

    var icon: String {
        switch self {
        case .home: "house.fill"
        case .activity: "figure.run"
        case .health: "heart.fill"
        case .routes: "map.fill"
        case .learn: "book.fill"
        }
    }
}

struct DemoRoute {
    static let coordinates = [
        CLLocationCoordinate2D(latitude: 31.2300, longitude: 121.4700),
        CLLocationCoordinate2D(latitude: 31.2317, longitude: 121.4735),
        CLLocationCoordinate2D(latitude: 31.2295, longitude: 121.4770),
        CLLocationCoordinate2D(latitude: 31.2265, longitude: 121.4750),
        CLLocationCoordinate2D(latitude: 31.2252, longitude: 121.4707),
        CLLocationCoordinate2D(latitude: 31.2276, longitude: 121.4680),
        CLLocationCoordinate2D(latitude: 31.2300, longitude: 121.4700)
    ]

    static let region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 31.2290, longitude: 121.4720),
        span: MKCoordinateSpan(latitudeDelta: 0.018, longitudeDelta: 0.018)
    )
}
