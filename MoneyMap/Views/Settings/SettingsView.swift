import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct ExportJSONDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    let data: Data

    init(data: Data) { self.data = data }
    init(configuration: ReadConfiguration) throws { self.data = Data() }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}

struct ExportCSVDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.commaSeparatedText] }
    let data: Data

    init(data: Data) { self.data = data }
    init(configuration: ReadConfiguration) throws { self.data = Data() }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}

struct SettingsView: View {
    @Environment(\.modelContext) private var context
    @Query private var rates: [ExchangeRate]

    @AppStorage("userNickname") private var userNickname: String = ""
    @AppStorage("hideBalance") private var hideBalance: Bool = false
    @AppStorage("iCloudSyncEnabled") private var iCloudEnabled = false

    @State private var showImporter = false
    @State private var showJSONExporter = false
    @State private var showCSVExporter = false
    @State private var jsonDoc: ExportJSONDocument?
    @State private var csvDoc: ExportCSVDocument?
    @State private var importMessage: String?
    @State private var showImportMessage = false
    @State private var showNicknameEdit = false
    @State private var showWidgetTutorial = false

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
                    profileCard
                        .padding(.horizontal, 14)
                        .padding(.top, 8)

                    settingsGroup(header: "显示与提醒") {
                        SettingsRow(
                            iconName: "eye.slash.fill",
                            iconColor: Color(hex: "#5B8FF9"),
                            title: "默认隐藏余额",
                            trailing: .toggle($hideBalance)
                        )
                    }

                    settingsGroup(header: "桌面 Widget") {
                        SettingsRow(
                            iconName: "rectangle.stack.fill",
                            iconColor: Theme.Palette.accent,
                            title: "添加资产 Widget",
                            subtitle: "在桌面长按 · 一眼看总资产",
                            trailing: .chevron,
                            onTap: { showWidgetTutorial = true }
                        )
                    }

                    settingsGroup(header: "数据备份") {
                        SettingsRow(
                            iconName: "square.and.arrow.up",
                            iconColor: Color(hex: "#34C759"),
                            title: "导出完整备份",
                            trailing: .value(".json"),
                            onTap: { exportJSON() }
                        )
                        Divider().opacity(0.4).padding(.leading, 56)
                        SettingsRow(
                            iconName: "tablecells",
                            iconColor: Color(hex: "#FF9500"),
                            title: "导出持仓为表格",
                            trailing: .value(".csv"),
                            onTap: { exportCSV() }
                        )
                        Divider().opacity(0.4).padding(.leading, 56)
                        SettingsRow(
                            iconName: "square.and.arrow.down",
                            iconColor: Color(hex: "#7B68EE"),
                            title: "从备份恢复",
                            trailing: .value(".json"),
                            onTap: { showImporter = true }
                        )
                    }

                    settingsGroup(header: "跨设备", footer: "开启后,换 iPhone 时数据自动同步。需要先在 Xcode 里启用 iCloud capability 才能生效;否则数据继续保存在本地。") {
                        SettingsRow(
                            iconName: "icloud.fill",
                            iconColor: Color(hex: "#5B8FF9"),
                            title: "iCloud 同步",
                            trailing: .toggle($iCloudEnabled)
                        )
                    }

                    settingsGroup(header: "行情数据源") {
                        SettingsRow(iconName: "chart.line.uptrend.xyaxis", iconColor: Color(hex: "#F4B860"), title: "基金净值", trailing: .info("天天基金"))
                        Divider().opacity(0.4).padding(.leading, 56)
                        SettingsRow(iconName: "chart.bar.fill", iconColor: Color.pnlNegative, title: "A 股行情", trailing: .info("新浪 / 东方财富"))
                        Divider().opacity(0.4).padding(.leading, 56)
                        SettingsRow(iconName: "globe.asia.australia.fill", iconColor: Color(hex: "#1ABC9C"), title: "港美股行情", trailing: .info("雅虎财经"))
                        Divider().opacity(0.4).padding(.leading, 56)
                        SettingsRow(iconName: "circle.hexagongrid.fill", iconColor: Color(hex: "#D4AF37"), title: "黄金现货", trailing: .info("上海黄金交易所"))
                        Divider().opacity(0.4).padding(.leading, 56)
                        SettingsRow(iconName: "yensign.circle", iconColor: Color(hex: "#5B8FF9"), title: "汇率", trailing: .info("雅虎财经"))
                    }

                    settingsGroup(header: "关于") {
                        SettingsRow(iconName: "info.circle.fill", iconColor: .secondary, title: "版本", trailing: .info("0.1.0"))
                    }

                    Spacer(minLength: 80)
                }
            }
            .background(Theme.Palette.pageBgWarm.ignoresSafeArea())
            .navigationTitle("设置")
            .navigationBarTitleDisplayMode(.large)
            .alert("导入结果", isPresented: $showImportMessage) {
                Button("好") { importMessage = nil }
            } message: {
                Text(importMessage ?? "")
            }
            .fileExporter(
                isPresented: $showJSONExporter,
                document: jsonDoc,
                contentType: .json,
                defaultFilename: "moneymap-backup-\(filenameDate()).json"
            ) { result in
                handleExportResult(result, type: "备份")
            }
            .fileExporter(
                isPresented: $showCSVExporter,
                document: csvDoc,
                contentType: .commaSeparatedText,
                defaultFilename: "moneymap-positions-\(filenameDate()).csv"
            ) { result in
                handleExportResult(result, type: "持仓表格")
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
                        .font(.system(size: 26, weight: .bold))
                        .foregroundStyle(.white)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text(displayNickname)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(.primary)
                    Text("跟随系统外观 · 红涨绿跌")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
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
                .font(.system(size: 11, weight: .bold))
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
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
                    .lineSpacing(2)
                    .padding(.horizontal, 22)
                    .padding(.top, 2)
            }
        }
    }

    // MARK: - Export / import

    private func exportJSON() {
        if let data = DataExportService.exportJSON(from: context) {
            jsonDoc = ExportJSONDocument(data: data)
            showJSONExporter = true
        }
    }

    private func exportCSV() {
        if let data = DataExportService.exportPositionsCSV(from: context, rates: rateMap) {
            csvDoc = ExportCSVDocument(data: data)
            showCSVExporter = true
        }
    }

    private func filenameDate() -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyyMMdd-HHmm"
        return f.string(from: Date())
    }

    private func handleExportResult(_ result: Result<URL, Error>, type: String) {
        switch result {
        case .success:
            ToastManager.shared.success("\(type)已保存")
        case .failure(let err):
            ToastManager.shared.error("导出失败", subtitle: err.localizedDescription)
        }
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
            Image(systemName: iconName)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(iconColor)
                .frame(width: 30, height: 30)
                .background(
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .fill(iconColor.opacity(0.14))
                )
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 15))
                    .foregroundStyle(.primary)
                if let subtitle {
                    Text(subtitle)
                        .font(.system(size: 11))
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
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.tertiary)
            }
        case .info(let text):
            Text(text)
                .font(.system(size: 13))
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
