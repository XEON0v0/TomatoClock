# TomatoClock 设计计划

> macOS 26 原生流体玻璃风格番茄钟应用
> 创建日期：2026-07-06

---

## 1. 项目概览

**TomatoClock** 是一个运行于 macOS 26 的原生番茄钟应用。它采用 SwiftUI 新增的 Liquid Glass 材质 API，呈现简约精美的视觉效果；通过经典 25/5/15 番茄工作法帮助用户保持专注，并提供菜单栏常驻、原生通知、7 天统计等完整体验。

### 1.1 核心目标

- **视觉**：充分利用 macOS 26 Liquid Glass 材质，让玻璃折射出淡淡的阶段色，简约而不单调
- **专注**：去除一切非必要干扰，单窗口、三按钮、一圆环
- **原生**：纯 SwiftUI 为主，必要时兑 AppKit；不引入任何 Web/Electron 套壳

### 1.2 非目标

- 不支持任务标签 / 任务列表
- 不支持手动加减时长
- 不兼容 macOS 25 及更早版本
- 不提供云同步

---

## 2. 技术栈

| 项 | 选择 |
|---|---|
| 语言 | Swift 6 |
| UI 框架 | SwiftUI（必要时 `NSViewRepresentable` / `NSStatusItem` / `NSWindow` 兜底） |
| 最低部署目标 | macOS 26.0 |
| 数据持久化 | SwiftData |
| 通知 | `UserNotifications` 框架 |
| 音效 | `AVFoundation`（轻柔钟声） |
| 计时驱动 | `TimelineView` + 基于 `Date` 的 remaining seconds 计算（避免后台/睡眠漂移） |
| 应用名 / Bundle | TomatoClock |
| Bundle ID | `com.ray.tomatoclock`（待定） |

---

## 3. 计时模型

### 3.1 阶段定义

| 阶段 | 时长 | 颜色 |
|---|---|---|
| 专注（Focus） | 25 分钟 | 珊瑚红 `#FF6B6B` |
| 短休息（Short Break） | 5 分钟 | 薄荷绿 `#4ECDC4` |
| 长休息（Long Break） | 15 分钟 | 天空蓝 `#6BB6FF` |

### 3.2 循环规则

```
专注 → 短休息 → 专注 → 短休息 → 专注 → 短休息 → 专注 → 长休息
        └─────────── 每 4 轮专注触发 1 次长休息 ───────────┘
```

- **自动衔接**：阶段结束后立即进入下一阶段，无需用户点击
- 跳过按钮直接进入下一阶段；重置按钮回到当前阶段起点
- 长休息结束后回到第 1 轮专注

### 3.3 计时实现

- 不用 `Timer.publish` 累加秒数（会因睡眠/后台漂移）
- 而是记录 `endDate: Date`，每帧用 `endDate - now` 计算 remaining
- 暂停时记录 `remainingAtPause`，恢复时重算 `endDate = now + remainingAtPause`
- `TimelineView(.animation)` 驱动 UI 刷新，每帧 60fps 平滑进度环

---

## 4. 窗口与外观

### 4.1 主窗口

- 尺寸：约 360 × 500 pt，固定不可缩放（保持精致感）
- 隐藏标题栏，保留交通灯（可拖动 / 关闭 / 最小化）
- 玻璃材质：`Glass.regular`（薄玻璃）
- 玻璃通过 `.glassEffect(.regular, in: .rect)` 应用于整个内容视图背景

### 4.2 背景层叠

```
┌─────────────────────────────────┐
│  ① 阶段色径向渐变色晕（透明度 ~15-20%）│
│     中心亮、边缘透明，随阶段切换平滑过渡│
├─────────────────────────────────┤
│  ② Glass.regular 玻璃材质           │
│     折射出色晕的淡淡阶段色 + 桌面背景  │
├─────────────────────────────────┤
│  ③ 倒计时圆环 + 中心文字 + 控制按钮   │
└─────────────────────────────────┘
```

- 色晕使用 `RadialGradient`，颜色为当前阶段色
- 阶段切换时色晕颜色用 `.animation(.easeInOut(duration: 0.8))` 平滑过渡

### 4.3 倒计时区域

```
        ╭─────────────╮
       ╱   ●●●●●●●●●   ╲      ← 阶段色圆环（进度随剩余时间减少）
      │   ╭───────╮    │
      │   │ 24:53 │    │     ← 大字号 mm:ss（系统等宽字体）
      │   ╰───────╯    │
      │    专注 · 第2轮  │     ← 阶段名 + 当前轮次
       ╲             ╱
        ╰─────────────╯

          ▶   ⏭   ↺          ← 三个玻璃质感按钮
```

- 圆环：`Circle().trim(from: 0, to: progress)` + `rotationEffect`
- 中心数字：`.monospacedDigit()` 等宽避免抖动
- 字号：约 56pt，字重 `.light`

