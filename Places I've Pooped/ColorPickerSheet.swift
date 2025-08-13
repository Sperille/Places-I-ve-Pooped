//
//  ColorPickerSheet.swift
//  Places I've Pooped
//

import SwiftUI

struct ColorPickerSheet: View {
    @Binding var selectedColor: Color
    let onColorSelected: (Color) -> Void
    @Environment(\.dismiss) private var dismiss
    
    @State private var hue: Double = 0.0
    @State private var saturation: Double = 1.0
    @State private var brightness: Double = 1.0
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                Text("Choose Your Color")
                    .font(.title2)
                    .fontWeight(.bold)
                    .padding(.top)
                
                // Current color preview
                VStack(spacing: 8) {
                    Text("Current Color")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Circle()
                        .fill(selectedColor)
                        .frame(width: 80, height: 80)
                        .overlay(
                            Circle()
                                .stroke(Color.primary.opacity(0.2), lineWidth: 2)
                        )
                }
                
                // Color wheel
                VStack(spacing: 16) {
                    Text("Color Wheel")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    ZStack {
                        // Color wheel background
                        Circle()
                            .fill(
                                AngularGradient(
                                    gradient: Gradient(colors: [
                                        Color.red, Color.orange, Color.yellow, Color.green,
                                        Color.blue, Color.purple, Color.pink, Color.red
                                    ]),
                                    center: .center
                                )
                            )
                            .frame(width: 200, height: 200)
                            .overlay(
                                Circle()
                                    .stroke(Color.primary.opacity(0.2), lineWidth: 2)
                            )
                        
                        // Brightness overlay
                        Circle()
                            .fill(
                                RadialGradient(
                                    gradient: Gradient(colors: [
                                        Color.white.opacity(1 - brightness),
                                        Color.clear
                                    ]),
                                    center: .center,
                                    startRadius: 0,
                                    endRadius: 100
                                )
                            )
                            .frame(width: 200, height: 200)
                        
                        // Selection indicator
                        Circle()
                            .fill(Color.white)
                            .frame(width: 20, height: 20)
                            .overlay(
                                Circle()
                                    .stroke(Color.black, lineWidth: 2)
                            )
                            .position(
                                x: 100 + cos(hue * 2 * .pi) * 80 * saturation,
                                y: 100 + sin(hue * 2 * .pi) * 80 * saturation
                            )
                    }
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                let center = CGPoint(x: 100, y: 100)
                                let deltaX = value.location.x - center.x
                                let deltaY = value.location.y - center.y
                                
                                // Calculate hue from angle
                                let angle = atan2(deltaY, deltaX)
                                hue = (angle + .pi) / (2 * .pi)
                                
                                // Calculate saturation from distance
                                let distance = sqrt(deltaX * deltaX + deltaY * deltaY)
                                saturation = min(distance / 80, 1.0)
                                
                                updateSelectedColor()
                            }
                    )
                }
                
                // Brightness slider
                VStack(spacing: 8) {
                    Text("Brightness")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    HStack {
                        Image(systemName: "sun.min")
                            .foregroundColor(.secondary)
                        
                        Slider(value: $brightness, in: 0...1) { _ in
                            updateSelectedColor()
                        }
                        .accentColor(.orange)
                        
                        Image(systemName: "sun.max")
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.horizontal)
                
                Spacer()
                
                // Action buttons
                HStack(spacing: 16) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .buttonStyle(.bordered)
                    
                    Button("Apply") {
                        onColorSelected(selectedColor)
                        dismiss()
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding(.bottom)
            }
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                // Initialize sliders from current color
                let uiColor = UIColor(selectedColor)
                var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
                uiColor.getHue(&h, saturation: &s, brightness: &b, alpha: &a)
                
                hue = Double(h)
                saturation = Double(s)
                brightness = Double(b)
            }
        }
    }
    
    private func updateSelectedColor() {
        selectedColor = Color(hue: hue, saturation: saturation, brightness: brightness)
    }
}




