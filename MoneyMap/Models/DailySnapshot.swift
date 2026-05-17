import Foundation
import SwiftData

@Model
final class DailySnapshot {
    @Attribute(.unique) var date: Date
    var totalValueCNY: Double
    var cashValue: Double
    var moneyFundValue: Double
    var fundValue: Double
    var stockAValue: Double
    var stockHKValue: Double
    var stockUSValue: Double
    var pendingValue: Double
    var dailyChange: Double
    var dailyChangePct: Double

    init(
        date: Date,
        totalValueCNY: Double,
        cashValue: Double = 0,
        moneyFundValue: Double = 0,
        fundValue: Double = 0,
        stockAValue: Double = 0,
        stockHKValue: Double = 0,
        stockUSValue: Double = 0,
        pendingValue: Double = 0,
        dailyChange: Double = 0,
        dailyChangePct: Double = 0
    ) {
        self.date = date
        self.totalValueCNY = totalValueCNY
        self.cashValue = cashValue
        self.moneyFundValue = moneyFundValue
        self.fundValue = fundValue
        self.stockAValue = stockAValue
        self.stockHKValue = stockHKValue
        self.stockUSValue = stockUSValue
        self.pendingValue = pendingValue
        self.dailyChange = dailyChange
        self.dailyChangePct = dailyChangePct
    }
}