### 4.4 控制按钮

| 按钮 | 图标 | 行为 |
|---|---|---|
| 开始 / 暂停 | `play.fill` / `pause.fill` | 切换计时状态 |
| 跳过 | `forward.fill` | 立即结束当前阶段，进入下一阶段 |
| 重置 | `arrow.counterclockwise` | 当前阶段回到起点（不计入完成数） |

- 按钮使用 `Glass.regular` 圆形玻璃质感，按压时 `GlassProminent` 高亮
- 主按钮（开始/暂停）直径稍大

### 4.5 阶段切换提示

- **钟声**：专注结束时播放轻柔钟声（`AVAudioPlayer`，时长 ~1.5s）
- **原生通知**：
  - 标题 = 下一阶段名（"短休息时间到" / "开始第 N 轮专注"）
  - 正文 = "上一轮已完成"
  - 点击通知回到主窗口
- 通过 `UserNotifications` 框架申请权限并发送

---

## 5. 菜单栏常驻

### 5.1 行为

- 主窗口关闭后，应用不退出，转为菜单栏常驻
- 菜单栏图标：圆形进度小图标，外圈为阶段色进度环，中心为当前阶段符号（🍅专注 / 🌿休息 / 🌊长休）或数字百分比
- 点击图标：展开下拉菜单
- 双击图标：重新打开主窗口

### 5.2 下拉菜单项

```
🍅 TomatoClock
─────────────────
专注 · 第2轮 · 24:53
─────────────────
开始/暂停     ⌘R
跳过          ⌘⇧N
重置          ⌘⇧R
─────────────────
打开主窗口     ⌘O
今日: 6 / 8
─────────────────
设置...
退出 TomatoClock   ⌘Q
```

- 菜单项使用 SwiftUI `Commands` + `NSStatusItem` 实现
- 仅菜单快捷键，不注册全局热键

---

## 6. 数据持久化

### 6.1 SwiftData 模型

```swift
@Model
final class FocusSession {
    @Attribute(.unique) var id: UUID
    var date: Date          // 完成日期（归一化到当天 00:00）
    var completedCount: Int // 当天累计完成的专注番茄数
    // 可选：var lastUpdated: Date
}
```

- 每天一条记录，`completedCount` 累加
- 完成一轮专注（25 分钟走完或被跳过时若已过半）才计数

### 6.2 统计视图

- 7 天柱状图：横轴为近 7 天日期，纵轴为完成番茄数
- 柱体使用阶段色（专注色），当日柱体高亮
- 显示在设置面板下方或独立 Tab

### 6.3 会话状态（非持久化）

- 当前阶段、剩余时间、是否暂停、当前轮次：仅内存中，重启归零
- 通过 `@AppStorage` 持久化的偏好见 §8

---

## 7. 应用生命周期

### 7.1 启动

1. 初始化 `TimerEngine`（计时逻辑）
2. 创建主窗口
3. 创建菜单栏 `NSStatusItem`
4. 申请通知权限
5. 预加载钟声音效

### 7.2 关闭主窗口

- 拦截 `windowShouldClose`，仅 `orderOut` 不退出应用
- 计时继续在后台进行
- 菜单栏图标显示进度

### 7.3 退出

- 仅通过菜单栏"退出"或 ⌘Q 退出
- 退出时若有进行中的专注，不计入完成数

---

## 8. 设置面板

通过菜单栏"设置..."打开，独立窗口。

| 项 | 类型 | 默认值 |
|---|---|---|
| 每日目标番茄数 | Int（Stepper，1-20） | 8 |
| 自动衔接下一阶段 | Bool（Toggle） | true |
| 阶段结束发声 | Bool（Toggle） | true |
| 发送系统通知 | Bool（Toggle） | true |

- 全部通过 `@AppStorage` 持久化
- 设置面板本身也使用玻璃材质，与主窗口风格统一
- 设置面板下方嵌入 7 天统计柱状图

---

## 9. 文件结构

