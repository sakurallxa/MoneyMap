import SwiftUI
import SwiftData
import UniformTypeIdentifiers
import UIKit

/// 导入用 FileDocument(仅 import 路径需要,export 改走 UIActivityViewController)
struct ExportJSONDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    let data: Data
    init(data: Data) { self.data = data }
    init(configuration: ReadConfiguration) throws { self.data = Data() }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}

/// 分享(导出)目标 — 用 Identifiable 包裹 URL,触发 .sheet(item:) 弹出系统分享面板
struct ShareItem: Identifiable {
    let id = UUID()
    let url: URL
}

/// UIActivityViewController 的 SwiftUI 包装 — 比 .fileExporter 在嵌套 NavigationStack/TabView 里更可靠
struct ActivityViewController: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

struct SettingsView: View {
    @Environment(\.modelContext) private var context
    @EnvironmentObject private var biometricLock: BiometricLock
    @Query private var rates: [ExchangeRate]

    @AppStorage("userNickname") private var userNickname: String = ""
    @AppStorage("iCloudSyncEnabled") private var iCloudEnabled = false

    @State private var showImporter = false
    @State private var shareItem: ShareItem?    // 触发系统分享面板(导出 JSON / CSV 走这一路)
    @State private var importMessage: String?
    @State private var showImportMessage = false
    @State private var showNicknameEdit = false
    @State private var showWidgetTutorial = false
    @State private var showICloudRestartAlert = false      // P1:iCloud 开关切换后弹"重启生效"

    private var rateMap: [String: Double] {
        var m: [String: Double] = ["CNY": 1.0, "HKD": 0.92, "USD": 7.18]
        for r in rates { m[r.fromCurrency] = r.rate }
        return m
    }

    private var displayNickname: String {
        let trimmed = userNickname.trimmingCharacters(in: .whitespaces)
        return trimmed.isEmpty ? "钱袋用户" : trimmed
    }

