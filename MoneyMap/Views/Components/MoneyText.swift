import SwiftUI

// MARK: - MoneyText(P0-004)
/// 全局唯一的金额渲染组件。锁死 ¥ 字号比、字距、隐藏掩码。
/// 所有钱的地方一律走这个组件,不要再写 `Text("¥...")` 三元。
struct MoneyText: View {
    enum Scale {
        case hero       // 主数字(总资产)¥30 / 数字 54
        case display    // 大数字(账户卡内大额)¥18 / 数字 34
        case metric     // 卡内 metric 单元(累计盈亏/年化)¥13 / 数字 22
        case body       // 行内主额(账户行/交易行)¥15 / 数字 15
        case caption    // 副信息小金额 ¥11 / 数字 11
    }

    let value: Double
    var scale: Scale = .body
    var signed: Bool = false       // 是否带 +/− 号(盈亏类)
    var hidden: Bool = false
    var color: Color? = nil        // 强制色;不传则跟随 .foregroundStyle
    var style: AnyShapeStyle? = nil    // 渐变 / Material 等复合样式;优先级高于 color
    var showCurrencySymbol: Bool = true
    var minimumScaleFactor: CGFloat = 0.7   // 大数字场景可压到 0.55
    /// 强制 size 覆盖 — 不希望走预设 scale 的字号场景使用(比如 13pt 与 PercentText 对齐)
    var sizeOverride: CGFloat? = nil

    /// hero / display 场景的渐变样式 — Hero 卡内的米→金渐变需要用 style 传入。
    private var primaryStyle: AnyShapeStyle {
        if let style { return style }
        return AnyShapeStyle(color ?? .primary)
    }
    private var primaryStyleDim85: AnyShapeStyle {
        if let style { return style }
        return AnyShapeStyle((color ?? .primary).opacity(0.85))
    }
    private var primaryStyleDim90: AnyShapeStyle {
        if let style { return style }
        return AnyShapeStyle((color ?? .primary).opacity(0.9))
    }

    var body: some View {
        if hidden {
            Text(Theme.HiddenMask.amount)
                .font(.system(size: numberSize, weight: numberWeight))
                .monospacedDigit()
                .foregroundStyle(primaryStyle)
        } else {
            HStack(alignment: .firstTextBaseline, spacing: 1) {
                if signed {
                    Text(value >= 0 ? "+" : "−")
                        .font(.system(size: signSize, weight: .heavy))
                        .foregroundStyle(primaryStyleDim90)
                }
                if showCurrencySymbol {
                    Text("¥")
                        .font(.system(size: currencySize, weight: .bold))
                        .foregroundStyle(primaryStyleDim85)
                        .padding(.trailing, 1)
                }
                Text(formatAmount(abs(value)))
                    .font(.system(size: numberSize, weight: numberWeight))
                    .kerning(numberKerning)
                    .monospacedDigit()
                    .foregroundStyle(primaryStyle)
                    .lineLimit(1)
                    .minimumScaleFactor(minimumScaleFactor)
            }
        }
    }

    private var numberSize: CGFloat {
        if let sizeOverride { return sizeOverride }
        switch scale {
        case .hero: return 54
        case .display: return 34
        case .metric: return 22
        case .body: return 15
        case .caption: return 11
        }
    }

    private var currencySize: CGFloat {
        // 大字号场景缩小 ¥ 以保持视觉优雅;小字号(body/caption)与数字同字号,与 PercentText 对齐。
        switch scale {
        case .hero, .display, .metric: return numberSize * 0.55
        case .body, .caption: return numberSize
        }
    }

    private var signSize: CGFloat {
        // 大字号场景缩小 +/− 号;小字号与数字同字号,确保 +¥1.00 +1.00% 两个 + 视觉一致
        switch scale {
        case .hero, .display, .metric: return numberSize * 0.65
        case .body, .caption: return numberSize
        }
    }

    private var numberWeight: Font.Weight {
        switch scale {
        case .hero: return .heavy
        case .display: return .bold
        case .metric: return .heavy
        case .body: return .semibold
        case .caption: return .semibold
        }
    }

    private var numberKerning: CGFloat {
        switch scale {
        case .hero: return -2
        case .display: return -0.8
        case .metric: return -0.5
        case .body, .caption: return 0
        }
    }

