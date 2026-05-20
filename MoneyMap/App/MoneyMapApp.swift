import SwiftUI
import SwiftData
import UIKit
import CoreText

private extension UIFont {
    func withTraits(_ traits: UIFontDescriptor.SymbolicTraits) -> UIFont? {
        guard let d = fontDescriptor.withSymbolicTraits(traits) else { return nil }
        return UIFont(descriptor: d, size: pointSize)
    }
}

@main
struct MoneyMapApp: App {
    let container: ModelContainer
    @AppStorage("hasOnboarded") private var hasOnboarded = false
    @StateObject private var biometricLock = BiometricLock()
    @Environment(\.scenePhase) private var scenePhase
    /// 只在真正"经过 .background"后才重新触发锁定。
    /// Face ID 系统弹窗只会让 scenePhase 短暂变 .inactive,**不会**经过 .background,
    /// 所以这个 flag 能阻止"Face ID 弹窗回来后又重新弹 Face ID"的死循环。
    @State private var wasInBackground = false

    init() {
        // XCTest runtime 下跳过重启动逻辑(字体注册、UIKit appearance、迁移等)
        // 避免单元测试加载 host App 时 init() 阻塞 / 崩溃
        let isRunningTests = ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil

        if !isRunningTests {
            Self.registerBundleFonts()        // 先注册字体,后续 appearance 才能命中
            Self.configureGlobalAppearance()
        }

        let schema = Schema([
            Account.self,
            Asset.self,
            Position.self,
            TransactionRecord.self,
            DCAPlan.self,
            PriceQuote.self,
            ExchangeRate.self,
            DailySnapshot.self,
            TargetAllocation.self
        ])

        // 默认走本地容器(冷启动 < 100ms),只有用户在「设置 · iCloud 同步」打开后才尝试 CloudKit,
        // 避免每次冷启都做一次 iCloud 握手(可能耗时 1-3s,首次启动表现为长时间白屏)。
        //
        // v1.0:iCloud 同步入口在 SettingsView 已隐藏,这里强制 false,
        // 防止旧 build UserDefaults 残留 true 导致 CloudKit 初始化崩溃(没加 capability)。
        // v1.1 加完 CloudKit capability + 模型内联默认值后,改回 UserDefaults 读取即可。
        let iCloudEnabled = false  // UserDefaults.standard.bool(forKey: "iCloudSyncEnabled")
        let resolved: ModelContainer
        if iCloudEnabled {
            do {
                let cloudConfig = ModelConfiguration("MoneyMap", schema: schema, cloudKitDatabase: .automatic)
                resolved = try ModelContainer(for: schema, configurations: cloudConfig)
            } catch {
                resolved = Self.makeLocalContainer(schema: schema)
            }
        } else {
            resolved = Self.makeLocalContainer(schema: schema)
        }
        container = resolved

        let context = ModelContext(container)

        // 已禁用自动种子数据,新用户进入将看到空态承接
        // DemoDataSeeder.seedIfNeeded(context: context)

        // 测试 runtime 不跑数据迁移(测试用 in-memory context)
        if !isRunningTests {
            // 一次性数据迁移:把历史 .confirmed 记录提升到 .completed,
            // 让数据库和显示层语义对齐(三态合并为两态)。
            if !UserDefaults.standard.bool(forKey: "txStatus_v3_confirmedMerged") {
                Self.migrateConfirmedToCompleted(context: context)
                UserDefaults.standard.set(true, forKey: "txStatus_v3_confirmedMerged")
            }
        }
        _ = context  // silence unused warning when isRunningTests is true

        // DCAService 处理已移到 ContentView.task 异步执行,避免在 init() 同步
        // 阻塞 SwiftUI body 构建(冷启动时启动屏停留过久会让人误以为"白屏")。
    }

