# Movea Flutter app

这是 Movea 的跨端主应用，目标平台为 iPhone、iPad、Mac 和 Android。平台宿主目录已经生成，业务代码通过 `lib/src` 和仓库内的共享 package 组织。地图使用 MapLibre 渲染，当前底图使用 OpenFreeMap 的 OpenMapTiles 数据，样式文件位于 `assets/maps/movea-minimal.json`。

## 本地验证

在本目录执行：

```bash
flutter pub get
flutter analyze
flutter test
flutter build ios --debug --no-codesign
flutter build macos --debug
```

Android、iOS 和 macOS 的平台配置由 Flutter CLI 生成；前台定位已经通过 `geolocator` 接入，
Health、后台任务和安全存储仍通过 `lib/src/platform` 逐步接入。

MapLibre 在 iOS/Android 使用原生渲染，在 macOS 使用 WebView 实现；macOS 沙盒已开启出站网络权限。后续可以将样式中的瓦片源切换为 Protomaps PMTiles，以支持更可控的离线地图方案。

Apple Watch 不放在 Flutter app 内，见仓库根目录 `watchos/MoveaWatch` 和 `docs/architecture.md`。

## 健身动作库

`assets/exercises/manifest.json` 包含 302 个动作的元数据，`assets/exercises/` 包含
906 帧透明 SVG 演示图。训练计划编辑器可以从动作库搜索并选入动作，计划详情和训练进行中
都可以打开循环演示、动作步骤、呼吸节奏、常见错误和安全提示。原始数据的署名和许可证见
仓库根目录的 [`third_party/workout-guide/`](../../third_party/workout-guide/)。
