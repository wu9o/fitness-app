# Changelog

本项目遵循 [Semantic Versioning](https://semver.org/)。

## [0.1.1] - 2026-09-17 — 可下载预览 Downloadable Preview

### Added

- 标签驱动的 GitHub Preview Release 流水线
- Android Release、iOS Simulator Debug 与 macOS Release 的持久化版本附件
- 中英文 README 中明确的构建类型、签名状态与下载说明

### Changed

- GitHub 官方 Actions 升级至当前主版本
- CI 临时产物与 GitHub Release 版本产物分离

### Distribution notes

- Android APK 使用开发签名，仅适合测试
- iOS 构建仅支持 Simulator，不是 iPhone 真机 IPA
- macOS 应用尚未进行 Developer ID 签名与公证

## [0.1.0] - 2026-09-17 — 起跑线 Trailhead

首个公开 Alpha 版本，建立 Movea 的跨平台产品和工程基线。

### Added

- Flutter iPhone、iPad、macOS 和 Android 共享应用架构
- 运动中心、GPS 记录、全局运动挂起卡片和运动历史
- MapLibre/OpenFreeMap 运动地图、路线保存、跟随、偏航和转向提醒
- HealthKit 运动与心率导入、睡眠详情、训练负荷和个性化心率区间
- 302 个健身动作、906 帧演示和可编辑训练计划
- 原生 watchOS 运动会话与摘要补传源码
- 本地恢复快照和 AES-256-GCM 加密备份导入导出

### Known limitations

- watchOS 源码尚未加入正式 target，也未完成配对真机验证
- Android Health Connect 和后台定位仍待接入与真机验证
- GitHub 备份目前是本地加密文件流程，不是完整的多设备自动同步
- 健康与训练建议仅供一般信息参考，不构成医疗建议
