//
//  MenuState.swift
//  Places I've Pooped
//
//  Created by Steven Perille on 7/4/25.
//

import SwiftUI

class MenuState: ObservableObject {
    @Published var showLogPoopSheet: Bool = false
    @Published var showAccountSheet: Bool = false
    @Published var showSettingsSheet: Bool = false
    @Published var currentScreen: Screen = .dashboard
}

