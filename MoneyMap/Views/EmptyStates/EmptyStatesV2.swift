import SwiftUI

// MARK: - 公共组件:铜色 CTA / + 按钮 / Chip / hairline

/// 主 CTA — 全宽胶囊,铜色 135° 渐变 + 内嵌高光 + 双层柔阴
struct BronzeCTA: View {
    let title: String
    var fullWidth: Bool = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Text(title)
                    .font(Theme.serif(15, weight: .bold))
                    .kerning(2)
                    .foregroundStyle(.white)
                Image(systemName: "arrow.right")
                    .font(.system(size: 14, weight: .heavy))
                    .foregroundStyle(.white)
            }
            .frame(maxWidth: fullWidth ? .infinity : nil)
            .padding(.vertical, 15)
            .padding(.horizontal, 24)
            .background(
                Capsule().fill(Theme.EmptyV2.bronzeCTA)
            )
            .overlay(
                Capsule()
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.28),
                                Color.white.opacity(0.0),
                                Color.black.opacity(0.12)
                            ],
                            startPoint: .top, endPoint: .bottom
                        ),
                        lineWidth: 0.6
                    )
            )
            .shadow(color: Theme.EmptyV2.bronze.opacity(0.33), radius: 13, x: 0, y: 12)
            .shadow(color: Theme.EmptyV2.bronze.opacity(0.19), radius: 4, x: 0, y: 3)
        }
        .buttonStyle(.plain)
    }
}

/// 暖色 chip 胶囊 — P1-016:转发到统一的 CategoryChip 组件
typealias ChipPill = CategoryChip

/// 中央渐变 hairline(两端透明,中段铜)
private struct CenterHairline: View {
    var width: CGFloat = 240
    var body: some View {
        Rectangle()
            .fill(
                LinearGradient(
                    colors: [
                        Color.clear,
                        Theme.EmptyV2.bronzeSoftBorder,
                        Color.clear
                    ],
                    startPoint: .leading, endPoint: .trailing
                )
            )
            .frame(width: width, height: 0.5)
    }
}

// MARK: - 自绘空态 SVG icon(72 viewBox / 1.6px / bronze gradient stroke)

/// 账户 · clipboard(P2-020:支持任意尺寸,76px 用于空态,24px 用于 list section header)
struct IconAccountClipboard: View {
    var size: CGFloat = 76
    var body: some View {
        Canvas { ctx, canvasSize in
            // 描边宽度按 size 线性缩放(76→1.6 / 24→0.5),小尺寸不会过粗
            let strokeWidth: CGFloat = max(0.5, size / 76 * 1.6)
            let scale = canvasSize.width / 72.0
            func sx(_ x: CGFloat) -> CGFloat { x * scale }
            func sy(_ y: CGFloat) -> CGFloat { y * scale }

            let stroke = GraphicsContext.Shading.linearGradient(
                Gradient(colors: [Theme.Bronze.up, Theme.Bronze.dark]),
                startPoint: CGPoint(x: 0, y: 0),
                endPoint: CGPoint(x: canvasSize.width, y: canvasSize.height)
            )
            let bodyFill = GraphicsContext.Shading.color(Theme.Bronze.primary.opacity(0.06))
            let clipFill = GraphicsContext.Shading.color(Theme.Bronze.primary.opacity(0.10))

            let bodyRect = CGRect(x: sx(18), y: sy(14), width: sx(36), height: sy(46))
            let bodyPath = Path(roundedRect: bodyRect, cornerRadius: sx(6))
            ctx.fill(bodyPath, with: bodyFill)
            ctx.stroke(bodyPath, with: stroke, lineWidth: strokeWidth)

            let clipRect = CGRect(x: sx(28), y: sy(8), width: sx(16), height: sy(10))
            let clipPath = Path(roundedRect: clipRect, cornerRadius: sx(3))
            ctx.fill(clipPath, with: clipFill)
            ctx.stroke(clipPath, with: stroke, lineWidth: strokeWidth)

            func line(_ x1: CGFloat, _ y1: CGFloat, _ x2: CGFloat, _ y2: CGFloat, alpha: CGFloat) {
                var p = Path()
                p.move(to: CGPoint(x: sx(x1), y: sy(y1)))
                p.addLine(to: CGPoint(x: sx(x2), y: sy(y2)))
                var s = ctx
                s.opacity = alpha
                s.stroke(p, with: stroke, style: StrokeStyle(lineWidth: strokeWidth, lineCap: .round))
            }
            line(26, 30, 46, 30, alpha: 1.0)
            line(26, 40, 40, 40, alpha: 0.55)
            line(26, 48, 44, 48, alpha: 0.55)
        }
        .frame(width: size, height: size)
    }
}

