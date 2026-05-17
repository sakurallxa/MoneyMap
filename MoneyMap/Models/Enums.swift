import Foundation

enum AccountType: String, Codable, CaseIterable {
    case cash = "CASH"
    case moneyFund = "MONEY_FUND"
    case fundApp = "FUND_APP"
    case brokerA = "BROKER_A"
    case brokerHK = "BROKER_HK"
    case brokerUS = "BROKER_US"
    case brokerHKUS = "BROKER_HKUS"
    case goldDeposit = "GOLD_DEPOSIT"
    case goldPhysical = "GOLD_PHYSICAL"

    var displayName: String {
        switch self {
        case .cash: return "现金账户"
        case .moneyFund: return "货币基金"
        case .fundApp: return "基金账户"
        case .brokerA: return "A 股账户"
        case .brokerHK: return "港股账户"
        case .brokerUS: return "美股账户"
        case .brokerHKUS: return "港美股账户"
        case .goldDeposit: return "积存金 / 纸黄金"
        case .goldPhysical: return "实体黄金"
        }
    }

    var iconName: String {
        switch self {
        case .cash: return "creditcard.fill"
        case .moneyFund: return "yensign.circle.fill"
        case .fundApp: return "chart.pie.fill"
        case .brokerA: return "chart.line.uptrend.xyaxis"
        case .brokerHK: return "h.square.fill"
        case .brokerUS: return "dollarsign.circle.fill"
        case .brokerHKUS: return "globe.asia.australia.fill"
        case .goldDeposit: return "circle.hexagongrid.fill"
        case .goldPhysical: return "shield.checkered"
        }
    }

    var isInvestment: Bool {
        switch self {
        case .fundApp, .brokerA, .brokerHK, .brokerUS, .brokerHKUS, .goldDeposit, .goldPhysical: return true
        case .cash, .moneyFund: return false
        }
    }

    var isGold: Bool {
        self == .goldDeposit || self == .goldPhysical
    }

    /// 新建账户时只显示这些可选项;legacy `brokerHKUS` 仅为兼容旧数据保留。
    static var userSelectable: [AccountType] {
        [.cash, .moneyFund, .fundApp, .brokerA, .brokerHK, .brokerUS, .goldDeposit, .goldPhysical]
    }

    /// 新建账户时按类型推荐的默认币种 — 港股=HKD,美股=USD,其他=CNY。
    var defaultCurrency: CurrencyCode {
        switch self {
        case .brokerHK: return .hkd
        case .brokerUS, .brokerHKUS: return .usd
        default: return .cny
        }
    }
}

enum CurrencyCode: String, Codable, CaseIterable {
    case cny = "CNY"
    case hkd = "HKD"
    case usd = "USD"

    var symbol: String {
        switch self {
        case .cny: return "¥"
        case .hkd: return "HK$"
        case .usd: return "$"
        }
    }

    /// 用户面向的中文名 — 用于 picker / 标签等 UI 展示。
    var displayName: String {
        switch self {
        case .cny: return "人民币"
        case .hkd: return "港币"
        case .usd: return "美元"
        }
    }
}

enum AssetType: String, Codable, CaseIterable {
    case cash = "CASH"
    case moneyFund = "MONEY_FUND"
    case openFund = "OPEN_FUND"
    case stockA = "STOCK_A"
    case stockHK = "STOCK_HK"
    case stockUS = "STOCK_US"

    var displayName: String {
        switch self {
        case .cash: return "现金"
        case .moneyFund: return "货基"
        case .openFund: return "基金"
        case .stockA: return "A 股"
        case .stockHK: return "港股"
        case .stockUS: return "美股"
        }
    }
}

enum AssetMarket: String, Codable {
    case sh = "SH"
    case sz = "SZ"
    case hk = "HK"
    case us = "US"
    case fund = "FUND"
}

