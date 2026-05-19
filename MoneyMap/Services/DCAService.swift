import Foundation
import SwiftData

enum DCAService {
    /// 触发所有到期的定投计划 — 创建 .pending 扣款 tx,扣减现金账户。
    /// 这个步骤应该在 PriceRefresh **之前**调用,确保新到期的扣款能拿到当天的真实价格。
    static func triggerDuePlans(context: ModelContext, today: Date = Date()) {
        let plans = (try? context.fetch(FetchDescriptor<DCAPlan>())) ?? []
        let accounts = (try? context.fetch(FetchDescriptor<Account>())) ?? []

        for plan in plans where plan.isActive {
            triggerIfDue(plan: plan, today: today, accounts: accounts, context: context)
        }

        try? context.save()
    }

    /// 把 T+2 + 已有最新价的 .pending 扣款升级为 .confirmed,合并/创建持仓。
    /// 这个步骤必须在 PriceRefresh **之后**调用,否则永远拿不到新鲜价格。
    ///
    /// **P1 修复**:同一轮内若有两笔"同账户同资产"的 pending(且当前还没建仓),
    /// 第一笔会建仓,第二笔不能再插入新 Position,必须能看到刚刚 insert 的那一条。
    /// SwiftData 在没有 save 前不会把新插入对象回到 fetch 结果里,所以我们用
    /// 一个 local dict 维护"本轮新增 / 已加仓"的持仓索引,每次确认前先查它。
    static func confirmRipePending(context: ModelContext, today: Date = Date()) async {
        let pending = (try? context.fetch(
            FetchDescriptor<TransactionRecord>(
                predicate: #Predicate { $0.statusRaw == "PENDING" }
            )
        )) ?? []
        let accounts = (try? context.fetch(FetchDescriptor<Account>())) ?? []
        let positions = (try? context.fetch(FetchDescriptor<Position>())) ?? []

        // "accountID|assetCode" → Position 索引,seed 一次,confirmIfRipe 内增量维护
        var positionIndex: [String: Position] = [:]
        for p in positions {
            guard let accID = p.account?.id else { continue }
            positionIndex[positionKey(accountID: accID, assetCode: p.assetCode)] = p
        }

        for tx in pending {
            await confirmIfRipe(
                tx: tx, today: today,
                accounts: accounts, positionIndex: &positionIndex, context: context
            )
        }

        try? context.save()
    }

    /// 老 API 转发 — 已存在的调用方还在用 processAll,保留兼容。
    /// 新代码请直接用 triggerDuePlans + confirmRipePending 两步。
    static func processAll(context: ModelContext, today: Date = Date()) {
        triggerDuePlans(context: context, today: today)
        Task { await confirmRipePending(context: context, today: today) }
    }

    private static func triggerIfDue(
        plan: DCAPlan,
        today: Date,
        accounts: [Account],
        context: ModelContext
    ) {
        let cal = Calendar.current
        let todayStart = cal.startOfDay(for: today)
        let dueStart = cal.startOfDay(for: plan.nextRunDate)
        guard dueStart <= todayStart else { return }

        if let last = plan.lastRunDate, cal.isDate(last, inSameDayAs: today) {
            return
        }

        guard let source = accounts.first(where: { $0.id == plan.sourceAccountID }) else { return }

        // 手续费率 % → 实际手续费金额 = amount × rate / 100
        let actualFee = plan.amount * plan.feeRatePercent / 100

        // P1.2:余额不足(含手续费) → 本轮跳过,不推进 lastRunDate / nextRunDate
        // 用户补足现金后下次启动会自动重试,不丢扣款
        let totalDebit = plan.amount + actualFee
        guard source.cashBalance >= totalDebit else { return }

        let before = source.cashBalance
        source.cashBalance -= totalDebit
        source.updatedAt = today

        let tx = TransactionRecord(
            tradeDate: today,
            type: .dcaDeduct,
            status: .pending,
            fromAccountID: plan.sourceAccountID,
            toAccountID: plan.targetAccountID,
            fromAccountName: plan.sourceAccountName,
            toAccountName: plan.targetAccountName,
            assetCode: plan.targetAssetCode,
            assetName: plan.targetAssetName,
            amount: plan.amount,
            fee: actualFee,    // 写入绝对金额,流水不存费率
            note: "[\(plan.name)] 自动扣款,等待 T+1 确认",
            dcaPlanID: plan.id,
            sourceBalanceBefore: before,
            sourceBalanceAfter: source.cashBalance
        )
        context.insert(tx)

        plan.lastRunDate = today
        plan.nextRunDate = nextRunDate(after: today, frequency: plan.frequency)
    }

    /// 持仓索引 key — "accountID|assetCode"
    private static func positionKey(accountID: UUID, assetCode: String) -> String {
        "\(accountID.uuidString)|\(assetCode)"
    }

