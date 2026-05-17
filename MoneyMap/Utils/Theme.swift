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
        static let heroAccent = Color(hex: "#C8956D")

        static let pnlUp = Color(hex: "#E63946")
        static let pnlDown = Color(hex: "#1B7F47")

        static let segmentCash = Color(hex: "#6B8AFD")
        static let segmentMoneyFund = Color(hex: "#9B7EE0")
        static let segmentFund = Color(hex: "#E6B469")
        static let segmentStockA = Color(hex: "#E63946")
        static let segmentStockHK = Color(hex: "#2A9D8F")
        static let segmentStockUS = Color(hex: "#1ABC9C")
        static let segmentPending = Color(hex: "#A0A8B5")
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