    /// 提取姓氏首字(若昵称是「陈先生」则取「陈」,否则取首字)。
    private var avatarChar: String {
        let n = displayNickname
        if n == "钱袋用户" { return "钱" }
        return String(n.prefix(1))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    settingsHeaderRow
                        .padding(.horizontal, 14)
                        .padding(.top, 8)
                    profileCard
                        .padding(.horizontal, 14)

                    settingsGroup(header: "桌面 Widget") {
                        SettingsRow(
                            iconName: "rectangle.stack.fill",
                            iconColor: Theme.Palette.accent,
                            title: "添加 Widget",
                            trailing: .chevron,
                            onTap: { showWidgetTutorial = true }
                        )
                    }

                    settingsGroup(header: "安全") {
                        SettingsRow(
                            iconName: "faceid",
                            iconColor: Theme.Bronze.dark,
                            title: "Face ID 解锁",
                            subtitle: "打开后,启动钱袋或从后台回来都需验证身份",
                            // 拦截 Toggle:先走 Face ID 验证,验证通过才真正改 enabled
                            trailing: .toggle(Binding(
                                get: { biometricLock.enabled },
                                set: { newValue in
                                    biometricLock.attemptToggle(to: newValue) { _ in
                                        // 失败时 enabled 不变,SwiftUI 会自动回弹 Toggle
                                    }
                                }
                            ))
                        )
                    }

                    settingsGroup(header: "数据备份") {
                        SettingsRow(
                            iconName: "square.and.arrow.up",
                            iconColor: Theme.Bronze.dark,
                            title: "导出完整备份",
                            trailing: .value(".json"),
                            onTap: { exportJSON() }
                        )
                        Divider().opacity(0.4).padding(.leading, 56)
                        SettingsRow(
                            iconName: "tablecells",
                            iconColor: Theme.Bronze.dark,
                            title: "导出持仓为表格",
                            trailing: .value(".csv"),
                            onTap: { exportCSV() }
                        )
                        Divider().opacity(0.4).padding(.leading, 56)
                        SettingsRow(
                            iconName: "square.and.arrow.down",
                            iconColor: Theme.Bronze.dark,
                            title: "从备份恢复",
                            trailing: .value(".json"),
                            onTap: { showImporter = true }
                        )
                    }

                    // TODO(v1.1): 恢复 iCloud 同步入口。
                    // v1.0 没有走 CloudKit capability + 没在所有 @Model 上加内联默认值,
                    // 开启 toggle 后 ModelContainer(for: schema, configurations: cloudConfig)
                    // 会在 init 时抛错。为避免上架时审核员开关一拨就 crash,
                    // 这一节先隐藏。底层 @AppStorage / App.init / .onChange 都保留,
                    // v1.1 把 CloudKit capability + 模型默认值补齐后,把下面这块解开即可。
                    /*
                    settingsGroup(header: "跨设备") {
                        SettingsRow(
                            iconName: "icloud.fill",
                            iconColor: Theme.Bronze.dark,
                            title: "iCloud 同步",
                            trailing: .toggle($iCloudEnabled)
                        )
                    }
                    */

                    settingsGroup(header: "行情数据源") {
                        SettingsRow(iconName: "chart.line.uptrend.xyaxis", iconColor: Theme.Bronze.dark, title: "基金净值", trailing: .info("天天 / 蛋卷"))
                        Divider().opacity(0.4).padding(.leading, 56)
                        SettingsRow(iconName: "chart.bar.fill", iconColor: Theme.Bronze.dark, title: "A 股行情", trailing: .info("新浪财经"))
                        Divider().opacity(0.4).padding(.leading, 56)
                        SettingsRow(iconName: "globe.asia.australia.fill", iconColor: Theme.Bronze.dark, title: "港美股行情", trailing: .info("新浪 / 雅虎"))
                        Divider().opacity(0.4).padding(.leading, 56)
                        SettingsRow(iconName: "circle.hexagongrid.fill", iconColor: Theme.Bronze.dark, title: "黄金现货", trailing: .info("上海黄金交易所"))
                        Divider().opacity(0.4).padding(.leading, 56)
                        SettingsRow(iconName: "yensign.circle", iconColor: Theme.Bronze.dark, title: "汇率", trailing: .info("新浪 / 雅虎"))
                    }

                    settingsGroup(header: "关于") {
                        NavigationLink {
                            AboutView()
                        } label: {
                            HStack(spacing: 12) {
                                IconBadge(systemName: "info.circle.fill", color: Theme.Bronze.dark, size: .sm)
                                Text("关于钱袋")
                                    .font(Theme.serif(15))
                                    .foregroundStyle(.primary)
                                Spacer(minLength: 0)
                                Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.1.0")
                                    .font(Theme.serif(13))
                                    .foregroundStyle(.tertiary)
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(.tertiary)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }

                    Spacer(minLength: 80)
                }
            }
            .background(Theme.Palette.pageBgWarm.ignoresSafeArea())
            .navigationBarHidden(true)
            // P1:切换 iCloud 同步必须重启 App 才能换 SwiftData 容器
            .onChange(of: iCloudEnabled) { _, _ in
                showICloudRestartAlert = true
            }
            .alert("需要重启 App", isPresented: $showICloudRestartAlert) {
                Button("好") { showICloudRestartAlert = false }
            } message: {
                Text("iCloud 同步开关在下次启动 App 时生效。请手动退出并重新打开钱袋。")
            }
            .alert("导入结果", isPresented: $showImportMessage) {
                Button("好") { importMessage = nil }
            } message: {
                Text(importMessage ?? "")
            }
            // P1:导出走 UIActivityViewController(包装 ShareItem),比 SwiftUI .fileExporter 在
            // 嵌套 NavigationStack + TabView 里可靠得多。用户点击「另存到文件」可选择保存路径。
            .sheet(item: $shareItem) { item in
                ActivityViewController(items: [item.url])
                    .ignoresSafeArea()
            }
            .fileImporter(
                isPresented: $showImporter,
                allowedContentTypes: [.json],
                allowsMultipleSelection: false
            ) { result in
                handleImport(result)
            }
            .sheet(isPresented: $showNicknameEdit) {
                NicknameEditSheet()
            }
            .sheet(isPresented: $showWidgetTutorial) {
                WidgetTutorialSheet()
            }
        }
    }

    // MARK: - Profile

    /// 顶部「设置」大标题 — 设置页不展示金额,因此不需要隐藏余额按钮
    private var settingsHeaderRow: some View {
        PageHeader(title: "设置")
    }

    /// P1-013:摘要型副标(版本号 + 同步状态)
    /// v1.0 iCloud 入口已隐藏,这里固定显示"本地优先" — 防止旧 build
    /// UserDefaults 残留 iCloudSyncEnabled=true 导致 UI 误报"iCloud 已开启"。
    /// v1.1 恢复 iCloud 时,把下面这行改回条件分支即可:
    /// return iCloudEnabled ? "\(v) · iCloud 已开启" : "\(v) · 本地优先"
    private var settingsSubtitle: String {
        let v = "v0.1.0"
        return "\(v) · 本地优先"
    }

    private var profileCard: some View {
        Button {
            showNicknameEdit = true
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [Theme.Palette.accent, Theme.Palette.accentDark],
                                startPoint: .topLeading, endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 56, height: 56)
                    Text(avatarChar)
                        .font(Theme.serif(26, weight: .bold))
                        .foregroundStyle(.white)
                }
                Text(displayNickname)
                    .font(Theme.serif(18, weight: .bold))
                    .foregroundStyle(.primary)
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color(.secondarySystemGroupedBackground))
            )
            .cardElevation()
        }
        .buttonStyle(.plain)
    }

    // MARK: - Group helper

    @ViewBuilder
    private func settingsGroup<Content: View>(
        header: String,
        footer: String? = nil,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(header)
                .font(Theme.serif(11, weight: .bold))
                .tracking(1.2)
                .foregroundStyle(.tertiary)
                .padding(.leading, 22)
            VStack(spacing: 0) {
                content()
            }
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color(.secondarySystemGroupedBackground))
            )
            .padding(.horizontal, 14)
            .cardElevation()

            if let footer {
                Text(footer)
                    .font(Theme.serif(11))
                    .foregroundStyle(.tertiary)
                    .lineSpacing(2)
                    .padding(.horizontal, 22)
                    .padding(.top, 2)
            }
        }
    }

    // MARK: - Export / import

    private func exportJSON() {
        guard let data = DataExportService.exportJSON(from: context) else {
            ToastManager.shared.error("导出失败", subtitle: "无数据可导出")
            return
        }
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("moneymap-backup-\(filenameDate()).json")
        do {
            try data.write(to: url, options: .atomic)
            shareItem = ShareItem(url: url)
        } catch {
            ToastManager.shared.error("导出失败", subtitle: error.localizedDescription)
        }
    }

    private func exportCSV() {
        guard let data = DataExportService.exportPositionsCSV(from: context, rates: rateMap) else {
            ToastManager.shared.error("导出失败", subtitle: "无持仓可导出")
            return
        }
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("moneymap-positions-\(filenameDate()).csv")
        do {
            try data.write(to: url, options: .atomic)
            shareItem = ShareItem(url: url)
        } catch {
            ToastManager.shared.error("导出失败", subtitle: error.localizedDescription)
        }
    }

    private func filenameDate() -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyyMMdd-HHmm"
        return f.string(from: Date())
    }

    private func handleImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            let didStart = url.startAccessingSecurityScopedResource()
            defer { if didStart { url.stopAccessingSecurityScopedResource() } }
            do {
                let data = try Data(contentsOf: url)
                try DataImportService.importJSON(data: data, context: context, replace: true)
                ToastManager.shared.success("导入成功 · 数据已恢复")
            } catch let importError as DataImportError {
                ToastManager.shared.error("导入失败", subtitle: importError.errorDescription)
            } catch {
                ToastManager.shared.error("导入失败", subtitle: error.localizedDescription)
            }
        case .failure(let err):
            ToastManager.shared.error("选择文件失败", subtitle: err.localizedDescription)
        }
    }
}

