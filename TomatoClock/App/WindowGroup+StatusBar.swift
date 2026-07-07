import SwiftUI
import AppKit

// MARK: - AppDelegate（菜单栏常驻 + 关闭窗口不退出）

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, ObservableObject {

    weak var appState: AppState?

    private var statusItem: NSStatusItem?
    private var statusHostingView: NSHostingView<AnyView>?

    /// 窗口引用（切换时仅 orderOut，不释放）
    private var mainWindow: NSWindow?
    private var workbenchWindow: NSWindow?

    private var menuTimer: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupStatusBar()
    }

    /// 关闭最后一个窗口后不退出应用（转为菜单栏常驻）
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }

    // MARK: Window switching

    func attachMainWindow(_ window: NSWindow) {
        window.title = "TomatoClock"
        configureMainWindowBehavior(window)
        window.delegate = self
        window.isReleasedWhenClosed = false
        mainWindow = window
    }

    private func configureMainWindowBehavior(_ window: NSWindow) {
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
    }

    func attachWorkbenchWindow(_ window: NSWindow) {
        window.title = "工作台"
        configureWorkbenchWindowBehavior(window)
        window.delegate = self
        window.isReleasedWhenClosed = false
        workbenchWindow = window
        DispatchQueue.main.async { [weak self, weak window] in
            guard let window else { return }
            self?.configureWorkbenchWindowBehavior(window)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self, weak window] in
            guard let window else { return }
            self?.configureWorkbenchWindowBehavior(window)
        }
    }

    private func configureWorkbenchWindowBehavior(_ window: NSWindow) {
        window.styleMask.formUnion([.titled, .closable, .miniaturizable, .resizable])
        window.styleMask.insert(.fullSizeContentView)
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isMovableByWindowBackground = true
        window.isOpaque = false
        window.backgroundColor = .clear
        window.collectionBehavior.remove([.auxiliary, .fullScreenAuxiliary, .fullScreenNone])
        window.collectionBehavior.insert([.primary, .fullScreenPrimary])
        window.minSize = NSSize(width: 880, height: 620)
        window.contentMinSize = NSSize(width: 880, height: 620)
        window.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        window.contentMaxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        if let fullScreenButton = window.standardWindowButton(.zoomButton) {
            fullScreenButton.isEnabled = true
            fullScreenButton.target = window
            fullScreenButton.action = #selector(NSWindow.toggleFullScreen(_:))
        }
    }

    // MARK: Status bar

    func setupStatusBar() {
        guard statusItem == nil else { return }
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem = item

        guard let button = item.button else { return }

        let hostingView = NSHostingView(rootView: AnyView(statusBarContent))
        hostingView.translatesAutoresizingMaskIntoConstraints = false
        button.subviews.forEach { $0.removeFromSuperview() }
        button.addSubview(hostingView)

        NSLayoutConstraint.activate([
            hostingView.leadingAnchor.constraint(equalTo: button.leadingAnchor, constant: 2),
            hostingView.trailingAnchor.constraint(equalTo: button.trailingAnchor, constant: -2),
            hostingView.topAnchor.constraint(equalTo: button.topAnchor, constant: 2),
            hostingView.bottomAnchor.constraint(equalTo: button.bottomAnchor, constant: -2),
        ])

        statusHostingView = hostingView

        button.action = #selector(statusItemClicked(_:))
        button.target = self
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])

        // 周期性刷新菜单栏小图标
        menuTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refreshStatusView() }
        }
    }

    private var statusBarContent: some View {
        guard let engine = appState?.engine else {
            return AnyView(EmptyView())
        }
        return AnyView(
            StatusBarView(
                phase: engine.phase,
                remaining: engine.remaining,
                totalDuration: engine.totalDuration,
                isRunning: engine.isRunning
            )
        )
    }

    private func refreshStatusView() {
        statusHostingView?.rootView = AnyView(statusBarContent)
    }

    @objc private func statusItemClicked(_ sender: Any?) {
        guard let event = NSApp.currentEvent else { return }
        if event.clickCount >= 2 {
            openMainWindow()
        } else {
            showMenu()
        }
    }

    private func showMenu() {
        guard let item = statusItem, let engine = appState?.engine else { return }

        let menu = NSMenu()
        menu.autoenablesItems = false

        let titleItem = NSMenuItem(title: "🍅 TomatoClock", action: nil, keyEquivalent: "")
        titleItem.isEnabled = false
        menu.addItem(titleItem)
        menu.addItem(.separator())

        let stateText = "\(engine.phase.theme.localizedName) · 第\(engine.currentRound)轮 · \(engine.remainingText)"
        let stateItem = NSMenuItem(title: stateText, action: nil, keyEquivalent: "")
        stateItem.isEnabled = false
        menu.addItem(stateItem)
        menu.addItem(.separator())

        let toggleItem = NSMenuItem(
            title: engine.isRunning ? "暂停" : "开始",
            action: #selector(menuToggle),
            keyEquivalent: "r"
        )
        toggleItem.target = self
        menu.addItem(toggleItem)

        let skipItem = NSMenuItem(title: "跳过", action: #selector(menuSkip), keyEquivalent: "n")
        skipItem.keyEquivalentModifierMask = [.command, .shift]
        skipItem.target = self
        menu.addItem(skipItem)

        let resetItem = NSMenuItem(title: "重置", action: #selector(menuReset), keyEquivalent: "r")
        resetItem.keyEquivalentModifierMask = [.command, .shift]
        resetItem.target = self
        menu.addItem(resetItem)

        menu.addItem(.separator())

        let openItem = NSMenuItem(title: "打开主窗口", action: #selector(openMainWindow), keyEquivalent: "o")
        openItem.target = self
        menu.addItem(openItem)

        if let appState = appState {
            let todayItem = NSMenuItem(title: "今日: \(appState.todayCompleted) / \(appState.dailyGoal)", action: nil, keyEquivalent: "")
            todayItem.isEnabled = false
            menu.addItem(todayItem)
        }

        menu.addItem(.separator())

        let settingsItem = NSMenuItem(title: "设置...", action: #selector(openSettings), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)

        let quitItem = NSMenuItem(title: "退出 TomatoClock", action: #selector(menuQuit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        item.menu = menu
        item.button?.performClick(nil)
    }

    // MARK: Menu actions

    @objc private func menuToggle() {
        guard let engine = appState?.engine else { return }
        engine.isRunning ? engine.pause() : engine.start()
    }

    @objc private func menuSkip() {
        appState?.engine.skip()
    }

    @objc private func menuReset() {
        appState?.engine.reset()
    }

    @objc func openMainWindow() {
        NSApp.activate(ignoringOtherApps: true)
        if let window = mainWindow, window.title == "TomatoClock" {
            window.makeKeyAndOrderFront(nil)
        } else if let window = NSApp.windows.first(where: { $0.title == "TomatoClock" && !($0 === workbenchWindow) }) {
            mainWindow = window
            window.makeKeyAndOrderFront(nil)
        }
    }

    @objc func openSettings() {
        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func menuQuit() {
        NSApp.terminate(nil)
    }
}

// MARK: - NSWindowDelegate（拦截关闭：仅 orderOut 不退出）

extension AppDelegate: NSWindowDelegate {
    func windowDidBecomeKey(_ notification: Notification) {
        guard let window = notification.object as? NSWindow, window === workbenchWindow else {
            return
        }
        configureWorkbenchWindowBehavior(window)
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        // 拦截关闭按钮：仅隐藏窗口，不真正关闭
        sender.orderOut(nil)
        return false
    }
}

// MARK: - Commands（菜单栏菜单项 / 快捷键）

struct TomatoCommands: Commands {
    @Environment(\.openWindow) private var openWindow

    weak var appState: AppState?
    weak var appDelegate: AppDelegate?

    var body: some Commands {
        CommandGroup(replacing: .newItem) {
            Button("开始 / 暂停") {
                guard let e = appState?.engine else { return }
                e.isRunning ? e.pause() : e.start()
            }
            .keyboardShortcut("r", modifiers: .command)

            Button("跳过阶段") {
                appState?.engine.skip()
            }
            .keyboardShortcut("n", modifiers: [.command, .shift])

            Button("重置阶段") {
                appState?.engine.reset()
            }
            .keyboardShortcut("r", modifiers: [.command, .shift])

            Divider()

            Button("打开主窗口") {
                appDelegate?.openMainWindow()
            }
            .keyboardShortcut("o", modifiers: .command)

            Button("打开工作台") {
                openWindow(id: "workbench")
                NSApp.activate(ignoringOtherApps: true)
            }
            .keyboardShortcut("f", modifiers: [.command, .shift])
        }
    }
}
