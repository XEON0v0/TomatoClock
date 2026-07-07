import Foundation
import UserNotifications

/// 通知管理：申请权限、发送阶段切换通知
final class NotificationManager: NSObject, @unchecked Sendable {

    static let shared = NotificationManager()

    private let center = UNUserNotificationCenter.current()

    private override init() {
        super.init()
    }

    /// 申请通知权限（仅在用户启用通知时调用）
    func requestAuthorizationIfNeeded() {
        center.getNotificationSettings { [weak self] settings in
            guard settings.authorizationStatus == .notDetermined else { return }
            self?.center.requestAuthorization(options: [.alert, .sound]) { _, _ in }
        }
    }

    /// 发送一条阶段切换通知
    /// - Parameters:
    ///   - newPhase: 即将进入的阶段
    ///   - round: 当前轮次
    func sendPhaseNotification(newPhase: TimerPhase, round: Int) {
        let title: String
        let body: String

        switch newPhase {
        case .focus:
            title = round == 1 ? "开始第 1 轮专注" : "开始第 \(round) 轮专注"
            body = "休息结束，重新进入专注"
        case .shortBreak:
            title = "短休息时间到"
            body = "上一轮专注已完成"
        case .longBreak:
            title = "长休息时间到"
            body = "已完成 4 轮专注，好好放松一下"
        }

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 0.2, repeats: false)
        let request = UNNotificationRequest(
            identifier: "phase-\(newPhase.rawValue)-\(UUID().uuidString)",
            content: content,
            trigger: trigger
        )

        center.add(request, withCompletionHandler: nil)
    }
}
