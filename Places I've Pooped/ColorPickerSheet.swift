//
//  ColorPickerSheet.swift
//  Places I've Pooped
//

import SwiftUI

struct ColorPickerSheet: View {
    @Binding var selectedColor: Color
    let onColorSelected: (Color) -> Void
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header
                VStack(spacing: 16) {
                    Text("Choose Your Color")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .padding(.top)
                    
                    // Current color preview
                    VStack(spacing: 8) {
                        Text("Selected Color")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        RoundedRectangle(cornerRadius: 16)
                            .fill(selectedColor)
                            .frame(width: 60, height: 60)
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(Color.primary.opacity(0.1), lineWidth: 1)
                            )
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 24)
                
                // Apple's native ColorPicker
                VStack(spacing: 20) {
                    ColorPicker("Select Color", selection: $selectedColor, supportsOpacity: false)
                        .labelsHidden()
                        .scaleEffect(1.2)
                }
                .padding(.horizontal)
                
                Spacer()
                
                // Action buttons
                VStack(spacing: 12) {
                    Button("Apply Color") {
                        onColorSelected(selectedColor)
                        dismiss()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    
                    Button("Cancel") {
                        dismiss()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                }
                .padding(.horizontal)
                .padding(.vertical, 20)
            }
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarHidden(true)
        }
    }
}




