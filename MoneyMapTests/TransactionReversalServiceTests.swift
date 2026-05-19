import XCTest
import SwiftData
@testable import MoneyMap

/// 覆盖 P0 资金安全核心:删除交易时反向应用资金 / 持仓影响。
///
/// 重点覆盖:
/// - 买入反向:持仓 shares 减回 + 现金加回(含 fee)
/// - 卖出反向:持仓加回 + 现金减回(扣手续费的净额)
/// - 分红反向:只动现金
/// - DCA 在途反向:**只退现金**
/// - DCA 已确认反向:**退现金 + 扣回持仓**(P0 资金虚增修复)
/// - 持仓不存在 → missingReferences
/// - 卖光后再删买入 → wouldGoNegative
@MainActor
final class TransactionReversalServiceTests: XCTestCase {

    // 健康检查 — 看 test runner 自己是否正常
    func test_smoke_runtime() {
        XCTAssertTrue(true)
    }

    // 诊断:in-memory ModelContainer 能否正常建出来
    func test_smoke_modelContainer() throws {
        let ctx = try SwiftDataTestHelper.makeInMemoryContext()
        XCTAssertNotNil(ctx)
    }

    // MARK: - reverseBuy

    func test_reverseBuy_revertsSharesAndCash_includingFee() throws {
        let ctx = try SwiftDataTestHelper.makeInMemoryContext()
        let cash = SwiftDataTestHelper.makeCashAccount(balance: 1_000, context: ctx)
        let inv = SwiftDataTestHelper.makeInvestmentAccount(context: ctx)
        let pos = SwiftDataTestHelper.makePosition(
            in: inv,
            shares: 200, avgCost: 11.5,    // 假设之前买过,totalCost = 200 × 11.5 = 2300(含手续费)
            context: ctx
        )
        // 模拟一笔已发生的"加仓"交易:¥1000 / 100 份 / 价格 ¥10,手续费 ¥3
        // 当时 cash 已扣 1003,position 已加到 200 shares(原来是 100)
        let tx = SwiftDataTestHelper.makeBuyTransaction(
            from: cash, to: inv, position: pos,
            amount: 1_000, shares: 100, price: 10, fee: 3,
            context: ctx
        )

        try TransactionReversalService.deleteWithReversal(tx, context: ctx)

        // 现金应该被加回 amount + fee = 1003
        XCTAssertEqual(cash.cashBalance, 1_000 + 1_003, accuracy: 0.001)
        // shares 应该减回到 100(200 - 100)
        XCTAssertEqual(pos.shares, 100, accuracy: 0.001)
        // 新 totalCost = 2300 - 1003 = 1297,avgCost = 1297 / 100 = 12.97
        XCTAssertEqual(pos.avgCost, 12.97, accuracy: 0.001)
    }

    func test_reverseBuy_clearsPositionWhenSharesGoToZero() throws {
        let ctx = try SwiftDataTestHelper.makeInMemoryContext()
        let cash = SwiftDataTestHelper.makeCashAccount(balance: 0, context: ctx)
        let inv = SwiftDataTestHelper.makeInvestmentAccount(context: ctx)
        let pos = SwiftDataTestHelper.makePosition(
            in: inv, shares: 100, avgCost: 10, context: ctx
        )
        // 那 100 shares 就是这笔买入加的(假设之前 0 shares)
        let tx = SwiftDataTestHelper.makeBuyTransaction(
            from: cash, to: inv, position: pos,
            amount: 1_000, shares: 100, price: 10, context: ctx
        )

        try TransactionReversalService.deleteWithReversal(tx, context: ctx)

        // 现金加回 1000
        XCTAssertEqual(cash.cashBalance, 1_000, accuracy: 0.001)
        // Position 应该被完全删除
        let remainingPositions = try ctx.fetch(FetchDescriptor<Position>())
        XCTAssertTrue(remainingPositions.isEmpty, "shares 减到 0 时 Position 应被删除")
    }

