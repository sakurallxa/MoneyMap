import SwiftUI

enum Theme {
    enum Spacing {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let xl: CGFloat = 20
        static let xxl: CGFloat = 28
    }

    enum Radius {
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let xl: CGFloat = 20
        static let xxl: CGFloat = 24
        static let pill: CGFloat = 999
    }

    enum Shadow {
        static let soft = ShadowStyle(color: .black.opacity(0.04), radius: 10, x: 0, y: 4)
        static let hero = ShadowStyle(color: .black.opacity(0.06), radius: 20, x: 0, y: 8)
    }

    struct ShadowStyle {
        let color: Color
        let radius: CGFloat
        let x: CGFloat
        let y: CGFloat
    }

    // MARK: - 铜色品牌色(单一来源 · P0-001)
    /// 全局铜色调色板 — 之前 `Palette.accent*` 与 `EmptyV2.bronze*` 是两套并行 token,
    /// 现已统一到这里。`Palette.accent` 与 `EmptyV2.bronze` 都改成此处的别名转发。
    enum Bronze {
        static let primary = Color(hex: "#C8956D")
        static let dark = Color(hex: "#A67849")
        static let up = Color(hex: "#D8A878")
        static let soft = Color(red: 200/255, green: 149/255, blue: 109/255).opacity(0.10)
        static let softBorder = Color(red: 200/255, green: 149/255, blue: 109/255).opacity(0.22)
        static let chipText = Color(red: 120/255, green: 80/255, blue: 40/255).opacity(0.78)

        /// CTA / + 按钮统一渐变(原 EmptyV2.bronzeCTA)
        static let cta = LinearGradient(
            colors: [primary, dark],
            startPoint: .topLeading, endPoint: .bottomTrailing
        )

        /// 描边渐变(自绘 icon 用,原 EmptyV2.bronzeStroke)
        static let stroke = LinearGradient(
            colors: [up, dark],
            startPoint: .topLeading, endPoint: .bottomTrailing
        )

