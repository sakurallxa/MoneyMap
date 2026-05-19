import SwiftUI

/// 首次启动 · 卡浮现欢迎页。
/// 设计语言:
///   统一暖米底(全局,无割裂) / 黑金"信物"卡(常驻 -3° 倾斜 + 7s 上下浮动) /
///   卡下方铜色光晕同步呼吸 / 衬线主标题 / 资产·洞察·复利 三栏 / 实色铜 CTA。
///   所有动画节奏 6–13s,远慢于心跳触发沉静体感;
///   staggered 渐入 1.1s + blur(4)→0,潜出而非弹出。
struct WelcomeView: View {
    @AppStorage("hasOnboarded") private var hasOnboarded = false

    // 卡片呼吸状态:仅 Y 位移与铜光晕呼吸,倾斜常驻 -3° 不变
    @State private var cardFloat: CGFloat = -5
    @State private var glowOpacity: Double = 0.30

    // staggered reveal
    @State private var revealBrand = false
    @State private var revealCard = false
    @State private var revealTitle = false
    @State private var revealSubtitle = false
    @State private var revealPillars = false
    @State private var revealCTA = false

    // 退场
    @State private var isLeaving = false

    /// 全局统一暖米底色 — 整页同一颜色,避免任何渐变接缝
    private let pageBg = Color(hex: "#EFE7D6")
    private let copper = Color(hex: "#A67849")
    private let copperDark = Color(hex: "#8C5E33")
    private let inkBrown = Color(hex: "#2A2620")
    private let mutedBrown = Color(hex: "#9A8870")
    private let goldText = Color(hex: "#C8956D")

    private func serif(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        // 复用全局 fallback 链:Source Han Serif → Songti SC → 系统衬线
        Theme.serif(size, weight: weight)
    }

