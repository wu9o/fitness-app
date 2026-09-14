# ADR 0001：跨端技术栈

- 状态：已接受
- 日期：2026-09-14

## 背景

Movea 需要覆盖 iPhone、iPad、Mac、Android 和 Apple Watch。运动、健康、后台定位和低功耗传感器又明显依赖平台能力。

## 决策

主应用采用 Flutter，Apple Watch 采用独立的原生 watchOS/SwiftUI target。跨平台层只依赖 Movea 自己的领域模型和 repository 接口，平台 SDK 不向上泄漏。

## 原因

1. Flutter 可以共享 iPhone、iPad、Mac 和 Android 的主要界面与应用流程。
2. Apple Watch workout session、HealthKit 传感器和后台行为需要原生能力与独立生命周期。
3. 领域模型、加密备份协议和数据合并逻辑可以跨端共享，不应绑定某一种 UI 技术。
4. 未来即使替换 Flutter，Watch 和同步协议也不需要重写。

## 后果

- 需要维护 Dart 主应用和少量 Swift Watch 代码。
- 需要为 HealthKit、Health Connect、Core Location 和 Android Location 分别实现 adapter。
- 需要分别验证手机、桌面端和 Watch 的交互，不再把一次 iPhone 模拟器通过视为整体完成。

## 未决事项

- 本地数据库选择 Drift 还是 SQLite 原生封装
- GitHub OAuth token 是否通过独立认证服务中转
- Watch 采样数据的压缩和上传批次
