# Movea 跨端架构

## 选择结论

主应用使用 Flutter，Apple Watch 使用原生 watchOS/SwiftUI。Flutter 覆盖 iPhone、iPad、Mac 和 Android；Watch 使用平台原生运动会话，避免牺牲后台能力、心率采集和电量表现。

## 分层

```text
presentation
  screens / navigation / responsive layout

application
  start workout / finish workout / follow route / sync data

domain
  ActivityType / WorkoutRecord / Route / SleepSummary

data
  local persistence / encrypted backup / merge and recovery

platform
  health / location / watch connectivity / secure storage
```

## 领域模型边界

跨平台模型不直接引用 HealthKit、Core Location 或 Android 类型。平台数据先转换为 Movea 自己的模型，再交给 application 层。

```text
WorkoutRecord
  id
  activityType
  startedAt
  endedAt
  duration
  distance
  sourceDevice
  routeId?

Route
  id
  name
  points
  distance
  createdAt
  sourceWorkoutId?
```

## 平台适配

| 能力 | Apple | Android | 共享接口 |
| --- | --- | --- | --- |
| 健康数据 | HealthKit | Health Connect | `HealthRepository` |
| 定位 | Core Location | Fused Location | `LocationRepository` |
| 安全存储 | Keychain | Android Keystore | `SecureStorage` |
| Watch 通信 | Watch Connectivity | 不适用 | `CompanionTransport` |
| 备份 | GitHub API | GitHub API | `BackupRepository` |

## GitHub 备份策略

GitHub 私密仓库是备份目标，不是在线数据库。客户端需要：

1. 在本地生成加密备份包
2. 使用日期/设备分片，减少多设备同时写入冲突
3. 下载远端 manifest 后合并记录
4. 使用版本号和幂等 ID 去重
5. 失败时保留本地待同步队列

当前 Flutter 骨架已经用 `SharedPreferencesWorkoutPersistence` 保存运动摘要，
作为离线优先的第一步；路线点、睡眠原始数据和加密 GitHub 备份仍沿用接口逐步接入。

## 地图与路线预览

路线页和室外运动页使用 Flutter 的 `flutter_map` 作为跨端地图容器，底图通过 `TileLayer`
加载，路线通过 `PolylineLayer` 绘制，起点和终点通过 `MarkerLayer` 标注。当前开发预览使用
OpenStreetMap 瓦片并显示署名，macOS 沙盒已开启出站网络权限；正式发布前需要根据覆盖区域、
缓存策略和服务条款切换到经过确认的地图瓦片服务。真实定位轨迹仍由 `LocationRepository`
提供，地图容器不直接依赖某个平台的定位 SDK。

## Watch 数据流

```text
Watch workout session
  -> local workout summary
  -> Watch Connectivity when available
  -> iPhone local database
  -> encrypted GitHub backup
```

Watch 端不能依赖每次都连接 iPhone 才能开始运动。运动过程必须能独立运行，连接恢复后再补传摘要和采样数据。