    private static func confirmIfRipe(
        tx: TransactionRecord,
        today: Date,
        accounts: [Account],
        positionIndex: inout [String: Position],
        context: ModelContext
    ) async {
        guard tx.type == .dcaDeduct, tx.status == .pending else { return }
        let cal = Calendar.current
        let dayDiff = cal.dateComponents([.day], from: cal.startOfDay(for: tx.tradeDate), to: cal.startOfDay(for: today)).day ?? 0
        guard dayDiff >= 2 else { return }

        guard let targetAccount = accounts.first(where: { $0.id == tx.toAccountID }) else { return }
        let key = positionKey(accountID: targetAccount.id, assetCode: tx.assetCode)
        let existingPosition = positionIndex[key]

        // P1-015 修复死代码:
        // - 老逻辑要求 existingPosition.updatedAt > tx.tradeDate(等价于"价格刷过") — 但首次扣款没 position,永远卡住
        // - 新逻辑分两路:
        //   1) 已有持仓 → 用持仓最新价(快路径)
        //   2) 没有持仓 → 直接调 QuoteResolver 拉一次实时价,然后建首仓
        let confirmPrice: Double
        if let ref = existingPosition,
           ref.updatedAt > tx.tradeDate,
           ref.lastPrice > 0 {
            confirmPrice = ref.lastPrice
        } else if existingPosition == nil {
            // 首次扣款 — 现拉一次价
            do {
                let quote = try await QuoteResolver.quote(
                    code: tx.assetCode,
                    accountType: targetAccount.type
                )
                confirmPrice = quote.price
            } catch {
                return       // 行情拉不到,等下一轮
            }
        } else {
            return           // 有持仓但价格没刷新,等下一轮
        }
        guard confirmPrice > 0 else { return }
        let confirmedShares = tx.amount / confirmPrice

        tx.statusRaw = TransactionStatus.confirmed.rawValue
        tx.confirmDate = today
        tx.shares = confirmedShares
        tx.price = confirmPrice

        // avgCost 含手续费 — (累计成本 + 本次本金 + 本次手续费) / 新份额
        if let pos = existingPosition {
            let newTotal = pos.shares + confirmedShares
            let newAvgCost = (pos.totalCost + tx.amount + tx.fee) / max(newTotal, 0.0001)
            pos.shares = newTotal
            pos.avgCost = newAvgCost
            pos.lastPrice = confirmPrice
            pos.updatedAt = today
        } else {
            // 首次建仓 avgCost = (本金 + 手续费) / 份额
            let firstAvg = confirmedShares > 0 ? (tx.amount + tx.fee) / confirmedShares : confirmPrice
            let pos = Position(
                account: targetAccount,
                assetCode: tx.assetCode,
                assetName: tx.assetName,
                shares: confirmedShares,
                avgCost: firstAvg,
                lastPrice: confirmPrice,
                prevClosePrice: confirmPrice,
                weekAgoPrice: confirmPrice,
                monthAgoPrice: confirmPrice,
                yearStartPrice: confirmPrice
            )
            context.insert(pos)
            // P1:同轮内若再有同账户同资产的 pending 要确认,通过 index 拿到这条刚插入的 Position 走加仓路径
            positionIndex[key] = pos
        }
    }

    static func nextRunDate(after date: Date, frequency: DCAFrequency) -> Date {
        let cal = Calendar.current
        switch frequency {
        case .daily:
            return cal.date(byAdding: .day, value: 1, to: date) ?? date
        case .weekly:
            return cal.date(byAdding: .day, value: 7, to: date) ?? date
        case .biweekly:
            return cal.date(byAdding: .day, value: 14, to: date) ?? date
        case .monthly:
            return cal.date(byAdding: .month, value: 1, to: date) ?? date
        }
    }

    /// 根据频率 + 周/月内具体日期,计算"从 today 出发的下一个扣款日"。
    /// 用于新建/编辑定投时自动回填日期选择器。
    static func computeNextRun(
        from today: Date = Date(),
        frequency: DCAFrequency,
        dayOfWeek: Int,
        dayOfMonth: Int
    ) -> Date {
        let cal = Calendar.current
        switch frequency {
        case .daily:
            return cal.date(byAdding: .day, value: 1, to: today) ?? today

        case .weekly, .biweekly:
            let targetCalWeekday = WeekdayPicker.toCalendarWeekday(dayOfWeek)
            let todayWeekday = cal.component(.weekday, from: today)
            var daysUntil = targetCalWeekday - todayWeekday
            if daysUntil <= 0 { daysUntil += 7 }
            return cal.date(byAdding: .day, value: daysUntil, to: today) ?? today

        case .monthly:
            let safeDay = max(1, min(28, dayOfMonth))
            var comps = cal.dateComponents([.year, .month], from: today)
            comps.day = safeDay
            let startOfToday = cal.startOfDay(for: today)
            if let candidate = cal.date(from: comps), candidate > startOfToday {
                return candidate
            }
            if let nextMonth = cal.date(byAdding: .month, value: 1, to: cal.date(from: comps) ?? today) {
                return nextMonth
            }
            return today
        }
    }

    static func manuallyConfirm(tx: TransactionRecord, price: Double, context: ModelContext) {
        guard tx.type == .dcaDeduct, tx.status == .pending, price > 0 else { return }
        let accounts = (try? context.fetch(FetchDescriptor<Account>())) ?? []
        let positions = (try? context.fetch(FetchDescriptor<Position>())) ?? []
        guard let target = accounts.first(where: { $0.id == tx.toAccountID }) else { return }
        let existing = positions.first { $0.account?.id == target.id && $0.assetCode == tx.assetCode }

        let confirmedShares = tx.amount / price
        tx.statusRaw = TransactionStatus.confirmed.rawValue
        tx.confirmDate = Date()
        tx.shares = confirmedShares
        tx.price = price

        // avgCost 含手续费
        if let pos = existing {
            let newTotal = pos.shares + confirmedShares
            let newAvgCost = (pos.totalCost + tx.amount + tx.fee) / max(newTotal, 0.0001)
            pos.shares = newTotal
            pos.avgCost = newAvgCost
            pos.lastPrice = price
            pos.updatedAt = Date()
        } else {
            let firstAvg = confirmedShares > 0 ? (tx.amount + tx.fee) / confirmedShares : price
            let pos = Position(
                account: target,
                assetCode: tx.assetCode,
                assetName: tx.assetName,
                shares: confirmedShares,
                avgCost: firstAvg,
                lastPrice: price,
                prevClosePrice: price,
                weekAgoPrice: price,
                monthAgoPrice: price,
                yearStartPrice: price
            )
            context.insert(pos)
        }
        try? context.save()
    }
}
