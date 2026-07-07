import SwiftUI
import SwiftData
import AppKit

struct PlanImportSheet: View {
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let session: PlanImportSessionController
    let plans: [WorkPlan]

    @State private var timer = Timer.publish(every: 1.5, on: .main, in: .common).autoconnect()
    @State private var commitError: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(session.overwritePlanID == nil ? "导入计划" : "覆盖当前计划")
                        .font(.system(size: 24, weight: .semibold))
                    Text(statusText)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button {
                    session.refresh()
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .frame(width: 30, height: 30)
                }
                .buttonStyle(.plain)
            }

            TextEditor(text: .constant(session.configurationSnippet))
                .font(.system(.caption, design: .monospaced))
                .frame(height: 150)
                .scrollContentBackground(.hidden)
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8))
                .overlay(alignment: .topTrailing) {
                    Button("复制") {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(session.configurationSnippet, forType: .string)
                    }
                    .padding(8)
                }

            if let summary = session.document.summary {
                preview(summary)
            } else {
                ContentUnavailableView(
                    "等待计划",
                    systemImage: "tray.and.arrow.down",
                    description: Text("启动上面的 MCP helper 后，让 agent 调用 import_plan。")
                )
            }

            if let error = session.errorMessage ?? commitError {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            Spacer()

            HStack {
                Button("取消") {
                    session.cancel()
                    appState.importSession = nil
                    dismiss()
                }
                Spacer()
                Button("继续等待") {
                    session.refresh()
                }
                Button("确认导入完成") {
                    do {
                        try appState.commitImport(from: session, context: modelContext, plans: plans)
                        dismiss()
                    } catch {
                        commitError = error.localizedDescription
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(session.document.stagedPlan == nil)
            }
        }
        .padding(24)
        .onReceive(timer) { _ in
            session.refresh()
        }
        .onDisappear {
            timer.upstream.connect().cancel()
            if session.document.state == .waiting || session.document.state == .received {
                session.cancel()
            }
        }
    }

    private var statusText: String {
        switch session.document.state {
        case .waiting:
            "等待 agent 写入计划"
        case .received:
            "已收到计划，可以继续等待替换或确认导入"
        case .committed:
            "导入已提交"
        case .cancelled:
            "导入已取消"
        case .expired:
            "导入已过期"
        }
    }

    private func preview(_ summary: PlanImportSummary) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(summary.title)
                .font(.headline)
            Text("\(summary.sectionCount) 个分区 · \(summary.itemCount) 项任务")
                .font(.caption)
                .foregroundStyle(.secondary)
            ForEach(summary.previewItems, id: \.self) { item in
                Label(item, systemImage: "checkmark.circle")
                    .font(.callout)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8))
    }
}
