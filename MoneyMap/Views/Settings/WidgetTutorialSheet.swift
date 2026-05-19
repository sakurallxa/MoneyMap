import SwiftUI

/// 桌面 Widget 添加教程,图文步骤。
struct WidgetTutorialSheet: View {
    @Environment(\.dismiss) private var dismiss

    private struct Step: Identifiable {
        let id: Int
        let title: String
        let detail: String
        let symbol: String
    }

    private let steps: [Step] = [
        .init(id: 1, title: "长按桌面空白处",
              detail: "进入「编辑模式」,图标会开始抖动。",
              symbol: "hand.tap.fill"),
        .init(id: 2, title: "点击左上角的「+」",
              detail: "打开 Widget 资源库,可以浏览所有应用提供的小组件。",
              symbol: "plus.app.fill"),
        .init(id: 3, title: "搜索「钱袋」",
              detail: "在顶部搜索栏输入「钱袋」或滚动到列表中找到它。",
              symbol: "magnifyingglass"),
        .init(id: 4, title: "选择尺寸 · 添加 Widget",
              detail: "支持小、中两种尺寸 · 点击「添加」,再轻按桌面任意位置完成。",
              symbol: "rectangle.stack.badge.plus")
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    heroCard
                    VStack(spacing: 14) {
                        ForEach(steps) { step in
                            stepCard(step)
                        }
                    }
                    .padding(.horizontal, 14)

                    hintCard
                        .padding(.horizontal, 14)
                        .padding(.top, 4)

                    Spacer(minLength: 60)
                }
                .padding(.top, 8)
            }
            .background(Theme.Palette.pageBgWarm.ignoresSafeArea())
            .navigationTitle("添加桌面 Widget")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { dismiss() }
                        .font(Theme.serif(15, weight: .bold))
                        .foregroundStyle(Theme.Palette.accentDark)
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    private var heroCard: some View {
        VStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Theme.Palette.accent, Theme.Palette.accentDark],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 88, height: 88)
                    .shadow(color: Theme.Palette.accent.opacity(0.35), radius: 18, y: 8)
                Image(systemName: "rectangle.stack.fill.badge.person.crop")
                    .font(.system(size: 38, weight: .semibold))
                    .foregroundStyle(.white)
            }

            Text("把总资产放上桌面")
                .font(Theme.serif(18, weight: .bold))
            Text("不打开 App 也能看一眼今日盈亏 ·\n4 步即可设置完毕")
                .font(Theme.serif(12))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .lineSpacing(3)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 22)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
        )
        .padding(.horizontal, 14)
        .cardElevation()
    }

    private func stepCard(_ step: Step) -> some View {
        HStack(alignment: .top, spacing: 14) {
            ZStack {
                Circle()
                    .fill(Theme.Palette.accent.opacity(0.12))
                    .frame(width: 38, height: 38)
                Text("\(step.id)")
                    .font(.system(size: 16, weight: .heavy))
                    .foregroundStyle(Theme.Palette.accentDark)
            }
            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 8) {
                    Text(step.title)
                        .font(Theme.serif(15, weight: .bold))
                    Image(systemName: step.symbol)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Theme.Palette.accent)
                }
                Text(step.detail)
                    .font(Theme.serif(12))
                    .foregroundStyle(.secondary)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
        )
        .cardElevation()
    }

    private var hintCard: some View {
        HStack(spacing: 10) {
            Image(systemName: "lightbulb.fill")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 30, height: 30)
                .background(Theme.Palette.accent)
                .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
            Text("Widget 每小时自动刷新一次 · 也可下拉 App 主页强制刷新最新行情")
                .font(Theme.serif(12))
                .foregroundStyle(Theme.Palette.accentDark)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Theme.Palette.accent.opacity(0.10))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Theme.Palette.accent.opacity(0.18), lineWidth: 0.5)
        )
    }
}
