//
//  ColorPickerSheet.swift
//  Places I've Pooped
//

import SwiftUI

struct ColorPickerSheet: View {
    @Binding var selectedColor: Color
    let onColorSelected: (Color) -> Void
    @Environment(\.dismiss) private var dismiss
    
    @State private var hexInput: String = ""
    @State private var showingError = false
    @State private var errorMessage = ""
    
    // Predefined colors for quick selection
    private let quickColors: [Color] = [
        .red, .orange, .yellow, .green, .blue, .purple, .pink,
        .brown, .gray, .black, .cyan, .mint, .indigo, .teal
    ]
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
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
                
                // Hex input section
                VStack(alignment: .leading, spacing: 8) {
                    Text("Hex Color Code")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    HStack {
                        Text("#")
                            .font(.title3)
                            .foregroundColor(.secondary)
                        
                        TextField("FFFFFF", text: $hexInput)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .textInputAutocapitalization(.never)
                            .disableAutocorrection(true)
                            .onChange(of: hexInput) { _, newValue in
                                // Remove any non-hex characters and limit to 6 characters
                                let filtered = newValue.filter { "0123456789ABCDEFabcdef".contains($0) }
                                hexInput = String(filtered.prefix(6)).uppercased()
                                
                                // Update color if valid hex
                                if hexInput.count == 6 {
                                    selectedColor = Color(hex: hexInput)
                                }
                            }
                    }
                    
                    if showingError {
                        Text(errorMessage)
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                }
                .padding(.horizontal)
                
                // Quick color selection
                VStack(alignment: .leading, spacing: 12) {
                    Text("Quick Colors")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .padding(.horizontal)
                    
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 12) {
                        ForEach(quickColors, id: \.self) { color in
                            Button(action: {
                                selectedColor = color
                                hexInput = color.toHex() ?? ""
                                showingError = false
                            }) {
                                Circle()
                                    .fill(color)
                                    .frame(width: 40, height: 40)
                                    .overlay(
                                        Circle()
                                            .stroke(selectedColor == color ? Color.blue : Color.clear, lineWidth: 2)
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal)
                }
                
                Spacer()
                
                // Action buttons
                HStack(spacing: 16) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .buttonStyle(.bordered)
                    
                    Button("Apply") {
                        if hexInput.count == 6 {
                            let color = Color(hex: hexInput)
                            onColorSelected(color)
                            dismiss()
                        } else {
                            showingError = true
                            errorMessage = "Please enter a valid 6-digit hex color code"
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(hexInput.count != 6)
                }
                .padding(.bottom)
            }
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                // Initialize hex input with current color
                hexInput = selectedColor.toHex()
            }
        }
    }
}




