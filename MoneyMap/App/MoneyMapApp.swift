import SwiftUI
import SwiftData

@main
struct MoneyMapApp: App {
    let container: ModelContainer

    init() {
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

        // Try CloudKit-enabled storage first. Falls back to local-only when
        // iCloud entitlements aren't provisioned (e.g. free dev account).
        let resolved: ModelContainer
        do {
            let cloudConfig = ModelConfiguration("MoneyMap", schema: schema, cloudKitDatabase: .automatic)
            resolved = try ModelContainer(for: schema, configurations: cloudConfig)
        } catch {
            do {
                let localConfig = ModelConfiguration("MoneyMap", schema: schema)
                resolved = try ModelContainer(for: schema, configurations: localConfig)
            } catch {
                fatalError("Failed to initialize SwiftData container: \(error)")
            }
        }
        container = resolved

        let context = ModelContext(container)
        DemoDataSeeder.seedIfNeeded(context: context)
        DCAService.processAll(context: context)
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.locale, Locale(identifier: "zh_CN"))
                .task {
                    let context = container.mainContext
                    DCAService.processAll(context: context)
                    await PriceRefreshService.refreshAll(context: context)
                    WidgetState.push(context: context)
                }
        }
        .modelContainer(container)
    }
}
