//
//  PoopManager+Cloudkit.swift
//  Places I've Pooped
//
//  Created by Steven Perille on 8/8/25.
//

import Foundation
import CloudKit

extension PoopManager {
    func replaceWithCloudKitRecords(_ records: [CKRecord]) {
        let mapped = records.compactMap { PoopPin.fromCKRecord($0) }
        DispatchQueue.main.async {
            self.poopPins = mapped
        }
    }
}
