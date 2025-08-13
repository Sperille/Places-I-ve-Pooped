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
