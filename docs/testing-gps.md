# Movea GPS 真实链路测试

## 推荐方案

使用 iOS Simulator 的 `simctl location start` 回放一组经纬度航点。系统会把航点插值成连续的 Core Location 更新，Movea 仍然通过 `GeolocatorLocationRepository` 接收 `Position`，再转换成自己的 `LocationPoint`。

```text
iOS Simulator Core Location
  -> Geolocator Position
  -> LocationPoint(timestamp / speed / altitude / accuracy)
  -> ActivityPage
  -> 实际轨迹、距离、配速、路线引导
  -> WorkoutRecord 持久化
```

因此这条链路不会把一条线直接画到地图上，也不会直接修改运动记录。地图上的珊瑚色轨迹、距离、当前配速和结束后的分段配速，都来自系统回放的位置点。

部分 Simulator 版本不会填写 `Position.speed`，这不代表没有速度数据。Movea 会在系统速度未知时，用最近 6 个带时间戳的 GPS 点计算距离/时间，并以短窗口平滑后的结果展示当前配速。

## iPhone Simulator 操作

先启动 Movea，并进入“运动 → 户外运动”。在终端执行：

```bash
cd /path/to/movea
./tooling/simulate-gps-route.sh prepare
```

然后在 App 中点击“开始跑步”，再执行：

```bash
./tooling/simulate-gps-route.sh start
```

默认速度是 6 m/s、每秒更新一次。可以覆盖参数：

```bash
SIMULATOR_UDID=219E976D-81B9-4F69-A68F-A7891B98560A \
SPEED=3 INTERVAL=1 \
./tooling/simulate-gps-route.sh start
```

结束测试后清除模拟定位：

```bash
./tooling/simulate-gps-route.sh clear
```

## 验收点

1. 开始后先看到“正在获取 GPS 定位”，随后变为“GPS 已定位”。
2. 运动中的距离逐步增加，当前配速和精度随位置点更新。
3. 地图上计划路线为蓝色，系统回放产生的实际轨迹为珊瑚色。
4. 选择计划路线时，沿线进度和偏离距离随当前位置变化；偏离航点后应显示偏离提示。
5. 结束后历史记录保留真实点位、时间戳、速度、海拔和精度，详情页可以看到分段配速。
6. 从详情页保存为“我的路线”后，路线库使用这次真实轨迹，而不是预置演示路线。

## 测试分层

- `flutter test`：使用不访问系统 GPS 的替身仓库，验证按钮、状态切换、持久化和页面布局，稳定且快速。
- `simctl location`：用于 iPhone 端到端验收，验证真实的系统定位 → Geolocator → App 数据链路。
- 真机：发布前用 Xcode 的 GPX Location 模拟或真实户外运动复核后台定位、锁屏、弱 GPS 和功耗。

仓库同时提供了 [`park-loop.gpx`](../tooling/fixtures/park-loop.gpx)。在 Xcode 中可以把它配置为 Scheme 的 Location Simulation，用于真机连接调试或需要 GPX 文件的测试流程；命令行 Simulator 则使用同一组航点的 [`park-loop.waypoints`](../tooling/fixtures/park-loop.waypoints)。

`flutter test` 和 Simulator 回放解决的是不同问题：前者不应依赖运行中的模拟器，后者才是“不是假画线”的定位验收。
