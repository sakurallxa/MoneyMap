import Foundation

struct PriceQuoteResult {
    let price: Double
    let prevClose: Double
    var assetName: String? = nil
    var changePct: Double {
        guard prevClose > 0 else { return 0 }
        return (price - prevClose) / prevClose * 100
    }
}

extension String.Encoding {
    static let gb18030 = String.Encoding(rawValue: CFStringConvertEncodingToNSStringEncoding(
        CFStringEncoding(CFStringEncodings.GB_18030_2000.rawValue)
    ))
}

enum PriceServiceError: Error {
    case invalidResponse
    case parseFailed
    case notFound
}

enum PriceService {
    private static let session: URLSession = {
        let cfg = URLSessionConfiguration.default
        cfg.timeoutIntervalForRequest = 8
        cfg.timeoutIntervalForResource = 12
        return URLSession(configuration: cfg)
    }()

    // MARK: - 基金净值 (天天基金)
    /// 拉取基金估值,返回当前估值和前一日净值。
    /// 接口: https://fundgz.1234567.com.cn/js/{code}.js
    static func fetchFundNAV(code: String) async throws -> PriceQuoteResult {
        let ts = Int(Date().timeIntervalSince1970 * 1000)
        guard let url = URL(string: "https://fundgz.1234567.com.cn/js/\(code).js?rt=\(ts)") else {
            throw PriceServiceError.invalidResponse
        }
        let (data, response) = try await session.data(from: url)
        let httpStatus = (response as? HTTPURLResponse)?.statusCode ?? -1
        let preview = String(data: data, encoding: .utf8)?.prefix(200) ?? "<binary>"
        print("📦 [Fund \(code)] HTTP \(httpStatus) bytes=\(data.count) body=\(preview)")
        guard let text = String(data: data, encoding: .utf8),
              let start = text.firstIndex(of: "{"),
              let end = text.lastIndex(of: "}")
        else { throw PriceServiceError.parseFailed }

        let jsonStr = String(text[start...end])
        guard let jsonData = jsonStr.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any]
        else { throw PriceServiceError.parseFailed }

        let gsz = (obj["gsz"] as? String).flatMap { Double($0) }
        let dwjz = (obj["dwjz"] as? String).flatMap { Double($0) }
        let gszzl = (obj["gszzl"] as? String).flatMap { Double($0) } ?? 0
        let fundName = obj["name"] as? String

