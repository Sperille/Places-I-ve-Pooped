//
//  FriendsView.swift
//  Places I've Pooped
//
//  Created by Steven Perille on 8/8/25.
//

import SwiftUI

struct FriendsView: View {
    @EnvironmentObject private var userManager: UserManager
    @State private var searchText = ""
    @State private var showAddFriend = false
    
    var filteredFriends: [Friend] {
        if searchText.isEmpty {
            return userManager.friends
        } else {
            return userManager.friends.filter { friend in
                friend.name.localizedCaseInsensitiveContains(searchText)
            }
        }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Search Bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    
                    TextField("Search friends...", text: $searchText)
                        .textFieldStyle(PlainTextFieldStyle())
                    
                    if !searchText.isEmpty {
                        Button(action: {
                            searchText = ""
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color(.systemGray6))
                .cornerRadius(10)
                .padding(.horizontal, 16)
                .padding(.top, 8)
                
                // Friends List
                if userManager.friends.isEmpty {
                    VStack(spacing: 16) {
                        Spacer()
                        
                        Image(systemName: "person.2.circle")
                            .font(.system(size: 64))
                            .foregroundColor(.secondary)
                        
                        Text("No Friends Yet")
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        Text("Add friends to see their poop logs and share your experiences together.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                        
                        Button(action: {
                            showAddFriend = true
                        }) {
                            Label("Add Friend", systemImage: "person.badge.plus")
                                .font(.headline)
                                .foregroundColor(.white)
                                .padding(.horizontal, 24)
                                .padding(.vertical, 12)
                                .background(Color.brown)
                                .cornerRadius(8)
                        }
                        
                        Spacer()
                    }
                } else {
                    List {
                        ForEach(filteredFriends) { friend in
                            HStack(spacing: 12) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(friend.name)
                                        .font(.body)
                                        .fontWeight(.medium)
                                    
                                    Text("Friend")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                            }
                            .padding(.vertical, 4)
                        }
                        .onDelete(perform: deleteFriend)
                    }
                    .listStyle(PlainListStyle())
                }
            }
            .navigationTitle("Friends")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: {
                        showAddFriend = true
                    }) {
                        Image(systemName: "person.badge.plus")
                            .font(.title3)
                    }
                    .disabled(userManager.friends.isEmpty)
                }
            }
        }
        .sheet(isPresented: $showAddFriend) {
            AddFriendView()
        }
    }
    
    private func deleteFriend(offsets: IndexSet) {
        // Remove friends from the local array
        for index in offsets {
            let friend = filteredFriends[index]
            userManager.friends.removeAll { $0.id == friend.id }
        }
        // TODO: Remove from CloudKit as well
    }
}

#Preview {
    FriendsView()
        .environmentObject(UserManager())
}
