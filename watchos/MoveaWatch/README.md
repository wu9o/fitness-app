# MoveaWatch

Apple Watch 原生 companion 的实现源码。当前已从计时器占位逻辑升级为真实 HealthKit 运动会话，但尚未绑定到 Xcode 的正式 watchOS App target。

## 已实现

- `HKWorkoutSession` + `HKLiveWorkoutBuilder`
- 户外跑、户外骑行和力量训练
- HealthKit 授权、开始、暂停、继续、结束和保存
- 实时心率、平均/最高心率、距离、活动能量和有效时长
- `WCSession.transferUserInfo` 后台排队补传运动摘要
- iPhone 收件箱与 HealthKit UUID 去重：HealthKit 完整记录优先
- HealthKit entitlement、隐私用途说明和 `workout-processing` 后台模式文件

## 建立正式 target

1. 在 `apps/movea/ios/Runner.xcworkspace` 中添加 watchOS App target。
2. Bundle ID 使用 iPhone App ID 的子级，并选择同一个 Team。
3. 把本目录 Swift 文件、`Info.plist` 和 `MoveaWatch.entitlements` 加入 target。
4. Signing & Capabilities 启用 HealthKit 和 Background Modes / Workout processing。
5. 确认 iPhone 与 Watch target 都包含 Watch Connectivity。

## 必须真机验收

- 首次 HealthKit 权限矩阵和拒绝后的恢复路径
- 锁屏、抬腕、暂停和长时间后台采集
- 心率、距离、能量与系统健身记录一致性
- iPhone 断连完成运动后重新连接只补传一次
- Watch 摘要先到、HealthKit 完整记录后到按 UUID 合并

Apple 明确要求使用配对真机测试 Watch Connectivity；模拟器类型检查不能代替传输验收。
