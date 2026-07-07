import SwiftUI
import SwiftData
import AppKit

struct WorkbenchWindow: View {
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext
    @Environment(\.openWindow) private var openWindow
    @Environment(\.dismissWindow) private var dismissWindow
    @Query(sort: \WorkPlan.updatedAt, order: .reverse) private var plans: [WorkPlan]

    var body: some View {
        GeometryReader { proxy in
            let isNarrow = proxy.size.width < 920
            Group {
                if isNarrow {
                    VStack(spacing: 0) {
                        PlanPanelView(plans: plans)
                            .frame(minHeight: 420)
                        Divider()
                        timerPanel
                            .frame(minHeight: 420)
                    }
                } else {
                    HStack(spacing: 0) {
                        PlanPanelView(plans: plans)
                            .frame(minWidth: 420, idealWidth: proxy.size.width * 0.45, maxWidth: proxy.size.width * 0.48)
                        Divider()
                        timerPanel
                            .frame(minWidth: 460, maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
            }
            .overlay(alignment: .topTrailing) {
                ReturnToMainWindowButton {
                    openWindow(id: "main")
                    dismissWindow(id: "workbench")
                    NSApp.activate(ignoringOtherApps: true)
                }
                    .padding(14)
            }
        }
        .glassEffect(.regular, in: .rect)
        .ignoresSafeArea(.container, edges: .top)
        .background(WorkbenchWindowConfigurator())
        .onAppear {
            appState.wireEngine(context: modelContext)
            appState.ensureActivePlan(in: plans)
        }
        .onChange(of: plans.map(\.id)) {
            appState.ensureActivePlan(in: plans)
        }
        .sheet(item: importSessionBinding) { session in
            PlanImportSheet(session: session, plans: plans)
                .frame(minWidth: 560, minHeight: 560)
        }
    }

    private var timerPanel: some View {
        GeometryReader { proxy in
            let ringSize = min(max(min(proxy.size.width, proxy.size.height) * 0.56, 300), 520)
            VStack {
                Spacer(minLength: 28)
                TimerPanelView(appState: appState, ringSize: ringSize, spacing: 34)
                Spacer(minLength: 28)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var importSessionBinding: Binding<PlanImportSessionController?> {
        Binding(
            get: { appState.importSession },
            set: { appState.importSession = $0 }
        )
    }
}

private struct ReturnToMainWindowButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "arrow.down.right.and.arrow.up.left")
                .font(.system(size: 13, weight: .medium))
                .frame(width: 30, height: 30)
                .foregroundStyle(.secondary)
                .background(.thinMaterial, in: Circle())
        }
        .buttonStyle(.plain)
        .help("返回主窗口")
    }
}

private struct WorkbenchWindowConfigurator: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView(frame: .zero)
        DispatchQueue.main.async {
            configure(window: view.window)
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            configure(window: nsView.window)
        }
    }

    private func configure(window: NSWindow?) {
        guard let window else { return }
        window.styleMask.formUnion([.titled, .closable, .miniaturizable, .resizable])
        window.styleMask.insert(.fullSizeContentView)
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isMovableByWindowBackground = true
        window.isOpaque = false
        window.backgroundColor = .clear
        configureFullScreenBehavior(for: window)
        window.minSize = NSSize(width: 880, height: 620)
        window.contentMinSize = NSSize(width: 880, height: 620)
        window.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        window.contentMaxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        DispatchQueue.main.async {
            configureFullScreenBehavior(for: window)
        }
        if let fullScreenButton = window.standardWindowButton(.zoomButton) {
            fullScreenButton.isEnabled = true
            fullScreenButton.target = window
            fullScreenButton.action = #selector(NSWindow.toggleFullScreen(_:))
        }
        (NSApp.delegate as? AppDelegate)?.attachWorkbenchWindow(window)
    }

    private func configureFullScreenBehavior(for window: NSWindow) {
        window.collectionBehavior.remove([.auxiliary, .fullScreenAuxiliary, .fullScreenNone])
        window.collectionBehavior.insert([.primary, .fullScreenPrimary])
        if let fullScreenButton = window.standardWindowButton(.zoomButton) {
            fullScreenButton.isEnabled = true
            fullScreenButton.target = window
            fullScreenButton.action = #selector(NSWindow.toggleFullScreen(_:))
        }
    }
}

extension PlanImportSessionController: Identifiable {
    var id: UUID { document.id }
}