        /// 米→金渐变 — Hero 数字 / 装饰菱形使用(P0-Composition)
        static let creamGoldGradient = LinearGradient(
            colors: [
                Color(hex: "#FBEFD2"),
                Color(hex: "#EAD09A"),
                Color(hex: "#C8956D")
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )

        /// 金箔 hairline 横线渐变(两端透明,中间金色)— Hero / Trend / Donut 卡顶端装饰共用
        /// 三张卡形成"金箔+黑金 hero + 米色卡"的视觉系列
        static let goldHairline = LinearGradient(
            colors: [
                Color(hex: "#C8956D").opacity(0.0),
                Color(hex: "#C8956D").opacity(0.55),
                Color(hex: "#FBEFD2").opacity(0.85),
                Color(hex: "#C8956D").opacity(0.55),
                Color(hex: "#C8956D").opacity(0.0)
            ],
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    // MARK: - 语义色(P0-002:与 PnL 红绿解耦)
    /// 用于 success / warning / danger 等"健康度/状态"语义,Rebalance 等场景使用。
    /// **绝对不要**直接复用 PnL 红绿色变量;让两套语义色独立演化。
    enum Semantic {
        static let success = Color(hex: "#1B7F47")   // 健康(暂时与 pnlDown 同值,但语义独立)
        static let warning = Color(hex: "#E89B2A")
        static let danger = Color(hex: "#C92A39")
        static let info = Color(hex: "#5B8FF9")
    }

    // MARK: - 类型 token(P1-007)
    /// 收敛"小标题/eyebrow/caption"碎片化
    enum TypeToken {
        static func eyebrow(_ size: CGFloat = 11) -> Font {
            Theme.serif(size, weight: .semibold)
        }
        static let eyebrowKerning: CGFloat = 1.6

        static func caption(_ size: CGFloat = 11) -> Font {
            Theme.serif(size)
        }

        static func label(_ size: CGFloat = 13) -> Font {
            Theme.serif(size, weight: .semibold)
        }
    }

    // MARK: - 隐藏掩码(P0-004)
    enum HiddenMask {
        /// 全局唯一货币隐藏掩码 — 所有需要"hideBalance ? mask : value"的地方一律走这个常量。
        static let amount = "¥••••"
        /// 不带 ¥ 的纯掩码(用于已经把 ¥ 拆出来单独渲染的场景)
        static let dotsOnly = "••••"
        /// 百分号掩码
        static let percent = "··%"
    }

    enum Palette {
        // —— 铜色:转发到 Theme.Bronze(单一来源)
        static let accent = Bronze.primary
        static let accentDark = Bronze.dark
        static let accentSoft = Color(hex: "#F5E9DC")
        static let heroAccent = Bronze.primary

        static let pnlUp = Color(hex: "#E63946")
        static let pnlDown = Color(hex: "#1B7F47")

        // Hero (黑金) 内部用的高饱和色,在深色背景上有更好的可读性
        static let heroAccentRed = Color(hex: "#FF8089")
        static let heroAccentGreen = Color(hex: "#8FD99E")

        // 暖色页面背景(P1-017:与 EmptyV2.pageBg 统一为同一值)
        static let pageBgWarm = Color(hex: "#F2EDE4")

        // 分类色 — P0-003:A 股不再与 PnL 红 #E63946 同值,改深酒红 #9B2C2C
        static let segmentCash = Color(hex: "#5B8FF9")
        static let segmentMoneyFund = Color(hex: "#7B68EE")
        static let segmentFund = Color(hex: "#F4B860")
        static let segmentStockA = Color(hex: "#9B2C2C")   // ← 原 #E63946
        static let segmentStockHK = Color(hex: "#2A9D8F")
        static let segmentStockUS = Color(hex: "#1ABC9C")
        static let segmentGold = Color(hex: "#D4AF37")
        static let segmentPending = Color(hex: "#A0A8B5")

        // 中性色 token(P2-026:hex 收敛)
        static let warmIcon = Color(hex: "#8A7B66")
        static let warmIconDisabled = Color(hex: "#C8B49A")
    }

    /// 黑金 Hero 卡的三段渐变
    static let heroBlackGoldGradient = LinearGradient(
        stops: [
            .init(color: Color(hex: "#16140F"), location: 0),
            .init(color: Color(hex: "#221A11"), location: 0.45),
            .init(color: Color(hex: "#2E2117"), location: 1)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    // MARK: - 字体

    /// 中文衬线字体族 — 优先思源宋体(项目内打包了 4 个 weight),fallback Songti SC,
    /// 极端情况退到系统 .serif design。思源宋体没有 Bold/Heavy,
    /// 我们用 Medium 作为"加粗"等价,避免 synthetic bold(合成伪粗)看着脏。
    enum SerifWeightMap {
        /// 探测家族里哪个 weight 实际可用 — 启动一次性计算
        static let hasSourceHan: Bool = UIFont(name: "SourceHanSerifSC-Regular", size: 12) != nil

        /// 给定 Font.Weight 返回对应的 PostScript 字体名(若思源宋体不可用,返回 nil 走 fallback)
        static func name(for weight: Font.Weight) -> String? {
            guard hasSourceHan else { return nil }
            switch weight {
            case .ultraLight, .thin:
                return "SourceHanSerifSC-ExtraLight"
            case .light:
                return "SourceHanSerifSC-Light"
            case .regular:
                return "SourceHanSerifSC-Regular"
            case .medium, .semibold, .bold, .heavy, .black:
                // 思源宋体最重就是 Medium;再重的 weight 一律用 Medium 真实字形
                return "SourceHanSerifSC-Medium"
            default:
                return "SourceHanSerifSC-Regular"
            }
        }

        /// UIFont 等价(给 NavigationBar / TabBar appearance 用)
        static func uiName(bold: Bool) -> String? {
            guard hasSourceHan else { return nil }
            return bold ? "SourceHanSerifSC-Medium" : "SourceHanSerifSC-Regular"
        }
    }

    /// 全局中文衬线 — Source Han Serif → Songti SC → 系统 .serif
    static func serif(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        if let name = SerifWeightMap.name(for: weight) {
            // 直接命名到具体字重的字体文件,不再让 SwiftUI 套 .weight() 合成伪粗
            return .custom(name, size: size)
        }
        // fallback:Songti SC(iOS 内置)+ SwiftUI weight 合成
        if UIFont(name: "Songti SC", size: 12) != nil {
            return .custom("Songti SC", size: size).weight(weight)
        }
        return .system(size: size, weight: weight, design: .serif)
    }

    /// UIKit 版本(NavigationBar / TabBar appearance 用)
    static func uiSerif(size: CGFloat, bold: Bool = false) -> UIFont {
        if let name = SerifWeightMap.uiName(bold: bold), let font = UIFont(name: name, size: size) {
            return font
        }
        // fallback:Songti SC + synthetic bold
        if let songti = UIFont(name: "Songti SC", size: size) {
            if bold, let bolded = songti.fontDescriptor.withSymbolicTraits(.traitBold) {
                return UIFont(descriptor: bolded, size: size)
            }
            return songti
        }
        return UIFont.systemFont(ofSize: size, weight: bold ? .bold : .regular)
    }

    /// 全局默认正文字体 — 用于 `.environment(\.font, ...)` 根注入
    static let serifBody: Font = serif(15)

    // MARK: - Empty States v2 tokens(向后兼容别名)
    /// **DEPRECATED**:历史命名空间,值统一指向 Theme.Bronze / Theme.Palette。
    /// 不要在新代码里使用 EmptyV2 前缀。
    enum EmptyV2 {
        static let pageBg = Palette.pageBgWarm        // 与 Palette.pageBgWarm 同源
        static let cardBg = Color(hex: "#FFFFFF")

        static let bronze = Bronze.primary
        static let bronzeDark = Bronze.dark
        static let bronzeUp = Bronze.up
        static let bronzeSoft = Bronze.soft
        static let bronzeSoftBorder = Bronze.softBorder
        static let chipText = Bronze.chipText

        // 暖色文字 — 故意不使用 .primary/.secondary(它们 cool tone 会破坏暖色基调)
        static let text1 = Color(hex: "#2A1E12")
        static let text2 = Color(red: 60/255, green: 40/255, blue: 20/255).opacity(0.55)
        static let text3 = Color(red: 60/255, green: 40/255, blue: 20/255).opacity(0.38)

        // Hero 黑栗 cocoa foil
        static let heroGold1 = Color(hex: "#FBEED1")
        static let heroGold2 = Color(hex: "#E8C99B")
        static let heroGold3 = Color(hex: "#C8956D")
        static let heroLabel = Color(hex: "#E8C99B")

        static let heroBg = LinearGradient(
            stops: [
                .init(color: Color(hex: "#3A2818"), location: 0),
                .init(color: Color(hex: "#2A1B0F"), location: 0.5),
                .init(color: Color(hex: "#1C1108"), location: 1)
            ],
            startPoint: UnitPoint(x: 0, y: 0),
            endPoint: UnitPoint(x: 1, y: 1)
        )

        // 别名转发:bronzeStroke / bronzeCTA / bronzeNum
        static let bronzeStroke = Bronze.stroke
        static let bronzeCTA = Bronze.cta

        static let bronzeNum = LinearGradient(
            stops: [
                .init(color: heroGold1, location: 0),
                .init(color: heroGold2, location: 0.45),
                .init(color: heroGold3, location: 1)
            ],
            startPoint: .top, endPoint: .bottom
        )
    }
}

/// 卡片的双层阴影。比单层 shadow 更有层次。
extension View {
    func cardElevation() -> some View {
        self
            .shadow(color: .black.opacity(0.04), radius: 10, x: 0, y: 4)
            .shadow(color: .black.opacity(0.025), radius: 22, x: 0, y: 10)
    }
}

extension View {
    func cardStyle(elevated: Bool = false) -> some View {
        let shadow = elevated ? Theme.Shadow.hero : Theme.Shadow.soft
        return self
            .padding(20)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.xl, style: .continuous))
            .shadow(color: shadow.color, radius: shadow.radius, x: shadow.x, y: shadow.y)
    }

    func heroCardStyle() -> some View {
        self
            .padding(.horizontal, 28)
            .padding(.vertical, 32)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.xxl, style: .continuous))
            .shadow(color: Theme.Shadow.hero.color, radius: Theme.Shadow.hero.radius, x: 0, y: Theme.Shadow.hero.y)
    }
}