enum TransactionType: String, Codable, CaseIterable {
    case buyFund = "BUY_FUND"
    case sellFund = "SELL_FUND"
    case buyStock = "BUY_STOCK"
    case sellStock = "SELL_STOCK"
    case dcaDeduct = "DCA_DEDUCT"
    case dcaConfirm = "DCA_CONFIRM"
    case transfer = "TRANSFER"
    case dividend = "DIVIDEND"
    case deposit = "DEPOSIT"
    case withdraw = "WITHDRAW"

    var displayName: String {
        switch self {
        case .buyFund: return "申购基金"
        case .sellFund: return "赎回基金"
        case .buyStock: return "买入股票"
        case .sellStock: return "卖出股票"
        case .dcaDeduct: return "定投扣款"
        case .dcaConfirm: return "定投确认"
        case .transfer: return "账户转账"
        case .dividend: return "分红"
        case .deposit: return "入金"
        case .withdraw: return "出金"
        }
    }
}

enum TransactionStatus: String, Codable, CaseIterable {
    case pending = "PENDING"
    case confirmed = "CONFIRMED"
    case completed = "COMPLETED"
    case cancelled = "CANCELLED"

    var displayName: String {
        switch self {
        case .pending: return "在途"
        case .confirmed: return "已确认"
        case .completed: return "已完成"
        case .cancelled: return "已取消"
        }
    }
}

/// 走势图区间——选定后取该区间内的所有每日快照绘制成折线。
/// 日 = 近 1 天;周 = 近 7 天;月 = 近 30 天;今年 = 自年初;全部 = 完整历史。
enum TrendRange: String, CaseIterable {
    case day = "D"
    case week = "W"
    case month = "M"
    case ytd = "YTD"
    case all = "ALL"

    var displayName: String {
        switch self {
        case .day: return "日"
        case .week: return "周"
        case .month: return "月"
        case .ytd: return "今年"
        case .all: return "全部"
        }
    }

    /// 走势卡的时间窗口起点。
    /// - 日:近 7 天(按天聚合)
    /// - 周:近 3 个月(按周聚合,~13 个点)
    /// - 月:近 1 年(按月聚合)
    /// - 今年:今年初至今(按月聚合)
    /// - 全部:近 5 年(按月聚合,曲线感强)
    var startDate: Date? {
        let cal = Calendar.current
        let now = Date()
        switch self {
        case .day:
            return cal.date(byAdding: .day, value: -7, to: now)
        case .week:
            return cal.date(byAdding: .month, value: -3, to: now)
        case .month:
            return cal.date(byAdding: .year, value: -1, to: now)
        case .ytd:
            return cal.date(from: cal.dateComponents([.year], from: now))
        case .all:
            return cal.date(byAdding: .year, value: -5, to: now)
        }
    }

    /// 聚合粒度(将按天的 DailySnapshot 折算成期末值序列)。
    enum Bucket {
        case day, week, month
    }

    var bucket: Bucket {
        switch self {
        case .day: return .day
        case .week: return .week
        case .month, .ytd, .all: return .month
        }
    }
}

enum RebalanceModel: String, Codable, CaseIterable {
    case conservative = "CONSERVATIVE"
    case balanced = "BALANCED"
    case aggressive = "AGGRESSIVE"
    case classic = "CLASSIC"
    case custom = "CUSTOM"

    var displayName: String {
        switch self {
        case .conservative: return "保守"
        case .balanced: return "平衡"
        case .aggressive: return "激进"
        case .classic: return "经典"
        case .custom: return "自定义"
        }
    }

    var tagline: String {
        switch self {
        case .conservative: return "现金/货基为主,股票占比低,适合 1-3 年要用的钱"
        case .balanced: return "中等风险,长期稳健增长,适合大部分人"
        case .aggressive: return "股票/基金占比高,追求长期高回报,需承受短期波动"
        case .classic: return "经典「永久投资组合」 · Harry Browne 1981 年提出 · 股 / 债 / 金 / 现 各 25%,跨经济周期稳健"
        case .custom: return "完全按你设定的比例"
        }
    }