```
TomatoClock/
├── TomatoClock.xcodeproj
├── TomatoClock/
│   ├── TomatoClockApp.swift          # @main，App 入口
│   ├── App/
│   │   ├── AppState.swift            # 全局状态：计时引擎、设置
│   │   └── WindowGroup+StatusBar.swift # 主窗口 + 菜单栏装配
│   ├── Models/
│   │   ├── TimerPhase.swift          # 阶段枚举（focus/shortBreak/longBreak）
│   │   ├── TimerEngine.swift         # 计时核心逻辑（无 UI）
│   │   └── FocusSession.swift        # SwiftData 模型
│   ├── Views/
│   │   ├── MainWindow.swift          # 主窗口根视图
│   │   ├── CountdownRingView.swift   # 圆环 + 中心数字
│   │   ├── ControlButtons.swift      # 三按钮组
│   │   ├── PhaseBackgroundView.swift # 阶段色径向渐变色晕
│   │   ├── StatusBarView.swift       # 菜单栏小图标视图
│   │   └── SettingsView.swift        # 设置面板 + 7天图表
│   ├── Charts/
│   │   └── WeeklyChartView.swift     # 7 天柱状图（Swift Charts）
│   ├── Notifications/
│   │   └── NotificationManager.swift # 通知权限与发送
│   ├── Sound/
│   │   └── SoundPlayer.swift         # 钟声播放
│   ├── Theme/
│   │   └── PhaseTheme.swift          # 阶段颜色定义、阶段名
│   └── Assets.xcassets/
│       ├── AppIcon.appiconset
│       └── bell.caf                  # 钟声音效
```

---

## 10. 关键实现要点

### 10.1 Liquid Glass 应用

```swift
content
    .background(
        PhaseBackgroundView(phase: engine.phase)
    )
    .glassEffect(.regular, in: .rect)
```

- 玻璃材质应用于内容视图背景，覆盖整个窗口
- 色晕放在玻璃之下，被玻璃折射呈现

### 10.2 计时引擎接口

```swift
@Observable
final class TimerEngine {
    private(set) var phase: TimerPhase
    private(set) var remaining: TimeInterval
    private(set) var isRunning: Bool
    private(set) var currentRound: Int  // 1-4
    private var endDate: Date?

    func start()
    func pause()
    func skip()
    func reset()
    func tick(now: Date)  // 由 TimelineView 调用
}
```

- 使用 `@Observable`（Swift 5.9 Observation）
- `endDate` 在 `start` / `pause` / `skip` / `reset` 时重算
- `tick(now:)` 由 `TimelineView(.animation)` 每帧调用

### 10.3 菜单栏实现

```swift
// 在 AppDelegate（NSApplicationDelegateAdaptor）中
private var statusItem: NSStatusItem!

func setupStatusBar() {
    statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    let view = NSHostingView(rootView: StatusBarView(engine: engine))
    statusItem.button?.subviews.forEach { $0.removeFromSuperview() }
    statusItem.button?.addSubview(view)
    // ... AutoLayout constraints
}
```

- 菜单使用 `NSMenu` + `NSMenuItem`
- 视图用 `NSHostingView` 承载 SwiftUI `StatusBarView`

### 10.4 窗口隐藏标题栏

```swift
WindowGroup {
    MainWindow()
}
.windowStyle(.hiddenTitleBar)
.defaultSize(width: 360, height: 500)
.windowResizability(.contentSize)  // 固定尺寸
```

---

## 11. 开发顺序

1. **M1：项目骨架**
   - 用 `ios-simulator` / 手动创建 Xcode 项目（macOS App，SwiftUI）
   - 配置 Info.plist：LSUIElement = false（保留 Dock 图标但可隐藏）
   - 编译通过空窗口

2. **M2：计时引擎 + 假 UI**
   - 实现 `TimerEngine`、`TimerPhase`
   - 用纯文本显示 remaining、phase、round
   - 三个按钮接到引擎

3. **M3：玻璃主窗口 + 圆环**
   - 实现倒计时圆环、中心数字、控制按钮玻璃质感
   - 阶段色径向渐变色晕
   - `.glassEffect` 应用

4. **M4：阶段切换 + 通知 + 音效**
   - 钟声播放
   - 通知发送
   - 自动衔接

5. **M5：菜单栏常驻**
   - `NSStatusItem` + 进度小图标
   - 关闭窗口不退出
   - 菜单项 + 快捷键

6. **M6：SwiftData + 7天图表**
   - `FocusSession` 模型
   - 完成计数写入
   - Swift Charts 柱状图

7. **M7：设置面板**
   - 4 项设置 + `@AppStorage`
   - 嵌入 7 天图表

8. **M8：打磨**
   - 动画曲线微调
   - 颜色调和
   - 应用图标
   - 在 macOS 26 模拟器 / 真机截图验证

---

## 12. 验证清单

- [ ] 主窗口玻璃折射出桌面背景
- [ ] 阶段切换时色晕颜色平滑过渡
- [ ] 计时在窗口隐藏 / 系统睡眠后仍准确
- [ ] 钟声 + 通知在专注结束正确触发
- [ ] 菜单栏图标随进度更新
- [ ] 重启应用后 7 天统计仍显示
- [ ] 设置面板 4 项开关生效
- [ ] ⌘Q 正常退出，关闭窗口不退出

---

## 13. 待定项

- [ ] 应用图标设计
- [ ] Bundle ID 最终确定（暂定 `com.ray.tomatoclock`）
- [ ] 钟声音频素材选择
- [ ] 是否上架 App Store（影响沙盒与签名配置）
