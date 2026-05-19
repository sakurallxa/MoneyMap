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
    /// ⚠️ DEPRECATED:历史字段,语义曾发生过破坏性变化(先金额后费率),不要再读写。
    /// 仅保留以避免 SwiftData 迁移问题。新代码一律使用 `feeRatePercent`。
    var feePerRun: Double = 0
    /// 手续费率(% 单位,默认 0)。实际手续费 = amount × feeRatePercent / 100。
    /// 例如:0.15 表示 0.15%。扣款时按计算后的绝对值从现金额外扣除,确认时计入持仓 avgCost。
    var feeRatePercent: Double = 0
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
        feeRatePercent: Double = 0,
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
        self.feeRatePercent = feeRatePercent
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
