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

    enum Palette {
        static let accent = Color(hex: "#C8956D")
        static let accentDark = Color(hex: "#A67849")
        static let accentSoft = Color(hex: "#F5E9DC")
        static let heroAccent = Color(hex: "#C8956D")

        static let pnlUp = Color(hex: "#E63946")
        static let pnlDown = Color(hex: "#1B7F47")

        // Hero (黑金) 内部用的高饱和色,在深色背景上有更好的可读性
        static let heroAccentRed = Color(hex: "#FF8089")
        static let heroAccentGreen = Color(hex: "#8FD99E")

        // 暖色页面背景
        static let pageBgWarm = Color(hex: "#F6F2EC")

        static let segmentCash = Color(hex: "#5B8FF9")
        static let segmentMoneyFund = Color(hex: "#7B68EE")
        static let segmentFund = Color(hex: "#F4B860")
        static let segmentStockA = Color(hex: "#E63946")
        static let segmentStockHK = Color(hex: "#2A9D8F")
        static let segmentStockUS = Color(hex: "#1ABC9C")
        static let segmentGold = Color(hex: "#D4AF37")
        static let segmentPending = Color(hex: "#A0A8B5")
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
