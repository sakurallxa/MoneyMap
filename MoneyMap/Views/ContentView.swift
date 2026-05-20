import SwiftUI

extension Notification.Name {
    /// 跨 tab 跳转 — object 传递目标 tab index(Int)
    static let switchToTab = Notification.Name("MoneyMap.switchToTab")
}

struct ContentView: View {
    @State private var selectedTab: Int = {
        if let arg = ProcessInfo.processInfo.environment["MONEYMAP_INITIAL_TAB"], let n = Int(arg) { return n }
        return 0
    }()
    @State private var showRebalance: Bool = ProcessInfo.processInfo.environment["MONEYMAP_SHOW_REBALANCE"] == "1"
    @State private var debugPrefill: RebalancePrefill? = {
        guard ProcessInfo.processInfo.environment["MONEYMAP_SHOW_BUY"] == "1" else { return nil }
        return RebalancePrefill(action: .buy, assetClass: .fund, amount: 12200)
    }()
    @State private var showTargetSheet: Bool = ProcessInfo.processInfo.environment["MONEYMAP_SHOW_TARGET"] == "1"

    var body: some View {
        TabView(selection: $selectedTab) {
            DashboardView()
                .tag(0)
                .tabItem {
                    Label("钱袋", systemImage: "bag.fill")
                }

            AccountsView()
                .tag(1)
                .tabItem {
                    Label("账户", systemImage: "wallet.pass.fill")
                }

            TransactionsView()
                .tag(2)
                .tabItem {
                    Label("交易", systemImage: "list.bullet.rectangle")
                }

            DCAPlansView()
                .tag(3)
                .tabItem {
                    Label("定投", systemImage: "calendar.badge.clock")
                }

            SettingsView()
                .tag(4)
                .tabItem {
                    Label("设置", systemImage: "gearshape")
                }
        }
        .tint(Theme.Palette.accentDark)    // 全局铜深色覆盖 SwiftUI 默认蓝 tint(系统 Back / Menu 等)
        .sheet(isPresented: $showRebalance) {
            // 注意:.tint 不会穿透 sheet 环境,每个 sheet 内 NavigationStack
            // 必须显式声明,否则 < 返回按钮会退回默认黑色 / 系统蓝。
            NavigationStack { RebalanceView() }
                .tint(Theme.Palette.accentDark)
        }
        .sheet(item: $debugPrefill) { p in
            NavigationStack {
                TransactionFormView(
                    type: p.action.formType,
                    onSave: { debugPrefill = nil },
                    rebalancePrefill: p
                )
            }
            .tint(Theme.Palette.accentDark)
        }
        .sheet(isPresented: $showTargetSheet) {
            TargetAllocationSheet()
                .tint(Theme.Palette.accentDark)
        }
        .overlay(ToastOverlayView())
        .onReceive(NotificationCenter.default.publisher(for: .switchToTab)) { note in
            if let idx = note.object as? Int {
                withAnimation(.easeInOut(duration: 0.25)) {
                    selectedTab = idx
                }
            }
        }
    }
}

#Preview {
    ContentView()
}