/// 交易 · list with bullets(P2-020:可缩放)
struct IconTxList: View {
    var size: CGFloat = 76
    var body: some View {
        Canvas { ctx, canvasSize in
            let strokeWidth: CGFloat = max(0.5, size / 76 * 1.6)
            let scale = canvasSize.width / 72.0
            func sx(_ x: CGFloat) -> CGFloat { x * scale }
            func sy(_ y: CGFloat) -> CGFloat { y * scale }

            let stroke = GraphicsContext.Shading.linearGradient(
                Gradient(colors: [Theme.Bronze.up, Theme.Bronze.dark]),
                startPoint: CGPoint(x: 0, y: 0),
                endPoint: CGPoint(x: canvasSize.width, y: canvasSize.height)
            )
            let fill = GraphicsContext.Shading.color(Theme.Bronze.primary.opacity(0.06))

            let bodyRect = CGRect(x: sx(10), y: sy(14), width: sx(52), height: sy(44))
            let bodyPath = Path(roundedRect: bodyRect, cornerRadius: sx(6))
            ctx.fill(bodyPath, with: fill)
            ctx.stroke(bodyPath, with: stroke, lineWidth: strokeWidth)

            for (i, y) in [24.0, 36.0, 48.0].enumerated() {
                let alpha: CGFloat = i == 0 ? 1.0 : 0.55
                let dotRect = CGRect(x: sx(17.6), y: sy(CGFloat(y) - 2.4), width: sx(4.8), height: sy(4.8))
                var s = ctx
                s.opacity = alpha
                s.fill(Path(ellipseIn: dotRect), with: stroke)

                var p = Path()
                p.move(to: CGPoint(x: sx(28), y: sy(CGFloat(y))))
                p.addLine(to: CGPoint(x: sx(54), y: sy(CGFloat(y))))
                s.stroke(p, with: stroke, style: StrokeStyle(lineWidth: strokeWidth, lineCap: .round))
            }
        }
        .frame(width: size, height: size)
    }
}

