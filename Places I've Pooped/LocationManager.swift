//
//  LocationManager.swift
//  Places I've Pooped
//
//  Created by Steven Perille on 7/6/25.
//

import Foundation
import CoreLocation
import MapKit
import SwiftUI

class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let locationManager = CLLocationManager()

    @Published var position: MapCameraPosition = .automatic

    @Published var region: MKCoordinateRegion = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 0, longitude: 0),
        span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
    )

    @Published var locationDescription: String = ""

    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.requestWhenInUseAuthorization()
        locationManager.startUpdatingLocation()
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }

        DispatchQueue.main.async {
            self.region = MKCoordinateRegion(
                center: location.coordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
            )
            self.position = .region(self.region) // ✅ sync position for SwiftUI `Map`
            self.reverseGeocode(location)
        }
    }

    private func reverseGeocode(_ location: CLLocation) {
        let geocoder = CLGeocoder()
        geocoder.reverseGeocodeLocation(location) { placemarks, error in
            if let place = placemarks?.first {
                self.locationDescription = [
                    place.name,
                    place.locality,
                    place.administrativeArea
                ]
                .compactMap { $0 }
                .joined(separator: ", ")
            } else if let error = error {
                print("❌ Reverse geocode failed: \(error.localizedDescription)")
            }
        }
    }

    func zoomIn() {
        region.span.latitudeDelta /= 2
        region.span.longitudeDelta /= 2
        position = .region(region)
    }

    func zoomOut() {
        region.span.latitudeDelta *= 2
        region.span.longitudeDelta *= 2
        position = .region(region)
    }

    var currentCoordinate: CLLocationCoordinate2D {
        region.center
    }
}

