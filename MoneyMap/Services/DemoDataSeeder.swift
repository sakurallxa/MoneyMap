import Foundation
import SwiftData

enum DemoDataSeeder {
    static func seedIfNeeded(context: ModelContext) {
        let descriptor = FetchDescriptor<Account>()
        let existing = (try? context.fetchCount(descriptor)) ?? 0
        guard existing == 0 else { return }
        seed(context: context)
    }

    static func seed(context: ModelContext) {
        let zhaoshang = Account(name: "招商银行卡", type: .cash, currency: .cny, cashBalance: 12580.50, note: "工资卡 / 定投扣款源")
        let chaoChao = Account(name: "朝朝宝", type: .moneyFund, currency: .cny, cashBalance: 35000.00, note: "招行活期理财")
        let yuEbao = Account(name: "余额宝", type: .moneyFund, currency: .cny, cashBalance: 6250.00, note: "支付宝货币基金")
        let aliFund = Account(name: "支付宝基金", type: .fundApp, currency: .cny, cashBalance: 0, note: "")
        let guangfa = Account(name: "广发基金 App", type: .fundApp, currency: .cny, cashBalance: 0, note: "")
        let nanfang = Account(name: "南方基金 App", type: .fundApp, currency: .cny, cashBalance: 0, note: "")
        let boshi = Account(name: "博时基金 App", type: .fundApp, currency: .cny, cashBalance: 0, note: "")
        let zhongxin = Account(name: "中信证券", type: .brokerA, currency: .cny, cashBalance: 2000.00, note: "")
        let yingliHK = Account(name: "盈立证券 · 港股", type: .brokerHK, currency: .hkd, cashBalance: 8500.00, note: "")
        let yingliUS = Account(name: "盈立证券 · 美股", type: .brokerUS, currency: .usd, cashBalance: 850.00, note: "")
        let aliGold = Account(name: "支付宝黄金", type: .goldDeposit, currency: .cny, cashBalance: 0, note: "积存金 · Au99.99")
        let physGold = Account(name: "家里金条", type: .goldPhysical, currency: .cny, cashBalance: 0, note: "实体投资金")

        let accounts = [zhaoshang, chaoChao, yuEbao, aliFund, guangfa, nanfang, boshi, zhongxin, yingliHK, yingliUS, aliGold, physGold]
        accounts.forEach { context.insert($0) }

        let p1 = Position(account: aliFund, assetCode: "005827", assetName: "易方达蓝筹精选",
                          shares: 1234.56, avgCost: 2.180, lastPrice: 2.345,
                          prevClosePrice: 2.338, weekAgoPrice: 2.312, monthAgoPrice: 2.280, yearStartPrice: 2.195)
        let p1b = Position(account: aliFund, assetCode: "001632", assetName: "天弘中证食品饮料",
                          shares: 2800.00, avgCost: 1.250, lastPrice: 1.408,
                          prevClosePrice: 1.395, weekAgoPrice: 1.380, monthAgoPrice: 1.342, yearStartPrice: 1.260)
        let p2 = Position(account: guangfa, assetCode: "005176", assetName: "广发科技先锋",
                          shares: 3200.00, avgCost: 1.745, lastPrice: 1.876,
                          prevClosePrice: 1.882, weekAgoPrice: 1.901, monthAgoPrice: 1.820, yearStartPrice: 1.760)
        let p2b = Position(account: guangfa, assetCode: "270002", assetName: "广发稳健增长",
                          shares: 1500.00, avgCost: 4.250, lastPrice: 4.512,
                          prevClosePrice: 4.498, weekAgoPrice: 4.460, monthAgoPrice: 4.380, yearStartPrice: 4.150)
        let p3 = Position(account: nanfang, assetCode: "004348", assetName: "南方中证 500 联接",
                          shares: 4500.00, avgCost: 1.310, lastPrice: 1.234,
                          prevClosePrice: 1.228, weekAgoPrice: 1.215, monthAgoPrice: 1.198, yearStartPrice: 1.295)
        let p3b = Position(account: nanfang, assetCode: "202301", assetName: "南方现金通利货币",
                          shares: 50000.00, avgCost: 1.000, lastPrice: 1.000,
                          prevClosePrice: 1.000, weekAgoPrice: 1.000, monthAgoPrice: 1.000, yearStartPrice: 1.000)
        let p4 = Position(account: boshi, assetCode: "050026", assetName: "博时医疗保健",
                          shares: 1500.00, avgCost: 3.200, lastPrice: 3.456,
                          prevClosePrice: 3.421, weekAgoPrice: 3.380, monthAgoPrice: 3.298, yearStartPrice: 3.150)
        let p5 = Position(account: zhongxin, assetCode: "510880", assetName: "红利 ETF",
                          shares: 1000.00, avgCost: 3.120, lastPrice: 3.450,
                          prevClosePrice: 3.428, weekAgoPrice: 3.395, monthAgoPrice: 3.380, yearStartPrice: 3.205)
        let p5b = Position(account: zhongxin, assetCode: "600519", assetName: "贵州茅台",
                          shares: 5, avgCost: 1680.00, lastPrice: 1742.50,
                          prevClosePrice: 1730.20, weekAgoPrice: 1715.00, monthAgoPrice: 1688.80, yearStartPrice: 1620.40)
        let p5c = Position(account: zhongxin, assetCode: "300750", assetName: "宁德时代",
                          shares: 30, avgCost: 225.00, lastPrice: 248.30,
                          prevClosePrice: 246.80, weekAgoPrice: 243.20, monthAgoPrice: 235.50, yearStartPrice: 198.40)
        let p6 = Position(account: yingliHK, assetCode: "0700.HK", assetName: "腾讯控股",
                          shares: 10, avgCost: 360.00, lastPrice: 385.00,
                          prevClosePrice: 382.50, weekAgoPrice: 378.00, monthAgoPrice: 370.50, yearStartPrice: 348.20)
        let p6b = Position(account: yingliHK, assetCode: "9988.HK", assetName: "阿里巴巴",
                          shares: 20, avgCost: 85.00, lastPrice: 92.40,
                          prevClosePrice: 91.80, weekAgoPrice: 90.20, monthAgoPrice: 88.50, yearStartPrice: 76.80)
        let p7 = Position(account: yingliUS, assetCode: "AAPL.US", assetName: "苹果",
                          shares: 3, avgCost: 215.00, lastPrice: 232.10,
                          prevClosePrice: 230.45, weekAgoPrice: 228.50, monthAgoPrice: 225.30, yearStartPrice: 207.80)
        let p7b = Position(account: yingliUS, assetCode: "NVDA.US", assetName: "英伟达",
                          shares: 5, avgCost: 98.00, lastPrice: 145.20,
                          prevClosePrice: 142.50, weekAgoPrice: 138.20, monthAgoPrice: 131.40, yearStartPrice: 86.50)
        let p7c = Position(account: yingliUS, assetCode: "TSLA.US", assetName: "特斯拉",
                          shares: 2, avgCost: 245.00, lastPrice: 318.40,
                          prevClosePrice: 312.80, weekAgoPrice: 305.50, monthAgoPrice: 295.20, yearStartPrice: 248.60)
        let p8 = Position(account: aliGold, assetCode: "AU9999", assetName: "黄金现货 Au99.99",
                          shares: 30, avgCost: 580.00, lastPrice: 612.50,
                          prevClosePrice: 610.20, weekAgoPrice: 605.80, monthAgoPrice: 598.40, yearStartPrice: 545.00)
        let p9 = Position(account: physGold, assetCode: "GOLDBAR", assetName: "投资金条 100g",
                          shares: 100, avgCost: 545.00, lastPrice: 612.50,
                          prevClosePrice: 610.20, weekAgoPrice: 605.80, monthAgoPrice: 598.40, yearStartPrice: 545.00)
        [p1, p1b, p2, p2b, p3, p3b, p4, p5, p5b, p5c, p6, p6b, p7, p7b, p7c, p8, p9].forEach { context.insert($0) }

        let today = Date()
        let cal = Calendar.current

        let dca = DCAPlan(
            name: "每周一定投 易方达蓝筹精选",
            sourceAccountID: zhaoshang.id,
            sourceAccountName: zhaoshang.name,
            targetAccountID: aliFund.id,
            targetAccountName: aliFund.name,
            targetAssetCode: "005827",
            targetAssetName: "易方达蓝筹精选",
            amount: 500,
            frequency: .weekly,
            nextRunDate: DCAService.computeNextRun(frequency: .weekly, dayOfWeek: 1, dayOfMonth: 1),
            dayOfWeek: 1,
            isActive: true
        )
        let dca2 = DCAPlan(
            name: "每月 1 号定投 南方中证 500",
            sourceAccountID: zhaoshang.id,
            sourceAccountName: zhaoshang.name,
            targetAccountID: nanfang.id,
            targetAccountName: nanfang.name,
            targetAssetCode: "004348",
            targetAssetName: "南方中证 500 联接",
            amount: 1000,
            frequency: .monthly,
            nextRunDate: DCAService.computeNextRun(frequency: .monthly, dayOfWeek: 1, dayOfMonth: 1),
            dayOfMonth: 1,
            isActive: true
        )
        let dca3 = DCAPlan(
            name: "每两周三定投 黄金积存",
            sourceAccountID: zhaoshang.id,
            sourceAccountName: zhaoshang.name,
            targetAccountID: aliGold.id,
            targetAccountName: aliGold.name,
            targetAssetCode: "AU9999",
            targetAssetName: "黄金现货 Au99.99",
            amount: 300,
            frequency: .biweekly,
            nextRunDate: DCAService.computeNextRun(frequency: .biweekly, dayOfWeek: 3, dayOfMonth: 1),
            dayOfWeek: 3,
            isActive: true
        )
        context.insert(dca)
        context.insert(dca2)
        context.insert(dca3)

        let tx1 = TransactionRecord(
            tradeDate: today,
            type: .dcaDeduct,
            status: .pending,
            fromAccountID: zhaoshang.id,
            toAccountID: aliFund.id,
            fromAccountName: zhaoshang.name,
            toAccountName: aliFund.name,
            assetCode: "005827",
            assetName: "易方达蓝筹精选",
            amount: 500,
            note: "周一定投扣款,等待 T+1 确认",
            dcaPlanID: dca.id
        )

        let tx2 = TransactionRecord(
            tradeDate: cal.date(byAdding: .day, value: -1, to: today)!,
            type: .dividend,
            status: .completed,
            toAccountID: yuEbao.id,
            toAccountName: yuEbao.name,
            assetCode: "510880",
            assetName: "红利 ETF",
            amount: 56.30,
            note: "现金分红到账"
        )

        let tx3 = TransactionRecord(
            tradeDate: cal.date(byAdding: .day, value: -3, to: today)!,
            type: .dcaConfirm,
            status: .confirmed,
            fromAccountID: zhaoshang.id,
            toAccountID: nanfang.id,
            fromAccountName: zhaoshang.name,
            toAccountName: nanfang.name,
            assetCode: "004348",
            assetName: "南方中证 500 联接",
            amount: 1000,
            shares: 810.37,
            price: 1.234,
            note: "月定投确认份额"
        )

        let tx4 = TransactionRecord(
            tradeDate: cal.date(byAdding: .day, value: -5, to: today)!,
            type: .buyStock,
            status: .completed,
            fromAccountID: yingliHK.id,
            toAccountID: yingliHK.id,
            fromAccountName: yingliHK.name,
            toAccountName: yingliHK.name,
            assetCode: "0700.HK",
            assetName: "腾讯控股",
            amount: 3850,
            shares: 10,
            price: 385.00,
            fee: 8.50,
            note: "港股买入"
        )

        // 同一天多笔 — 测试 List 同日多 row 的视觉效果
        let busyDay = cal.date(byAdding: .day, value: -2, to: today)!
        let tx5 = TransactionRecord(
            tradeDate: cal.date(byAdding: .hour, value: 9, to: busyDay)!,
            type: .deposit,
            status: .completed,
            toAccountID: zhaoshang.id,
            toAccountName: zhaoshang.name,
            amount: 8000,
            note: "工资入账"
        )
        let tx6 = TransactionRecord(
            tradeDate: cal.date(byAdding: .hour, value: 10, to: busyDay)!,
            type: .transfer,
            status: .completed,
            fromAccountID: zhaoshang.id,
            toAccountID: yuEbao.id,
            fromAccountName: zhaoshang.name,
            toAccountName: yuEbao.name,
            amount: 3000,
            note: "转一部分到余额宝"
        )
        let tx7 = TransactionRecord(
            tradeDate: cal.date(byAdding: .hour, value: 14, to: busyDay)!,
            type: .buyFund,
            status: .completed,
            fromAccountID: zhaoshang.id,
            toAccountID: aliFund.id,
            fromAccountName: zhaoshang.name,
            toAccountName: aliFund.name,
            assetCode: "270002",
            assetName: "广发稳健增长",
            amount: 2000,
            shares: 1234.5678,
            price: 1.6201,
            note: "手动加仓"
        )
        let tx8 = TransactionRecord(
            tradeDate: cal.date(byAdding: .hour, value: 16, to: busyDay)!,
            type: .withdraw,
            status: .completed,
            fromAccountID: zhaoshang.id,
            fromAccountName: zhaoshang.name,
            amount: 500,
            note: "提现 ATM"
        )

        [tx1, tx2, tx3, tx4, tx5, tx6, tx7, tx8].forEach { context.insert($0) }

        seedSnapshots(context: context, today: today)

        let hkdRate = ExchangeRate(from: .hkd, to: .cny, rate: 0.92)
        let usdRate = ExchangeRate(from: .usd, to: .cny, rate: 7.18)
        context.insert(hkdRate)
        context.insert(usdRate)

        for (cls, pct) in RebalanceService.defaultTargets() {
            context.insert(TargetAllocation(assetClass: cls, percent: pct))
        }

        try? context.save()
    }

