import Foundation

struct AccountReturns {
    var marketValue: Double = 0
    var totalCost: Double = 0
    var dailyPnL: Double = 0
    var weeklyPnL: Double = 0
    var monthlyPnL: Double = 0
    var ytdPnL: Double = 0
    var unrealizedPnL: Double = 0

    var dailyPnLPercent: Double = 0
    var weeklyPnLPercent: Double = 0
    var monthlyPnLPercent: Double = 0
    var ytdPnLPercent: Double = 0
    var unrealizedPnLPercent: Double = 0

    var annualizedReturnPercent: Double = 0
}

enum AccountReturnsService {
    static func compute(
        account: Account,
        positions: [Position],
        today: Date = Date(),
        rates: [String: Double] = ["CNY": 1.0, "HKD": 0.92, "USD": 7.18]
    ) -> AccountReturns {
        let accountPositions = positions.filter { $0.account?.id == account.id }
        guard !accountPositions.isEmpty else {
            return AccountReturns()
        }

        var r = AccountReturns()
        var prevValue = 0.0
        var weekAgoValue = 0.0
        var monthAgoValue = 0.0
        var yearStartValue = 0.0

        for p in accountPositions {
            let fx = rates[p.effectiveCurrency.rawValue] ?? 1.0
            r.marketValue += p.marketValue * fx
            r.totalCost += p.totalCost * fx
            prevValue += p.shares * p.prevClosePrice * fx
            weekAgoValue += p.shares * p.weekAgoPrice * fx
            monthAgoValue += p.shares * p.monthAgoPrice * fx
            yearStartValue += p.shares * p.yearStartPrice * fx
        }

        r.dailyPnL = r.marketValue - prevValue
        r.weeklyPnL = r.marketValue - weekAgoValue
        r.monthlyPnL = r.marketValue - monthAgoValue
        r.ytdPnL = r.marketValue - yearStartValue
        r.unrealizedPnL = r.marketValue - r.totalCost

        r.dailyPnLPercent = pct(r.dailyPnL, base: prevValue)
        r.weeklyPnLPercent = pct(r.weeklyPnL, base: weekAgoValue)
        r.monthlyPnLPercent = pct(r.monthlyPnL, base: monthAgoValue)
        r.ytdPnLPercent = pct(r.ytdPnL, base: yearStartValue)
        r.unrealizedPnLPercent = pct(r.unrealizedPnL, base: r.totalCost)

        r.annualizedReturnPercent = annualize(ytdPercent: r.ytdPnLPercent, today: today)

        return r
    }

    private static func pct(_ delta: Double, base: Double) -> Double {
        guard base > 0 else { return 0 }
        return delta / base * 100
    }

    private static func annualize(ytdPercent: Double, today: Date) -> Double {
        let cal = Calendar.current
        let startOfYear = cal.date(from: cal.dateComponents([.year], from: today)) ?? today
        let daysElapsed = cal.dateComponents([.day], from: startOfYear, to: today).day ?? 1
        let elapsed = max(1, daysElapsed)
        let ratio = Double(elapsed) / 365.0
        guard ratio > 0 else { return ytdPercent }
        let multiplier = 1 + ytdPercent / 100
        guard multiplier > 0 else { return ytdPercent }
        return (pow(multiplier, 1 / ratio) - 1) * 100
    }
}
