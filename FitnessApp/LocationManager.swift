import CoreLocation
import Foundation
import SwiftUI

@MainActor
final class LocationManager: NSObject, ObservableObject {
    @Published private(set) var isRecording = false
    @Published private(set) var isPaused = false
    @Published private(set) var distance: CLLocationDistance = 0
    @Published private(set) var route: [CLLocationCoordinate2D] = []
    @Published private(set) var authorizationStatus: CLAuthorizationStatus

    private let manager = CLLocationManager()
    private var lastLocation: CLLocation?
    private var startedAt: Date?

    override init() {
        authorizationStatus = manager.authorizationStatus
        super.init()
        manager.delegate = self
        manager.activityType = .fitness
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.distanceFilter = 5
        manager.pausesLocationUpdatesAutomatically = false
        manager.allowsBackgroundLocationUpdates = true
    }

    func start() {
        if authorizationStatus == .notDetermined {
            manager.requestAlwaysAuthorization()
        }
        isRecording = true
        isPaused = false
        distance = 0
        route = []
        lastLocation = nil
        startedAt = Date()
        manager.startUpdatingLocation()
    }

    func togglePause() {
        guard isRecording else { return }
        isPaused.toggle()
        if isPaused {
            manager.stopUpdatingLocation()
        } else {
            manager.startUpdatingLocation()
        }
    }

    func finish() {
        isRecording = false
        isPaused = false
        manager.stopUpdatingLocation()
        lastLocation = nil
        startedAt = nil
    }
}

extension LocationManager: CLLocationManagerDelegate {
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            authorizationStatus = manager.authorizationStatus
            if authorizationStatus == .authorizedAlways || authorizationStatus == .authorizedWhenInUse {
                if isRecording && !isPaused {
                    manager.startUpdatingLocation()
                }
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        Task { @MainActor in
            guard isRecording, !isPaused else { return }
            for location in locations where location.horizontalAccuracy >= 0 {
                if let lastLocation {
                    distance += location.distance(from: lastLocation)
                }
                lastLocation = location
                route.append(location.coordinate)
            }
        }
    }
}
