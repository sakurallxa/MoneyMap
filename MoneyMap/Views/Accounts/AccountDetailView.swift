import SwiftUI
import SwiftData

struct AccountDetailView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    let account: Account
    @Query private var allPositions: [Position]
    @Query private var rates: [ExchangeRate]
    @AppStorage("hideBalance") private var hideBalance = false

    @State private var showEditSheet = false
    @State private var showAddPositionSheet = false
    @State private var showDeleteAlert = false
    @State private var editingPosition: Position?
    @State private var deletingPosition: Position?

    private var positions: [Position] {
        allPositions.filter { $0.account?.id == account.id }
    }

    private var rateMap: [String: Double] {
        var m: [String: Double] = ["CNY": 1.0, "HKD": 0.92, "USD": 7.18]
        for r in rates { m[r.fromCurrency] = r.rate }
        return m
    }

    private var returns: AccountReturns {
        AccountReturnsService.compute(account: account, positions: positions, rates: rateMap)
    }

    private var totalValueCNY: Double {
        let cashFx = rateMap[account.currency.rawValue] ?? 1.0
        let cashCNY = account.cashBalance * cashFx
        let posCNY = positions.reduce(0.0) { sum, p in
            let fx = rateMap[p.effectiveCurrency.rawValue] ?? 1.0
            return sum + p.marketValue * fx
        }
        return cashCNY + posCNY
    }

    private var isInvestmentAccount: Bool { account.type.isInvestment }

    private var hasMultipleCurrencies: Bool {
        let set = Set(positions.map { $0.effectiveCurrency })
        if set.count > 1 { return true }
        if let only = set.first, only != account.currency, !positions.isEmpty { return true }
        return false
    }

    var body: some View {
        List {
            Section { summaryHero }
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: 0, leading: 14, bottom: 6, trailing: 14))
                .listRowSeparator(.hidden)

            if isInvestmentAccount && !positions.isEmpty {
                Section { returnsCard }
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 6, leading: 14, bottom: 6, trailing: 14))
                    .listRowSeparator(.hidden)
            }

            if !positions.isEmpty {
                Section {
                    ForEach(positions) { pos in
                        PositionRow(position: pos)
                            .listRowBackground(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .fill(Color(.secondarySystemGroupedBackground))
                            )
                            .listRowInsets(EdgeInsets(top: 14, leading: 16, bottom: 14, trailing: 16))
                            .listRowSeparator(.hidden)
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button(role: .destructive) {
                                    deletingPosition = pos
                                } label: { Label("删除", systemImage: "trash") }
                                Button {
                                    editingPosition = pos
                                } label: { Label("编辑", systemImage: "pencil") }
                                .tint(.blue)
                            }
                    }
                } header: {
                    Text("持仓 · \(positions.count) 项")
                        .font(.system(size: 11, weight: .bold))
                        .kerning(1.2)
                        .foregroundStyle(.tertiary)
                        .textCase(nil)
                        .padding(.horizontal, 6)
                }
            }
        }
        .listStyle(.plain)
        .listRowSpacing(8)
        .scrollContentBackground(.hidden)
        .contentMargins(.horizontal, 14, for: .scrollContent)
        .background(Theme.Palette.pageBgWarm.ignoresSafeArea())
        .navigationTitle(account.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button { showEditSheet = true } label: {
                        Label("编辑账户", systemImage: "pencil")
                    }
                    if isInvestmentAccount {
                        Button { showAddPositionSheet = true } label: {
                            Label("添加持仓", systemImage: "plus.circle")
                        }
                    }
                    Divider()
                    Button(role: .destructive) {
                        showDeleteAlert = true
                    } label: {
                        Label("删除账户", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "slider.horizontal.3")
                        .font(.body)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .sheet(isPresented: $showEditSheet) { EditAccountSheet(account: account) }
        .sheet(isPresented: $showAddPositionSheet) { AddPositionSheet(account: account) }
        .sheet(item: $editingPosition) { pos in EditPositionSheet(position: pos) }
        .alert("删除账户?", isPresented: $showDeleteAlert) {
            Button("取消", role: .cancel) {}
            Button("删除", role: .destructive) {
                let name = account.name
                context.delete(account)
                do {
                    try context.save()
                    ToastManager.shared.success("已删除「\(name)」")
                    dismiss()
                } catch {
                    ToastManager.shared.error("删除失败", subtitle: error.localizedDescription)
                }
            }
        } message: {
            Text("将永久删除「\(account.name)」及其所有持仓和相关交易引用。")
        }
        .alert("删除持仓?", isPresented: Binding(
            get: { deletingPosition != nil },
            set: { if !$0 { deletingPosition = nil } }
        )) {
            Button("取消", role: .cancel) { deletingPosition = nil }
            Button("删除", role: .destructive) {
                if let p = deletingPosition {
                    let name = p.assetName
                    context.delete(p)
                    do {
                        try context.save()
                        ToastManager.shared.success("已删除持仓「\(name)」")
                    } catch {
                        ToastManager.shared.error("删除失败", subtitle: error.localizedDescription)
                    }
                }
                deletingPosition = nil
            }
        } message: {
            if let p = deletingPosition {
                Text("将永久删除「\(p.assetName)」持仓记录。已经发生的交易记录会保留。")
            }
        }
    }

    /// 账户 Hero — 深邃黑金(Onyx)信用卡风格,Centurion / Apple Card titanium 味道。
    private var summaryHero: some View {
        ZStack(alignment: .topLeading) {
            // 1. 深炭灰对角渐变底
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.135, green: 0.135, blue: 0.150),
                            Color(red: 0.055, green: 0.055, blue: 0.070)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            // 2. 顶边高光(亚光金属反射)
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.22),
                            Color.white.opacity(0.05),
                            Color.clear
                        ],
                        startPoint: .top,
                        endPoint: .center
                    ),
                    lineWidth: 1
                )

            // 3. 右上角铜色柔光
            RadialGradient(
                colors: [
                    Color(red: 0.78, green: 0.58, blue: 0.42, opacity: 0.30),
                    Color.clear
                ],
                center: .topTrailing,
                startRadius: 0,
                endRadius: 220
            )
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))

            // 4. 左下角微弱蓝紫光,补反差
            RadialGradient(
                colors: [
                    Color(red: 0.30, green: 0.32, blue: 0.45, opacity: 0.18),
                    Color.clear
                ],
                center: .bottomLeading,
                startRadius: 0,
                endRadius: 180
            )
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))

            // 5. 右下暗金波纹(guilloche 风)
            HeroWaves(waveCount: 9, amplitude: 7, wavelength: 95, phaseStep: 0.32)
                .stroke(
                    LinearGradient(
                        colors: [
                            Color(red: 0.85, green: 0.66, blue: 0.40, opacity: 0.85),
                            Color(red: 0.78, green: 0.58, blue: 0.32, opacity: 0.30),
                            Color(red: 0.78, green: 0.58, blue: 0.32, opacity: 0.0)
                        ],
                        startPoint: .trailing,
                        endPoint: .leading
                    ),
                    lineWidth: 1.0
                )
                .frame(width: 240, height: 130)
                .offset(x: 150, y: 70)
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))

            // 6. 内容
            heroContent
                .padding(22)
        }
        .frame(height: 188)
        .shadow(color: .black.opacity(0.30), radius: 22, x: 0, y: 12)
    }

    /// Hero 内容层
    private var heroContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 顶行:chip + 铜色英文 label + 角落账户类型 icon
            HStack(alignment: .top, spacing: 12) {
                emvChip
                VStack(alignment: .leading, spacing: 3) {
                    Text(englishLabel)
                        .font(.system(size: 10, weight: .heavy))
                        .tracking(2.4)
                        .foregroundStyle(Color(red: 0.82, green: 0.62, blue: 0.46))
                    Text(account.type.displayName)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color.white.opacity(0.92))
                }
                Spacer()
                Image(systemName: account.type.iconName)
                    .font(.system(size: 17, weight: .light))
                    .foregroundStyle(Color.white.opacity(0.22))
            }

            Spacer(minLength: 14)

            // BALANCE label
            Text(balanceLabel)
                .font(.system(size: 9, weight: .bold))
                .tracking(1.8)
                .foregroundStyle(Color.white.opacity(0.42))

            // 大数字
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text("¥")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.72))
                Text(hideBalance ? "· · · · ·" : formatNumber(totalValueCNY))
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .kerning(-0.8)
                    .monospacedDigit()
                    .foregroundStyle(.white)
                    .accessibilityLabel(totalValueCNY.accessibilityAmountLabel(prefix: "账户总值", hidden: hideBalance))
            }
            .padding(.top, 2)

            Spacer(minLength: 0)

            // 底部账户名
            Text(account.name)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Color.white.opacity(0.58))
                .lineLimit(1)
        }
    }

    /// 金色 EMV chip 装饰(纯视觉)
    private var emvChip: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.92, green: 0.74, blue: 0.46),
                            Color(red: 0.62, green: 0.42, blue: 0.22)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            // chip 表面纹路 — 3 横线 + 1 竖线
            VStack(spacing: 2) {
                ForEach(0..<3) { _ in
                    Color.black.opacity(0.18).frame(height: 0.7)
                }
            }
            .padding(.horizontal, 3)
            Rectangle()
                .fill(Color.black.opacity(0.20))
                .frame(width: 0.7)
        }
        .frame(width: 28, height: 20)
        .overlay(
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .strokeBorder(Color.black.opacity(0.18), lineWidth: 0.5)
        )
    }

    /// 账户类型对应的铜色英文 label(Onyx 卡常见的"产品线"标签)
    private var englishLabel: String {
        switch account.type {
        case .cash:           return "CASH ACCOUNT"
        case .moneyFund:      return "MONEY MARKET"
        case .fundApp:        return "FUND ACCOUNT"
        case .brokerA:        return "BROKERAGE · A"
        case .brokerHK:       return "BROKERAGE · HK"
        case .brokerUS:       return "BROKERAGE · US"
        case .brokerHKUS:     return "BROKERAGE"
        case .goldDeposit:    return "GOLD DEPOSIT"
        case .goldPhysical:   return "GOLD VAULT"
        }
    }

    /// BALANCE 子标签 — 自动带"折算"提示(多币或非 CNY 单币)
    private var balanceLabel: String {
        if hasMultipleCurrencies {
            return "BALANCE · 含外币 · CNY 折算"
        }
        if account.currency != .cny {
            return "BALANCE · \(account.currency.rawValue) · CNY 折算"
        }
        return "BALANCE · CNY"
    }

    private var returnsCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("收益概览")
                .font(.system(size: 17, weight: .bold))

            VStack(spacing: 12) {
                MetricRow(label: "今日",
                          value: hideBalance ? kHiddenAmountMask : CurrencyFormatter.signedCNY(returns.dailyPnL),
                          valueColor: Color.pnlColor(returns.dailyPnL),
                          valueSubtitle: hideBalance ? "··%" : CurrencyFormatter.percent(returns.dailyPnLPercent))
                Divider().opacity(0.4)
                MetricRow(label: "近 7 天",
                          value: hideBalance ? kHiddenAmountMask : CurrencyFormatter.signedCNY(returns.weeklyPnL),
                          valueColor: Color.pnlColor(returns.weeklyPnL),
                          valueSubtitle: hideBalance ? "··%" : CurrencyFormatter.percent(returns.weeklyPnLPercent))
                Divider().opacity(0.4)
                MetricRow(label: "近 30 天",
                          value: hideBalance ? kHiddenAmountMask : CurrencyFormatter.signedCNY(returns.monthlyPnL),
                          valueColor: Color.pnlColor(returns.monthlyPnL),
                          valueSubtitle: hideBalance ? "··%" : CurrencyFormatter.percent(returns.monthlyPnLPercent))
                Divider().opacity(0.4)
                MetricRow(label: "今年至今",
                          value: hideBalance ? kHiddenAmountMask : CurrencyFormatter.signedCNY(returns.ytdPnL),
                          valueColor: Color.pnlColor(returns.ytdPnL),
                          valueSubtitle: hideBalance ? "··%" : CurrencyFormatter.percent(returns.ytdPnLPercent))
            }

            // 底部累计盈亏 highlight 行
            HStack {
                Text("累计盈亏")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text(hideBalance ? kHiddenAmountMask : CurrencyFormatter.signedCNY(returns.unrealizedPnL))
                        .font(.system(size: 17, weight: .heavy))
                        .monospacedDigit()
                        .foregroundStyle(Color.pnlColor(returns.unrealizedPnL))
                    Text(hideBalance ? "··%" : CurrencyFormatter.percent(returns.unrealizedPnLPercent))
                        .font(.system(size: 11, weight: .semibold))
                        .monospacedDigit()
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.black.opacity(0.035))
            )
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
        )
        .cardElevation()
    }

    private func formatNumber(_ v: Double) -> String {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.maximumFractionDigits = 0
        return f.string(from: NSNumber(value: v)) ?? "0"
    }
}

