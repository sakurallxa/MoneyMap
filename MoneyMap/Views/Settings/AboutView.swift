import SwiftUI

/// 设置 → 关于钱袋 二级页。展示 App 介绍 / 数据隐私 / 行情来源 / 致谢。
struct AboutView: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                heroBanner
                introCard
                privacyCard
                creditsCard
                footer
            }
            .padding(.horizontal, 14)
            .padding(.top, 8)
            .padding(.bottom, 40)
        }
        .background(Theme.Palette.pageBgWarm.ignoresSafeArea())
        .navigationTitle("关于钱袋")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Hero

    private var heroBanner: some View {
        VStack(spacing: 14) {
            // App Logo(与 Home Screen icon 一致)
            Image("Logo")
                .resizable()
                .interpolation(.high)
                .aspectRatio(contentMode: .fit)
                .frame(width: 96, height: 96)
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                .shadow(color: Theme.Bronze.primary.opacity(0.28), radius: 14, x: 0, y: 7)

            VStack(spacing: 6) {
                Text("钱袋")
                    .font(Theme.serif(30, weight: .heavy))
                    .kerning(-0.5)
                    .foregroundStyle(Theme.EmptyV2.text1)
                Text("把你的钱装一起")
                    .font(Theme.serif(13))
                    .kerning(0.6)
                    .foregroundStyle(.secondary)
            }

            // 金箔 hairline
            Rectangle()
                .fill(Theme.Bronze.goldHairline)
                .frame(height: 0.6)
                .frame(maxWidth: 220)
                .padding(.top, 4)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Theme.Bronze.softBorder, lineWidth: 0.5)
        )
        .cardElevation()
    }

    // MARK: - Intro

    private var introCard: some View {
        sectionCard(title: "做这个 App 的初衷") {
            paragraph("管理多渠道跨渠道的资产,把现金、基金、港股、美股、黄金等装在同一个口袋里。一眼看到全部资产+今日盈亏,不需要打开 N 个 App。数据本地为主,不推荐不打扰。")
        }
    }

    // MARK: - Privacy

    private var privacyCard: some View {
        sectionCard(title: "数据与隐私") {
            VStack(alignment: .leading, spacing: 10) {
                paragraph("所有资产数据存储在你自己的设备本地,不会上传任何服务器。")
                paragraph("行情拉取只发送资产代码到公开行情源(新浪/雅虎/天天/蛋卷/上海黄金交易所),不携带任何账户信息。")
                paragraph("钱袋没有后端服务器,没有用户账号体系,不收集设备标识、不做行为追踪。")
            }
        }
    }

    // MARK: - Credits

    private var creditsCard: some View {
        sectionCard(title: "致谢") {
            VStack(alignment: .leading, spacing: 8) {
                creditLine(name: "思源宋体", by: "Adobe Originals + Google")
                creditLine(name: "SF Symbols", by: "Apple")
                creditLine(name: "SwiftUI · SwiftData · WidgetKit", by: "Apple")
            }
        }
    }

    // MARK: - Footer

    private var footer: some View {
        VStack(spacing: 4) {
            Text("版本 \(appVersion)")
                .font(Theme.serif(12, weight: .semibold))
                .foregroundStyle(.secondary)
                .monospacedDigit()
            Text("© 2026 钱袋")
                .font(Theme.serif(11))
                .foregroundStyle(.tertiary)
        }
        .padding(.top, 8)
    }

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.1.0"
    }

    // MARK: - Reusable section card

    @ViewBuilder
    private func sectionCard<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(Theme.TypeToken.eyebrow())
                .kerning(Theme.TypeToken.eyebrowKerning)
                .foregroundStyle(Theme.Bronze.dark)
            content()
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
        )
        .cardElevation()
    }

    private func paragraph(_ text: String) -> some View {
        Text(text)
            .font(Theme.serif(13))
            .foregroundStyle(.secondary)
            .lineSpacing(4)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func creditLine(name: String, by: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(name)
                .font(Theme.serif(13, weight: .semibold))
                .foregroundStyle(.primary)
            Text("·")
                .foregroundStyle(.tertiary)
            Text(by)
                .font(Theme.serif(12))
                .foregroundStyle(.secondary)
            Spacer()
        }
    }
}

#Preview {
    NavigationStack { AboutView() }
}
