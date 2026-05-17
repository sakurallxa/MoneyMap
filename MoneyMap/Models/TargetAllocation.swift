import Foundation
import SwiftData

@Model
final class TargetAllocation {
    @Attribute(.unique) var assetClassRaw: String
    var targetPercent: Double
    var updatedAt: Date

    init(assetClass: AssetClass, percent: Double) {
        self.assetClassRaw = assetClass.rawValue
        self.targetPercent = percent
        self.updatedAt = Date()
    }

    var assetClass: AssetClass {
        AssetClass(rawValue: assetClassRaw) ?? .cash
    }
}
