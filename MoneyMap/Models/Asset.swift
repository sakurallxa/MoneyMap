import Foundation
import SwiftData

@Model
final class Asset {
    @Attribute(.unique) var code: String
    var name: String
    var typeRaw: String
    var marketRaw: String
    var currencyRaw: String
    var createdAt: Date

    init(
        code: String,
        name: String,
        type: AssetType,
        market: AssetMarket,
        currency: CurrencyCode = .cny
    ) {
        self.code = code
        self.name = name
        self.typeRaw = type.rawValue
        self.marketRaw = market.rawValue
        self.currencyRaw = currency.rawValue
        self.createdAt = Date()
    }

    var type: AssetType {
        AssetType(rawValue: typeRaw) ?? .openFund
    }

    var market: AssetMarket {
        AssetMarket(rawValue: marketRaw) ?? .fund
    }

    var currency: CurrencyCode {
        CurrencyCode(rawValue: currencyRaw) ?? .cny
    }
}