    /// P1-015 一次性迁移:把所有 statusRaw = "CONFIRMED" 的交易记录改为 "COMPLETED"
    private static func migrateConfirmedToCompleted(context: ModelContext) {
        let descriptor = FetchDescriptor<TransactionRecord>(
            predicate: #Predicate { $0.statusRaw == "CONFIRMED" }
        )
        guard let rows = try? context.fetch(descriptor), !rows.isEmpty else { return }
        for r in rows {
            r.statusRaw = "COMPLETED"
        }
        try? context.save()
    }

    /// 运行时把 bundle 里的 OTF 字体注册到 CoreText / UIKit。
    /// 用 CTFontManagerRegisterFontsForURL 而不是 Info.plist 的 UIAppFonts,
    /// 是因为 Xcode 的 INFOPLIST_KEY_* 白名单不认识 UIAppFonts,
    /// 即使在 build settings 里配置了也不会写进生成的 Info.plist。
    private static func registerBundleFonts() {
        let fontNames = [
            "SourceHanSerifSC-Regular",
            "SourceHanSerifSC-Medium",
            "SourceHanSerifSC-Light",
            "SourceHanSerifSC-ExtraLight"
        ]
        for name in fontNames {
            guard let url = Bundle.main.url(forResource: name, withExtension: "otf") else {
                continue
            }
            var error: Unmanaged<CFError>?
            let ok = CTFontManagerRegisterFontsForURL(url as CFURL, .process, &error)
            if !ok, let err = error?.takeRetainedValue() {
                // CTFontManagerErrorAlreadyRegistered = 105;遇到这个不当失败
                let code = CFErrorGetCode(err)
                if code != 105 {
                    debugLog("[Font] register \(name) failed: \(err)")
                }
            }
        }
    }

    /// 创建本地容器(无 CloudKit),冷启动最快路径
    private static func makeLocalContainer(schema: Schema) -> ModelContainer {
        do {
            let localConfig = ModelConfiguration("MoneyMap", schema: schema)
            return try ModelContainer(for: schema, configurations: localConfig)
        } catch {
            fatalError("Failed to initialize SwiftData local container: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            ZStack {
                // 全局兜底底色 — 保证任意首帧之前都不会闪白
                Color(red: 239/255, green: 231/255, blue: 214/255)
                    .ignoresSafeArea()

                if hasOnboarded {
                    ContentView()
                        .environment(\.locale, Locale(identifier: "zh_CN"))
                        .environment(\.font, Theme.serifBody)
                        .task {
                            // P1 5 步原子序列(顺序很重要):
                            // ① 触发到期定投 → 生成 .pending 扣款
                            // ② 刷行情 → 拿到最新价
                            // ③ 用最新价确认成熟的 .pending → 升级 .completed + 调持仓
                            // ④ 当天快照 → 趋势图有数据
                            // ⑤ Widget 推送
                            let context = container.mainContext
                            DCAService.triggerDuePlans(context: context)
                            await PriceRefreshService.refreshAll(context: context)
                            await DCAService.confirmRipePending(context: context)
                            SnapshotService.recordToday(context: context)
                            WidgetState.push(context: context)
                        }
                        .transition(.opacity.combined(with: .scale(scale: 0.98)))
                } else {
                    WelcomeView()
                        .environment(\.locale, Locale(identifier: "zh_CN"))
                        .environment(\.font, Theme.serifBody)
                        .transition(.opacity)
                }

                // 生物识别锁遮罩 — 在所有内容之上,只有 enabled + isLocked 时显示
                if biometricLock.isLocked {
                    BiometricLockOverlay(lock: biometricLock)
                        .zIndex(1000)
                        .transition(.opacity)
                }
            }
            .animation(.easeInOut(duration: 0.55), value: hasOnboarded)
            .animation(.easeInOut(duration: 0.25), value: biometricLock.isLocked)
            // 锁死浅色模式 — 钱袋整套调色板(铜+米色 + 黑金 hero)是浅色设计,
            // 卡片用了 Color(.secondarySystemGroupedBackground) 等系统动态色,
            // 跟随系统深色模式会让卡片变近黑色,与浅米色页面冲突。
            .preferredColorScheme(.light)
            .environmentObject(biometricLock)
            // 启动时 — 若开关 on 直接锁
            .onAppear { biometricLock.lockIfEnabled() }
            // scenePhase 状态机:只在真正经过 .background 后,回到 .active 时重新锁定
            .onChange(of: scenePhase) { _, newPhase in
                switch newPhase {
                case .background:
                    wasInBackground = true
                case .active:
                    if wasInBackground {
                        wasInBackground = false
                        biometricLock.lockIfEnabled()
                    }
                case .inactive:
                    // Face ID 系统弹窗会触发这个;什么都不做
                    break
                @unknown default:
                    break
                }
            }
        }
        .modelContainer(container)
    }

