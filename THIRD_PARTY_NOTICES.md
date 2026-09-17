# Third-party notices

Movea 使用以下第三方软件、数据和视觉内容。依赖包的完整版本清单见 `apps/movea/pubspec.lock`。

## Workout Guide exercise artwork

- Project: <https://github.com/bryllim/workout-guide>
- Copyright: Bryl Lim and identified upstream contributors
- License: CC BY-SA 4.0 for exercise artwork; MIT for imported software/documentation portions
- Local notices: [`third_party/workout-guide`](third_party/workout-guide)

部分首帧作品源自 [Everkinetic](https://github.com/everkinetic/data)。每个动作的创作者、来源链接、许可证和修改说明保留在 `apps/movea/assets/exercises/manifest.json` 中。

## MapLibre and OpenFreeMap

Movea 使用 MapLibre 渲染地图，并通过 OpenFreeMap 获取基于 OpenStreetMap 的地图数据。地图样式中的 attribution 字段保留 `© OpenStreetMap contributors · OpenFreeMap`，应用分发和部署时不得移除所需署名。

- MapLibre: <https://maplibre.org/>
- OpenFreeMap: <https://openfreemap.org/>
- OpenStreetMap copyright: <https://www.openstreetmap.org/copyright>

## Flutter packages

Flutter 和 Dart 依赖由各自作者按其声明的许可证提供。重新分发二进制文件时，应使用对应平台的许可证收集机制生成并展示完整依赖许可证。
