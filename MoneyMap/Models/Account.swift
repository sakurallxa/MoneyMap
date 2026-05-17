import Foundation
import SwiftData

@Model
final class Account {
    @Attribute(.unique) var id: UUID
    var name: String
    var typeRaw: String
    var currencyRaw: String
    var cashBalance: Double
    var note: String
    var createdAt: Date
    var updatedAt: Date

    @Relationship(deleteRule: .cascade, inverse: \Position.account)
    var positions: [Position] = []

    init(
        id: UUID = UUID(),
        name: String,
        type: AccountType,
        currency: CurrencyCode = .cny,
        cashBalance: Double = 0,
        note: String = ""
    ) {
        self.id = id
        self.name = name
        self.typeRaw = type.rawValue
        self.currencyRaw = currency.rawValue
        self.cashBalance = cashBalance
        self.note = note
        self.createdAt = Date()
        self.updatedAt = Date()
    }

    var type: AccountType {
        AccountType(rawValue: typeRaw) ?? .cash
    }

    var currency: CurrencyCode {
        CurrencyCode(rawValue: currencyRaw) ?? .cny
    }
}
