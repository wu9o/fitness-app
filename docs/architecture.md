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
  ActivityType / WorkoutRecord / Route / SleepSummary / TrainingPlan

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

当前 Flutter 骨架已经用 `SharedPreferencesWorkoutPersistence` 保存运动摘要和 GPS 路线点，
作为离线优先的第一步；训练计划和带路线点的路线摘要使用各自的 SharedPreferences 持久化，
睡眠原始数据和加密 GitHub 备份仍沿用接口逐步接入。

健康概览由 `HealthStore` 统一承载加载、刷新和来源状态。iOS 通过 `movea/health` MethodChannel
读取 HealthKit 的睡眠、体重、步数和静息心率，并先转换为 `HealthSnapshot`；独立的
`DeviceWorkoutRepository` 在用户主动触发后读取最近 30 天的运动摘要，把 HealthKit UUID、设备、
平均/最高心率、活动能量和距离转换为共享 `WorkoutRecord`。导入时按来源 UUID 幂等去重，缺失的指标
保持为空，不从路线或速度推测。HealthKit 不可用、
用户未授权或其他平台尚未接入时返回带 `HealthDataSource.demo` 的明确降级快照。这样首页和健康页
不会各自写死一套健康数字，也为 Android Health Connect 复用同一接口。

前台户外定位由 `GeolocatorLocationRepository` 负责权限、定位服务检查、5 米采样间隔和
低精度点过滤；`ActivityPage` 负责运动生命周期、暂停/继续、距离累计和计划路线引导。
当前配速优先使用平台提供的速度；若平台速度未知，则由最近一组带时间戳的 GPS 点按距离/时间
计算，避免 Simulator 或部分设备返回未知速度时显示错误的空数据。
路线引导使用计划路线线段投影计算偏离距离和沿线进度；运动详情可将实际 GPS 轨迹命名后
写入 `RouteStore`，作为下一次可复用的“我的路线”。
GPS 点还会携带速度、海拔和精度，运动记录从原始点派生平均速度、累计爬升和定位质量，
并持久化因低精度、无效坐标或异常跳变而过滤的采样数，避免把这些统计值与地图渲染逻辑耦合。
结束运动时使用等待写入完成的持久化路径，写入成功后才清除活动草稿并打开运动总结，防止页面跳转
早于本地落盘。

运动强度先采用用户在总结页主动选择的体感等级，记录到 `WorkoutRecord.perceivedEffort`。主观负荷
使用“有效运动分钟 × 体感分值”形成 Movea 内部趋势分，只用于同一个人的周期比较，不替代心率、
卡路里或专业训练建议。运动心率和能量仅在 HealthKit 或未来 Health Connect 返回可信来源时展示；
导入的摘要没有路线点时，界面明确标注“设备记录来源”，不把摘要距离伪装成 GPS 轨迹。
iOS 户外运动使用 `AppleSettings` 开启后台定位，并在 Runner 中声明 `location` Background Mode；
应用存活时，锁屏或切换应用会继续采集 GPS。当前运动同时写入 `ActiveWorkoutStore` 草稿，异常退出后
恢复为暂停状态，保留活动类型、计划路线、已采集轨迹、距离和有效时长。发布前仍需在多款真机上验证
长时间锁屏、低电量模式、系统回收和功耗表现；系统强制终止进程期间不会伪造缺失的 GPS 点。草稿写入
通过串行队列合并高频 GPS 更新，结束运动时让清理操作排在已开始写入之后，避免并发写入覆盖已清除状态。

## 地图与路线预览

路线页和室外运动页直接使用 MapLibre Flutter 作为跨端地图容器，底图采用 OpenFreeMap 的
OpenMapTiles 矢量瓦片，样式由 `apps/movea/assets/maps/movea-minimal.json` 完全控制。路线
使用 MapLibre 的 `PolylineLayer` 绘制，起点和终点通过 `WidgetLayer` 标注。主题采用中等信息
密度，保留水域、公园、主要/次要道路、适量道路名称、区域名称和少量运动相关 POI，隐藏普通
商业 POI、建筑名称、铁路/地铁线和低等级小路标签。OpenFreeMap 不需要高德 Key，地图服务
和样式也不再依赖高德自定义地图控制台；正式发布前仍需要根据覆盖区域、缓存策略和服务条款
确认公共瓦片服务是否适合长期使用，必要时切换到 Protomaps PMTiles 自托管。真实定位轨迹
仍由 `LocationRepository` 提供，地图容器不直接依赖某个平台的定位 SDK。

## Watch 数据流

```text
Watch workout session
  -> local workout summary
  -> Watch Connectivity when available
  -> iPhone local database
  -> encrypted GitHub backup
```

Watch 端不能依赖每次都连接 iPhone 才能开始运动。运动过程必须能独立运行，连接恢复后再补传摘要和采样数据。