    var body: some View {
        ZStack {
            // 全局唯一暖米底 — 整页同色,无渐变、无接缝
            pageBg.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer().frame(height: 14)

                // 顶部品牌行(两侧细金线 + 字)
                brandLine
                    .opacity(revealBrand ? 1 : 0)
                    .blur(radius: revealBrand ? 0 : 4)

                Spacer().frame(height: 46)

                // 黑金信物卡 + 下方铜光晕
                cardWithGlow
                    .frame(height: 220)
                    .opacity(revealCard ? 1 : 0)
                    .blur(radius: revealCard ? 0 : 4)

                Spacer().frame(height: 58)

                // 衬线主标题
                Text("让 财 富 有 迹 可 循")
                    .font(serif(23, weight: .regular))
                    .tracking(5)
                    .foregroundStyle(inkBrown)
                    .opacity(revealTitle ? 1 : 0)
                    .blur(radius: revealTitle ? 0 : 4)

                Spacer().frame(height: 22)

                // 副文案
                VStack(spacing: 6) {
                    Text("一处管理所有账户与持仓")
                    Text("看见每一笔钱真正的去向")
                }
                .font(serif(13))
                .kerning(1.0)
                .foregroundStyle(mutedBrown)
                .opacity(revealSubtitle ? 1 : 0)
                .blur(radius: revealSubtitle ? 0 : 4)

                Spacer().frame(height: 44)

                // 三栏:资产·洞察·复利
                HStack(spacing: 0) {
                    Spacer()
                    pillarColumn("资 产", "ASSET")
                    Spacer()
                    pillarColumn("洞 察", "INSIGHT")
                    Spacer()
                    pillarColumn("复 利", "COMPOUND")
                    Spacer()
                }
                .padding(.horizontal, 26)
                .opacity(revealPillars ? 1 : 0)
                .blur(radius: revealPillars ? 0 : 4)

                Spacer(minLength: 28)

                // CTA
                Button(action: enterApp) {
                    Text("开 启 钱 袋")
                        .font(serif(17, weight: .semibold))
                        .kerning(4)
                        .foregroundStyle(Color(hex: "#FBF3E2"))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 19)
                        .background(
                            ZStack {
                                RoundedRectangle(cornerRadius: 22, style: .continuous)
                                    .fill(
                                        LinearGradient(
                                            colors: [
                                                Color(hex: "#BC885A"),
                                                Color(hex: "#A06D40")
                                            ],
                                            startPoint: .top, endPoint: .bottom
                                        )
                                    )
                                RoundedRectangle(cornerRadius: 22, style: .continuous)
                                    .stroke(
                                        LinearGradient(
                                            colors: [
                                                Color.white.opacity(0.22),
                                                Color.white.opacity(0.0)
                                            ],
                                            startPoint: .top, endPoint: .bottom
                                        ),
                                        lineWidth: 0.8
                                    )
                            }
                        )
                        .shadow(color: copperDark.opacity(0.30), radius: 18, x: 0, y: 10)
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 24)
                .opacity(revealCTA ? 1 : 0)
                .blur(radius: revealCTA ? 0 : 4)
                .padding(.bottom, 30)
            }
        }
        .opacity(isLeaving ? 0 : 1)
        .scaleEffect(isLeaving ? 1.02 : 1)
        .onAppear { startChoreography() }
    }

    // MARK: - 顶部品牌行(两侧 hairline 金线)

    private var brandLine: some View {
        HStack(spacing: 14) {
            Rectangle()
                .fill(mutedBrown.opacity(0.45))
                .frame(width: 26, height: 0.5)
            Text("MONEYMAP · EST. 2026")
                .font(.system(size: 11, weight: .medium))
                .kerning(3.6)
                .foregroundStyle(mutedBrown.opacity(0.85))
            Rectangle()
                .fill(mutedBrown.opacity(0.45))
                .frame(width: 26, height: 0.5)
        }
    }

    // MARK: - 卡 + 卡下铜光晕

    private var cardWithGlow: some View {
        ZStack {
            // 铜色光晕(置于卡下方,与卡片呼吸同步)
            Ellipse()
                .fill(
                    RadialGradient(
                        colors: [
                            copper.opacity(glowOpacity * 0.55),
                            copper.opacity(glowOpacity * 0.18),
                            copper.opacity(0)
                        ],
                        center: .center,
                        startRadius: 4,
                        endRadius: 160
                    )
                )
                .frame(width: 300, height: 140)
                .offset(y: 90)
                .blur(radius: 18)

            // 信物卡(常驻 -3° 倾斜)
            luxeCard
                .rotationEffect(.degrees(-3))
                .offset(y: cardFloat)
        }
    }

    // MARK: - 黑金信物卡

    private var luxeCard: some View {
        ZStack {
            // 主黑金底(单色为主,微渐变体现质感)
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(
                    LinearGradient(
                        stops: [
                            .init(color: Color(hex: "#1B1612"), location: 0),
                            .init(color: Color(hex: "#251B12"), location: 0.55),
                            .init(color: Color(hex: "#2E2117"), location: 1)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            // 金色波纹底纹(更清晰)
            cardWaveGuilloche
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .allowsHitTesting(false)

            // 右上径向暖金高光
            RadialGradient(
                colors: [copper.opacity(0.22), .clear],
                center: .topTrailing,
                startRadius: 4, endRadius: 160
            )
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))

            // hairline 描边
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .inset(by: 0.3)
                .stroke(Color.white.opacity(0.10), lineWidth: 0.5)

            VStack(spacing: 0) {
                // 顶行:芯片 + PRIVATE · WEALTH + 双圈
                HStack(alignment: .center) {
                    chipShape
                        .frame(width: 26, height: 20)
                    Text("PRIVATE · WEALTH")
                        .font(.system(size: 9, weight: .semibold))
                        .kerning(2.4)
                        .foregroundStyle(goldText)
                    Spacer()
                    Image(systemName: "circlebadge.2")
                        .font(.system(size: 13))
                        .foregroundStyle(goldText.opacity(0.7))
                }

                Spacer()

                // 中央:钱袋(米→金 衬线,字距适中)
                Text("钱 袋")
                    .font(Theme.serif(32, weight: .regular))
                    .tracking(4)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [
                                Color(hex: "#FBEFD2"),
                                Color(hex: "#EAD09A"),
                                Color(hex: "#C8956D")
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .shadow(color: copper.opacity(0.32), radius: 5, x: 0, y: 2)

                Spacer()

                // 底行:· · 2026 / MEMBER
                HStack {
                    Text("· ·  2026")
                        .font(.system(size: 10, weight: .medium))
                        .kerning(2)
                        .foregroundStyle(goldText.opacity(0.88))
                    Spacer()
                    Text("MEMBER")
                        .font(.system(size: 9, weight: .semibold))
                        .kerning(2.8)
                        .foregroundStyle(goldText.opacity(0.88))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
        }
        .frame(width: 260, height: 162)
        .shadow(color: .black.opacity(0.26), radius: 22, x: 0, y: 14)
        .shadow(color: copperDark.opacity(0.14), radius: 10, x: 0, y: 4)
    }

    /// 卡面金色 chip
    private var chipShape: some View {
        RoundedRectangle(cornerRadius: 4, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        Color(hex: "#E6C887"),
                        Color(hex: "#B8884C"),
                        Color(hex: "#8E6438")
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(
                VStack(spacing: 2) {
                    Capsule().fill(Color.black.opacity(0.18)).frame(height: 1)
                    Capsule().fill(Color.black.opacity(0.18)).frame(height: 1)
                    Capsule().fill(Color.black.opacity(0.18)).frame(height: 1)
                }
                .padding(.horizontal, 4)
                .padding(.vertical, 4)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .stroke(Color.white.opacity(0.25), lineWidth: 0.4)
            )
    }

    /// 卡面 guilloché 流线(更明显,贴近参考图)
    private var cardWaveGuilloche: some View {
        Canvas { context, size in
            let goldA = Color(red: 200/255, green: 149/255, blue: 109/255, opacity: 0.28)
            let goldB = Color(red: 251/255, green: 239/255, blue: 210/255, opacity: 0.16)

            for i in 0..<8 {
                var path = Path()
                let baseY = size.height * 0.50 + CGFloat(i - 4) * 10
                path.move(to: CGPoint(x: 0, y: baseY))
                for x in stride(from: 0.0, through: size.width, by: 2) {
                    let amp: CGFloat = 4 + CGFloat(abs(i - 4)) * 1.4
                    let phase = CGFloat(i) * 0.35
                    let y = baseY + sin((x / 24) + phase) * amp
                    path.addLine(to: CGPoint(x: x, y: y))
                }
                context.stroke(
                    path,
                    with: .color(i.isMultiple(of: 2) ? goldA : goldB),
                    lineWidth: 0.65
                )
            }
        }
    }

    // MARK: - 三栏(中文衬线 + 英文 caps)

    private func pillarColumn(_ zh: String, _ en: String) -> some View {
        VStack(spacing: 8) {
            Text(zh)
                .font(serif(15, weight: .regular))
                .tracking(2)
                .foregroundStyle(copperDark)
            Text(en)
                .font(.system(size: 9, weight: .medium))
                .kerning(2.6)
                .foregroundStyle(mutedBrown.opacity(0.85))
        }
    }

    // MARK: - choreography

    private func startChoreography() {
        // 卡片缓慢上下浮动(倾斜常驻 -3° 不变):7s 单向 → 14s 一轮
        withAnimation(.easeInOut(duration: 7).repeatForever(autoreverses: true)) {
            cardFloat = 9
        }

        // 铜光晕呼吸同步,7s 单向
        withAnimation(.easeInOut(duration: 7).repeatForever(autoreverses: true)) {
            glowOpacity = 0.95
        }

        // staggered 渐入(1.1s + blur(4)→0,潜出而非弹出)
        withAnimation(.easeOut(duration: 1.1).delay(0.10)) { revealBrand = true }
        withAnimation(.easeOut(duration: 1.1).delay(0.40)) { revealCard = true }
        withAnimation(.easeOut(duration: 1.1).delay(1.20)) { revealTitle = true }
        withAnimation(.easeOut(duration: 1.1).delay(1.90)) { revealSubtitle = true }
        withAnimation(.easeOut(duration: 1.1).delay(2.50)) { revealPillars = true }
        withAnimation(.easeOut(duration: 1.1).delay(3.10)) { revealCTA = true }
    }

    private func enterApp() {
        withAnimation(.easeInOut(duration: 0.55)) {
            isLeaving = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
            hasOnboarded = true
        }
    }
}

#Preview {
    WelcomeView()
}
