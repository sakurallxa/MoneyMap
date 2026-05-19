import Foundation
import SwiftData
@testable import MoneyMap

/// 测试用 in-memory SwiftData 容器工厂。
/// 每个测试 case 调一次 → 拿到全新的、干净的、不持久化的 context。
enum SwiftDataTestHelper {

    /// 强引用所有为测试创建过的 container,防止函数返回后 ARC 把它释放。
    /// ModelContext 对 container 的引用是弱引用 — 如果不在这里 retain,
    /// 第一次 context.insert(...) 会触底访问已释放的 backing store → 进程崩溃。
    @MainActor private static var retainedContainers: [ModelContainer] = []

    /// 返回一个 in-memory ModelContainer 的 mainContext。
    /// 每个测试用全新 container,避免与 host App 的 SwiftData 容器冲突。
    @MainActor
    static func makeInMemoryContext() throws -> ModelContext {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: Account.self, Position.self, TransactionRecord.self,
                DCAPlan.self, DailySnapshot.self, Asset.self,
                PriceQuote.self, ExchangeRate.self, TargetAllocation.self,
            configurations: config
        )
        retainedContainers.append(container)
        return container.mainContext
    }

    // MARK: - 工厂方法 — 快速建测试数据

    /// 建一个现金账户(默认 CNY,余额可配)
    static func makeCashAccount(
        name: String = "测试招行卡",
        balance: Double = 10_000,
        currency: CurrencyCode = .cny,
        context: ModelContext
    ) -> Account {
        let acc = Account(
            name: name,
            type: .cash,
            currency: currency,
            cashBalance: balance
        )
        context.insert(acc)
        try? context.save()
        return acc
    }

    /// 建一个投资账户(默认基金 App)
    static func makeInvestmentAccount(
        name: String = "测试基金账户",
        type: AccountType = .fundApp,
        currency: CurrencyCode = .cny,
        context: ModelContext
    ) -> Account {
        let acc = Account(
            name: name,
            type: type,
            currency: currency,
            cashBalance: 0
        )
        context.insert(acc)
        try? context.save()
        return acc
    }

    /// 在指定投资账户下建一个持仓
    static func makePosition(
        in account: Account,
        assetCode: String = "TEST001",
        assetName: String = "测试资产",
        shares: Double = 100,
        avgCost: Double = 10,
        lastPrice: Double = 12,
        context: ModelContext
    ) -> Position {
        let pos = Position(
            account: account,
            assetCode: assetCode,
            assetName: assetName,
            shares: shares,
            avgCost: avgCost,
            lastPrice: lastPrice,
            prevClosePrice: lastPrice,
            weekAgoPrice: lastPrice,
            monthAgoPrice: lastPrice,
            yearStartPrice: lastPrice
        )
        // 让 updatedAt > 任何 tradeDate,以便走 DCAService 的快路径(已刷过价)
        pos.updatedAt = Date().addingTimeInterval(86_400)
        context.insert(pos)
        try? context.save()
        return pos
    }

    /// 建一笔已完成的买入交易(用来测试 reverseBuy)
    static func makeBuyTransaction(
        from cash: Account,
        to investment: Account,
        position: Position,
        amount: Double = 1_000,
        shares: Double = 100,
        price: Double = 10,
        fee: Double = 0,
        context: ModelContext
    ) -> TransactionRecord {
        let tx = TransactionRecord(
            tradeDate: Date(),
            type: position.assetClass == .fund ? .buyFund : .buyStock,
            status: .completed,
            fromAccountID: cash.id,
            toAccountID: investment.id,
            fromAccountName: cash.name,
            toAccountName: investment.name,
            assetCode: position.assetCode,
            assetName: position.assetName,
            amount: amount,
            shares: shares,
            price: price,
            fee: fee
        )
        context.insert(tx)
        return tx
    }
}