    private func formatAmount(_ v: Double) -> String {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.maximumFractionDigits = scale == .hero ? 0 : 2
        f.minimumFractionDigits = (scale == .body || scale == .caption) ? 2 : 0
        return f.string(from: NSNumber(value: v)) ?? "0"
    }
}

// MARK: - PercentText(P2-026)
/// 统一百分比渲染。固定 2 位小数,带正负符号。
struct PercentText: View {
    let value: Double      // 0.0123 表示 1.23%,或者传入"已经×100"的值由 alreadyPercent 控制
    var size: CGFloat = 11
    var signed: Bool = true
    var hidden: Bool = false
    var color: Color? = nil
    var style: AnyShapeStyle? = nil   // .tertiary / 渐变等;优先级高于 color
    var alreadyPercent: Bool = true  // value 本身已经是 12.34 这种形式

    private var resolvedStyle: AnyShapeStyle {
        if let style { return style }
        return AnyShapeStyle(color ?? .secondary)
    }

    var body: some View {
        if hidden {
            Text(Theme.HiddenMask.percent)
                .font(.system(size: size, weight: .semibold))
                .monospacedDigit()
                .foregroundStyle(resolvedStyle)
        } else {
            let pct = alreadyPercent ? value : value * 100
            let s = signed
                ? String(format: "%+.2f%%", pct)
                : String(format: "%.2f%%", pct)
            Text(s)
                .font(.system(size: size, weight: .semibold))
                .monospacedDigit()
                .foregroundStyle(resolvedStyle)
        }
    }
}

// MARK: - PageHeader(P0-005)
/// 所有 tab(钱袋 / 账户 / 交易 / 定投 / 设置)顶部 header 的统一实现。
/// 用 `.lastTextBaseline` 对齐策略,内部处理大标题 / 副标 / 右侧按钮间的基线一致问题。
struct PageHeader<Trailing: View>: View {
    let title: String
    let subtitle: String?
    @ViewBuilder let trailing: () -> Trailing

    var body: some View {
        HStack(alignment: .lastTextBaseline, spacing: 10) {
            Text(title)
                .font(Theme.serif(30, weight: .heavy))
                .kerning(-0.8)
                .foregroundStyle(Theme.EmptyV2.text1)
                .layoutPriority(1)
            if let subtitle, !subtitle.isEmpty {
                Text(subtitle)
                    .font(Theme.serif(13, weight: .medium))
                    .foregroundStyle(Theme.EmptyV2.text2)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }
            Spacer(minLength: 6)
            trailing()
        }
        .padding(.horizontal, 4)
    }
}

// 无 trailing 的便利构造
extension PageHeader where Trailing == EmptyView {
    init(title: String, subtitle: String? = nil) {
        self.title = title
        self.subtitle = subtitle
        self.trailing = { EmptyView() }
    }
}

// MARK: - BronzeAddButton(P1-013)
/// 统一 + 按钮 — 替换所有 tab header 上的 +(列表 + 空态共用一处定义)。
/// 用渐变 + 内嵌高光 + 阴影的"精致版",不再用"纯色 + 单层阴影"的简化版。
struct BronzeAddButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(Theme.Bronze.cta)
                    .frame(width: 36, height: 36)
                Image(systemName: "plus")
                    .font(.system(size: 17, weight: .heavy))
                    .foregroundStyle(.white)
            }
            .overlay(
                Circle()
                    .stroke(
                        LinearGradient(
                            colors: [Color.white.opacity(0.32), Color.white.opacity(0.0)],
                            startPoint: .top, endPoint: .bottom
                        ),
                        lineWidth: 0.6
                    )
            )
            .shadow(color: Theme.Bronze.primary.opacity(0.33), radius: 7, x: 0, y: 6)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - HideBalanceToggle(P0-006)
/// 全局"隐藏余额"开关入口 — 5 个 tab header 都用这个。
/// 直接读写 @AppStorage("hideBalance"),不再各 tab 自己持有 binding。
struct HideBalanceToggle: View {
    @AppStorage("hideBalance") private var hideBalance = false

