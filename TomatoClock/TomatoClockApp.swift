import SwiftUI
import SwiftData
import AppKit

@main
struct TomatoClockApp: App {

    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var appState = AppState()

    var body: some Scene {
        Window("TomatoClock", id: "main") {
            MainWindow()
                .environment(appState)
                .modelContainer(FocusSessionStore.makeContainer())
                .onAppear {
                    appDelegate.appState = appState
                    appDelegate.setupStatusBar()
                    NotificationManager.shared.requestAuthorizationIfNeeded()
                }
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 360, height: 500)
        .windowResizability(.contentSize)
        .restorationBehavior(.disabled)
        .defaultLaunchBehavior(.presented)
        .commands {
            TomatoCommands(appState: appState, appDelegate: appDelegate)
        }

        Window("工作台", id: "workbench") {
            WorkbenchWindow()
                .environment(appState)
                .modelContainer(FocusSessionStore.makeContainer())
        }
        .windowStyle(.hiddenTitleBar)
        .windowManagerRole(.principal)
        .defaultSize(width: 1180, height: 760)
        .windowResizability(.automatic)
        .restorationBehavior(.disabled)
        .defaultLaunchBehavior(.suppressed)

        // 设置面板（独立窗口）
        Settings {
            SettingsView()
                .environment(appState)
                .modelContainer(FocusSessionStore.makeContainer())
        }
    }
}
