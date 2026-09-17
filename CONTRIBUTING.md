# Contributing to Movea

感谢你关注动迹 Movea。项目仍处于 Alpha 阶段，优先接受边界清楚、可以验证的改动。

## 开始之前

- Bug 请描述设备、系统版本、复现步骤、预期结果和实际结果。
- 新能力请先说明使用场景、涉及的平台，以及它如何适配本地优先的数据模型。
- 不要在 Issue、截图、日志、测试夹具或提交中包含真实健康数据、GPS 住址、Token、Key 或密钥。
- 动作插画的修改必须继续遵守 CC BY-SA 4.0，并保留来源和修改说明。

## 本地开发

```bash
cd apps/movea
flutter pub get
flutter analyze
flutter test
```

Apple 平台的相关改动还应至少完成对应构建：

```bash
flutter build ios --simulator --debug
flutter build macos --debug
```

真实定位、HealthKit 和 Apple Watch 能力必须明确区分模拟器验证与真机验证。

## 提交与 Pull Request

- 使用 `feat:`、`fix:`、`docs:`、`refactor:`、`test:` 等清晰前缀。
- 一个提交尽量只解决一个问题，避免混入无关格式化。
- PR 需要写明改动、验证方式、平台影响和仍未验证的边界。
- UI 改动请提供目标设备截图；数据迁移或恢复改动请提供失败与回滚测试。

提交贡献即表示你有权提供相关内容，并同意自有源代码按本仓库 MIT License 发布。第三方内容继续遵循各自许可证。