    /// 全局 UIKit 外观 — system 字体(空态 v2 规范)+ 铜色强调
    private static func configureGlobalAppearance() {
        // 铜色:与 Theme.Palette.accent (#C8956D) 完全一致
        let bronze = UIColor(red: 200/255, green: 149/255, blue: 109/255, alpha: 1)
        let bronzeDark = UIColor(red: 166/255, green: 120/255, blue: 73/255, alpha: 1)
        let inkTitle = UIColor(red: 42/255, green: 30/255, blue: 18/255, alpha: 1)
        let tabUnselected = UIColor(red: 60/255, green: 40/255, blue: 20/255, alpha: 0.4)

        // UIWindow 底色:launch screen 消失到 SwiftUI 首帧渲染之间的窗口空隙也是暖米
        // (默认是白色,会在冷启动瞬间闪一下)
        let pageBgWarm = UIColor(red: 239/255, green: 231/255, blue: 214/255, alpha: 1)
        UIWindow.appearance().backgroundColor = pageBgWarm

        // NavigationBar — 中文衬线大标题(Source Han Serif → Songti SC → 系统 fallback)
        // 使用默认材质背景(避免 sheet 滚动时内容透过 nav bar 与标题重叠)
        let navAppearance = UINavigationBarAppearance()
        navAppearance.configureWithDefaultBackground()
        let serifLarge = Theme.uiSerif(size: 32, bold: true)
        let serifInline = Theme.uiSerif(size: 17, bold: true)
        navAppearance.largeTitleTextAttributes = [
            .font: serifLarge,
            .foregroundColor: inkTitle,
            .kern: -0.8
        ]
        navAppearance.titleTextAttributes = [
            .font: serifInline,
            .foregroundColor: inkTitle
        ]
        UINavigationBar.appearance().standardAppearance = navAppearance
        UINavigationBar.appearance().scrollEdgeAppearance = navAppearance
        UINavigationBar.appearance().compactAppearance = navAppearance
        UINavigationBar.appearance().tintColor = bronze

        // TabBar — 选中铜深、未选浅棕灰(中文衬线 fallback)
        let tabFont = Theme.uiSerif(size: 10, bold: false)
        let tabFontBold = Theme.uiSerif(size: 10, bold: true)

        let tabAppearance = UITabBarAppearance()
        tabAppearance.configureWithDefaultBackground()
        let tabItem = UITabBarItemAppearance(style: .stacked)
        tabItem.selected.iconColor = bronzeDark
        tabItem.selected.titleTextAttributes = [
            .font: tabFontBold,
            .foregroundColor: bronzeDark,
            .kern: 0.3
        ]
        tabItem.normal.iconColor = tabUnselected
        tabItem.normal.titleTextAttributes = [
            .font: tabFont,
            .foregroundColor: tabUnselected,
            .kern: 0.3
        ]
        tabAppearance.stackedLayoutAppearance = tabItem
        tabAppearance.inlineLayoutAppearance = tabItem
        tabAppearance.compactInlineLayoutAppearance = tabItem
        UITabBar.appearance().standardAppearance = tabAppearance
        UITabBar.appearance().scrollEdgeAppearance = tabAppearance
        UITabBar.appearance().tintColor = bronzeDark
        UITabBar.appearance().unselectedItemTintColor = tabUnselected
    }
}
