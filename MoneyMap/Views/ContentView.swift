import SwiftUI

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
                    Label("总览", systemImage: "chart.pie.fill")
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
        .tint(.accentColor)
        .sheet(isPresented: $showRebalance) {
            NavigationStack { RebalanceView() }
        }
        .sheet(item: $debugPrefill) { p in
            AddTransactionSheet(prefill: p)
        }
        .sheet(isPresented: $showTargetSheet) {
            TargetAllocationSheet()
        }
        .overlay(ToastOverlayView())
        .sheet(isPresented: $showNicknameOnboarding) {
            NicknameOnboardingView()
                .interactiveDismissDisabled(true)
        }
        .onAppear {
            checkFirstLaunchOnboarding()
        }
    }

    @State private var showNicknameOnboarding = false
    @AppStorage("userNickname") private var userNickname: String = ""
    @AppStorage("didShowNicknameOnboarding") private var didShowOnboarding: Bool = false

    private func checkFirstLaunchOnboarding() {
        if !didShowOnboarding && userNickname.isEmpty {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                showNicknameOnboarding = true
            }
        }
    }
}

#Preview {
    ContentView()
}