/// 定投 · calendar + clock badge(P2-020:可缩放)
struct IconDCACal: View {
    var size: CGFloat = 76
    var body: some View {
        Canvas { ctx, canvasSize in
            let strokeWidth: CGFloat = max(0.5, size / 76 * 1.6)
            let scale = canvasSize.width / 72.0
            func sx(_ x: CGFloat) -> CGFloat { x * scale }
            func sy(_ y: CGFloat) -> CGFloat { y * scale }

            let stroke = GraphicsContext.Shading.linearGradient(
                Gradient(colors: [Theme.Bronze.up, Theme.Bronze.dark]),
                startPoint: CGPoint(x: 0, y: 0),
                endPoint: CGPoint(x: canvasSize.width, y: canvasSize.height)
            )
            let fill = GraphicsContext.Shading.color(Theme.Bronze.primary.opacity(0.06))
            let bgColor = GraphicsContext.Shading.color(Theme.EmptyV2.pageBg)

            // 日历主体 (10,16,44,40) r=5
            let bodyRect = CGRect(x: sx(10), y: sy(16), width: sx(44), height: sy(40))
            let bodyPath = Path(roundedRect: bodyRect, cornerRadius: sx(5))
            ctx.fill(bodyPath, with: fill)
            ctx.stroke(bodyPath, with: stroke, lineWidth: strokeWidth)

            // 挂钉 (20,10→20,20)
            func line(_ x1: CGFloat, _ y1: CGFloat, _ x2: CGFloat, _ y2: CGFloat) {
                var p = Path()
                p.move(to: CGPoint(x: sx(x1), y: sy(y1)))
                p.addLine(to: CGPoint(x: sx(x2), y: sy(y2)))
                ctx.stroke(p, with: stroke, style: StrokeStyle(lineWidth: strokeWidth, lineCap: .round))
            }
            line(20, 10, 20, 20)
            line(44, 10, 44, 20)

            // 顶部 hairline (10,26 → 54,26)
            var hairline = Path()
            hairline.move(to: CGPoint(x: sx(10), y: sy(26)))
            hairline.addLine(to: CGPoint(x: sx(54), y: sy(26)))
            ctx.stroke(hairline, with: stroke, lineWidth: strokeWidth)

            // 日期点阵 opacity 0.55
            let dots: [(CGFloat, CGFloat)] = [
                (18,34),(26,34),(34,34),(42,34),
                (18,42),(26,42),(34,42),
                (18,50)
            ]
            for d in dots {
                let dotRect = CGRect(x: sx(d.0 - 1.4), y: sy(d.1 - 1.4), width: sx(2.8), height: sy(2.8))
                var s = ctx
                s.opacity = 0.55
                s.fill(Path(ellipseIn: dotRect), with: stroke)
            }

            // 右下时钟徽章 circle(54,50,r=11)
            let clockRect = CGRect(x: sx(43), y: sy(39), width: sx(22), height: sy(22))
            let clockPath = Path(ellipseIn: clockRect)
            ctx.fill(clockPath, with: bgColor)
            ctx.stroke(clockPath, with: stroke, lineWidth: strokeWidth)

            // 时针 (54,44) → (54,50) → (58,52)
            var hand = Path()
            hand.move(to: CGPoint(x: sx(54), y: sy(44)))
            hand.addLine(to: CGPoint(x: sx(54), y: sy(50)))
            hand.addLine(to: CGPoint(x: sx(58), y: sy(52)))
            ctx.stroke(hand, with: stroke, style: StrokeStyle(lineWidth: strokeWidth, lineCap: .round, lineJoin: .round))
        }
        .frame(width: size, height: size)
    }
}

// MARK: - NavPro 顶部栏(空态版,system 字体)

/// v2 设计 §4.1 共通顶部 — 大标题(system bold 30 / tracking -0.8)+ inline 副标 + trailing
struct NavProEmpty<Trailing: View>: View {
    let title: String
    let subtitle: String?
    @ViewBuilder let trailing: () -> Trailing

    var body: some View {
        HStack(alignment: .bottom, spacing: 0) {
            HStack(alignment: .lastTextBaseline, spacing: 10) {
                Text(title)
                    .font(Theme.serif(30, weight: .heavy))
                    .kerning(-0.8)
                    .foregroundStyle(Theme.EmptyV2.text1)
                if let subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(Theme.serif(13, weight: .medium))
                        .foregroundStyle(Theme.EmptyV2.text2)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                }
                Spacer(minLength: 6)
            }
            HStack(spacing: 8) {
                trailing()
            }
        }
        .frame(minHeight: 40, alignment: .bottom)
        .padding(.leading, 20)
        .padding(.trailing, 16)
        .padding(.top, 8)
        .padding(.bottom, 8)
    }
}

// MARK: - EmptyTabFrame:账户 / 交易 / 定投 三屏共用

struct EmptyTabFrame<Icon: View, Bottom: View>: View {
    let navTitle: String
    let navSubtitle: String?
    @ViewBuilder let icon: () -> Icon
    let h1: String
    let bodyText: String
    let ctaText: String
    let ctaAction: () -> Void
    let addAction: () -> Void
    @ViewBuilder let bottomContent: () -> Bottom

