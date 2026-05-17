import SwiftUI

/// 走势图区间切换 — 暗色(Hero)/亮色(走势卡)两套配色。
/// SwiftUI 原生 Picker(.segmented) 无法定制暗色,所以手写。
struct RangeTabsView: View {
    @Binding var range: TrendRange
    var dark: Bool = false

    var body: some View {
        HStack(spacing: 0) {
            ForEach(TrendRange.allCases, id: \.self) { r in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        range = r
                    }
                } label: {
                    Text(r.displayName)
                        .font(.system(size: 13, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                        .background(
                            range == r ?
                                (dark ? Color.white : Color.primary)
                                : Color.clear
                        )
                        .foregroundStyle(
                            range == r ?
                                (dark ? Color.black : Color.white)
                                : (dark ? Color.white.opacity(0.55) : Color.secondary)
                        )
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(3)
        .background(
            dark ? Color.white.opacity(0.10) : Color.black.opacity(0.045)
        )
        .clipShape(Capsule())
    }
}