// MARK: - Row

private struct SettingsRow: View {
    enum Trailing {
        case toggle(Binding<Bool>)
        case value(String)
        case info(String)
        case chevron
    }

    let iconName: String
    let iconColor: Color
    let title: String
    var subtitle: String? = nil
    var trailing: Trailing = .chevron
    var onTap: (() -> Void)? = nil

    var body: some View {
        let content = HStack(spacing: 12) {
            IconBadge(systemName: iconName, color: iconColor, size: .sm)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(Theme.serif(15))
                    .foregroundStyle(.primary)
                if let subtitle {
                    Text(subtitle)
                        .font(Theme.serif(11))
                        .foregroundStyle(.tertiary)
                }
            }
            Spacer(minLength: 0)
            trailingView
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .contentShape(Rectangle())

        if case .toggle = trailing {
            content
        } else if let onTap {
            Button(action: onTap) { content }
                .buttonStyle(.plain)
        } else {
            content
        }
    }

    @ViewBuilder
    private var trailingView: some View {
        switch trailing {
        case .toggle(let binding):
            Toggle("", isOn: binding)
                .labelsHidden()
                .tint(Theme.Palette.accent)
        case .value(let text):
            HStack(spacing: 4) {
                Text(text)
                    .font(Theme.serif(13))
                    .foregroundStyle(.secondary)
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.tertiary)
            }
        case .info(let text):
            Text(text)
                .font(Theme.serif(13))
                .foregroundStyle(.secondary)
        case .chevron:
            Image(systemName: "chevron.right")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.tertiary)
        }
    }
}

#Preview {
    SettingsView()
        .modelContainer(for: [Account.self, Position.self, TransactionRecord.self, DailySnapshot.self, DCAPlan.self, Asset.self, PriceQuote.self, ExchangeRate.self], inMemory: true)
}