    var body: some View {
        ZStack {
            Theme.EmptyV2.pageBg.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 0) {
                    NavProEmpty(title: navTitle, subtitle: navSubtitle) {
                        BronzeAddButton(action: addAction)
                    }

                    VStack(spacing: 0) {
                        Spacer().frame(height: 76)

                        icon()
                            .accessibilityHidden(true)

                        Spacer().frame(height: 22)

                        Text(h1)
                            .font(Theme.serif(22, weight: .bold))
                            .kerning(-0.2)
                            .foregroundStyle(Theme.EmptyV2.text1)
                            .multilineTextAlignment(.center)

                        Spacer().frame(height: 12)

                        Text(bodyText)
                            .font(Theme.serif(14))
                            .foregroundStyle(Theme.EmptyV2.text2)
                            .lineSpacing(5)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: 280)

                        Spacer().frame(height: 32)

                        BronzeCTA(title: ctaText, action: ctaAction)
                            .frame(maxWidth: 280)
                            .accessibilityLabel("\(ctaText),打开添加表单")

                        Spacer().frame(height: 28)

                        CenterHairline(width: 240)

                        Spacer().frame(height: 18)

                        bottomContent()

                        Spacer().frame(height: 60)
                    }
                    .padding(.horizontal, 32)
                }
            }
        }
    }
}

// MARK: - ❷ 账户空态

struct AccountsEmptyV2: View {
    let addAction: () -> Void

    var body: some View {
        EmptyTabFrame(
            navTitle: "账户",
            navSubtitle: "0 个账户",
            icon: { IconAccountClipboard() },
            h1: "还没有账户",
            bodyText: "先添加一个账户,把现金、基金、股票、黄金都装进钱袋",
            ctaText: "添加账户",
            ctaAction: addAction,
            addAction: addAction
        ) {
            VStack(spacing: 12) {
                Text("常 见 账 户 类 型")
                    .font(Theme.serif(11, weight: .semibold))
                    .kerning(3)
                    .foregroundStyle(Theme.EmptyV2.text3)
                FlowChips(items: ["现金", "基金 App", "券商", "黄金存折"])
            }
        }
    }
}

// MARK: - ❸ 交易空态

struct TransactionsEmptyV2: View {
    let monthCountText: String
    let addAction: () -> Void

    var body: some View {
        EmptyTabFrame(
            navTitle: "交易",
            navSubtitle: monthCountText,
            icon: { IconTxList() },
            h1: "还没有交易记录",
            bodyText: "买卖、转账、定投扣款 — 都会自动汇总成时间线",
            ctaText: "记一笔",
            ctaAction: addAction,
            addAction: addAction
        ) {
            VStack(spacing: 12) {
                Text("自 动 归 类")
                    .font(Theme.serif(11, weight: .semibold))
                    .kerning(3)
                    .foregroundStyle(Theme.EmptyV2.text3)
                FlowChips(items: ["加仓", "卖出", "分红", "转账", "出入金"])
            }
        }
    }
}

// MARK: - ❹ 定投空态

struct DCAEmptyV2: View {
    let addAction: () -> Void

    var body: some View {
        EmptyTabFrame(
            navTitle: "定投",
            navSubtitle: "尚未创建定投",
            icon: { IconDCACal() },
            h1: "还没有定投计划",
            bodyText: "按时把钱装进去 — 让时间替你做决定",
            ctaText: "设个定投",
            ctaAction: addAction,
            addAction: addAction
        ) {
            Text("到期日自动创建定投记录 · T+N 确认份额更新总资产和收益")
                .font(Theme.serif(12, weight: .medium))
                .kerning(0.6)
                .lineSpacing(4)
                .foregroundStyle(Theme.EmptyV2.text2)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 280)
        }
    }
}

/// 简易居中 wrap chips
struct FlowChips: View {
    let items: [String]
    var body: some View {
        HStack(spacing: 8) {
            ForEach(items, id: \.self) { ChipPill(text: $0) }
        }
    }
}

// MARK: - ❶ 钱袋空态(组合页:Hero + Steps + Trend + Donut)

