# 动迹 Movea

[![Flutter CI](https://github.com/wu9o/fitness-app/actions/workflows/flutter-ci.yml/badge.svg)](https://github.com/wu9o/fitness-app/actions/workflows/flutter-ci.yml)
[![License: MIT](https://img.shields.io/badge/code-MIT-blue.svg)](LICENSE)
[![Exercise assets: CC BY-SA 4.0](https://img.shields.io/badge/exercise%20assets-CC%20BY--SA%204.0-green.svg)](third_party/workout-guide/LICENSE-ASSETS)

面向个人使用、本地优先的多设备运动与健康记录应用。项目当前处于 **Alpha** 阶段，欢迎体验、讨论和贡献，但尚不适合替代专业医疗或训练建议。

Movea 记录跑步、骑行、拉伸、力量训练、睡眠和健康数据，目标是让同一套个人数据可以在 iPhone、iPad、Mac、Apple Watch 和 Android 之间自然流动。

> 当前仓库正在从早期 SwiftUI 原型迁移到 Flutter 主应用 + 原生 Apple Watch 模块的跨平台架构。现有 SwiftUI 代码保留在 `legacy/swiftui-prototype`，用于对照原有交互和视觉稿。

## 当前能力

- 户外运动：跑步、骑行等运动的 GPS 记录、暂停恢复、配速和轨迹质量
- 路线：MapLibre + OpenFreeMap 自定义运动地图、路线保存、跟随、偏航和转向提醒
- 运动分析：全部记录、训练日历、周报、负荷趋势、心率曲线和个性化心率区间
- 健身训练：302 个动作、906 帧演示、训练计划模板和训练中动作指导
- 健康：HealthKit 运动与心率导入、睡眠详情、体重与恢复信息的统一入口
- 数据安全：本地校验恢复、AES-256-GCM 加密导出与恢复，不在源码中保存账号密钥
- 多设备：iPhone/iPad/macOS Flutter 应用，以及待接入正式 target 的原生 watchOS 模块

## 快速开始

环境要求：Flutter 3.47 或兼容的 stable 版本、Dart 3.3+；构建 Apple 平台还需要 Xcode。

```bash
git clone https://github.com/wu9o/fitness-app.git
cd fitness-app/apps/movea
flutter pub get
flutter analyze
flutter test
flutter run
```

GPS 模拟、平台构建和设备验证见 [`docs/development.md`](docs/development.md) 与 [`docs/testing-gps.md`](docs/testing-gps.md)。

## 产品方向

- 记录：运动过程、GPS 路线、运动时长和训练类型
- 复用：保存路线，查看难度、爬升、参考配速和补水建议，并在下一次运动时跟随路线
- 了解：睡眠、恢复状态和运动趋势
- 学习：跑步、骑行、拉伸和力量训练知识
- 动作库：内置 Workout Guide 的 302 个动作和 906 帧演示，支持按部位、类型和器械检索
- 同步：本地优先，使用端到端加密数据备份到个人 GitHub 私密仓库
- 多端：手机负责完整体验，Mac/iPad 负责查看和分析，Apple Watch 负责运动中的快速记录

## 目标设备

| 设备 | 目标体验 | 实现方式 |
| --- | --- | --- |
| iPhone | 完整运动、健康和路线体验 | Flutter |
| iPad | 分栏查看记录、路线和健康趋势 | Flutter 自适应布局 |
| Mac | 历史记录、趋势分析和数据管理 | Flutter macOS |
| Android | 运动记录、路线和健康数据 | Flutter |
| Apple Watch | 独立开始/暂停/结束运动、心率和定位 | 原生 watchOS / SwiftUI |

## 技术架构

```text
                    +-----------------------+
                    |       Movea API       |
                    |  domain / sync / auth |
                    +-----------+-----------+
                                |
             +------------------+------------------+
             |                                     |
  +----------v-----------+              +----------v-----------+
  | Flutter applications |              | Native Watch target  |
  | iPhone / iPad / Mac  |              | watchOS workout      |
  | Android              |              | HealthKit / sensors  |
  +----------+-----------+              +----------+-----------+
             |                                     |
  +----------v-----------+              +----------v-----------+
  | Platform adapters    |              | Watch Connectivity   |
  | Health / location    |<------------>| iPhone companion     |
  +----------------------+              +----------------------+
```

- Flutter/Dart：共享主要界面、导航、领域模型、记录和同步流程
- 平台适配层：隔离 HealthKit、Health Connect、Core Location 和 Android Location
- Apple Watch：使用 watchOS Workout Session，避免把低功耗传感器能力塞进跨平台 UI
- 数据层：设备本地持久化作为第一数据源，GitHub 私密仓库作为加密备份，不作为实时数据库
- 本地数据安全：运动记录校验快照、损坏诊断，以及 AES-256-GCM 加密备份文件的导出与验证

## 数据与隐私

运动和健康数据默认保存在设备本地。上传 GitHub 前先在设备端加密，私密仓库只保存加密备份文件和版本清单。

当前阶段不会把 GitHub token 或明文健康数据写入仓库。跨设备同步需要处理 OAuth token 安全、冲突合并、离线重试和恢复密钥，这些会在同步模块中单独设计和测试。

## 仓库结构

```text
fitness-app/
├── apps/
│   └── movea/                 # Flutter 主应用：iOS / iPadOS / macOS / Android
├── packages/
│   ├── movea_domain/           # 运动、路线、睡眠和记录领域模型
│   ├── movea_data/             # 本地存储、加密备份和同步接口
│   └── movea_design/           # 颜色、字体、组件和响应式设计 token
├── watchos/
│   └── MoveaWatch/             # 原生 Apple Watch companion target
├── docs/
│   ├── product.md              # 产品边界和核心流程
│   ├── architecture.md         # 跨端架构和数据边界
│   ├── development.md          # 本地开发与验证方式
│   └── testing-gps.md          # iOS Simulator 真实 GPS 轨迹回放
├── tooling/
│   ├── simulate-gps-route.sh   # Core Location 航点回放脚本
│   └── fixtures/                # 可重复的测试轨迹
├── legacy/
│   └── swiftui-prototype/      # 第一版 SwiftUI 原型，仅作迁移参考
└── README.md
```

## 迁移路线

1. 完成 Flutter 工程和共享领域模型
2. 迁移首页、运动、健康、路线和学习流程
3. 加入 iPad 分栏布局和 macOS 键鼠交互
4. 接入 Android 定位和 Health Connect
5. 加入独立 Apple Watch workout session
6. 完成加密 GitHub 备份、冲突合并和恢复流程
7. 用真实 iPhone、Apple Watch 和 Android 设备完成发布前验证

## 当前状态

- SwiftUI 原型：可运行，用于保留已确认的视觉和交互参考
- Flutter 主应用：已具备 MapLibre/OpenFreeMap 地图、可折叠运动控制、本地运动记录、运动结束总结、GPS 采样质量、路线触觉与中文语音提醒、HealthKit 设备运动与心率曲线导入、个性化心率 5 区、校验恢复快照、加密备份恢复、记录来源筛选、28 天负荷趋势、睡眠详情、训练计划模板和路线保存/跟随流程
- 健身动作库：已导入动作元数据和 SVG 演示帧；训练计划可从动作库选动作，计划详情和训练中都可打开动作演示
- 下一阶段路线图：见 [`docs/roadmap.md`](docs/roadmap.md)，继续补充 Apple Watch 真机来源验证、路线音频/触觉和 GPS 稳定性验证，再推进多设备同步
- Apple Watch：原生运动会话、实时指标和摘要补传源码已实现，尚待加入正式 watchOS target 并完成配对真机验证
- GitHub 加密同步：已有概念验证，尚未作为正式数据层发布

## 参与贡献

问题反馈和代码贡献请先阅读 [`CONTRIBUTING.md`](CONTRIBUTING.md)。安全问题请不要提交公开 Issue，处理方式见 [`SECURITY.md`](SECURITY.md)。

## 许可证与第三方内容

Movea 自有源代码以 [MIT License](LICENSE) 发布。动作插画来自 [Workout Guide](https://github.com/bryllim/workout-guide)，按 [CC BY-SA 4.0](third_party/workout-guide/LICENSE-ASSETS) 使用；其中部分作品源自 Everkinetic，完整署名和改动记录见 [`third_party/workout-guide`](third_party/workout-guide) 与动作 `manifest.json`。地图数据和运行时服务的署名见 [`THIRD_PARTY_NOTICES.md`](THIRD_PARTY_NOTICES.md)。

## 开发原则

- 先定义跨端领域模型，再实现平台界面
- 所有平台能力都通过 adapter 隔离
- 运动记录必须可离线创建和读取
- 真实健康数据与演示数据必须明确区分
- 每个端都要做 UI 走查，不以单一 iPhone 模拟器通过作为完成标准
