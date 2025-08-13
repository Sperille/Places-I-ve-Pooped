//
//  MapView.swift
//  Places I've Pooped
//

import SwiftUI
import MapKit
import CoreLocation

struct MapView: View {
    @EnvironmentObject var poopManager: PoopManager
    @EnvironmentObject var locationManager: LocationManager
    @EnvironmentObject private var menuState: MenuState

    @State private var camera: MapCameraPosition = .automatic
    @State private var selectedPin: PoopPin? = nil   // tapped pin -> detail sheet

    var body: some View {
        Map(position: $camera) {
            // Show current user location (system style)
            UserAnnotation()

            // Poop pins: Apple-style pin, dynamic color, no label
            ForEach(poopManager.poopPins) { pin in
                Annotation("", coordinate: pin.coordinate) { // empty title => no callout label
                    ZStack {
                        // Outer circle with user color
                        Circle()
                            .fill(pin.userColor)
                            .frame(width: 24, height: 24)
                        
                        // Inner circle with white (reduced size)
                        Circle()
                            .fill(.white)
                            .frame(width: 8, height: 8)
                        
                        // Map pin icon in center
                        Image(systemName: "mappin.fill")
                            .foregroundStyle(pin.userColor)
                            .font(.system(size: 12))
                    }
                        .shadow(radius: 1)
                        .contentShape(Rectangle()) // reliable hit target
                        .onTapGesture { selectedPin = pin } // open detail
                }
            }
        }
        .mapControls {
            MapUserLocationButton()
            MapCompass()
        }
        .task {
            // Keep existing fetch + initial camera behavior
            poopManager.fetchPoopPins()
            camera = .region(locationManager.region)
        }
        // Recenter to last added pin
        .onChange(of: poopManager.lastAddedPin?.id) { _ in
            guard let pin = poopManager.lastAddedPin else { return }
            withAnimation(.easeInOut) {
                camera = .region(MKCoordinateRegion(
                    center: pin.coordinate,
                    span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                ))
            }
        }
        // Follow location updates until the user moves the map
        .onReceive(locationManager.$region) { new in
            if case .automatic = camera { camera = .region(new) }
        }
        // Detail sheet for tapped pin
        .sheet(item: $selectedPin) { pin in
            PoopDetailView(poop: pin)
        }
        .navigationTitle("Map")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { menuState.currentScreen = .account } label: {
                    Image(systemName: "person.crop.circle.fill")
                        .symbolRenderingMode(.hierarchical)
                        .font(.title2)
                }
                .accessibilityLabel("Account")
            }
        }
    }
}
