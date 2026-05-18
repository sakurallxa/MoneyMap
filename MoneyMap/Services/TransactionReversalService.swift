import Foundation
import SwiftData

/// 删除已记录的交易时,把它对持仓 / 现金账户的影响反向应用,
/// 保证"删除后数据自洽":删一笔买入会自动减仓 + 退还现金;删卖出会反向加仓 + 扣回现金;等等。
///
/// 设计原则
/// - 1a:Position.shares 反向后归零时,直接删除该 Position(不保留 0 持仓僵尸)
/// - 2a:若反向后 shares 会 < 0(说明该交易后还有过后续卖出/确认),拒绝删除,Toast 报错
enum TransactionReversalService {
    enum ReversalError: LocalizedError {
        case wouldGoNegative(assetName: String)
        case missingReferences

        var errorDescription: String? {
            switch self {
            case .wouldGoNegative(let n):
                return "删除会让「\(n)」的持仓变成负数,请先撤销后续卖出 / 确认再试"
            case .missingReferences:
                return "关联账户或持仓已经不存在,无法回退资产数据"
            }
        }
    }

    /// 入口 — 删除交易并反向应用其副作用。失败时抛错。
    static func deleteWithReversal(_ tx: TransactionRecord, context: ModelContext) throws {
        let accounts = (try? context.fetch(FetchDescriptor<Account>())) ?? []
        let positions = (try? context.fetch(FetchDescriptor<Position>())) ?? []

        switch tx.type {
        case .buyFund, .buyStock:
            try reverseBuy(tx: tx, accounts: accounts, positions: positions, context: context)
        case .sellFund, .sellStock:
            try reverseSell(tx: tx, accounts: accounts, positions: positions, context: context)
        case .dividend:
            try reverseDividend(tx: tx, accounts: accounts)
        case .dcaDeduct:
            try reverseDcaDeduct(tx: tx, accounts: accounts)
        case .dcaConfirm:
            try reverseDcaConfirm(tx: tx, positions: positions, context: context)
        case .deposit:
            try reverseDeposit(tx: tx, accounts: accounts)
        case .withdraw:
            try reverseWithdraw(tx: tx, accounts: accounts)
        case .transfer:
            try reverseTransfer(tx: tx, accounts: accounts)
        }

        context.delete(tx)
        try context.save()
    }

    // MARK: - 各类型反向逻辑

    /// 买入 — 反向:持仓 shares 减回 / totalCost 减回 / avgCost 重算 / 现金账户余额加回。
    private static func reverseBuy(
        tx: TransactionRecord, accounts: [Account], positions: [Position], context: ModelContext
    ) throws {
        guard let posAccID = tx.toAccountID,
              let pos = positions.first(where: { $0.account?.id == posAccID && $0.assetCode == tx.assetCode })
        else { throw ReversalError.missingReferences }

        let newShares = pos.shares - tx.shares
        if newShares < -0.000001 {
            throw ReversalError.wouldGoNegative(assetName: pos.assetName)
        }

        let newTotalCost = pos.totalCost - tx.amount
        if newShares <= 0.000001 {
            // 1a:仓清空,删 Position
            context.delete(pos)
        } else {
            pos.shares = newShares
            pos.avgCost = max(0, newTotalCost / newShares)
            pos.updatedAt = Date()
        }

        // 现金账户回退(钱回到 fromAccount)
        if let from = tx.fromAccountID, let cash = accounts.first(where: { $0.id == from }) {
            cash.cashBalance += tx.amount
            cash.updatedAt = Date()
        }
    }

    /// 卖出 — 反向:持仓 shares 加回 / 现金账户减回。avgCost 不变(卖出本就不改 avgCost)。
    private static func reverseSell(
        tx: TransactionRecord, accounts: [Account], positions: [Position], context: ModelContext
    ) throws {
        guard let posAccID = tx.fromAccountID,
              let pos = positions.first(where: { $0.account?.id == posAccID && $0.assetCode == tx.assetCode })
        else { throw ReversalError.missingReferences }

        pos.shares += tx.shares
        pos.updatedAt = Date()

        if let toID = tx.toAccountID, let cash = accounts.first(where: { $0.id == toID }) {
            cash.cashBalance = max(0, cash.cashBalance - tx.amount)
            cash.updatedAt = Date()
        }
    }

    /// 分红 — 反向:现金账户减回。持仓不动(分红本就不影响持仓)。
    private static func reverseDividend(tx: TransactionRecord, accounts: [Account]) throws {
        guard let toID = tx.toAccountID, let cash = accounts.first(where: { $0.id == toID }) else {
            throw ReversalError.missingReferences
        }
        cash.cashBalance = max(0, cash.cashBalance - tx.amount)
        cash.updatedAt = Date()
    }

    /// 定投扣款(在途)— 反向:把扣掉的钱退回现金账户。持仓尚未确认,不动。
    private static func reverseDcaDeduct(tx: TransactionRecord, accounts: [Account]) throws {
        guard let from = tx.fromAccountID, let cash = accounts.first(where: { $0.id == from }) else {
            throw ReversalError.missingReferences
        }
        cash.cashBalance += tx.amount
        cash.updatedAt = Date()
    }

    /// 定投确认 — 反向:持仓 shares / totalCost 减回。现金已在 dcaDeduct 时扣过,这里不动。
    private static func reverseDcaConfirm(
        tx: TransactionRecord, positions: [Position], context: ModelContext
    ) throws {
        guard let toID = tx.toAccountID,
              let pos = positions.first(where: { $0.account?.id == toID && $0.assetCode == tx.assetCode })
        else { throw ReversalError.missingReferences }

        let newShares = pos.shares - tx.shares
        if newShares < -0.000001 {
            throw ReversalError.wouldGoNegative(assetName: pos.assetName)
        }

        let newTotalCost = pos.totalCost - tx.amount
        if newShares <= 0.000001 {
            context.delete(pos)
        } else {
            pos.shares = newShares
            pos.avgCost = max(0, newTotalCost / newShares)
            pos.updatedAt = Date()
        }
    }

    /// 入金 — 反向:现金账户减回。
    private static func reverseDeposit(tx: TransactionRecord, accounts: [Account]) throws {
        guard let toID = tx.toAccountID, let cash = accounts.first(where: { $0.id == toID }) else {
            throw ReversalError.missingReferences
        }
        cash.cashBalance = max(0, cash.cashBalance - tx.amount)
        cash.updatedAt = Date()
    }

    /// 出金 — 反向:现金账户加回。
    private static func reverseWithdraw(tx: TransactionRecord, accounts: [Account]) throws {
        guard let from = tx.fromAccountID, let cash = accounts.first(where: { $0.id == from }) else {
            throw ReversalError.missingReferences
        }
        cash.cashBalance += tx.amount
        cash.updatedAt = Date()
    }

    /// 转账 — 反向:from 加回,to 减回。
    private static func reverseTransfer(tx: TransactionRecord, accounts: [Account]) throws {
        let from = tx.fromAccountID.flatMap { id in accounts.first { $0.id == id } }
        let to = tx.toAccountID.flatMap { id in accounts.first { $0.id == id } }
        guard let from, let to else {
            throw ReversalError.missingReferences
        }
        from.cashBalance += tx.amount
        to.cashBalance = max(0, to.cashBalance - tx.amount)
        from.updatedAt = Date()
        to.updatedAt = Date()
    }
}