        let current = gsz ?? dwjz
        let prev = dwjz ?? current
        guard let curr = current, let pv = prev, curr > 0 else {
            throw PriceServiceError.parseFailed
        }
        let derivedPrev = gszzl != 0 ? curr / (1 + gszzl / 100) : pv
        return PriceQuoteResult(price: curr, prevClose: derivedPrev, assetName: fundName)
    }

    // MARK: - A 股行情 (新浪)
    /// 接口: https://hq.sinajs.cn/list=sh600519 / sz000001
    static func fetchAShare(code: String) async throws -> PriceQuoteResult {
        let prefix: String
        if code.hasPrefix("6") || code.hasPrefix("5") || code.hasPrefix("9") {
            prefix = "sh"
        } else {
            prefix = "sz"
        }
        return try await fetchSinaQuote(symbol: "\(prefix)\(code)", isHK: false)
    }

    // MARK: - 港股行情 (新浪)
    /// 接口: https://hq.sinajs.cn/list=hk00700
    static func fetchHKStock(code: String) async throws -> PriceQuoteResult {
        let padded = code.count < 5 ? String(repeating: "0", count: 5 - code.count) + code : code
        return try await fetchSinaQuote(symbol: "hk\(padded)", isHK: true)
    }

    private static func fetchSinaQuote(symbol: String, isHK: Bool) async throws -> PriceQuoteResult {
        guard let url = URL(string: "https://hq.sinajs.cn/list=\(symbol)") else {
            throw PriceServiceError.invalidResponse
        }
        var req = URLRequest(url: url)
        req.setValue("https://finance.sina.com.cn", forHTTPHeaderField: "Referer")
        req.setValue("Mozilla/5.0", forHTTPHeaderField: "User-Agent")
        let (data, _) = try await session.data(for: req)

        guard let eqIdx = data.firstIndex(of: UInt8(ascii: "=")),
              let firstQuoteRel = data[data.index(after: eqIdx)...].firstIndex(of: UInt8(ascii: "\"")),
              let endQuoteRel = data[data.index(after: firstQuoteRel)...].firstIndex(of: UInt8(ascii: "\""))
        else { throw PriceServiceError.parseFailed }

        let contentStart = data.index(after: firstQuoteRel)
        let contentEnd = endQuoteRel
        let content = data[contentStart..<contentEnd]

        var commas: [Data.Index] = []
        var i = content.startIndex
        while i < content.endIndex {
            if content[i] == UInt8(ascii: ",") {
                commas.append(i)
            }
            i = content.index(after: i)
        }
        guard commas.count >= 6 else { throw PriceServiceError.parseFailed }

        func bytes(_ idx: Int) -> Data {
            let s = idx == 0 ? content.startIndex : content.index(after: commas[idx - 1])
            let e = idx < commas.count ? commas[idx] : content.endIndex
            return Data(content[s..<e])
        }

        func partAscii(_ idx: Int) -> String? {
            String(data: bytes(idx), encoding: .ascii)
        }

        func partGB(_ idx: Int) -> String? {
            String(data: bytes(idx), encoding: .gb18030) ?? String(data: bytes(idx), encoding: .utf8)
        }

        // 港股: [0]英文名 [1]中文名 [2]开盘 [3]昨收 [4]最高 [5]最低 [6]当前
        // A 股: [0]中文名 [1]开盘 [2]昨收 [3]当前 [4]最高 [5]最低
        let prevCloseIdx = isHK ? 3 : 2
        let currentIdx = isHK ? 6 : 3
        let nameIdx = isHK ? 1 : 0

        guard let pStr = partAscii(prevCloseIdx), let cStr = partAscii(currentIdx),
              let prev = Double(pStr.trimmingCharacters(in: .whitespaces)),
              let curr = Double(cStr.trimmingCharacters(in: .whitespaces)),
              curr > 0
        else { throw PriceServiceError.parseFailed }

        let name = partGB(nameIdx)?.trimmingCharacters(in: .whitespaces)
        return PriceQuoteResult(price: curr, prevClose: prev, assetName: name?.isEmpty == false ? name : nil)
    }

    // MARK: - 美股行情 (Yahoo Finance)
    /// 接口: https://query1.finance.yahoo.com/v8/finance/chart/AAPL
    static func fetchUSStock(symbol: String) async throws -> PriceQuoteResult {
        guard let url = URL(string: "https://query1.finance.yahoo.com/v8/finance/chart/\(symbol)") else {
            throw PriceServiceError.invalidResponse
        }
        var req = URLRequest(url: url)
        req.setValue("Mozilla/5.0", forHTTPHeaderField: "User-Agent")
        let (data, response) = try await session.data(for: req)
        let httpStatus = (response as? HTTPURLResponse)?.statusCode ?? -1
        let preview = String(data: data, encoding: .utf8)?.prefix(300) ?? "<binary>"
        print("📦 [US \(symbol)] HTTP \(httpStatus) bytes=\(data.count) body=\(preview)")
        guard let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let chart = obj["chart"] as? [String: Any],
              let results = chart["result"] as? [[String: Any]],
              let first = results.first,
              let meta = first["meta"] as? [String: Any]
        else { throw PriceServiceError.parseFailed }

        let current = (meta["regularMarketPrice"] as? Double) ?? (meta["regularMarketPrice"] as? NSNumber)?.doubleValue
        let prev = (meta["chartPreviousClose"] as? Double) ?? (meta["previousClose"] as? Double) ?? (meta["chartPreviousClose"] as? NSNumber)?.doubleValue
        let name = (meta["longName"] as? String) ?? (meta["shortName"] as? String)
        guard let curr = current, curr > 0 else { throw PriceServiceError.parseFailed }
        return PriceQuoteResult(price: curr, prevClose: prev ?? curr, assetName: name)
    }

    // MARK: - 历史行情 (Yahoo Finance)
    struct HistoricalMilestones {
        let weekAgo: Double?
        let monthAgo: Double?
        let yearStart: Double?
    }

    /// 通过 Yahoo Finance 拉取 1 年内的日线,返回近 7 天 / 近 30 天 / 年初的收盘价。
    /// `yahooSymbol` 示例:`AAPL`(美股)、`0700.HK`(港股)、`600519.SS` / `000001.SZ`(A 股)。
    static func fetchYahooHistorical(yahooSymbol: String) async throws -> HistoricalMilestones {
        guard let url = URL(string: "https://query1.finance.yahoo.com/v8/finance/chart/\(yahooSymbol)?range=1y&interval=1d") else {
            throw PriceServiceError.invalidResponse
        }
        var req = URLRequest(url: url)
        req.setValue("Mozilla/5.0", forHTTPHeaderField: "User-Agent")
        let (data, _) = try await session.data(for: req)

        guard let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let chart = obj["chart"] as? [String: Any],
              let results = chart["result"] as? [[String: Any]],
              let first = results.first,
              let timestamps = first["timestamp"] as? [Int],
              let indicators = first["indicators"] as? [String: Any],
              let quote = (indicators["quote"] as? [[String: Any]])?.first,
              let closes = quote["close"] as? [Any]
        else { throw PriceServiceError.parseFailed }

        let now = Date()
        let cal = Calendar.current
        let weekAgo = cal.date(byAdding: .day, value: -7, to: now) ?? now
        let monthAgo = cal.date(byAdding: .day, value: -30, to: now) ?? now
        let yearStart = cal.date(from: cal.dateComponents([.year], from: now)) ?? now

        func closeAt(_ targetDate: Date) -> Double? {
            let targetTS = targetDate.timeIntervalSince1970
            var bestIdx = -1
            var bestDiff = Double.infinity
            for (i, ts) in timestamps.enumerated() {
                let d = abs(Double(ts) - targetTS)
                if d < bestDiff { bestDiff = d; bestIdx = i }
            }
            guard bestIdx >= 0, bestIdx < closes.count else { return nil }
            if let n = closes[bestIdx] as? Double { return n }
            if let n = closes[bestIdx] as? NSNumber { return n.doubleValue }
            return nil
        }

        return HistoricalMilestones(
            weekAgo: closeAt(weekAgo),
            monthAgo: closeAt(monthAgo),
            yearStart: closeAt(yearStart)
        )
    }

    /// 通过天天基金的历史净值接口拉取基金的过去净值。
    static func fetchFundHistorical(code: String) async throws -> HistoricalMilestones {
        guard let url = URL(string: "https://api.fund.eastmoney.com/f10/lsjz?fundCode=\(code)&pageIndex=1&pageSize=260") else {
            throw PriceServiceError.invalidResponse
        }
        var req = URLRequest(url: url)
        req.setValue("https://fundf10.eastmoney.com/", forHTTPHeaderField: "Referer")
        req.setValue("Mozilla/5.0", forHTTPHeaderField: "User-Agent")
        let (data, _) = try await session.data(for: req)
        guard let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let dataObj = obj["Data"] as? [String: Any],
              let list = dataObj["LSJZList"] as? [[String: Any]]
        else { throw PriceServiceError.parseFailed }

        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"
        df.timeZone = TimeZone(identifier: "Asia/Shanghai")

        struct Pt { let date: Date; let nav: Double }
        let points: [Pt] = list.compactMap { item in
            guard let dStr = item["FSRQ"] as? String,
                  let navStr = item["DWJZ"] as? String,
                  let nav = Double(navStr),
                  let d = df.date(from: dStr) else { return nil }
            return Pt(date: d, nav: nav)
        }
        guard !points.isEmpty else { throw PriceServiceError.parseFailed }

        let now = Date()
        let cal = Calendar.current
        let weekAgo = cal.date(byAdding: .day, value: -7, to: now) ?? now
        let monthAgo = cal.date(byAdding: .day, value: -30, to: now) ?? now
        let yearStart = cal.date(from: cal.dateComponents([.year], from: now)) ?? now

        func closest(_ target: Date) -> Double? {
            var best: Pt?
            var bestDiff = Double.infinity
            for p in points {
                let d = abs(p.date.timeIntervalSince(target))
                if d < bestDiff { bestDiff = d; best = p }
            }
            return best?.nav
        }

        return HistoricalMilestones(
            weekAgo: closest(weekAgo),
            monthAgo: closest(monthAgo),
            yearStart: closest(yearStart)
        )
    }

    // MARK: - 黄金现货 (上海黄金交易所 Au99.99, CNY/克)
    /// 主源:上海黄金交易所 Au99.99(通过东方财富 API,JSON 格式)
    /// 备源:Yahoo `GC=F`(NYMEX 期货 USD/oz)换算
    static func fetchGoldSpotCNYPerGram() async throws -> PriceQuoteResult {
        // 优先用 SGE 实时现货
        if let sge = try? await fetchSGEAu9999() {
            return sge
        }
        // 备用:Yahoo 黄金期货换算
        async let goldUSDPerOz = fetchUSStock(symbol: "GC=F")
        async let usdToCNY = fetchFXRate(from: .usd, to: .cny)
        let oz = try await goldUSDPerOz
        let rate = (try? await usdToCNY) ?? 7.18
        let perGramCNYCurrent = oz.price / 31.1035 * rate
        let perGramCNYPrev = oz.prevClose / 31.1035 * rate
        return PriceQuoteResult(
            price: perGramCNYCurrent,
            prevClose: perGramCNYPrev,
            assetName: "黄金现货(国际折算)"
        )
    }

    /// 拉取上海黄金交易所 Au99.99 现货价 — 通过东方财富 push2 接口。
    /// 接口示例: https://push2.eastmoney.com/api/qt/stock/get?secid=47.Au99_99
    /// 返回字段: f43=最新价(×10^f59), f60=昨收, f59=小数位
    static func fetchSGEAu9999() async throws -> PriceQuoteResult {
        let candidates = ["47.Au99_99", "8.Au99_99", "118.Au99_99"]
        for secid in candidates {
            if let result = try? await fetchEastmoneyQuote(secid: secid, fallbackName: "黄金 Au99.99") {
                return result
            }
        }
        throw PriceServiceError.parseFailed
    }

    private static func fetchEastmoneyQuote(secid: String, fallbackName: String) async throws -> PriceQuoteResult {
        let ts = Int(Date().timeIntervalSince1970 * 1000)
        let urlStr = "https://push2.eastmoney.com/api/qt/stock/get?secid=\(secid)&fields=f43,f57,f58,f59,f60&_=\(ts)"
        guard let url = URL(string: urlStr) else {
            throw PriceServiceError.invalidResponse
        }
        var req = URLRequest(url: url)
        req.setValue("Mozilla/5.0", forHTTPHeaderField: "User-Agent")
        req.setValue("https://quote.eastmoney.com/", forHTTPHeaderField: "Referer")
        let (data, _) = try await session.data(for: req)

        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let info = root["data"] as? [String: Any]
        else { throw PriceServiceError.parseFailed }

        func num(_ key: String) -> Double? {
            if let v = info[key] as? Double { return v }
            if let v = info[key] as? Int { return Double(v) }
            if let v = info[key] as? NSNumber { return v.doubleValue }
            return nil
        }

        let scale = (info["f59"] as? Int).map { pow(10.0, Double($0)) } ?? 100
        guard let priceRaw = num("f43"), priceRaw > 0 else {
            throw PriceServiceError.parseFailed
        }
        let prevRaw = num("f60") ?? priceRaw
        let price = priceRaw / scale
        let prev = prevRaw / scale
        let name = (info["f58"] as? String) ?? fallbackName
        return PriceQuoteResult(price: price, prevClose: prev, assetName: name)
    }

    // MARK: - 汇率 (Yahoo Finance)
    /// 例:USDCNY=X / HKDCNY=X
    static func fetchFXRate(from: CurrencyCode, to: CurrencyCode) async throws -> Double {
        if from == to { return 1.0 }
        let pair = "\(from.rawValue)\(to.rawValue)=X"
        guard let url = URL(string: "https://query1.finance.yahoo.com/v8/finance/chart/\(pair)") else {
            throw PriceServiceError.invalidResponse
        }
        var req = URLRequest(url: url)
        req.setValue("Mozilla/5.0", forHTTPHeaderField: "User-Agent")
        let (data, _) = try await session.data(for: req)
        guard let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let chart = obj["chart"] as? [String: Any],
              let results = chart["result"] as? [[String: Any]],
              let first = results.first,
              let meta = first["meta"] as? [String: Any]
        else { throw PriceServiceError.parseFailed }
        let rate = (meta["regularMarketPrice"] as? Double) ?? (meta["regularMarketPrice"] as? NSNumber)?.doubleValue
        guard let r = rate, r > 0 else { throw PriceServiceError.parseFailed }
        return r
    }
}
