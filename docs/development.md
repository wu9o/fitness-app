# Movea 开发说明

## 工具链

- Flutter stable
- Dart
- Xcode：iOS、iPadOS、macOS 和 watchOS 构建
- Android Studio：Android 构建和 Health Connect 调试

## 本地目录

Flutter SDK 默认不提交到仓库。建议通过系统包管理器或官方 SDK 安装，并确认以下命令可用：

```bash
flutter --version
dart --version
flutter doctor -v
```

## 验证层级

```bash
flutter analyze
flutter test
flutter build ios --no-codesign
flutter build macos
```

平台适配和设备功能需要额外验证：

- iPhone：真实定位、后台运动、健康授权
- iPad：分栏和横屏布局、HealthKit 可用性
- Mac：键鼠操作、窗口缩放和数据查看
- Android：定位权限、Health Connect、返回手势
- Apple Watch：独立 workout session、锁屏/抬腕、断连恢复

## 提交规范

- `feat:` 新能力
- `fix:` 问题修复
- `refactor:` 结构调整
- `docs:` 文档调整
- 每次提交说明对应的验证命令