    func test_reverseBuy_throwsWouldGoNegative_whenSharesAlreadySoldOut() throws {
        let ctx = try SwiftDataTestHelper.makeInMemoryContext()
        let cash = SwiftDataTestHelper.makeCashAccount(balance: 0, context: ctx)
        let inv = SwiftDataTestHelper.makeInvestmentAccount(context: ctx)
        // 之前买了 100 份,现在持仓只剩 30 份(用户已经卖了 70)
        let pos = SwiftDataTestHelper.makePosition(
            in: inv, shares: 30, avgCost: 10, context: ctx
        )
        // 想删除"买入 100 份"那笔 → 反向后会变成 -70,应该拒绝
        let tx = SwiftDataTestHelper.makeBuyTransaction(
            from: cash, to: inv, position: pos,
            amount: 1_000, shares: 100, price: 10, context: ctx
        )

        XCTAssertThrowsError(try TransactionReversalService.deleteWithReversal(tx, context: ctx)) { err in
            guard let revErr = err as? TransactionReversalService.ReversalError,
                  case .wouldGoNegative = revErr else {
                XCTFail("期望抛 wouldGoNegative,实际:\(err)")
                return
            }
        }
        // 拒绝后,数据不应该被改
        XCTAssertEqual(cash.cashBalance, 0, accuracy: 0.001)
        XCTAssertEqual(pos.shares, 30, accuracy: 0.001)
    }

    // MARK: - reverseSell

    func test_reverseSell_addsBackSharesAndDeductsCash() throws {
        let ctx = try SwiftDataTestHelper.makeInMemoryContext()
        let cash = SwiftDataTestHelper.makeCashAccount(balance: 500, context: ctx)
        let inv = SwiftDataTestHelper.makeInvestmentAccount(context: ctx)
        let pos = SwiftDataTestHelper.makePosition(
            in: inv, shares: 50, avgCost: 10, context: ctx
        )
        // 模拟"卖出 50 份 / ¥500 / 手续费 ¥2"。现金应收到 ¥498。
        let tx = TransactionRecord(
            tradeDate: Date(),
            type: .sellFund,
            status: .completed,
            fromAccountID: inv.id,
            toAccountID: cash.id,
            fromAccountName: inv.name,
            toAccountName: cash.name,
            assetCode: pos.assetCode,
            assetName: pos.assetName,
            amount: 500, shares: 50, price: 10, fee: 2
        )
        ctx.insert(tx)

        try TransactionReversalService.deleteWithReversal(tx, context: ctx)

        // 现金应减回 amount - fee = 498(原本到账 498,现在退回去)
        XCTAssertEqual(cash.cashBalance, 500 - 498, accuracy: 0.001)
        // 持仓加回 50 份 → 现在 100
        XCTAssertEqual(pos.shares, 100, accuracy: 0.001)
    }

    // MARK: - reverseDividend

    func test_reverseDividend_onlyAffectsCash() throws {
        let ctx = try SwiftDataTestHelper.makeInMemoryContext()
        let cash = SwiftDataTestHelper.makeCashAccount(balance: 100, context: ctx)
        let inv = SwiftDataTestHelper.makeInvestmentAccount(context: ctx)
        let pos = SwiftDataTestHelper.makePosition(in: inv, shares: 100, context: ctx)
        let sharesBefore = pos.shares
        let tx = TransactionRecord(
            tradeDate: Date(),
            type: .dividend,
            status: .completed,
            toAccountID: cash.id,
            assetCode: pos.assetCode,
            amount: 50
        )
        ctx.insert(tx)
        try TransactionReversalService.deleteWithReversal(tx, context: ctx)
        XCTAssertEqual(cash.cashBalance, 50, accuracy: 0.001)
        XCTAssertEqual(pos.shares, sharesBefore, "分红反向不应影响持仓")
    }

    // MARK: - reverseDcaDeduct - pending (在途)

    func test_reverseDcaDeduct_pending_onlyRefundsCash() throws {
        let ctx = try SwiftDataTestHelper.makeInMemoryContext()
        let cash = SwiftDataTestHelper.makeCashAccount(balance: 800, context: ctx)
        let inv = SwiftDataTestHelper.makeInvestmentAccount(context: ctx)
        // 在途 DCA:还没建仓,shares = 0,fee = 0
        let tx = TransactionRecord(
            tradeDate: Date(),
            type: .dcaDeduct,
            status: .pending,
            fromAccountID: cash.id,
            toAccountID: inv.id,
            assetCode: "PENDING_ASSET",
            amount: 200, shares: 0
        )
        ctx.insert(tx)

        try TransactionReversalService.deleteWithReversal(tx, context: ctx)

        XCTAssertEqual(cash.cashBalance, 1_000, accuracy: 0.001, "pending DCA 退现金 200")
        let positions = try ctx.fetch(FetchDescriptor<Position>())
        XCTAssertTrue(positions.isEmpty, "pending DCA 时没有持仓被建,不应有 ghost")
    }