/// 持仓行 — 渐变 icon + 资产名 + 代码(黄金附克数) + 右侧市值
/// 极简版:不展示今日%/累计%/份额(基金股票),重点是金额分布。
struct PositionRow: View {
    let position: Position
    @AppStorage("hideBalance") private var hideBalance = false

    private var currency: CurrencyCode { position.effectiveCurrency }

    private var isGold: Bool { position.assetClass == .gold }

    private var iconColor: Color {
        switch position.assetClass {
        case .gold: return Color(hex: "#D4AF37")
        case .fund: return Color(hex: "#F4B860")
        case .stockA: return Color(hex: "#E63946")
        case .stockHK: return Color(hex: "#2A9D8F")
        case .stockUS: return Color(hex: "#1ABC9C")
        case .cash, .moneyFund: return Color(hex: "#5B8FF9")
        }
    }

    /// 副行:基金/股票 = 代码;黄金 = 代码 · X.XX g
    private var subtitle: String {
        if isGold {
            return "\(position.assetCode) · \(String(format: "%.2f", position.shares)) g"
        }
        return position.assetCode
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // 上半段:身份信息(icon + 资产名 + 代码 / 黄金克数)
            HStack(alignment: .center, spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [iconColor.opacity(0.28), iconColor.opacity(0.10)],
                                startPoint: .topLeading, endPoint: .bottomTrailing
                            )
                        )
                    Text(String(position.assetName.prefix(1)))
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(iconColor)
                }
                .frame(width: 40, height: 40)

                VStack(alignment: .leading, spacing: 3) {
                    Text(position.assetName)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(subtitle)
                        .font(.system(size: 11))
                        .foregroundStyle(.tertiary)
                        .monospacedDigit()
                }
                Spacer(minLength: 0)
            }

            // 下半段:2 行 metric,显式标签 + 右对齐数字
            VStack(spacing: 10) {
                metricRow(
                    label: "持仓金额",
                    value: hideBalance ? kHiddenAmountMask : "\(currency.symbol)\(formatValue(position.marketValue))",
                    valueColor: .primary,
                    valueWeight: .bold
                )
                cumulativeMetricRow
                if daysSinceUpdate >= 7 {
                    staleWarningRow
                }
            }
        }
    }

    /// 上次更新距今天数 — 用于判断价格是否陈旧。
    private var daysSinceUpdate: Int {
        let cal = Calendar.current
        return cal.dateComponents([.day], from: cal.startOfDay(for: position.updatedAt), to: cal.startOfDay(for: Date())).day ?? 0
    }

    /// 持仓行的"价格陈旧"警告 — 仅 ≥ 7 天才显示。
    private var staleWarningRow: some View {
        HStack(spacing: 6) {
            Image(systemName: "clock.badge.exclamationmark")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.orange)
            Text("上次更新 \(daysSinceUpdate) 天前 · 建议手动更新价格")
                .font(.system(size: 11))
                .foregroundStyle(.orange)
            Spacer()
        }
        .padding(.top, 2)
    }

    /// 累计盈亏专用行 — ¥ 与 % 拆成 2 个 Text,中间 6pt 间距,避免挤在一起。
    /// 方向已由 +/- 符号表达,不再附加上升/下降箭头(避免冗余)。
    private var cumulativeMetricRow: some View {
        let pnl = position.unrealizedPnL
        let pct = position.unrealizedPnLPercent
        let color = Color.pnlColor(pnl)
        let isUp = pnl >= 0
        return HStack {
            Text("累计盈亏")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
            Spacer()
            HStack(spacing: 0) {
                Text(hideBalance ? "¥····" : "\(isUp ? "+" : "-")\(currency.symbol)\(formatValue(abs(pnl)))")
                    .font(.system(size: 14, weight: .semibold))
                    .monospacedDigit()
                    .foregroundStyle(color)
                Text(hideBalance ? "··%" : String(format: "%+.2f%%", pct))
                    .font(.system(size: 13, weight: .medium))
                    .monospacedDigit()
                    .foregroundStyle(color.opacity(0.85))
                    .padding(.leading, 6)
            }
        }
    }

    /// 单行 metric:左标签灰 / 右数字带颜色;可选左边箭头。
    @ViewBuilder
    private func metricRow(
        label: String,
        value: String,
        valueColor: Color,
        valueWeight: Font.Weight,
        leadingIcon: String? = nil
    ) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
            Spacer()
            HStack(spacing: 4) {
                if let icon = leadingIcon {
                    Image(systemName: icon)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(valueColor)
                }
                Text(value)
                    .font(.system(size: 14, weight: valueWeight))
                    .monospacedDigit()
                    .foregroundStyle(valueColor)
            }
        }
    }

    private func formatValue(_ v: Double) -> String {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.minimumFractionDigits = 2
        f.maximumFractionDigits = 2
        return f.string(from: NSNumber(value: v)) ?? "0.00"
    }
}

/// Hero 卡片右下角的 guilloche 风波纹 — 多条平行 sin 波,每条相位错开。
struct HeroWaves: Shape {
    var waveCount: Int = 7
    var amplitude: CGFloat = 6
    var wavelength: CGFloat = 90
    /// 每条波相对上一条的相位偏移(产生交错感)
    var phaseStep: CGFloat = 0.35

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let spacing = rect.height / CGFloat(waveCount + 1)
        let steps = 60
        for i in 0..<waveCount {
            let baseY = spacing * CGFloat(i + 1)
            let phase = phaseStep * CGFloat(i)
            path.move(to: CGPoint(x: 0, y: baseY))
            for s in 1...steps {
                let x = rect.width * CGFloat(s) / CGFloat(steps)
                let theta = (x / wavelength) * .pi * 2 + phase * .pi
                let y = baseY + sin(theta) * amplitude
                path.addLine(to: CGPoint(x: x, y: y))
            }
        }
        return path
    }
}