struct DashboardEmptyV2: View {
    let nickname: String
    let onAddAccount: () -> Void
    @Binding var hideBalance: Bool
    let onRefresh: () -> Void
    let isRefreshing: Bool

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        let base: String
        switch hour {
        case 5..<12: base = "早上好"
        case 12..<14: base = "中午好"
        case 14..<18: base = "下午好"
        case 18..<23: base = "晚上好"
        default: base = "夜深了"
        }
        let trimmed = nickname.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty || trimmed == "钱袋用户" {
            return base
        }
        return "\(base),\(trimmed)"
    }

    var body: some View {
        ZStack {
            Theme.EmptyV2.pageBg.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 14) {
                    NavProEmpty(title: "钱袋", subtitle: greeting) {
                        IconRound(systemName: hideBalance ? "eye.slash" : "eye") {
                            withAnimation { hideBalance.toggle() }
                        }
                        IconRound(systemName: "arrow.clockwise", rotating: isRefreshing) {
                            onRefresh()
                        }
                    }
                    .padding(.bottom, -8)

                    HomeHeroEmpty()
                        .padding(.horizontal, 14)
                    StepCard(onTap: onAddAccount)
                        .padding(.horizontal, 14)
                    TrendPlaceholder()
                        .padding(.horizontal, 14)
                    DonutPlaceholder()
                        .padding(.horizontal, 14)
                        .padding(.bottom, 60)
                }
            }
        }
    }
}

/// 灰底 36×36 圆形按钮(钱袋 tab 顶部 eye / refresh)
private struct IconRound: View {
    let systemName: String
    var rotating: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(Color.black.opacity(0.04))
                    .frame(width: 36, height: 36)
                Image(systemName: systemName)
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(Theme.EmptyV2.text2)
                    .rotationEffect(.degrees(rotating ? 360 : 0))
                    .animation(
                        rotating
                            ? .linear(duration: 1).repeatForever(autoreverses: false)
                            : .default,
                        value: rotating
                    )
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Hero ¥0 黑栗 cocoa foil 卡

struct HomeHeroEmpty: View {
    var body: some View {
        ZStack(alignment: .topLeading) {
            // 主黑栗渐变底
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Theme.EmptyV2.heroBg)

            // 对角扫光 (115deg)
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(
                    LinearGradient(
                        stops: [
                            .init(color: .clear, location: 0),
                            .init(color: Color(red: 232/255, green: 201/255, blue: 155/255).opacity(0.10), location: 0.35),
                            .init(color: Color(red: 212/255, green: 175/255, blue: 55/255).opacity(0.14), location: 0.50),
                            .init(color: Color(red: 232/255, green: 201/255, blue: 155/255).opacity(0.08), location: 0.65),
                            .init(color: .clear, location: 1)
                        ],
                        startPoint: UnitPoint(x: 0, y: 0.2),
                        endPoint: UnitPoint(x: 1, y: 0.8)
                    )
                )
                .allowsHitTesting(false)

            // 等高线 SVG paths(7 条)
            ContourLines()
                .stroke(Theme.EmptyV2.heroLabel.opacity(0.16), lineWidth: 0.5)
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                .allowsHitTesting(false)

            // 右上角径向暖光
            RadialGradient(
                colors: [
                    Theme.EmptyV2.heroLabel.opacity(0.28),
                    .clear
                ],
                center: .topTrailing,
                startRadius: 4, endRadius: 160
            )
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .allowsHitTesting(false)

            // inset 顶部高光描边
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .inset(by: 0.3)
                .stroke(
                    LinearGradient(
                        colors: [
                            Color(red: 232/255, green: 201/255, blue: 155/255).opacity(0.18),
                            Color.black.opacity(0.55)
                        ],
                        startPoint: .top, endPoint: .bottom
                    ),
                    lineWidth: 0.6
                )

            VStack(alignment: .leading, spacing: 0) {
                // 顶行:● 总资产 · TOTAL  /  尚未开始记录
                HStack {
                    HStack(spacing: 7) {
                        Circle()
                            .fill(Theme.EmptyV2.heroLabel)
                            .frame(width: 5, height: 5)
                            .shadow(color: Theme.EmptyV2.heroLabel.opacity(0.7), radius: 3)
                        Text("总资产 · TOTAL")
                            .font(Theme.serif(10.5, weight: .bold))
                            .kerning(2)
                            .foregroundStyle(Theme.EmptyV2.heroLabel)
                    }
                    Spacer()
                    Text("尚未开始记录")
                        .font(Theme.serif(10.5, weight: .medium))
                        .kerning(0.5)
                        .foregroundStyle(Theme.EmptyV2.heroLabel.opacity(0.55))
                }

                // hairline 分隔
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Theme.EmptyV2.heroLabel.opacity(0.42),
                                Theme.EmptyV2.heroLabel.opacity(0.05)
                            ],
                            startPoint: .leading, endPoint: .trailing
                        )
                    )
                    .frame(height: 0.5)
                    .padding(.top, 12)

