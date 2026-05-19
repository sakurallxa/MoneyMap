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
            try reverseDcaDeduct(tx: tx, accounts: accounts, positions: positions, context: context)
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

    // MARK: - 共用 helper

    /// 对指定账户的指定资产做"反向减仓":shares 减回、totalCost 减回(本金+手续费)、avgCost 重算;
    /// 减到 ≤epsilon 时删除 Position;减后 <-epsilon 时抛 wouldGoNegative;
    /// 找不到 Position 时抛 missingReferences。
    /// 被 reverseBuy / reverseDcaConfirm / reverseDcaDeduct(settled) 共用。
    /// 注意:Position.totalCost 是含手续费的,所以反向时也要减 (amount + fee)。
    private static func reducePositionForAsset(
        accountID: UUID,
        assetCode: String,
        shares: Double,
        amount: Double,
        fee: Double,
        positions: [Position],
        context: ModelContext
    ) throws {
        guard let pos = positions.first(where: { $0.account?.id == accountID && $0.assetCode == assetCode })
        else { throw ReversalError.missingReferences }

        let newShares = pos.shares - shares
        if newShares < -0.000001 {
            throw ReversalError.wouldGoNegative(assetName: pos.assetName)
        }

        let newTotalCost = pos.totalCost - (amount + fee)
        if newShares <= 0.000001 {
            context.delete(pos)
        } else {
            pos.shares = newShares
            pos.avgCost = max(0, newTotalCost / newShares)
            pos.updatedAt = Date()
        }
    }

    // MARK: - 各类型反向逻辑

    /// 买入 — 反向:持仓 shares 减回 / totalCost 减回(含手续费)/ avgCost 重算 / 现金账户余额加回(本金+手续费)。
    private static func reverseBuy(
        tx: TransactionRecord, accounts: [Account], positions: [Position], context: ModelContext
    ) throws {
        guard let posAccID = tx.toAccountID else { throw ReversalError.missingReferences }
        try reducePositionForAsset(
            accountID: posAccID,
            assetCode: tx.assetCode,
            shares: tx.shares,
            amount: tx.amount,
            fee: tx.fee,
            positions: positions,
            context: context
        )

        // 现金账户回退(本金 + 手续费一并返回 fromAccount)
        if let from = tx.fromAccountID, let cash = accounts.first(where: { $0.id == from }) {
            cash.cashBalance += (tx.amount + tx.fee)
            cash.updatedAt = Date()
        }
    }

    /// 卖出 — 反向:持仓 shares 加回 / 现金账户减回(原到账金额 = 卖出金额 - 手续费)。avgCost 不变。
    private static func reverseSell(
        tx: TransactionRecord, accounts: [Account], positions: [Position], context: ModelContext
    ) throws {
        guard let posAccID = tx.fromAccountID,
              let pos = positions.first(where: { $0.account?.id == posAccID && $0.assetCode == tx.assetCode })
        else { throw ReversalError.missingReferences }

        pos.shares += tx.shares
        pos.updatedAt = Date()

        if let toID = tx.toAccountID, let cash = accounts.first(where: { $0.id == toID }) {
            // P0:不再 max(0, ...) 静默截断,允许出现负数(用户可以看到再去补)
            // 卖出时到账 = amount - fee,反向时也只减回到账的部分
            cash.cashBalance -= (tx.amount - tx.fee)
            cash.updatedAt = Date()
        }
    }

    /// 分红 — 反向:现金账户减回。持仓不动(分红本就不影响持仓)。
    private static func reverseDividend(tx: TransactionRecord, accounts: [Account]) throws {
        guard let toID = tx.toAccountID, let cash = accounts.first(where: { $0.id == toID }) else {
            throw ReversalError.missingReferences
        }
        cash.cashBalance -= tx.amount     // P0:不再静默截断
        cash.updatedAt = Date()
    }

    /// 定投扣款 — 反向:
    /// - .pending(在途):只退现金,持仓不动(未确认,没建仓)
    /// - .confirmed/.completed(已成交):退现金 + 反向扣回持仓(已加仓/建仓)
    /// P0:防止"删已确认 DCA 只退钱不退持仓"导致资产虚增。
    ///
    /// 操作顺序:**先扣持仓,后退现金**。
    /// 持仓扣减如果抛错(missingReferences / wouldGoNegative),cash 还没被改,内存状态干净。
    /// 反之如果先动 cash 再扣持仓,扣持仓失败时 cash 已经是内存脏对象,
    /// 后续如果触发 save 就会把这次"应该不发生"的现金回退静默持久化。
    private static func reverseDcaDeduct(
        tx: TransactionRecord, accounts: [Account], positions: [Position], context: ModelContext
    ) throws {
        // 1. 先校验现金账户存在(只读,不修改)
        guard let from = tx.fromAccountID,
              let cash = accounts.first(where: { $0.id == from })
        else { throw ReversalError.missingReferences }

        // 2. 已确认/完成 → 先扣持仓。失败立刻抛出,cash 还没被改。
        if tx.status.isSettled, tx.shares > 0 {
            guard let toID = tx.toAccountID else { throw ReversalError.missingReferences }
            try reducePositionForAsset(
                accountID: toID,
                assetCode: tx.assetCode,
                shares: tx.shares,
                amount: tx.amount,
                fee: tx.fee,
                positions: positions,
                context: context
            )
        }

        // 3. 持仓扣减成功(或不需要扣) → 退回现金(本金 + 手续费)
        cash.cashBalance += (tx.amount + tx.fee)
        cash.updatedAt = Date()
    }

    /// 定投确认 — 反向:持仓 shares / totalCost 减回(含手续费)。现金已在 dcaDeduct 时扣过,这里不动。
    private static func reverseDcaConfirm(
        tx: TransactionRecord, positions: [Position], context: ModelContext
    ) throws {
        guard let toID = tx.toAccountID else { throw ReversalError.missingReferences }
        try reducePositionForAsset(
            accountID: toID,
            assetCode: tx.assetCode,
            shares: tx.shares,
            amount: tx.amount,
            fee: tx.fee,
            positions: positions,
            context: context
        )
    }

    /// 入金 — 反向:现金账户减回。
    private static func reverseDeposit(tx: TransactionRecord, accounts: [Account]) throws {
        guard let toID = tx.toAccountID, let cash = accounts.first(where: { $0.id == toID }) else {
            throw ReversalError.missingReferences
        }
        cash.cashBalance -= tx.amount     // P0:不再静默截断
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
        to.cashBalance -= tx.amount       // P0:不再静默截断
        from.updatedAt = Date()
        to.updatedAt = Date()
    }
}
