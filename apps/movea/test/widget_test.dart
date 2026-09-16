import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movea_data/movea_data.dart';
import 'package:movea_domain/movea_domain.dart';
import 'package:movea/main.dart';
import 'package:movea/src/app.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:movea/src/exercise_catalog.dart';

class _FakeHealthRepository implements HealthRepository {
  @override
  Future<HealthSnapshot> readSnapshot() async {
    const demo = HealthSnapshot.demo;
    return HealthSnapshot(
      sleep: demo.sleep,
      weightKg: demo.weightKg,
      weightChangeKg: demo.weightChangeKg,
      restingHeartRate: demo.restingHeartRate,
      steps: demo.steps,
      source: HealthDataSource.healthKit,
      lastSyncedAt: null,
    );
  }
}

Future<void> pumpMobile(WidgetTester tester) async {
  SharedPreferences.setMockInitialValues({});
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  await tester.pumpWidget(const MoveaApp());
}

void main() {
  testWidgets('Movea shows the primary navigation', (tester) async {
    await pumpMobile(tester);

    expect(find.text('首页'), findsOneWidget);
    expect(find.text('运动'), findsOneWidget);
    expect(find.text('健康'), findsOneWidget);
    expect(find.text('路线'), findsOneWidget);
    expect(find.text('学习'), findsOneWidget);
  });

  test('Exercise catalog loads the bundled workout guide', () async {
    final store = ExerciseCatalogStore();
    await store.load();
    expect(store.error, isNull, reason: store.error);
    expect(store.exercises, hasLength(302));
    expect(store.find('squat')?.displayName, '深蹲');
  });

  testWidgets('Movea can open the activity page', (tester) async {
    await pumpMobile(tester);
    await tester.tap(find.text('运动').last);
    await tester.pumpAndSettle();
    expect(find.text('本周运动概览'), findsOneWidget);
    await tester.tap(find.text('选择运动'));
    await tester.pumpAndSettle();
    expect(find.text('选择今天的运动'), findsOneWidget);
    await tester.tap(find.text('户外跑'));
    await tester.pumpAndSettle();

    expect(find.text('准备好了吗？'), findsOneWidget);
    expect(find.text('开始跑步'), findsOneWidget);
    expect(find.text('MapLibre 地图预览'), findsOneWidget);
  });

  testWidgets('Movea can switch every primary tab', (tester) async {
    await pumpMobile(tester);

    await tester.tap(find.text('健康').last);
    await tester.pumpAndSettle();
    expect(find.text('昨晚睡眠'), findsOneWidget);

    await tester.tap(find.text('路线').last);
    await tester.pumpAndSettle();
    expect(find.text('公园环线'), findsOneWidget);
    expect(find.byKey(const ValueKey('route-thumbnail')), findsNWidgets(2));

    await tester.tap(find.byTooltip('保存路线').first);
    await tester.pump();
    await tester.tap(find.text('我的'));
    await tester.pump();
    expect(find.text('公园环线'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('route-thumbnail')));
    await tester.pumpAndSettle();
    expect(find.text('路线详情'), findsOneWidget);
    expect(find.text('开始并跟随路线'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.tap(find.text('推荐'));
    await tester.pump();
    await tester.tap(find.text('跟随路线').first);
    await tester.pumpAndSettle();
    expect(find.text('跟随路线 · 公园环线'), findsOneWidget);
    expect(find.text('开始跑步'), findsOneWidget);
    expect(find.byTooltip('取消路线'), findsOneWidget);
    await tester.tap(find.byTooltip('取消路线'));
    await tester.pump();
    expect(find.text('地图已接入 · 尚未开始'), findsOneWidget);
    expect(find.text('选择路线'), findsOneWidget);
    await tester.tap(find.text('选择路线'));
    await tester.pumpAndSettle();
    expect(find.text('把喜欢的路线留给下一次'), findsOneWidget);

    await tester.tap(find.text('学习').last);
    await tester.pumpAndSettle();
    expect(find.text('跑前热身'), findsOneWidget);
  });

  testWidgets('Movea health page opens sleep detail', (tester) async {
    await pumpMobile(tester);
    await tester.tap(find.text('健康').last);
    await tester.pumpAndSettle();

    expect(find.text('健康数据中心'), findsOneWidget);
    expect(find.text('当前体重'), findsOneWidget);
    await tester.tap(find.text('昨晚睡眠'));
    await tester.pumpAndSettle();

    expect(find.text('睡眠详情'), findsOneWidget);
    expect(find.text('睡眠阶段'), findsOneWidget);
    expect(find.text('深度睡眠 78 分钟'), findsOneWidget);
    expect(find.text('快速眼动 102 分钟'), findsOneWidget);
  });

  test('HealthStore preserves the source of a health snapshot', () async {
    final store = HealthStore(repository: _FakeHealthRepository());

    await store.restore();

    expect(store.error, isNull);
    expect(store.isLoading, isFalse);
    expect(store.snapshot.source, HealthDataSource.healthKit);
    expect(store.snapshot.sourceLabel, 'HealthKit');
  });

  testWidgets('Movea sports hub opens calendar and weekly report',
      (tester) async {
    await pumpMobile(tester);
    await tester.tap(find.text('运动').last);
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView).first, const Offset(0, -420));
    await tester.pumpAndSettle();

    expect(find.text('全部运动记录'), findsOneWidget);
    expect(find.text('训练日历'), findsOneWidget);
    expect(find.text('运动周报'), findsOneWidget);
    expect(find.text('运动状态'), findsOneWidget);

    await tester.tap(find.text('训练日历'));
    await tester.pumpAndSettle();
    expect(find.text('点选日期查看记录；蓝点是计划日，珊瑚色是已完成运动。'), findsOneWidget);
    expect(find.byTooltip('上个月'), findsOneWidget);
    await tester.tap(find.byTooltip('上个月'));
    await tester.pump();
    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.tap(find.text('运动周报'));
    await tester.pumpAndSettle();
    expect(find.text('每日运动时长'), findsOneWidget);
    expect(find.text('运动类型分布'), findsOneWidget);
  });

  testWidgets('Movea settings describe the open map stack', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: SettingsPage()),
    );
    await tester.pumpAndSettle();

    expect(find.text('地图服务'), findsOneWidget);
    expect(find.text('OpenFreeMap 已启用'), findsOneWidget);
    expect(find.text('无需 Key；地图样式和路线叠加由 Movea 自己控制'), findsOneWidget);
  });

  testWidgets('Movea activity flow supports type, pause, finish and history',
      (tester) async {
    await pumpMobile(tester);
    await tester.tap(find.text('运动').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('选择运动'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('户外骑行'));
    await tester.pump();
    expect(find.text('开始骑行'), findsOneWidget);
    expect(find.text('开始后将记录你的路线和运动数据'), findsOneWidget);

    await tester.tap(find.text('开始骑行'));
    await tester.pump();
    expect(find.text('暂停'), findsOneWidget);

    await tester.tap(find.text('暂停'));
    await tester.pump();
    expect(find.text('继续'), findsOneWidget);

    await tester.tap(find.text('继续'));
    await tester.pump();
    await tester.tap(find.text('结束'));
    await tester.pump();
    await tester.tap(find.text('全部运动记录'));
    await tester.pumpAndSettle();
    expect(find.text('全部运动记录'), findsOneWidget);
    expect(find.text('骑行'), findsNWidgets(2));
    expect(find.byType(ListTile), findsOneWidget);

    await tester.tap(find.byType(ListTile));
    await tester.pumpAndSettle();
    expect(find.text('运动详情'), findsOneWidget);
    expect(find.text('实际 GPS 轨迹'), findsOneWidget);
    expect(find.text('本地已保存'), findsOneWidget);
  });

  testWidgets('Movea activity can minimize and restore a live session',
      (tester) async {
    await pumpMobile(tester);
    await tester.tap(find.text('运动').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('选择运动'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('户外跑'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('开始跑步'));
    await tester.pump();
    expect(find.byTooltip('缩小运动'), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);

    await tester.tap(find.byTooltip('缩小运动'));
    await tester.pump();
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.text('跑步 · 正在记录'), findsOneWidget);

    await tester.tap(find.text('跑步 · 正在记录'));
    await tester.pump();
    expect(find.byTooltip('缩小运动'), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);

    await tester.tap(find.text('正在记录 · GPS 轨迹'));
    await tester.pump();
    await tester.tap(find.text('结束'));
    await tester.pump();
    expect(find.text('跑步 · 正在记录'), findsNothing);
  });

  testWidgets('Movea training plans can be opened, edited and started',
      (tester) async {
    await pumpMobile(tester);
    await tester.tap(find.text('运动').last);
    await tester.pumpAndSettle();

    await tester.drag(
      find.byType(ListView).first,
      const Offset(0, -620),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('管理计划'));
    await tester.pumpAndSettle();
    expect(find.text('你的训练模板'), findsOneWidget);
    expect(find.text('核心稳定'), findsOneWidget);

    await tester.tap(find.text('核心稳定'));
    await tester.pumpAndSettle();
    expect(find.text('动作顺序与节奏'), findsOneWidget);
    await tester.tap(find.text('编辑'));
    await tester.pumpAndSettle();
    expect(find.text('动作编排'), findsOneWidget);

    await tester.drag(find.byType(ListView).last, const Offset(0, -620));
    await tester.pumpAndSettle();
    await tester.tap(find.text('添加动作'));
    await tester.pump(const Duration(seconds: 2));
    await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)));
    await tester.pump();
    final exerciseSearch = find.byWidgetPredicate((widget) {
      return widget is TextField &&
          widget.decoration?.labelText == '搜索动作、部位或器械';
    });
    await tester.enterText(exerciseSearch, '深蹲');
    await tester.pump();
    await tester.tap(find
        .byWidgetPredicate((widget) => widget is Text && widget.data == '深蹲'));
    await tester.pumpAndSettle();
    expect(find.text('深蹲'), findsOneWidget);

    await tester.tap(find.text('保存').last);
    await tester.pumpAndSettle();
    expect(find.text('计划详情'), findsOneWidget);
    await tester.tap(find
        .byWidgetPredicate((widget) => widget is Text && widget.data == '深蹲'));
    await tester.pumpAndSettle();
    expect(find.text('动作步骤'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.text('开始这套计划'));
    await tester.pumpAndSettle();
    expect(find.text('开始训练'), findsOneWidget);
    expect(find.text('下一个动作'), findsOneWidget);
    await tester.tap(find.text('查看动作演示'));
    await tester.pumpAndSettle();
    expect(find.text('已暂停训练计时'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.text('下一个动作'));
    await tester.pump();
    expect(find.text('死虫式'), findsOneWidget);
  });

  testWidgets('Movea route tabs and learning categories respond',
      (tester) async {
    await pumpMobile(tester);
    await tester.tap(find.text('路线').last);
    await tester.pumpAndSettle();

    await tester.tap(find.text('我的'));
    await tester.pump();
    expect(find.text('还没有保存的路线'), findsOneWidget);

    await tester.tap(find.text('学习').last);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ChoiceChip, '骑行'));
    await tester.pump();
    expect(find.text('骑行前检查'), findsOneWidget);
    expect(find.text('跑前热身'), findsNothing);
  });

  testWidgets('Movea uses a side menu on iPad-sized screens', (tester) async {
    tester.view.physicalSize = const Size(820, 1180);
    tester.view.devicePixelRatio = 1;
    await tester.pumpWidget(const MoveaApp());
    await tester.pumpAndSettle();

    expect(find.byType(NavigationBar), findsNothing);
    expect(find.byTooltip('运动'), findsOneWidget);
    await tester.tap(find.byTooltip('运动'));
    await tester.pump(const Duration(milliseconds: 250));
    await tester.tap(find.text('选择运动'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('户外跑'));
    await tester.pump();
    expect(find.text('开始跑步'), findsOneWidget);
  });

  test('WorkoutStore persists and restores records', () async {
    SharedPreferences.setMockInitialValues({});
    final persistence = SharedPreferencesWorkoutPersistence();
    final original = WorkoutStore(persistence: persistence);
    final startedAt = DateTime(2026, 9, 14, 8);
    await original.restore();

    original.add(WorkoutRecord(
      id: 'persistence-test',
      activity: ActivityType.ride,
      startedAt: startedAt,
      duration: const Duration(minutes: 42),
      distanceMeters: 12300,
      routePoints: const [
        LocationPoint(latitude: 31.2304, longitude: 121.4737),
        LocationPoint(
          latitude: 31.2322,
          longitude: 121.4780,
          speedMetersPerSecond: 2.8,
          altitudeMeters: 18.5,
        ),
      ],
      trainingPlanId: 'morning-activation',
      completedActions: 4,
      plannedActions: 6,
    ));
    await Future<void>.delayed(Duration.zero);

    final restored = WorkoutStore(persistence: persistence);
    await restored.restore();
    expect(restored.records, hasLength(1));
    expect(restored.records.single.activity, ActivityType.ride);
    expect(restored.records.single.duration, const Duration(minutes: 42));
    expect(restored.records.single.distanceMeters, 12300);
    expect(restored.records.single.routePoints, hasLength(2));
    expect(restored.records.single.routePoints.last.longitude, 121.4780);
    expect(restored.records.single.routePoints.last.speedMetersPerSecond, 2.8);
    expect(restored.records.single.routePoints.last.altitudeMeters, 18.5);
    expect(restored.records.single.trainingPlanId, 'morning-activation');
    expect(restored.records.single.completedActions, 4);
    expect(restored.records.single.plannedActions, 6);
  });

  test('TrainingPlanStore persists and restores custom plans', () async {
    SharedPreferences.setMockInitialValues({});
    final persistence = SharedPreferencesTrainingPlanPersistence();
    final original = TrainingPlanStore(persistence: persistence);
    await original.restore();

    const plan = TrainingPlan(
      id: 'custom-plan',
      name: '测试计划',
      description: '自定义动作组合',
      rounds: 4,
      restBetweenRoundsSeconds: 60,
      difficulty: '中级',
      scheduledWeekdays: [1, 3, 5],
      actions: [
        TrainingAction(
          id: 'test-plank',
          name: '平板支撑',
          muscle: '核心稳定',
          workSeconds: 45,
          restSeconds: 30,
        ),
      ],
    );
    await original.save(plan);

    final restored = TrainingPlanStore(persistence: persistence);
    await restored.restore();
    final actual =
        restored.plans.firstWhere((item) => item.id == 'custom-plan');
    expect(actual.name, '测试计划');
    expect(actual.rounds, 4);
    expect(actual.actions.single.workSeconds, 45);
    expect(actual.scheduledWeekdays, [1, 3, 5]);
    expect(actual.scheduleLabel, '周一、周三、周五');
  });

  test('RouteStore saves a recorded route for reuse', () async {
    SharedPreferences.setMockInitialValues({});
    final persistence = SharedPreferencesRoutePersistence();
    final original = RouteStore(persistence: persistence);

    await original.save(const RouteSummary(
      id: 'record-route-test',
      name: '周末慢跑',
      distanceMeters: 4800,
      estimatedMinutes: 30,
      tags: ['跑步', '我的记录'],
      points: [
        LocationPoint(latitude: 31.2304, longitude: 121.4737),
        LocationPoint(latitude: 31.2322, longitude: 121.4780),
      ],
      isSaved: true,
    ));

    final restored = RouteStore(persistence: persistence);
    await restored.restore();
    final route =
        restored.routes.firstWhere((item) => item.id == 'record-route-test');
    expect(route.name, '周末慢跑');
    expect(route.isSaved, isTrue);
    expect(route.points, hasLength(2));
  });

  test('WorkoutRecord derives pace, climb and GPS quality', () {
    final record = WorkoutRecord(
      id: 'metrics-test',
      activity: ActivityType.run,
      startedAt: DateTime(2026, 9, 15),
      duration: const Duration(minutes: 10),
      distanceMeters: 1500,
      routePoints: const [
        LocationPoint(
          latitude: 31.2304,
          longitude: 121.4737,
          accuracy: 8,
          altitudeMeters: 12,
        ),
        LocationPoint(
          latitude: 31.2322,
          longitude: 121.4780,
          accuracy: 12,
          altitudeMeters: 30,
        ),
        LocationPoint(
          latitude: 31.2290,
          longitude: 121.4835,
          accuracy: 10,
          altitudeMeters: 22,
        ),
      ],
    );

    expect(record.averageSpeedMetersPerSecond, 2.5);
    expect(record.elevationGainMeters, 18);
    expect(record.averageAccuracyMeters, 10);
  });

  testWidgets('Workout detail shows kilometre split pace', (tester) async {
    final record = WorkoutRecord(
      id: 'split-test',
      activity: ActivityType.run,
      startedAt: DateTime(2026, 9, 15, 8),
      duration: const Duration(minutes: 12),
      distanceMeters: 1500,
      routePoints: [
        LocationPoint(
          latitude: 31.2304,
          longitude: 121.4737,
          timestamp: DateTime(2026, 9, 15, 8),
        ),
        LocationPoint(
          latitude: 31.2322,
          longitude: 121.4830,
          timestamp: DateTime(2026, 9, 15, 8, 8),
        ),
        LocationPoint(
          latitude: 31.2290,
          longitude: 121.4880,
          timestamp: DateTime(2026, 9, 15, 8, 12),
        ),
      ],
    );

    await tester.pumpWidget(MaterialApp(
      home: WorkoutDetailPage(record: record),
    ));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView), const Offset(0, -620));
    await tester.pump();

    expect(find.text('分段配速'), findsOneWidget);
    expect(find.text('1 km'), findsOneWidget);
    expect(find.text('最后'), findsOneWidget);
  });
}
