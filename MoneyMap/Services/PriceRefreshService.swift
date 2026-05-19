import Foundation
import SwiftData

enum PriceRefreshService {
    /// 刷新所有持仓的当前价 + 汇率。失败的资产保留旧价。
    @MainActor
    static func refreshAll(context: ModelContext) async {
        let positions = (try? context.fetch(FetchDescriptor<Position>())) ?? []
        let accounts = (try? context.fetch(FetchDescriptor<Account>())) ?? []

        // 完全没有持仓 且 没有外币账户(HKD/USD)时,FX/价格接口都无需调用,
        // 避免新用户进入首页后还要等 1-3s 的 FX 拉取。
        let hasForeignCurrency = accounts.contains {
            $0.currency != .cny
        } || positions.contains { ($0.account?.currency ?? .cny) != .cny }
        if positions.isEmpty && !hasForeignCurrency {
            return
        }

        let cal = Calendar.current
        let today = Date()

        await withTaskGroup(of: (UUID, PriceQuoteResult?).self) { group in
            for pos in positions {
                guard let acc = pos.account else { continue }
                let assetCode = pos.assetCode
                let accType = acc.type
                group.addTask {
                    let result: PriceQuoteResult?
                    do {
                        switch accType {
                        case .fundApp:
                            // 黄金 ETF 也可能在基金账户被持有
                            if GoldRecognizer.isGoldAssetCode(assetCode) {
                                result = try await PriceService.fetchAShare(code: assetCode)
                            } else {
                                result = try await PriceService.fetchFundNAV(code: assetCode)
                            }
                        case .brokerA:
                            // A股账户里的黄金 ETF 用 A股接口拉
                            result = try await PriceService.fetchAShare(code: assetCode)
                        case .brokerHK:
                            let code = assetCode.replacingOccurrences(of: ".HK", with: "")
                            result = try await PriceService.fetchHKStock(code: code)
                        case .brokerUS:
                            let symbol = assetCode.replacingOccurrences(of: ".US", with: "")
                            result = try await PriceService.fetchUSStock(symbol: symbol)
                        case .brokerHKUS:
                            if assetCode.hasSuffix(".HK") {
                                let code = assetCode.replacingOccurrences(of: ".HK", with: "")
                                result = try await PriceService.fetchHKStock(code: code)
                            } else if assetCode.hasSuffix(".US") {
                                let symbol = assetCode.replacingOccurrences(of: ".US", with: "")
                                result = try await PriceService.fetchUSStock(symbol: symbol)
                            } else {
                                result = try await PriceService.fetchUSStock(symbol: assetCode)
                            }
                        case .goldDeposit:
                            // 积存金、纸黄金 — 拉黄金现货 CNY/克
                            result = try await PriceService.fetchGoldSpotCNYPerGram()
                        case .goldPhysical:
                            // 实体黄金价格随时间变动较少,但仍按现货价更新
                            result = try await PriceService.fetchGoldSpotCNYPerGram()
                        default:
                            result = nil
                        }
                    } catch {
                        result = nil
                    }
                    return (pos.id, result)
                }
            }

            for await (id, quote) in group {
                guard let quote = quote,
                      let pos = positions.first(where: { $0.id == id })
                else { continue }
                pos.prevClosePrice = quote.prevClose
                pos.lastPrice = quote.price
                pos.updatedAt = today
            }
        }
        _ = cal

        await refreshRates(context: context)
        try? context.save()

        await refreshHistorical(context: context)
    }

    /// 拉历史净值/股价填充 weekAgo / monthAgo / yearStart。
    /// 失败时保留旧值,不报错。
    @MainActor
    private static func refreshHistorical(context: ModelContext) async {
        let positions = (try? context.fetch(FetchDescriptor<Position>())) ?? []
        await withTaskGroup(of: (UUID, PriceService.HistoricalMilestones?).self) { group in
            for pos in positions {
                guard let acc = pos.account else { continue }
                let assetCode = pos.assetCode
                let accType = acc.type
                group.addTask {
                    let result: PriceService.HistoricalMilestones?
                    do {
                        switch accType {
                        case .fundApp:
                            result = try await PriceService.fetchFundHistorical(code: assetCode)
                        case .brokerA:
                            let suffix: String
                            if assetCode.hasPrefix("6") || assetCode.hasPrefix("5") || assetCode.hasPrefix("9") {
                                suffix = ".SS"
                            } else {
                                suffix = ".SZ"
                            }
                            result = try await PriceService.fetchYahooHistorical(yahooSymbol: assetCode + suffix)
                        case .brokerHK:
                            let clean = assetCode.replacingOccurrences(of: ".HK", with: "")
                            let padded = clean.count < 4 ? String(repeating: "0", count: 4 - clean.count) + clean : clean
                            result = try await PriceService.fetchYahooHistorical(yahooSymbol: padded + ".HK")
                        case .brokerUS:
                            let clean = assetCode.replacingOccurrences(of: ".US", with: "")
                            result = try await PriceService.fetchYahooHistorical(yahooSymbol: clean)
                        case .brokerHKUS:
                            if assetCode.hasSuffix(".HK") {
                                let clean = assetCode.replacingOccurrences(of: ".HK", with: "")
                                let padded = clean.count < 4 ? String(repeating: "0", count: 4 - clean.count) + clean : clean
                                result = try await PriceService.fetchYahooHistorical(yahooSymbol: padded + ".HK")
                            } else {
                                let clean = assetCode.replacingOccurrences(of: ".US", with: "")
                                result = try await PriceService.fetchYahooHistorical(yahooSymbol: clean)
                            }
                        default:
                            result = nil
                        }
                    } catch {
                        result = nil
                    }
                    return (pos.id, result)
                }
            }

            for await (id, m) in group {
                guard let m = m, let pos = positions.first(where: { $0.id == id }) else { continue }
                if let w = m.weekAgo, w > 0 { pos.weekAgoPrice = w }
                if let mo = m.monthAgo, mo > 0 { pos.monthAgoPrice = mo }
                if let y = m.yearStart, y > 0 { pos.yearStartPrice = y }
            }
        }
        try? context.save()
    }

    @MainActor
    private static func refreshRates(context: ModelContext) async {
        let pairs: [(CurrencyCode, CurrencyCode)] = [(.hkd, .cny), (.usd, .cny)]
        for (from, to) in pairs {
            do {
                let rate = try await PriceService.fetchFXRate(from: from, to: to)
                let existing = try? context.fetch(
                    FetchDescriptor<ExchangeRate>()
                ).first { $0.fromCurrency == from.rawValue && $0.toCurrency == to.rawValue }
                if let r = existing {
                    r.rate = rate
                    r.date = Date()
                } else {
                    context.insert(ExchangeRate(from: from, to: to, rate: rate))
                }
            } catch {
                continue
            }
        }
    }
}
