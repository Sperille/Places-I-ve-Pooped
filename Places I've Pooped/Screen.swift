//
//  Screen.swift
//  Places I've Pooped
//

import Foundation

/// App-level navigation targets used by the bottom bar.
enum Screen: Hashable {
    case dashboard
    case map
    case groups
    case friends

    // Keep these for sheets or deep links if you still use them.
    case account
    case settings
}