    private static func seedSnapshots(context: ModelContext, today: Date) {
        // 种 3 年(1095 天)历史日快照,模拟长期累计,让走势图 周/月/年 粒度都有数据。
        // 趋势:从 3 年前的 ¥45,000 缓慢爬升到今天的 ¥240,000(包含 demo 持仓)。
        let cal = Calendar.current
        let totalDays = 365 * 3
        let startValue = 45_000.0
        let endValue = 240_000.0
        var prev = startValue
        for i in stride(from: totalDays, through: 0, by: -1) {
            guard let d = cal.date(byAdding: .day, value: -i, to: today) else { continue }
            let progress = Double(totalDays - i) / Double(totalDays)
            // 复合增长曲线 + 周期性波动 + 随机噪声
            let baseTrend = startValue + (endValue - startValue) * progress
            let wave = sin(Double(totalDays - i) / 30.0) * (baseTrend * 0.04)
            let noise = Double.random(in: -800...1200)
            let total = baseTrend + wave + noise
            let delta = total - prev
            let pct = prev > 0 ? delta / prev * 100 : 0
            let snap = DailySnapshot(
                date: cal.startOfDay(for: d),
                totalValueCNY: total,
                cashValue: total * 0.30,
                moneyFundValue: total * 0.15,
                fundValue: total * 0.20,
                stockAValue: total * 0.05,
                stockHKValue: total * 0.04,
                stockUSValue: total * 0.06,
                pendingValue: i == 0 ? 500 : 0,
                dailyChange: delta,
                dailyChangePct: pct
            )
            context.insert(snap)
            prev = total
        }
    }
}
