# Movea Flutter app

这是 Movea 的跨端主应用，目标平台为 iPhone、iPad、Mac 和 Android。平台宿主目录已经生成，业务代码通过 `lib/src` 和仓库内的共享 package 组织。

## 本地验证

在本目录执行：

```bash
flutter pub get
flutter analyze
flutter test
flutter build ios --debug --no-codesign
flutter build macos --debug
```

Android、iOS 和 macOS 的平台配置由 Flutter CLI 生成；Health、定位、后台任务和安全存储仍通过 `lib/src/platform` 逐步接入。

Apple Watch 不放在 Flutter app 内，见仓库根目录 `watchos/MoveaWatch` 和 `docs/architecture.md`。