    // MARK: - reverseDcaDeduct - confirmed (P0 资金虚增修复)

    func test_reverseDcaDeduct_confirmed_revertsCashAndPosition() throws {
        let ctx = try SwiftDataTestHelper.makeInMemoryContext()
        let cash = SwiftDataTestHelper.makeCashAccount(balance: 800, context: ctx)
        let inv = SwiftDataTestHelper.makeInvestmentAccount(context: ctx)
        // 已确认的 DCA 扣款 → 持仓被加过份额
        let pos = SwiftDataTestHelper.makePosition(
            in: inv, assetCode: "DCA_ASSET",
            shares: 50, avgCost: 4, context: ctx
        )
        let tx = TransactionRecord(
            tradeDate: Date(),
            type: .dcaDeduct,
            status: .confirmed,
            fromAccountID: cash.id,
            toAccountID: inv.id,
            assetCode: "DCA_ASSET",
            amount: 200, shares: 50, price: 4, fee: 0
        )
        ctx.insert(tx)

        try TransactionReversalService.deleteWithReversal(tx, context: ctx)

        // P0 资金虚增 bug 修复验证:
        // (a) 现金应该退回 200
        XCTAssertEqual(cash.cashBalance, 1_000, accuracy: 0.001, "已确认 DCA 删除应退回现金")
        // (b) 持仓 shares 应该减回 — pos 已被 reducePositionForAsset 处理
        //     原 50 shares = 这次扣款贡献的,反向后应清空
        let positions = try ctx.fetch(FetchDescriptor<Position>())
        XCTAssertTrue(positions.isEmpty, "已确认 DCA 删除应回滚持仓(P0 核心修复)")
    }

    // MARK: - reverseDcaDeduct 顺序正确性(P0 升级修复)

    func test_reverseDcaDeduct_throwsBeforeTouchingCash_whenPositionMissing() throws {
        let ctx = try SwiftDataTestHelper.makeInMemoryContext()
        let cash = SwiftDataTestHelper.makeCashAccount(balance: 1_000, context: ctx)
        let inv = SwiftDataTestHelper.makeInvestmentAccount(context: ctx)
        // 已确认的 DCA,但持仓被外部删除了(数据不自洽场景)
        let tx = TransactionRecord(
            tradeDate: Date(),
            type: .dcaDeduct,
            status: .confirmed,
            fromAccountID: cash.id,
            toAccountID: inv.id,
            assetCode: "GHOST",
            amount: 200, shares: 50, price: 4, fee: 0
        )
        ctx.insert(tx)

        XCTAssertThrowsError(try TransactionReversalService.deleteWithReversal(tx, context: ctx))
        // 关键验证:cash 不应该被改(P0 升级修复:先扣持仓再退现金,失败时 cash 干净)
        XCTAssertEqual(cash.cashBalance, 1_000, accuracy: 0.001,
                       "持仓扣减抛错时,cash 应保持原值")
    }

    // MARK: - reverseDeposit / Withdraw / Transfer

    func test_reverseDeposit_deductsCashBack() throws {
        let ctx = try SwiftDataTestHelper.makeInMemoryContext()
        let cash = SwiftDataTestHelper.makeCashAccount(balance: 5_000, context: ctx)
        let tx = TransactionRecord(
            tradeDate: Date(),
            type: .deposit,
            status: .completed,
            toAccountID: cash.id,
            amount: 1_000
        )
        ctx.insert(tx)

        try TransactionReversalService.deleteWithReversal(tx, context: ctx)
        XCTAssertEqual(cash.cashBalance, 4_000, accuracy: 0.001)
    }

    func test_reverseTransfer_movesCashBack() throws {
        let ctx = try SwiftDataTestHelper.makeInMemoryContext()
        let from = SwiftDataTestHelper.makeCashAccount(name: "From", balance: 500, context: ctx)
        let to = SwiftDataTestHelper.makeCashAccount(name: "To", balance: 1_500, context: ctx)
        let tx = TransactionRecord(
            tradeDate: Date(),
            type: .transfer,
            status: .completed,
            fromAccountID: from.id,
            toAccountID: to.id,
            amount: 1_000
        )
        ctx.insert(tx)

        try TransactionReversalService.deleteWithReversal(tx, context: ctx)
        XCTAssertEqual(from.cashBalance, 1_500, accuracy: 0.001, "from 加回 1000")
        XCTAssertEqual(to.cashBalance, 500, accuracy: 0.001, "to 减回 1000")
    }
}
