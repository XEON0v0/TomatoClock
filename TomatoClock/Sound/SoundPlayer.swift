import Foundation
import AVFoundation
#if canImport(AppKit)
import AppKit
#endif

/// 钟声音效播放器
///
/// 优先从 Bundle 加载 `bell.caf`；若找不到则回退到系统自带柔和音效。
final class SoundPlayer: @unchecked Sendable {

    static let shared = SoundPlayer()

    private var player: AVAudioPlayer?

    private init() {}

    /// 播放一次阶段结束钟声
    func playBell() {
        // 优先使用 bundle 中的 bell 资源
        if let url = bundleBellURL() {
            play(url: url)
            return
        }
        // 回退：系统自带柔和音效
        #if canImport(AppKit)
        NSSound(named: "Glass")?.play()
        #endif
    }

    private func bundleBellURL() -> URL? {
        Bundle.main.url(forResource: "bell", withExtension: "caf")
            ?? Bundle.main.url(forResource: "bell", withExtension: "aiff")
            ?? Bundle.main.url(forResource: "bell", withExtension: "mp3")
    }

    private func play(url: URL) {
        do {
            let p = try AVAudioPlayer(contentsOf: url)
            p.volume = 0.7
            p.prepareToPlay()
            p.play()
            self.player = p
        } catch {
            #if canImport(AppKit)
            NSSound(named: "Glass")?.play()
            #endif
        }
    }
}
