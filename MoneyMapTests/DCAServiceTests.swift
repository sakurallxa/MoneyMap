import XCTest
import SwiftData
@testable import MoneyMap

/// 覆盖 DCA 资金流转关键路径。
///
/// 重点:
/// - triggerDuePlans: 到期触发 → 生成 .pending tx + 扣现金(含手续费率)
/// - triggerDuePlans 余额不足:跳过,不推进 lastRunDate(P1.2)
/// - triggerDuePlans 同一天已触发:不重复
/// - confirmRipePending: T+2 后用持仓最新价升级为 .confirmed
/// - **P1 同轮重复持仓修复**:同账户同资产的两笔 pending 不应建出两个 Position
@MainActor
final class DCAServiceTests: XCTestCase {

    // MARK: - triggerDuePlans

    func test_triggerDuePlans_createsPendingAndDeductsCashWithFee() throws {
        let ctx = try SwiftDataTestHelper.makeInMemoryContext()
        let cash = SwiftDataTestHelper.makeCashAccount(balance: 10_000, context: ctx)
        let inv = SwiftDataTestHelper.makeInvestmentAccount(context: ctx)
        // 创建一个"昨天就到期"的 DCA plan(amount = 1000, fee rate = 0.5%)
        let plan = DCAPlan(
            name: "测试定投",
            sourceAccountID: cash.id, sourceAccountName: cash.name,
            targetAccountID: inv.id, targetAccountName: inv.name,
            targetAssetCode: "FUND001", targetAssetName: "测试基金",
            amount: 1_000,
            feeRatePercent: 0.5,    // 0.5% 手续费率
            frequency: .weekly,
            nextRunDate: Date().addingTimeInterval(-86_400)    // 昨天
        )
        ctx.insert(plan)
        try ctx.save()

        DCAService.triggerDuePlans(context: ctx)

        // 现金应被扣 amount + (amount × rate / 100) = 1000 + 5 = 1005
        XCTAssertEqual(cash.cashBalance, 8_995, accuracy: 0.001)

        let pending = try ctx.fetch(
            FetchDescriptor<TransactionRecord>(predicate: #Predicate { $0.statusRaw == "PENDING" })
        )
        XCTAssertEqual(pending.count, 1)
        XCTAssertEqual(pending[0].amount, 1_000, accuracy: 0.001)
        XCTAssertEqual(pending[0].fee, 5, accuracy: 0.001, "手续费应为本金 × 费率 / 100")
        XCTAssertEqual(pending[0].assetCode, "FUND001")
    }

    func test_triggerDuePlans_skipsWhenCashInsufficient() throws {
        let ctx = try SwiftDataTestHelper.makeInMemoryContext()
        let cash = SwiftDataTestHelper.makeCashAccount(balance: 500, context: ctx)    // 不够
        let inv = SwiftDataTestHelper.makeInvestmentAccount(context: ctx)
        let nextRun = Date().addingTimeInterval(-86_400)
        let plan = DCAPlan(
            name: "余额不足测试",
            sourceAccountID: cash.id, sourceAccountName: cash.name,
            targetAccountID: inv.id, targetAccountName: inv.name,
            targetAssetCode: "F002", targetAssetName: "F2",
            amount: 1_000,    // 大于 cash 余额
            frequency: .weekly,
            nextRunDate: nextRun
        )
        ctx.insert(plan)
        try ctx.save()

        DCAService.triggerDuePlans(context: ctx)

        // 现金不应被扣
        XCTAssertEqual(cash.cashBalance, 500, accuracy: 0.001)
        // 不应有 pending tx
        let pending = try ctx.fetch(
            FetchDescriptor<TransactionRecord>(predicate: #Predicate { $0.statusRaw == "PENDING" })
        )
        XCTAssertTrue(pending.isEmpty)
        // lastRunDate / nextRunDate 不应被推进(下次启动还能重试)
        XCTAssertNil(plan.lastRunDate)
        XCTAssertEqual(plan.nextRunDate.timeIntervalSince1970, nextRun.timeIntervalSince1970, accuracy: 0.001)
    }

    func test_triggerDuePlans_doesNotRunTwiceOnSameDay() throws {
        let ctx = try SwiftDataTestHelper.makeInMemoryContext()
        let cash = SwiftDataTestHelper.makeCashAccount(balance: 10_000, context: ctx)
        let inv = SwiftDataTestHelper.makeInvestmentAccount(context: ctx)
        let plan = DCAPlan(
            name: "去重测试",
            sourceAccountID: cash.id, sourceAccountName: cash.name,
            targetAccountID: inv.id, targetAccountName: inv.name,
            targetAssetCode: "F003", targetAssetName: "F3",
            amount: 1_000,
            frequency: .daily,
            nextRunDate: Date().addingTimeInterval(-3600)
        )
        ctx.insert(plan)
        try ctx.save()

        // 第一次触发
        DCAService.triggerDuePlans(context: ctx)
        let balanceAfterFirst = cash.cashBalance

        // 同一天再触发一次
        DCAService.triggerDuePlans(context: ctx)

        // 余额不应再被扣(只有一次 pending)
        XCTAssertEqual(cash.cashBalance, balanceAfterFirst, accuracy: 0.001)
        let pending = try ctx.fetch(
            FetchDescriptor<TransactionRecord>(predicate: #Predicate { $0.statusRaw == "PENDING" })
        )
        XCTAssertEqual(pending.count, 1, "同一天应只触发一次")
    }

    // MARK: - confirmRipePending

    func test_confirmRipePending_confirmsT2WithExistingPosition() async throws {
        let ctx = try SwiftDataTestHelper.makeInMemoryContext()
        let cash = SwiftDataTestHelper.makeCashAccount(balance: 10_000, context: ctx)
        let inv = SwiftDataTestHelper.makeInvestmentAccount(context: ctx)
        // 已有持仓,价格 = 5,updatedAt 远比 pending tx 的 tradeDate 新(走快路径)
        let pos = SwiftDataTestHelper.makePosition(
            in: inv, assetCode: "RIPE001", shares: 100, avgCost: 5, lastPrice: 5, context: ctx
        )
        // pending tx 3 天前发起 — 满足 dayDiff >= 2 的确认条件
        let threeDaysAgo = Date().addingTimeInterval(-3 * 86_400)
        let tx = TransactionRecord(
            tradeDate: threeDaysAgo,
            type: .dcaDeduct,
            status: .pending,
            fromAccountID: cash.id, toAccountID: inv.id,
            assetCode: "RIPE001",
            amount: 500, fee: 0
        )
        ctx.insert(tx)
        try ctx.save()

        await DCAService.confirmRipePending(context: ctx)

        // tx 应该被升级
        XCTAssertEqual(tx.statusRaw, TransactionStatus.confirmed.rawValue)
        // shares 应该被算出来:amount / price = 500 / 5 = 100
        XCTAssertEqual(tx.shares, 100, accuracy: 0.001)
        // 持仓 shares 应加到 200
        XCTAssertEqual(pos.shares, 200, accuracy: 0.001)
        // avgCost 应按 (totalCost + amount + fee) / newTotal = (500 + 500 + 0) / 200 = 5
        XCTAssertEqual(pos.avgCost, 5, accuracy: 0.001)
    }

    // MARK: - 🔴 P1 关键回归测试 — 同账户同资产两笔 pending 不应建出两个 Position

    func test_confirmRipePending_doesNotDuplicatePositionForSameAssetInSameRound() async throws {
        let ctx = try SwiftDataTestHelper.makeInMemoryContext()
        let cash = SwiftDataTestHelper.makeCashAccount(balance: 10_000, context: ctx)
        let inv = SwiftDataTestHelper.makeInvestmentAccount(context: ctx)
        // 已有持仓(用来让 confirmIfRipe 走快路径,不调网络)
        let pos = SwiftDataTestHelper.makePosition(
            in: inv, assetCode: "DUP_TEST",
            shares: 50, avgCost: 5, lastPrice: 5,
            context: ctx
        )
        // 两笔 pending,同账户 + 同资产,都已 T+2 成熟
        let threeDaysAgo = Date().addingTimeInterval(-3 * 86_400)
        let tx1 = TransactionRecord(
            tradeDate: threeDaysAgo,
            type: .dcaDeduct,
            status: .pending,
            fromAccountID: cash.id, toAccountID: inv.id,
            assetCode: "DUP_TEST",
            amount: 100
        )
        let tx2 = TransactionRecord(
            tradeDate: threeDaysAgo,
            type: .dcaDeduct,
            status: .pending,
            fromAccountID: cash.id, toAccountID: inv.id,
            assetCode: "DUP_TEST",
            amount: 200
        )
        ctx.insert(tx1)
        ctx.insert(tx2)
        try ctx.save()

        await DCAService.confirmRipePending(context: ctx)

        // 关键验证:两笔确认后,Position 仍应只有 **1 个**(不是 2 个!)
        let positions = try ctx.fetch(FetchDescriptor<Position>())
        let dupPositions = positions.filter { $0.assetCode == "DUP_TEST" }
        XCTAssertEqual(dupPositions.count, 1,
                       "P1 同轮重复持仓修复:同账户同资产的多笔 pending 不应建出多个 Position")
        // shares 应该是 50(原始) + 100/5 + 200/5 = 50 + 20 + 40 = 110
        XCTAssertEqual(pos.shares, 110, accuracy: 0.001)
        // 两笔都应升级为 confirmed
        XCTAssertEqual(tx1.statusRaw, TransactionStatus.confirmed.rawValue)
        XCTAssertEqual(tx2.statusRaw, TransactionStatus.confirmed.rawValue)
    }

    // MARK: - manuallyConfirm

    func test_manuallyConfirm_createsNewPositionWithFeeInAvgCost() throws {
        let ctx = try SwiftDataTestHelper.makeInMemoryContext()
        let cash = SwiftDataTestHelper.makeCashAccount(balance: 1_000, context: ctx)
        let inv = SwiftDataTestHelper.makeInvestmentAccount(context: ctx)
        // pending tx,**无现有持仓**(首次建仓场景)
        let tx = TransactionRecord(
            tradeDate: Date(),
            type: .dcaDeduct,
            status: .pending,
            fromAccountID: cash.id, toAccountID: inv.id,
            assetCode: "FIRST_BUY",
            assetName: "首次建仓",
            amount: 1_000, fee: 5    // 手续费 ¥5
        )
        ctx.insert(tx)
        try ctx.save()

        DCAService.manuallyConfirm(tx: tx, price: 10, context: ctx)

        // 应建一个新 Position
        let positions = try ctx.fetch(FetchDescriptor<Position>())
        XCTAssertEqual(positions.count, 1)
        let pos = positions[0]
        XCTAssertEqual(pos.shares, 100, accuracy: 0.001)    // 1000 / 10
        // avgCost 含手续费:(1000 + 5) / 100 = 10.05
        XCTAssertEqual(pos.avgCost, 10.05, accuracy: 0.001)
        XCTAssertEqual(pos.assetCode, "FIRST_BUY")
    }
}
