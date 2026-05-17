import Foundation
import SwiftData

@Model
final class PriceQuote {
    var assetCode: String
    var date: Date
    var price: Double
    var changePct: Double

    init(assetCode: String, date: Date, price: Double, changePct: Double = 0) {
        self.assetCode = assetCode
        self.date = date
        self.price = price
        self.changePct = changePct
    }
}

@Model
final class ExchangeRate {
    var fromCurrency: String
    var toCurrency: String
    var rate: Double
    var date: Date

    init(from: CurrencyCode, to: CurrencyCode, rate: Double, date: Date = Date()) {
        self.fromCurrency = from.rawValue
        self.toCurrency = to.rawValue
        self.rate = rate
        self.date = date
    }
}
