import Foundation
import SwiftData

@Model
final class TransactionRecord {
    @Attribute(.unique) var id: UUID
    var tradeDate: Date
    var confirmDate: Date?
    var typeRaw: String
    var statusRaw: String

    var fromAccountID: UUID?
    var toAccountID: UUID?
    var fromAccountName: String
    var toAccountName: String

    var assetCode: String
    var assetName: String

    var amount: Double
    var shares: Double
    var price: Double
    var fee: Double
    var note: String

    var dcaPlanID: UUID?

    var sourceBalanceBefore: Double
    var sourceBalanceAfter: Double
    var targetBalanceBefore: Double
    var targetBalanceAfter: Double

    init(
        id: UUID = UUID(),
        tradeDate: Date = Date(),
        type: TransactionType,
        status: TransactionStatus = .completed,
        fromAccountID: UUID? = nil,
        toAccountID: UUID? = nil,
        fromAccountName: String = "",
        toAccountName: String = "",
        assetCode: String = "",
        assetName: String = "",
        amount: Double = 0,
        shares: Double = 0,
        price: Double = 0,
        fee: Double = 0,
        note: String = "",
        dcaPlanID: UUID? = nil,
        sourceBalanceBefore: Double = -1,
        sourceBalanceAfter: Double = -1,
        targetBalanceBefore: Double = -1,
        targetBalanceAfter: Double = -1
    ) {
        self.id = id
        self.tradeDate = tradeDate
        self.confirmDate = status == .confirmed || status == .completed ? tradeDate : nil
        self.typeRaw = type.rawValue
        self.statusRaw = status.rawValue
        self.fromAccountID = fromAccountID
        self.toAccountID = toAccountID
        self.fromAccountName = fromAccountName
        self.toAccountName = toAccountName
        self.assetCode = assetCode
        self.assetName = assetName
        self.amount = amount
        self.shares = shares
        self.price = price
        self.fee = fee
        self.note = note
        self.dcaPlanID = dcaPlanID
        self.sourceBalanceBefore = sourceBalanceBefore
        self.sourceBalanceAfter = sourceBalanceAfter
        self.targetBalanceBefore = targetBalanceBefore
        self.targetBalanceAfter = targetBalanceAfter
    }

    var hasSourceBalanceTrail: Bool {
        sourceBalanceBefore >= 0 && sourceBalanceAfter >= 0
    }
    var hasTargetBalanceTrail: Bool {
        targetBalanceBefore >= 0 && targetBalanceAfter >= 0
    }

    var type: TransactionType {
        TransactionType(rawValue: typeRaw) ?? .buyFund
    }

    var status: TransactionStatus {
        TransactionStatus(rawValue: statusRaw) ?? .completed
    }

    /// 不含手续费的"账面金额" — 用于展示"这笔交易的本金"。
    var signedAmount: Double {
        switch type {
        case .buyFund, .buyStock, .dcaDeduct, .withdraw:
            return -amount
        case .sellFund, .sellStock, .dividend, .deposit:
            return amount
        case .dcaConfirm, .transfer:
            return 0
        }
    }

    /// 净现金流(含手续费)— 用于"实际从现金账户进出多少钱"的展示。
    /// 买入/扣款:`-(amount + fee)`,卖出:`+(amount - fee)`。
    /// 月度净流入、列表 row 右侧金额展示一律走这个。
    var netSignedCashAmount: Double {
        switch type {
        case .buyFund, .buyStock, .dcaDeduct:
            return -(amount + fee)
        case .sellFund, .sellStock:
            return amount - fee
        case .withdraw:
            return -amount
        case .dividend, .deposit:
            return amount
        case .dcaConfirm, .transfer:
            return 0
        }
    }
}
