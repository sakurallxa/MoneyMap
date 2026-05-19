import Foundation

/// 单一行情分发入口 — 输入资产代码 + 账户类型,输出统一的 PriceQuoteResult。
/// 替代 AddPositionSheet / AddDCAPlanSheet / EditDCAPlanSheet / TransactionFormView 各自的派发代码。
enum QuoteResolver {
    enum ResolverError: LocalizedError {
        case unsupportedAccountType
        var errorDescription: String? {
            switch self {
            case .unsupportedAccountType: return "当前账户类型暂不支持自动拉取行情"
            }
        }
    }

    /// 按账户类型拉取报价。智能容错:即使账户类型与代码格式不严格匹配,
    /// 也会按代码格式做 fallback,避免用户把券商账户误分类导致拉不到行情。
    /// - Parameters:
    ///   - code: 用户输入的资产代码(可以带 .HK / .US 后缀,内部会规范化)
    ///   - accountType: 决定 **首选** API;失败时按代码格式做兜底
    /// - Throws: `ResolverError` 或上游 `PriceServiceError`
    static func quote(code rawCode: String, accountType: AccountType) async throws -> PriceQuoteResult {
        let code = rawCode.uppercased().trimmingCharacters(in: .whitespaces)

        // 全局兜底:**纯字母代码**几乎只可能是美股(AAPL / TSLA / NVDA 等)。
        // 在任何"非美股"账户里输入字母代码,都先尝试美股 API,避免被错配到基金/A股/港股 API 后失败。
        // .US 后缀也归到这里。
        let stripped = code.replacingOccurrences(of: ".US", with: "")
        let looksLikeUSTicker = !stripped.isEmpty && stripped.allSatisfy { $0.isLetter }
        if looksLikeUSTicker && accountType != .brokerUS && accountType != .brokerHKUS {
            return try await PriceService.fetchUSStock(symbol: stripped)
        }

        switch accountType {
        case .fundApp:
            // 黄金 ETF 也常被放在基金 App 账户里
            if GoldRecognizer.isGoldAssetCode(code) {
                return try await PriceService.fetchAShare(code: code)
            }
            return try await PriceService.fetchFundNAV(code: code)

        case .brokerA:
            return try await PriceService.fetchAShare(code: code)

        case .brokerHK:
            let c = code.replacingOccurrences(of: ".HK", with: "")
            return try await PriceService.fetchHKStock(code: c)

        case .brokerUS:
            // 智能容错:用户在 US 账户输入了 5 位纯数字(实际是港股)→ 尝试 HK
            if code.count == 5, code.allSatisfy({ $0.isNumber }) {
                return try await PriceService.fetchHKStock(code: code)
            }
            let c = code.replacingOccurrences(of: ".US", with: "")
            return try await PriceService.fetchUSStock(symbol: c)

        case .brokerHKUS:
            if code.hasSuffix(".HK") {
                let c = code.replacingOccurrences(of: ".HK", with: "")
                return try await PriceService.fetchHKStock(code: c)
            } else if code.hasSuffix(".US") {
                let c = code.replacingOccurrences(of: ".US", with: "")
                return try await PriceService.fetchUSStock(symbol: c)
            } else {
                // 没后缀 — 按格式推断:全字母 → 美股;数字 → 港股
                if code.allSatisfy({ $0.isLetter }) {
                    return try await PriceService.fetchUSStock(symbol: code)
                } else {
                    return try await PriceService.fetchHKStock(code: code)
                }
            }

        case .goldDeposit, .goldPhysical:
            return try await PriceService.fetchGoldSpotCNYPerGram()

        case .cash, .moneyFund:
            throw ResolverError.unsupportedAccountType
        }
    }

    /// 仅拉取名称(不关心价格变化),用于资产名自动同步场景。
    /// 失败时返回 nil 而不是抛错 — 调用方决定是否兜底(如 GoldRecognizer.inferGoldName)。
    static func resolveAssetName(code: String, accountType: AccountType) async -> String? {
        guard let result = try? await quote(code: code, accountType: accountType) else {
            return nil
        }
        return result.assetName
    }
}