    var body: some View {
        Button {
            withAnimation { hideBalance.toggle() }
        } label: {
            Image(systemName: hideBalance ? "eye.slash" : "eye")
                .font(.system(size: 17))
                .foregroundStyle(Theme.Palette.warmIcon)
                .frame(width: 36, height: 36)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("切换余额显示")
        .accessibilityValue(hideBalance ? "已隐藏" : "已显示")
    }
}

// MARK: - 三类胶囊(P1-016)
/// 三种语义明确的胶囊形组件:
/// - `SegmentedChip`:filter / range tab,选中黑底白字,**有选中态**
/// - `StatusPill`:状态标签(在途 / 已完成 / 进行中 / 错误),带语义色,**只读**
/// - `CategoryChip`:只读分类标签(现金 / 基金 / 股票...),铜色软底,**只读**

/// SegmentedChip — 可点击,带选中态。
struct SegmentedChip: View {
    let title: String
    let count: Int?           // 可选数量徽标
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Text(title)
                    .font(Theme.serif(13, weight: .semibold))
                if let count {
                    Text("\(count)")
                        .font(.system(size: 11))
                        .monospacedDigit()
                        .opacity(0.5)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(selected ? Color.primary : Color.black.opacity(0.045))
            .foregroundStyle(selected ? Color(.systemBackground) : .primary)
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

/// StatusPill — 只读状态标签,带语义色。
struct StatusPill: View {
    enum Tone {
        case pending      // 黄 — 在途
        case settled      // 铜 — 已完成 / 已确认
        case active       // 铜深 — 进行中(DCA)
        case paused       // 灰 — 已暂停 / 已取消
        case danger       // 红 — 错误 / 警告
        var bg: Color {
            switch self {
            case .pending:  return Theme.Semantic.warning.opacity(0.16)
            case .settled:  return Theme.Bronze.soft
            case .active:   return Theme.Bronze.soft
            case .paused:   return Color.black.opacity(0.06)
            case .danger:   return Theme.Semantic.danger.opacity(0.14)
            }
        }
        var fg: Color {
            switch self {
            case .pending:  return Theme.Semantic.warning
            case .settled:  return Theme.Bronze.dark
            case .active:   return Theme.Bronze.dark
            case .paused:   return .secondary
            case .danger:   return Theme.Semantic.danger
            }
        }
    }

    let text: String
    let tone: Tone

    var body: some View {
        Text(text)
            .font(Theme.serif(11, weight: .semibold))
            .foregroundStyle(tone.fg)
            .padding(.horizontal, 9)
            .padding(.vertical, 3)
            .background(tone.bg)
            .clipShape(Capsule())
    }
}

/// CategoryChip — 只读分类标签(现金/基金/股票...),铜色软底 + 描边。
struct CategoryChip: View {
    let text: String

    var body: some View {
        Text(text)
            .font(Theme.serif(12, weight: .semibold))
            .kerning(0.5)
            .foregroundStyle(Theme.Bronze.chipText)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                Capsule().fill(Theme.Bronze.soft)
            )
            .overlay(
                Capsule().stroke(Theme.Bronze.softBorder, lineWidth: 0.5)
            )
    }
}

// MARK: - IconBadge(P1-011)
/// 三档尺寸图标容器:.lg(42·账户行) / .md(38·交易行) / .sm(30·设置/表单行)
/// opacity:lg 0.18(略浓,匹配账户类目色),md/sm 0.14(轻量)
struct IconBadge: View {
    enum Size {
        case lg, md, sm
        var box: CGFloat {
            switch self { case .lg: 42; case .md: 38; case .sm: 30 }
        }
        var icon: CGFloat {
            switch self { case .lg: 17; case .md: 15; case .sm: 13 }
        }
        var corner: CGFloat {
            switch self { case .lg: 12; case .md: 10; case .sm: 9 }
        }
        var bgOpacity: Double {
            switch self { case .lg: 0.18; case .md, .sm: 0.14 }
        }
    }
    let systemName: String
    let color: Color
    var size: Size = .md

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size.corner, style: .continuous)
                .fill(color.opacity(size.bgOpacity))
            Image(systemName: systemName)
                .font(.system(size: size.icon, weight: .semibold))
                .foregroundStyle(color)
        }
        .frame(width: size.box, height: size.box)
    }
}
