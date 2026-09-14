# MoveaWatch

Apple Watch 原生 companion target 的源码预留目录。

当前目录包含 Watch 端的运动生命周期 UI 骨架，但还没有把它绑定到正式的 Xcode watchOS target；这样可以先稳定跨端协议，再接入真实传感器。

正式接入时使用 Xcode 创建 watchOS App target，并实现：

- `HKWorkoutSession`：跑步、户外骑行和室内训练
- 心率、距离、能量和 GPS 采样
- 独立开始、暂停、继续和结束
- `WatchConnectivity`：向 iPhone 补传运动摘要
- 断连状态下本地保存，恢复连接后再同步

源码入口：

- `MoveaWatchApp.swift`：Watch 端极简运动界面
- `WatchWorkoutCoordinator.swift`：开始、暂停、继续、结束的生命周期骨架

Watch 端不复制完整的 iPhone 页面，只提供运动中的高频操作和关键指标。