                // ¥0
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text("¥")
                        .font(.system(size: 26, weight: .bold))
                        .kerning(-0.4)
                        .foregroundStyle(Theme.EmptyV2.bronzeNum)
                        .opacity(0.85)
                    Text("0")
                        .font(.system(size: 52, weight: .heavy))
                        .kerning(-2)
                        .foregroundStyle(Theme.EmptyV2.bronzeNum)
                        .shadow(color: Theme.EmptyV2.heroLabel.opacity(0.18), radius: 8, y: 2)
                }
                .padding(.top, 14)
                .accessibilityLabel("总资产 零元,暂无数据")

                // chevron divider
                HStack(spacing: 6) {
                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: [.clear, Theme.EmptyV2.heroLabel.opacity(0.32)],
                                startPoint: .leading, endPoint: .trailing
                            )
                        )
                        .frame(height: 0.5)
                    Rectangle()
                        .fill(Theme.EmptyV2.bronze)
                        .frame(width: 6, height: 6)
                        .rotationEffect(.degrees(45))
                        .opacity(0.7)
                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: [Theme.EmptyV2.heroLabel.opacity(0.32), .clear],
                                startPoint: .leading, endPoint: .trailing
                            )
                        )
                        .frame(height: 0.5)
                }
                .padding(.top, 14)
                .padding(.bottom, 12)

                // sub stats
                HStack(spacing: 10) {
                    heroStat("累计盈亏")
                    heroStat("年化收益率")
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 18)
        }
        .shadow(color: Color(red: 58/255, green: 40/255, blue: 24/255).opacity(0.32), radius: 18, x: 0, y: 18)
        .shadow(color: Color(red: 58/255, green: 40/255, blue: 24/255).opacity(0.18), radius: 6, x: 0, y: 4)
    }

    private func heroStat(_ label: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(Theme.serif(10.5, weight: .bold))
                .kerning(1.4)
                .foregroundStyle(Theme.EmptyV2.heroLabel.opacity(0.62))
            Text("—")
                .font(.system(size: 22, weight: .heavy))
                .kerning(-0.5)
                .foregroundStyle(Theme.EmptyV2.heroLabel.opacity(0.42))
                .accessibilityLabel("暂无数据")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 14)
        .padding(.top, 12)
        .padding(.bottom, 14)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.white.opacity(0.05))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Theme.EmptyV2.heroLabel.opacity(0.16), lineWidth: 0.5)
        )
    }
}

/// 等高线 — 7 条二次贝塞尔(viewBox 360×220 自适应宽度)
private struct ContourLines: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let w = rect.width
        let h = rect.height
        // viewBox 360×220 — 把 y 坐标按比例映射,x 全宽
        let kx: CGFloat = w / 360
        let ky: CGFloat = h / 220

        struct Wave { let y0: CGFloat; let cy1: CGFloat; let cx2: CGFloat; let y2: CGFloat; let cx3: CGFloat; let cy3: CGFloat; let y4: CGFloat }
        // 简化:每条用两段 quadratic
        let waves: [(start: CGFloat, c1: CGFloat, end: CGFloat, c2: CGFloat, last: CGFloat)] = [
            (180, 150, 170, 140, 140),
            (160, 130, 150, 118, 118),
            (140, 108, 128, 94,  94),
            (118, 84,  108, 70,  70),
            (94,  60,  84,  46,  46),
            (70,  38,  62,  22,  22),
            (46,  16,  38,  -4,  -4)
        ]

        for wv in waves {
            p.move(to: CGPoint(x: -10 * kx, y: wv.start * ky))
            p.addQuadCurve(
                to: CGPoint(x: 180 * kx, y: wv.end * ky),
                control: CGPoint(x: 80 * kx, y: wv.c1 * ky)
            )
            p.addQuadCurve(
                to: CGPoint(x: 380 * kx, y: wv.last * ky),
                control: CGPoint(x: 280 * kx, y: wv.c2 * ky)
            )
        }

        return p
    }
}

