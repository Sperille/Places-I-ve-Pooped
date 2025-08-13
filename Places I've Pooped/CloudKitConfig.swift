//
//  CloudKitConfig.swift
//  Places I've Pooped
//
//  Created by Steven Perille on 8/8/25.
//

import CloudKit

enum CKEnv {
    static let container = CKContainer(identifier: "iCloud.PlacesIvePooped")
    static let publicDB  = container.publicCloudDatabase
    static let privateDB = container.privateCloudDatabase
}
