import SwiftUI
import AppKit

/// 主窗口根视图
struct MainWindow: View {

    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext
    @Environment(\.openWindow) private var openWindow
    @Environment(\.dismissWindow) private var dismissWindow

    var body: some View {
        content
        .overlay(alignment: .topTrailing) {
            OpenWorkbenchButton {
                openWorkbench()
            }
            .padding(.top, 14)
            .padding(.trailing, 14)
        }
        .glassEffect(.regular, in: .rect)
        .ignoresSafeArea(.container, edges: .top)
        .frame(width: 360, height: 500)
        .background(MainWindowConfigurator())
        .onAppear {
            appState.wireEngine(context: modelContext)
        }
    }

    private var content: some View {
        GeometryReader { proxy in
            let shortestSide = min(proxy.size.width, proxy.size.height)
            let ringSize = min(max(shortestSide * 0.56, 240), 560)
            let spacing = min(max(proxy.size.height * 0.07, 32), 56)

            VStack(spacing: spacing) {
                Spacer(minLength: 8)

                TimerPanelView(
                    appState: appState,
                    ringSize: ringSize,
                    spacing: spacing
                )

                Spacer(minLength: 12)
            }
            .padding(.horizontal, 24)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
    }

    private func openWorkbench() {
        openWindow(id: "workbench")
        dismissWindow(id: "main")
        NSApp.activate(ignoringOtherApps: true)
    }
}

private struct OpenWorkbenchButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "arrow.up.left.and.arrow.down.right")
                .font(.system(size: 12, weight: .medium))
                .frame(width: 28, height: 28)
                .foregroundStyle(.tertiary)
                .background(.ultraThinMaterial, in: Circle())
        }
        .buttonStyle(.plain)
        .contentShape(Circle())
        .help("打开工作台")
    }
}

private struct MainWindowConfigurator: NSViewRepresentable {
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
        window.title = "TomatoClock"
        window.styleMask.formUnion([.titled, .closable, .miniaturizable])
        window.styleMask.insert(.fullSizeContentView)
        window.styleMask.remove(.resizable)
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isMovableByWindowBackground = true
        window.isOpaque = false
        window.backgroundColor = .clear
        window.collectionBehavior.remove(.fullScreenPrimary)
        window.minSize = NSSize(width: 360, height: 500)
        window.contentMinSize = NSSize(width: 360, height: 500)
        window.maxSize = NSSize(width: 360, height: 500)
        window.contentMaxSize = NSSize(width: 360, height: 500)
        (NSApp.delegate as? AppDelegate)?.attachMainWindow(window)
    }
}

#Preview {
    MainWindow()
        .environment(AppState())
        .modelContainer(FocusSessionStore.makeContainer())
}