// MARK: - StepCard 三步引导

struct StepCard: View {
    let onTap: () -> Void

    private let steps: [(n: Int, t: String, s: String)] = [
        (1, "添加账户", "现金 · 基金 App · 券商 · 黄金"),
        (2, "录入持仓 / 创建定投", "自动跟踪市值与浮动盈亏"),
        (3, "查看总资产 · 走势 · 分布", "数据自动汇总到首页")
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("开始你的财富地图")
                .font(Theme.serif(19, weight: .bold))
                .kerning(-0.3)
                .foregroundStyle(Theme.EmptyV2.text1)

            Text("三步把所有钱归集到这里")
                .font(Theme.serif(13))
                .foregroundStyle(Theme.EmptyV2.text2)
                .padding(.top, 4)

            VStack(alignment: .leading, spacing: 16) {
                ForEach(steps, id: \.n) { s in
                    HStack(alignment: .top, spacing: 14) {
                        ZStack {
                            Circle()
                                .fill(Theme.EmptyV2.bronzeSoft)
                                .frame(width: 30, height: 30)
                            Circle()
                                .stroke(Theme.EmptyV2.bronzeSoftBorder, lineWidth: 0.5)
                                .frame(width: 30, height: 30)
                            Text("\(s.n)")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(Theme.EmptyV2.bronzeDark)
                        }
                        VStack(alignment: .leading, spacing: 3) {
                            Text(s.t)
                                .font(Theme.serif(15, weight: .bold))
                                .kerning(-0.1)
                                .foregroundStyle(Theme.EmptyV2.text1)
                            Text(s.s)
                                .font(Theme.serif(12.5))
                                .foregroundStyle(Theme.EmptyV2.text2)
                        }
                        Spacer(minLength: 0)
                    }
                }
            }
            .padding(.top, 18)

            // hairline + CTA
            Rectangle()
                .fill(Theme.EmptyV2.bronzeSoftBorder)
                .frame(height: 0.5)
                .padding(.top, 16)

            BronzeCTA(title: "添加账户", action: onTap)
                .padding(.top, 16)
        }
        .padding(.horizontal, 22)
        .padding(.top, 20)
        .padding(.bottom, 18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Theme.EmptyV2.cardBg)
        )
        .shadow(color: Color.black.opacity(0.04), radius: 0, x: 0, y: 1)
        .shadow(color: Color.black.opacity(0.03), radius: 12, x: 0, y: 10)
    }
}

// MARK: - 资产趋势 placeholder

struct TrendPlaceholder: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("资产趋势")
                        .font(Theme.serif(17, weight: .bold))
                        .kerning(-0.2)
                        .foregroundStyle(Theme.EmptyV2.text1)
                    Text("每日自动记录,等待时间生效")
                        .font(Theme.serif(12))
                        .foregroundStyle(Theme.EmptyV2.text2)
                }
                Spacer()
                ZStack {
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .fill(Theme.EmptyV2.bronzeSoft)
                        .frame(width: 30, height: 30)
                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 14, weight: .heavy))
                        .foregroundStyle(Theme.EmptyV2.bronzeDark)
                }
            }

            // 虚线波形
            DottedWave()
                .stroke(
                    Theme.EmptyV2.bronzeStroke,
                    style: StrokeStyle(lineWidth: 1.4, lineCap: .round, dash: [3, 5])
                )
                .frame(height: 80)
                .opacity(0.55)
                .padding(.top, 12)

            Text("至少 2 天数据后,曲线会绘制在这里")
                .font(Theme.serif(11.5))
                .kerning(0.5)
                .foregroundStyle(Theme.EmptyV2.text3)
                .frame(maxWidth: .infinity)
                .padding(.top, 4)
        }
        .padding(.horizontal, 18)
        .padding(.top, 16)
        .padding(.bottom, 14)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Theme.EmptyV2.cardBg)
        )
        .shadow(color: Color.black.opacity(0.04), radius: 0, x: 0, y: 1)
        .shadow(color: Color.black.opacity(0.03), radius: 12, x: 0, y: 10)
    }
}

