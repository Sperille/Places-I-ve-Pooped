//
//  GroupMember.swift
//  Places I've Pooped
//
//  Created by Steven Perille on 8/4/25.
//

import SwiftUI

struct GroupMember: Identifiable {
    let id: String
    let userID: String
    let name: String
    let color: Color
    let joinedAt: Date
}
