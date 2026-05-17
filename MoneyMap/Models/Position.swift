import Foundation
import SwiftData

@Model
final class Position {
    @Attribute(.unique) var id: UUID
    var assetCode: String
    var assetName: String
    var shares: Double
    var avgCost: Double
    var lastPrice: Double
    var prevClosePrice: Double
    var weekAgoPrice: Double
    var monthAgoPrice: Double
    var yearStartPrice: Double
    var updatedAt: Date

    var account: Account?

    init(
        id: UUID = UUID(),
        account: Account,
        assetCode: String,
        assetName: String,
        shares: Double,
        avgCost: Double = 0,
        lastPrice: Double = 0,
        prevClosePrice: Double = 0,
        weekAgoPrice: Double = 0,
        monthAgoPrice: Double = 0,
        yearStartPrice: Double = 0
    ) {
        self.id = id
        self.account = account
        self.assetCode = assetCode
        self.assetName = assetName
        self.shares = shares
        self.avgCost = avgCost
        self.lastPrice = lastPrice
        self.prevClosePrice = prevClosePrice == 0 ? lastPrice : prevClosePrice
        self.weekAgoPrice = weekAgoPrice == 0 ? lastPrice : weekAgoPrice
        self.monthAgoPrice = monthAgoPrice == 0 ? lastPrice : monthAgoPrice
        self.yearStartPrice = yearStartPrice == 0 ? lastPrice : yearStartPrice
        self.updatedAt = Date()
    }

    var marketValue: Double {
        shares * lastPrice
    }

    var totalCost: Double {
        shares * avgCost
    }

    var unrealizedPnL: Double {
        marketValue - totalCost
    }

    var unrealizedPnLPercent: Double {
        guard totalCost > 0 else { return 0 }
        return (marketValue - totalCost) / totalCost * 100
    }

    var effectiveCurrency: CurrencyCode {
        if assetCode.hasSuffix(".US") { return .usd }
        if assetCode.hasSuffix(".HK") { return .hkd }
        if let t = account?.type {
            switch t {
            case .brokerUS: return .usd
            case .brokerHK: return .hkd
            case .goldDeposit, .goldPhysical: return .cny
            default: break
            }
        }
        return account?.currency ?? .cny
    }

    var assetClass: AssetClass {
        // 任何账户里只要代码是黄金 ETF,优先归到 .gold
        if GoldRecognizer.isGoldAssetCode(assetCode) { return .gold }
        guard let t = account?.type else { return .fund }
        switch t {
        case .goldDeposit, .goldPhysical: return .gold
        case .fundApp: return .fund
        case .brokerA: return .stockA
        case .brokerHK: return .stockHK
        case .brokerUS: return .stockUS
        case .brokerHKUS:
            return assetCode.hasSuffix(".US") ? .stockUS : .stockHK
        case .cash, .moneyFund: return .fund
        }
    }

    var dailyPnL: Double { shares * (lastPrice - prevClosePrice) }
    var weeklyPnL: Double { shares * (lastPrice - weekAgoPrice) }
    var monthlyPnL: Double { shares * (lastPrice - monthAgoPrice) }
    var ytdPnL: Double { shares * (lastPrice - yearStartPrice) }

    var dailyPnLPercent: Double {
        guard prevClosePrice > 0 else { return 0 }
        return (lastPrice - prevClosePrice) / prevClosePrice * 100
    }
    var weeklyPnLPercent: Double {
        guard weekAgoPrice > 0 else { return 0 }
        return (lastPrice - weekAgoPrice) / weekAgoPrice * 100
    }
    var monthlyPnLPercent: Double {
        guard monthAgoPrice > 0 else { return 0 }
        return (lastPrice - monthAgoPrice) / monthAgoPrice * 100
    }
    var ytdPnLPercent: Double {
        guard yearStartPrice > 0 else { return 0 }
        return (lastPrice - yearStartPrice) / yearStartPrice * 100
    }
}
