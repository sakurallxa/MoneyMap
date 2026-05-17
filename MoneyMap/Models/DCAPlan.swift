import Foundation
import SwiftData

@Model
final class DCAPlan {
    @Attribute(.unique) var id: UUID
    var name: String
    var sourceAccountID: UUID
    var sourceAccountName: String
    var targetAccountID: UUID
    var targetAccountName: String
    var targetAssetCode: String
    var targetAssetName: String
    var amount: Double
    var frequencyRaw: String
    /// 每周/每两周时使用,1=周一, 7=周日
    var dayOfWeek: Int
    /// 每月时使用,1-28
    var dayOfMonth: Int
    var nextRunDate: Date
    var lastRunDate: Date?
    var isActive: Bool
    var createdAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        sourceAccountID: UUID,
        sourceAccountName: String,
        targetAccountID: UUID,
        targetAccountName: String,
        targetAssetCode: String,
        targetAssetName: String,
        amount: Double,
        frequency: DCAFrequency,
        nextRunDate: Date,
        dayOfWeek: Int = 1,
        dayOfMonth: Int = 1,
        isActive: Bool = true
    ) {
        self.id = id
        self.name = name
        self.sourceAccountID = sourceAccountID
        self.sourceAccountName = sourceAccountName
        self.targetAccountID = targetAccountID
        self.targetAccountName = targetAccountName
        self.targetAssetCode = targetAssetCode
        self.targetAssetName = targetAssetName
        self.amount = amount
        self.frequencyRaw = frequency.rawValue
        self.dayOfWeek = dayOfWeek
        self.dayOfMonth = dayOfMonth
        self.nextRunDate = nextRunDate
        self.isActive = isActive
        self.createdAt = Date()
    }

    var frequency: DCAFrequency {
        DCAFrequency(rawValue: frequencyRaw) ?? .weekly
    }
}
