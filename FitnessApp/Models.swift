import MapKit
import SwiftUI

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
