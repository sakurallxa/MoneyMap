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

    @State private var showImporter = false
    @State private var showJSONExporter = false
    @State private var showCSVExporter = false
    @State private var jsonDoc: ExportJSONDocument?
    @State private var csvDoc: ExportCSVDocument?
    @State private var importMessage: String?
    @State private var showImportMessage = false
    @AppStorage("iCloudSyncEnabled") private var iCloudEnabled = false

    private var rateMap: [String: Double] {
        var m: [String: Double] = ["CNY": 1.0, "HKD": 0.92, "USD": 7.18]
        for r in rates { m[r.fromCurrency] = r.rate }
        return m
    }

    var body: some View {
        NavigationStack {
            List {
                Section("数据备份") {
                    Button {
                        if let data = DataExportService.exportJSON(from: context) {
                            jsonDoc = ExportJSONDocument(data: data)
                            showJSONExporter = true
                        }
                    } label: {
                        settingsRow(icon: "square.and.arrow.up", title: "导出完整备份", value: ".json")
                    }
                    Button {
                        if let data = DataExportService.exportPositionsCSV(from: context, rates: rateMap) {
                            csvDoc = ExportCSVDocument(data: data)
                            showCSVExporter = true
                        }
                    } label: {
                        settingsRow(icon: "tablecells", title: "导出持仓为表格", value: ".csv")
                    }
                    Button {
                        showImporter = true
                    } label: {
                        settingsRow(icon: "square.and.arrow.down", title: "从备份恢复", value: ".json")
                    }
                }

                Section {
                    Toggle(isOn: $iCloudEnabled) {
                        HStack {
                            Image(systemName: "icloud")
                                .frame(width: 24)
                                .foregroundStyle(.accent)
                            Text("iCloud 同步")
                        }
                    }
                } header: {
                    Text("跨设备")
                } footer: {
                    Text("开启后,换 iPhone 时数据自动同步。需要先在 Xcode 里启用 iCloud capability 才能生效;否则数据继续保存在本地。")
                }

                Section("行情数据源") {
                    infoRow(icon: "chart.line.uptrend.xyaxis", title: "基金净值", value: "天天基金")
                    infoRow(icon: "chart.bar.fill", title: "A 股行情", value: "新浪 / 东方财富")
                    infoRow(icon: "globe.asia.australia.fill", title: "港美股行情", value: "雅虎财经")
                    infoRow(icon: "circle.hexagongrid.fill", title: "黄金现货", value: "上海黄金交易所")
                    infoRow(icon: "yensign.circle", title: "汇率", value: "雅虎财经")
                }

                Section("关于") {
                    infoRow(icon: "info.circle.fill", title: "版本", value: "0.1.0")
                }
            }
            .navigationTitle("我的")
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
        }
    }

    @ViewBuilder
    private func settingsRow(icon: String, title: String, value: String) -> some View {
        HStack {
            Image(systemName: icon)
                .frame(width: 24)
                .foregroundStyle(.accent)
            Text(title)
                .foregroundStyle(.primary)
            Spacer()
            if !value.isEmpty {
                Text(value)
                    .foregroundStyle(.secondary)
                    .font(.subheadline)
            }
            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
    }

    /// 纯展示型行,无右侧 chevron。
    @ViewBuilder
    private func infoRow(icon: String, title: String, value: String) -> some View {
        HStack {
            Image(systemName: icon)
                .frame(width: 24)
                .foregroundStyle(.accent)
            Text(title)
                .foregroundStyle(.primary)
            Spacer()
            if !value.isEmpty {
                Text(value)
                    .foregroundStyle(.secondary)
                    .font(.subheadline)
            }
        }
    }

    private func filenameDate() -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyyMMdd-HHmm"
        return f.string(from: Date())
    }

    private func handleExportResult(_ result: Result<URL, Error>, type: String) {
        switch result {
        case .success: importMessage = "\(type)已保存"
        case .failure(let err): importMessage = "导出失败:\(err.localizedDescription)"
        }
        showImportMessage = true
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
                importMessage = "导入成功,数据已恢复"
            } catch let importError as DataImportError {
                importMessage = importError.errorDescription
            } catch {
                importMessage = "导入失败:\(error.localizedDescription)"
            }
        case .failure(let err):
            importMessage = "选择文件失败:\(err.localizedDescription)"
        }
        showImportMessage = true
    }

}

#Preview {
    SettingsView()
        .modelContainer(for: [Account.self, Position.self, TransactionRecord.self, DailySnapshot.self, DCAPlan.self, Asset.self, PriceQuote.self, ExchangeRate.self], inMemory: true)
}
