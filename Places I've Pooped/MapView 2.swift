
import SwiftUI
import MapKit

struct PoopPin: Identifiable {
    let id = UUID()
    let coordinate: CLLocationCoordinate2D
}

struct MapView: View {
    @StateObject private var locationManager = LocationManager()
    @State private var poopPins: [PoopPin] = []

    var body: some View {
        ZStack {
            Map(position: $locationManager.position) {
                UserAnnotation()
                ForEach(poopPins) { pin in
                    Annotation("Poop Pin", coordinate: pin.coordinate) {
                        Text("💩").font(.system(size: 30)).shadow(radius: 2)
                    }
                }
            }
            .mapControls {
                MapUserLocationButton()
            }
            .ignoresSafeArea()

            VStack {
                Spacer()
                Button(action: addPoopPin) {
                    Text("💩 Drop Pin")
                        .font(.headline)
                        .padding()
                        .background(Color.brown)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                        .shadow(radius: 4)
                }
                .padding()
            }
        }
    }

    func addPoopPin() {
        if case let .region(region) = locationManager.position {
            let newPin = PoopPin(coordinate: region.center)
            poopPins.append(newPin)
        }
    }
}

#Preview {
    MapView()
}
