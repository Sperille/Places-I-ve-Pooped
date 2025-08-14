//
//  LogPoopView.swift
//  Places I've Pooped
//
//  Created by Steven Perille on 7/3/25.
//

import SwiftUI
import MapKit
import PhotosUI
import _MapKit_SwiftUI

struct LogPoopView: View {
    @EnvironmentObject var poopManager: PoopManager
    @EnvironmentObject var auth: AuthManager
    @EnvironmentObject var groupsManager: GroupsManager
    @Environment(\.presentationMode) var presentationMode

    @State private var tpRating = 3
    @State private var cleanliness = 3
    @State private var privacy = 3
    @State private var plumbing = 3
    @State private var overallVibes = 3
    @State private var comment = ""
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var selectedImageData: Data?

    @StateObject private var locationManager = LocationManager()

    var body: some View {
        NavigationView {
            ScrollView {
            VStack(spacing: 20) {
                // Location Display
                VStack(alignment: .leading, spacing: 8) {
                    Text("Location")
                        .font(.headline)
                    
                    if !locationManager.locationDescription.isEmpty {
                        Text(locationManager.locationDescription)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    // Map showing current location
                    Map(position: .constant(.region(locationManager.region))) {
                        UserAnnotation()
                    }
                    .frame(height: 200)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }

                // Rating Categories
                VStack(spacing: 16) {
                    StarRatingView(rating: $tpRating, label: "Toilet Paper")

                    Divider()
                        .frame(height: 1)
                        .background(Color(hex: "#A67C52"))

                    StarRatingView(rating: $cleanliness, label: "Cleanliness")

                    Divider()
                        .frame(height: 1)
                        .background(Color(hex: "#A67C52"))

                    StarRatingView(rating: $privacy, label: "Privacy")

                    Divider()
                        .frame(height: 1)
                        .background(Color(hex: "#A67C52"))

                    StarRatingView(rating: $plumbing, label: "Plumbing")

                    Divider()
                        .frame(height: 1)
                        .background(Color(hex: "#A67C52"))

                    StarRatingView(rating: $overallVibes, label: "Overall Vibes")
                }
                .frame(maxWidth: .infinity)
                .multilineTextAlignment(.center)

                // Comment Section
                VStack(alignment: .leading, spacing: 8) {
                    Text("Comment (Optional)")
                        .font(.headline)
                    
                    ZStack(alignment: .topLeading) {
                        if comment.isEmpty {
                            Text("Leave a comment...")
                                .foregroundColor(.gray)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                        }

                        TextEditor(text: $comment)
                            .frame(minHeight: 120)
                            .padding(8)
                            .background(Color(.systemGray6))
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(Color(.systemGray4), lineWidth: 1)
                            )
                            .cornerRadius(10)
                            .toolbar {
                                ToolbarItemGroup(placement: .keyboard) {
                                    Spacer()
                                    Button("Done") {
                                        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                                    }
                                }
                            }
                    }
                }

                // Photo Picker
                VStack(alignment: .leading, spacing: 8) {
                    Text("Add Photo (Optional)")
                        .font(.headline)
                    
                    PhotosPicker(selection: $selectedPhoto, matching: .images) {
                        if let selectedImageData,
                           let uiImage = UIImage(data: selectedImageData) {
                            Image(uiImage: uiImage)
                                .resizable()
                                .scaledToFill()
                                .frame(maxWidth: .infinity)
                                .frame(height: 200)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        } else {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color(.systemGray5))
                                .frame(maxWidth: .infinity)
                                .frame(height: .infinity)
                                .frame(height: 200)
                                .overlay(
                                    VStack {
                                        Image(systemName: "camera.fill")
                                            .font(.largeTitle)
                                            .foregroundColor(.secondary)
                                        Text("Tap to add photo")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                )
                        }
                    }
                }

                // Brown Save Poop Button
                Button(action: savePoop) {
                    Text("Save Poop")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.brown)
                        .cornerRadius(12)
                }
                .padding(.top, 20)

                Spacer()
            }
            .padding()
        }
        .navigationTitle("Log a Poop")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Cancel") {
                    presentationMode.wrappedValue.dismiss()
                }
                .foregroundColor(.red)
            }
            
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Save Poop") {
                    savePoop()
                }
                .foregroundColor(.brown)
                .fontWeight(.semibold)
            }
        }
        }
        .onChange(of: selectedPhoto) { _ in
            Task {
                if let data = try? await selectedPhoto?.loadTransferable(type: Data.self) {
                    selectedImageData = data
                }
            }
        }
    }
    
    // MARK: - Helper Functions
    
    private func savePoop() {
        Task {
            // Ensure userID is available, otherwise return early
            guard let userID = auth.currentUserRecordID?.recordName else {
                print("Error: User not logged in. Cannot log poop without a user ID.")
                return
            }

            // Get the current location coordinate
            let center = locationManager.currentCoordinate

            // Get current group ID if user is in a group
            let currentGroupID = groupsManager.currentGroupID

            // Get user's color from group membership
            let userColor = await getUserColorFromGroup()

            // Save photo if selected
            var photoURL: URL? = nil
            if let selectedImageData {
                let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
                let fileName = "poop_photo_\(UUID().uuidString).jpg"
                let fileURL = documentsDirectory.appendingPathComponent(fileName)
                
                do {
                    try selectedImageData.write(to: fileURL)
                    photoURL = fileURL
                } catch {
                    print("Error saving photo: \(error)")
                }
            }

            // Get the proper user name
            let userName = getProperUserName()
            
            // Log the poop entry using PoopManager
            poopManager.addPoopPin(
                userID: userID,
                userName: userName,
                userColor: userColor,
                groupID: currentGroupID,
                coordinate: center,
                locationDescription: locationManager.locationDescription.isEmpty ? "Current Location" : locationManager.locationDescription,
                tpRating: tpRating,
                cleanliness: cleanliness,
                privacy: privacy,
                plumbing: plumbing,
                overallVibes: overallVibes,
                comment: comment,
                photoURL: photoURL
            )

            // Dismiss the view upon successful logging
            presentationMode.wrappedValue.dismiss()
        }
    }
    
    private func getUserColorFromGroup() async -> Color? {
        guard let userID = auth.currentUserRecordID?.recordName else { 
            return nil 
        }
        
        // First try to get color from group members
        if let groupID = groupsManager.currentGroupID {
            // If members aren't loaded yet, fetch them
            if groupsManager.members.isEmpty {
                groupsManager.fetchMembers(groupID: groupID)
                // Give a small delay for the fetch to complete
                try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
            }
            
            // Now try to find the user's color
            if let member = groupsManager.members.first(where: { $0.userID == userID }) {
                return member.color
            }
        }
        
        // Fallback: try to get color from UserDefaults (if user has set a color before)
        if let colorHex = UserDefaults.standard.string(forKey: "user.color.hex") {
            // Simple hex to color conversion
            let hex = colorHex.trimmingCharacters(in: .whitespacesAndNewlines)
            if hex.hasPrefix("#") {
                let start = hex.index(hex.startIndex, offsetBy: 1)
                let hexColor = String(hex[start...])
                
                if let rgbValue = UInt(hexColor, radix: 16) {
                    let red = Double((rgbValue >> 16) & 0xFF) / 255.0
                    let green = Double((rgbValue >> 8) & 0xFF) / 255.0
                    let blue = Double(rgbValue & 0xFF) / 255.0
                    let color = Color(red: red, green: green, blue: blue)
                    return color
                }
            }
        }
        
        return nil // Will use default blue color
    }
    
    private func getProperUserName() -> String {
        // Try to get name from multiple sources
        let authName = auth.currentUserName.trimmingCharacters(in: .whitespacesAndNewlines)
        let defaultsName = UserDefaults.standard.string(forKey: "auth.displayName")?.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Use auth name if available, otherwise try UserDefaults, otherwise fallback
        return authName.isEmpty ? (defaultsName ?? "User") : authName
    }
}

// MARK: - Preview Provider

#Preview {
    LogPoopView()
        // Provide required environment objects for the preview
        .environmentObject(PoopManager())
        .environmentObject(AuthManager())
        .environmentObject(GroupsManager())
}