private struct DottedWave: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let w = rect.width
        let h = rect.height
        // d="M 0 50 Q 50 30 100 45 T 200 40 T 320 38" — 映射到 rect
        let scaleY = h / 80
        func y(_ v: CGFloat) -> CGFloat { v * scaleY }
        let x0: CGFloat = 0
        let x1: CGFloat = w * 100 / 320
        let x2: CGFloat = w * 200 / 320
        let x3: CGFloat = w
        let c1x: CGFloat = w * 50 / 320
        let c2x: CGFloat = w * 150 / 320  // mirror reflection
        let c3x: CGFloat = w * 250 / 320

        p.move(to: CGPoint(x: x0, y: y(50)))
        p.addQuadCurve(to: CGPoint(x: x1, y: y(45)),
                       control: CGPoint(x: c1x, y: y(30)))
        // T command — reflection: use mirrored control
        p.addQuadCurve(to: CGPoint(x: x2, y: y(40)),
                       control: CGPoint(x: c2x, y: y(60)))
        p.addQuadCurve(to: CGPoint(x: x3, y: y(38)),
                       control: CGPoint(x: c3x, y: y(20)))
        return p
    }
}

// MARK: - 资产分布 placeholder(60 radial ticks)

struct DonutPlaceholder: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("资产分布")
                .font(Theme.serif(17, weight: .bold))
                .kerning(-0.2)
                .foregroundStyle(Theme.EmptyV2.text1)

            HStack {
                Spacer()
                ZStack {
                    RadialTicks()
                    Text("—")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(Theme.EmptyV2.bronze.opacity(0.5))
                }
                .frame(width: 160, height: 160)
                Spacer()
            }
            .padding(.top, 14)

            HStack(spacing: 8) {
                Spacer()
                ChipPill(text: "现金")
                ChipPill(text: "基金")
                ChipPill(text: "股票")
                ChipPill(text: "黄金")
                ChipPill(text: "…")
                Spacer()
            }
            .padding(.top, 10)

            Text("添加账户后查看各类资产占比")
                .font(Theme.serif(11.5))
                .kerning(0.5)
                .foregroundStyle(Theme.EmptyV2.text3)
                .frame(maxWidth: .infinity)
                .padding(.top, 14)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Theme.EmptyV2.cardBg)
        )
        .shadow(color: Color.black.opacity(0.04), radius: 0, x: 0, y: 1)
        .shadow(color: Color.black.opacity(0.03), radius: 12, x: 0, y: 10)
    }
}

private struct RadialTicks: View {
    var body: some View {
        Canvas { ctx, size in
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let scale = size.width / 160
            let r1: CGFloat = 56 * scale
            let r2: CGFloat = 64 * scale
            let stroke = GraphicsContext.Shading.linearGradient(
                Gradient(colors: [Theme.EmptyV2.bronzeUp, Theme.EmptyV2.bronzeDark]),
                startPoint: CGPoint(x: 0, y: 0),
                endPoint: CGPoint(x: size.width, y: size.height)
            )
            for i in 0..<60 {
                let angle = Double(i) / 60 * .pi * 2 - .pi / 2
                let x1 = center.x + CGFloat(cos(angle)) * r1
                let y1 = center.y + CGFloat(sin(angle)) * r1
                let x2 = center.x + CGFloat(cos(angle)) * r2
                let y2 = center.y + CGFloat(sin(angle)) * r2
                var p = Path()
                p.move(to: CGPoint(x: x1, y: y1))
                p.addLine(to: CGPoint(x: x2, y: y2))

                var s = ctx
                s.opacity = i.isMultiple(of: 5) ? 0.55 : 0.28
                s.stroke(p, with: stroke, style: StrokeStyle(lineWidth: 1.3, lineCap: .round))
            }
        }
    }
}