    var presetTargets: [AssetClass: Double] {
        switch self {
        case .conservative:
            return [.cash: 20, .moneyFund: 25, .fund: 30, .stockA: 5, .stockHK: 5, .stockUS: 5, .gold: 10]
        case .balanced:
            return [.cash: 10, .moneyFund: 15, .fund: 30, .stockA: 15, .stockHK: 10, .stockUS: 10, .gold: 10]
        case .aggressive:
            return [.cash: 5, .moneyFund: 5, .fund: 20, .stockA: 25, .stockHK: 15, .stockUS: 20, .gold: 10]
        case .classic:
            // 永久投资组合 25/25/25/25:股/债/金/现
            // 在我们 7 大类里拆分:
            //   现金类(cash+moneyFund) 25 → 10/15
            //   股票类(A+HK+US) 25 → 10/8/7
            //   基金 25(代理长期债券基金)
            //   黄金 25
            return [.cash: 10, .moneyFund: 15, .fund: 25, .stockA: 10, .stockHK: 8, .stockUS: 7, .gold: 25]
        case .custom:
            return [:]
        }
    }
}

enum AssetClass: String, Codable, CaseIterable {
    case cash = "CASH"
    case moneyFund = "MONEY_FUND"
    case fund = "FUND"
    case stockA = "STOCK_A"
    case stockHK = "STOCK_HK"
    case stockUS = "STOCK_US"
    case gold = "GOLD"

    var displayName: String {
        switch self {
        case .cash: return "现金"
        case .moneyFund: return "货基"
        case .fund: return "基金"
        case .stockA: return "A 股"
        case .stockHK: return "港股"
        case .stockUS: return "美股"
        case .gold: return "黄金"
        }
    }

    var hexColor: String {
        switch self {
        case .cash: return "#5B8FF9"
        case .moneyFund: return "#7B68EE"
        case .fund: return "#F4B860"
        case .stockA: return "#E63946"
        case .stockHK: return "#2A9D8F"
        case .stockUS: return "#1ABC9C"
        case .gold: return "#D4AF37"
        }
    }
}

enum GoldRecognizer {
    /// 常见 A 股黄金 ETF 代码 — 即使在 A 股账户也归到 gold 类别
    static let goldETFCodes: Set<String> = [
        "518880", // 华安黄金易ETF
        "518800", // 国泰黄金ETF
        "159934", // 易方达黄金ETF
        "159937", // 博时黄金ETF
        "518660", // 工银黄金ETF
        "518680", // 建信易黄金ETF
        "518600", // 国泰黄金联接
        "159812", // 平安黄金ETF
        "518890", // 永赢黄金ETF
    ]

    static func isGoldAssetCode(_ code: String) -> Bool {
        goldETFCodes.contains(code.uppercased())
    }
}

enum DCAFrequency: String, Codable, CaseIterable {
    case daily = "DAILY"
    case weekly = "WEEKLY"
    case biweekly = "BIWEEKLY"
    case monthly = "MONTHLY"

    var displayName: String {
        switch self {
        case .daily: return "每天"
        case .weekly: return "每周"
        case .biweekly: return "每两周"
        case .monthly: return "每月"
        }
    }

    var needsDayOfWeek: Bool { self == .weekly || self == .biweekly }
    var needsDayOfMonth: Bool { self == .monthly }
}

enum WeekdayPicker {
    /// 我们的内部约定:1=周一, 7=周日
    static let labels: [String] = ["一", "二", "三", "四", "五", "六", "日"]
    static func displayName(_ dayOfWeek: Int) -> String {
        let idx = max(1, min(7, dayOfWeek)) - 1
        return "周" + labels[idx]
    }

    /// 转换为系统 Calendar.weekday(1=周日, 2=周一, ..., 7=周六)
    static func toCalendarWeekday(_ dayOfWeek: Int) -> Int {
        // 我们的 1=周一 → Calendar 2; 7=周日 → Calendar 1
        return dayOfWeek == 7 ? 1 : dayOfWeek + 1
    }
}
