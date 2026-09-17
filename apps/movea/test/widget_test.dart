import 'dart:async';
import 'dart:convert';

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

class _FakeDeviceWorkoutRepository implements DeviceWorkoutRepository {
  @override
  Future<List<WorkoutRecord>> readRecentWorkouts({int days = 30}) async => [
        WorkoutRecord(
          id: 'healthkit-device-workout',
          activity: ActivityType.run,
          startedAt: DateTime(2026, 9, 15, 7, 30),
          duration: const Duration(minutes: 36),
          distanceMeters: 6200,
          sourceDevice: 'Apple Watch',
          dataSource: WorkoutDataSource.healthKit,
          sourceWorkoutId: 'device-workout',
          averageHeartRateBpm: 148,
          maximumHeartRateBpm: 171,
          activeEnergyKilocalories: 438,
          heartRateSamples: const [
            HeartRateSample(offset: Duration.zero, bpm: 112),
            HeartRateSample(offset: Duration(seconds: 10), bpm: 132),
            HeartRateSample(offset: Duration(seconds: 20), bpm: 148),
            HeartRateSample(offset: Duration(seconds: 30), bpm: 166),
          ],
        ),
      ];
}

class _GatedActiveWorkoutPersistence implements ActiveWorkoutPersistence {
  final Completer<void> writeGate = Completer<void>();
  ActiveWorkoutDraft? stored;
  int writes = 0;
  int clears = 0;

  @override
  Future<ActiveWorkoutDraft?> read() async => stored;

  @override
  Future<void> write(ActiveWorkoutDraft draft) async {
    writes++;
    await writeGate.future;
    stored = draft;
  }

  @override
  Future<void> clear() async {
    clears++;
    stored = null;
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
    await tester.tap(find.text('开始运动'));
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
    expect(find.text('路线概览'), findsOneWidget);
    await tester.drag(find.byType(ListView).last, const Offset(0, -700));
    await tester.pumpAndSettle();
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

    expect(find.text('运动记录'), findsOneWidget);
    expect(find.text('还没有运动记录'), findsOneWidget);
    expect(find.text('本周运动概览'), findsOneWidget);

    await tester.drag(find.byType(ListView).first, const Offset(0, -420));
    await tester.pumpAndSettle();

    expect(find.text('训练日历'), findsOneWidget);
    expect(find.text('运动周报'), findsOneWidget);
    expect(find.text('运动状态'), findsOneWidget);
    expect(find.text('设备运动'), findsOneWidget);

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

  testWidgets('Device workouts are previewed and explicitly imported',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final store = WorkoutStore();
    await store.restore();
    await tester.pumpWidget(MaterialApp(
      home: DeviceWorkoutImportPage(
        store: store,
        repository: _FakeDeviceWorkoutRepository(),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('从设备导入'), findsOneWidget);
    expect(find.text('读取 HealthKit 运动'), findsOneWidget);
    expect(store.records, isEmpty);

    await tester.tap(find.text('读取 HealthKit 运动'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Apple Watch'), findsOneWidget);
    expect(find.textContaining('均值 148 次/分'), findsOneWidget);
    expect(store.records, isEmpty);

    await tester.tap(find.text('导入'));
    await tester.pumpAndSettle();
    expect(store.records, hasLength(1));
    expect(store.records.single.dataSource, WorkoutDataSource.healthKit);
    expect(store.records.single.heartRateSamples, hasLength(4));
    expect(find.text('已同步'), findsOneWidget);
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

  testWidgets('Settings save and preview personalized heart rate zones',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final store = TrainingProfileStore();
    await store.restore();
    await tester.pumpWidget(
      MaterialApp(home: SettingsPage(profileStore: store)),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('maximum-heart-rate-edit')));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byKey(const ValueKey('maximum-heart-rate-input')), '190');
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();

    expect(store.profile.maximumHeartRateBpm, 190);
    expect(find.text('190 bpm · 个性化 5 区'), findsOneWidget);
    expect(find.text('114–132 bpm'), findsOneWidget);
    expect(find.text('≥ 171 bpm'), findsOneWidget);
  });

  testWidgets('Settings persist route haptics and voice preferences',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final profileStore = TrainingProfileStore();
    final routePreferencesStore = RouteGuidancePreferencesStore();
    await profileStore.restore();
    await routePreferencesStore.restore();
    await tester.pumpWidget(
      RouteGuidancePreferencesScope(
        notifier: routePreferencesStore,
        child: MaterialApp(
          home: SettingsPage(profileStore: profileStore),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(routePreferencesStore.preferences.hapticsEnabled, isTrue);
    await tester.tap(find.byKey(const ValueKey('route-haptics-toggle')));
    await tester.pumpAndSettle();
    expect(routePreferencesStore.preferences.hapticsEnabled, isFalse);
    expect(routePreferencesStore.preferences.voiceEnabled, isFalse);
    await tester.tap(find.byKey(const ValueKey('route-voice-toggle')));
    await tester.pumpAndSettle();
    expect(routePreferencesStore.preferences.voiceEnabled, isTrue);
    expect(routePreferencesStore.preferences.hapticsEnabled, isFalse);

    final restored = RouteGuidancePreferencesStore();
    await restored.restore();
    expect(restored.preferences.hapticsEnabled, isFalse);
    expect(restored.preferences.voiceEnabled, isTrue);
  });

  testWidgets('Movea activity flow supports type, pause, finish and history',
      (tester) async {
    await pumpMobile(tester);
    await tester.tap(find.text('运动').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('开始运动'));
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
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pumpAndSettle();
    expect(find.text('运动总结'), findsOneWidget);
    expect(find.text('运动已保存'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('GPS 数据质量'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('GPS 数据质量'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('完成'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('完成'));
    await tester.pumpAndSettle();
    expect(find.text('运动记录'), findsOneWidget);
    await tester.tap(find.text('全部 1 条'));
    await tester.pumpAndSettle();
    expect(find.text('全部运动记录'), findsOneWidget);
    expect(find.text('骑行'), findsNWidgets(2));
    expect(find.byType(ListTile), findsOneWidget);

    await tester.ensureVisible(find.widgetWithText(ChoiceChip, 'HealthKit'));
    await tester.pump();
    await tester.tap(find.widgetWithText(ChoiceChip, 'HealthKit'));
    await tester.pump();
    expect(find.text('还没有符合条件的运动记录'), findsOneWidget);
    await tester.ensureVisible(find.widgetWithText(ChoiceChip, 'Movea GPS'));
    await tester.pump();
    await tester.tap(find.widgetWithText(ChoiceChip, 'Movea GPS'));
    await tester.pump();
    expect(find.byType(ListTile), findsOneWidget);

    await tester.tap(find.byType(ListTile));
    await tester.pumpAndSettle();
    expect(find.text('运动详情'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('实际 GPS 轨迹'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('实际 GPS 轨迹'), findsOneWidget);
    expect(find.text('本地已保存'), findsOneWidget);
  });

  testWidgets('Movea activity can minimize and restore a live session',
      (tester) async {
    await pumpMobile(tester);
    await tester.tap(find.text('运动').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('开始运动'));
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
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pumpAndSettle();
    expect(find.text('运动总结'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('完成'),
      500,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(find.text('完成'));
    await tester.pump();
    await tester.tap(find.text('完成'));
    await tester.pumpAndSettle();
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
    await tester.tap(find.text('开始运动'));
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
      discardedLocationSamples: 3,
      perceivedEffort: WorkoutEffort.hard,
      dataSource: WorkoutDataSource.healthKit,
      sourceWorkoutId: 'healthkit-persistence-test',
      averageHeartRateBpm: 142,
      maximumHeartRateBpm: 169,
      activeEnergyKilocalories: 512,
      heartRateSamples: const [
        HeartRateSample(offset: Duration.zero, bpm: 118),
        HeartRateSample(offset: Duration(seconds: 12), bpm: 145),
      ],
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
    expect(restored.records.single.discardedLocationSamples, 3);
    expect(restored.records.single.perceivedEffort, WorkoutEffort.hard);
    expect(restored.records.single.subjectiveTrainingLoad, 294);
    expect(restored.records.single.dataSource, WorkoutDataSource.healthKit);
    expect(
        restored.records.single.sourceWorkoutId, 'healthkit-persistence-test');
    expect(restored.records.single.averageHeartRateBpm, 142);
    expect(restored.records.single.maximumHeartRateBpm, 169);
    expect(restored.records.single.activeEnergyKilocalories, 512);
    expect(restored.records.single.heartRateSamples, hasLength(2));
    expect(restored.records.single.heartRateSamples.last.bpm, 145);
  });

  test('Workout archive rejects a modified payload', () {
    final record = WorkoutRecord(
      id: 'archive-checksum',
      activity: ActivityType.run,
      startedAt: DateTime(2026, 9, 17, 7),
      duration: const Duration(minutes: 20),
      distanceMeters: 3200,
    );
    const codec = WorkoutArchiveCodec();
    final archive = codec.encode(
      [record],
      createdAt: DateTime.utc(2026, 9, 17),
    );
    final decoded = codec.decode(archive);
    expect(decoded.isValid, isTrue);
    expect(decoded.records.single.id, record.id);

    final envelope = jsonDecode(archive) as Map<String, dynamic>;
    envelope['checksum'] = List.filled(64, '0').join();
    final tampered = codec.decode(jsonEncode(envelope));
    expect(tampered.isValid, isFalse);
    expect(tampered.error, 'checksum mismatch');
  });

  test('Encrypted backup round-trips and rejects the wrong passphrase',
      () async {
    SharedPreferences.setMockInitialValues({
      SharedPreferencesWorkoutPersistence.storageKey: [
        jsonEncode({
          'id': 'encrypted-workout',
          'activity': 'run',
          'startedAt': DateTime(2026, 9, 17, 7).toIso8601String(),
          'durationSeconds': 1800,
          'distanceMeters': 5000,
          'routePoints': const [],
          'sourceDevice': 'iPhone',
        }),
      ],
      'movea.routes.v1': jsonEncode([
        {'id': 'route-one'}
      ]),
      'movea.training_plans.v1': jsonEncode([
        {'id': 'plan-one'},
        {'id': 'plan-two'},
      ]),
      SharedPreferencesTrainingProfilePersistence.storageKey: 190,
    });
    final service = EncryptedBackupService();
    final archive = await service.createArchive(
      passphrase: 'correct horse battery staple',
      createdAt: DateTime.utc(2026, 9, 17, 9, 30),
    );

    expect(archive, isNot(contains('encrypted-workout')));
    final decrypted = await service.inspectArchive(
      archive: archive,
      passphrase: 'correct horse battery staple',
    );
    expect(decrypted.manifest.workoutCount, 1);
    expect(decrypted.manifest.routeCount, 1);
    expect(decrypted.manifest.trainingPlanCount, 2);
    expect(decrypted.manifest.includesTrainingProfile, isTrue);
    expect(
      decrypted.preferences[SharedPreferencesWorkoutPersistence.storageKey],
      hasLength(1),
    );

    await expectLater(
      service.inspectArchive(
        archive: archive,
        passphrase: 'definitely the wrong password',
      ),
      throwsA(
        isA<EncryptedBackupException>().having(
          (error) => error.message,
          'message',
          contains('口令错误'),
        ),
      ),
    );

    final preferences = await SharedPreferences.getInstance();
    await preferences.setStringList(
      SharedPreferencesWorkoutPersistence.storageKey,
      ['newer-local-record-that-will-be-replaced'],
    );
    await preferences.setInt(
      SharedPreferencesTrainingProfilePersistence.storageKey,
      175,
    );
    await preferences.setBool(
      SharedPreferencesRouteGuidancePreferencesPersistence.hapticsKey,
      true,
    );
    final restoredManifest = await service.restoreArchive(
      archive: archive,
      passphrase: 'correct horse battery staple',
    );
    expect(restoredManifest.workoutCount, 1);
    expect(
      preferences
          .getStringList(
            SharedPreferencesWorkoutPersistence.storageKey,
          )!
          .single,
      contains('encrypted-workout'),
    );
    expect(
      preferences.getInt(
        SharedPreferencesTrainingProfilePersistence.storageKey,
      ),
      190,
    );
    expect(
      preferences.getBool(
        SharedPreferencesRouteGuidancePreferencesPersistence.hapticsKey,
      ),
      isNull,
    );
  });

  test('Workout storage detects corruption and repairs from its snapshot',
      () async {
    SharedPreferences.setMockInitialValues({});
    final persistence = SharedPreferencesWorkoutPersistence();
    final record = WorkoutRecord(
      id: 'recoverable-record',
      activity: ActivityType.ride,
      startedAt: DateTime(2026, 9, 17, 8),
      duration: const Duration(minutes: 40),
      distanceMeters: 12000,
    );
    await persistence.write([record]);
    final preferences = await SharedPreferences.getInstance();
    await preferences.setStringList(
      SharedPreferencesWorkoutPersistence.storageKey,
      ['not-json'],
    );

    final report = await persistence.inspectIntegrity();
    expect(report.status, WorkoutDataIntegrityStatus.recoverable);
    expect(report.invalidPrimaryRecordCount, 1);
    expect(report.recoveryRecordCount, 1);
    expect((await persistence.read()).single.id, record.id);

    final store = WorkoutStore(persistence: persistence);
    await store.restore();
    expect(store.records.single.id, record.id);
    expect(await store.repairFromRecoverySnapshot(), isTrue);
    final repaired = await persistence.inspectIntegrity();
    expect(repaired.status, WorkoutDataIntegrityStatus.healthy);
    expect(repaired.primaryRecordCount, 1);
  });

  test('WorkoutStore de-duplicates imported source workouts', () async {
    SharedPreferences.setMockInitialValues({});
    final store = WorkoutStore();
    await store.restore();
    WorkoutRecord imported(String id) => WorkoutRecord(
          id: id,
          activity: ActivityType.run,
          startedAt: DateTime(2026, 9, 15),
          duration: const Duration(minutes: 30),
          distanceMeters: 5000,
          dataSource: WorkoutDataSource.healthKit,
          sourceWorkoutId: 'same-healthkit-uuid',
        );

    expect(await store.importAndPersist([imported('first')]), 1);
    expect(await store.importAndPersist([imported('second')]), 0);
    expect(store.records, hasLength(1));
  });

  test('WorkoutStore enriches a device workout without losing feedback',
      () async {
    SharedPreferences.setMockInitialValues({});
    final store = WorkoutStore();
    await store.restore();
    final startedAt = DateTime(2026, 9, 15);
    await store.importAndPersist([
      WorkoutRecord(
        id: 'healthkit-enrichment',
        activity: ActivityType.run,
        startedAt: startedAt,
        duration: const Duration(minutes: 30),
        distanceMeters: 5000,
        dataSource: WorkoutDataSource.healthKit,
        sourceWorkoutId: 'enrichment-uuid',
      ),
    ]);
    await store.updateAndPersist(
      store.records.single.copyWith(perceivedEffort: WorkoutEffort.moderate),
    );

    final changed = await store.importAndPersist([
      WorkoutRecord(
        id: 'healthkit-enrichment',
        activity: ActivityType.run,
        startedAt: startedAt,
        duration: const Duration(minutes: 30),
        distanceMeters: 5000,
        dataSource: WorkoutDataSource.healthKit,
        sourceWorkoutId: 'enrichment-uuid',
        averageHeartRateBpm: 146,
        heartRateSamples: const [
          HeartRateSample(offset: Duration.zero, bpm: 132),
          HeartRateSample(offset: Duration(seconds: 10), bpm: 146),
        ],
      ),
    ]);

    expect(changed, 1);
    expect(store.records.single.averageHeartRateBpm, 146);
    expect(store.records.single.heartRateSamples, hasLength(2));
    expect(store.records.single.perceivedEffort, WorkoutEffort.moderate);
  });

  test('Heart rate samples produce bounded observed band durations', () {
    final record = WorkoutRecord(
      id: 'heart-rate-bands',
      activity: ActivityType.run,
      startedAt: DateTime(2026, 9, 16),
      duration: const Duration(minutes: 10),
      distanceMeters: 1800,
      heartRateSamples: const [
        HeartRateSample(offset: Duration.zero, bpm: 110),
        HeartRateSample(offset: Duration(seconds: 10), bpm: 128),
        HeartRateSample(offset: Duration(seconds: 25), bpm: 148),
        HeartRateSample(offset: Duration(minutes: 2), bpm: 168),
        HeartRateSample(offset: Duration(minutes: 2, seconds: 20), bpm: 165),
      ],
    );

    expect(record.heartRateBandDurations[HeartRateBand.easy],
        const Duration(seconds: 10));
    expect(record.heartRateBandDurations[HeartRateBand.aerobic],
        const Duration(seconds: 15));
    expect(record.heartRateBandDurations[HeartRateBand.tempo],
        const Duration(seconds: 30));
    expect(record.heartRateBandDurations[HeartRateBand.high],
        const Duration(seconds: 20));
    expect(record.heartRateObservedDuration, const Duration(seconds: 75));
  });

  test('Maximum heart rate produces personalized five-zone durations', () {
    final definitions = heartRateZonesForMaximum(190);
    expect(definitions.map((item) => item.rangeLabel),
        ['< 114', '114–132', '133–151', '152–170', '≥ 171']);

    final record = WorkoutRecord(
      id: 'personalized-heart-rate-zones',
      activity: ActivityType.run,
      startedAt: DateTime(2026, 9, 16),
      duration: const Duration(minutes: 5),
      distanceMeters: 1000,
      heartRateSamples: const [
        HeartRateSample(offset: Duration.zero, bpm: 105),
        HeartRateSample(offset: Duration(seconds: 10), bpm: 120),
        HeartRateSample(offset: Duration(seconds: 25), bpm: 140),
        HeartRateSample(offset: Duration(minutes: 2), bpm: 160),
        HeartRateSample(offset: Duration(minutes: 2, seconds: 20), bpm: 180),
        HeartRateSample(offset: Duration(minutes: 2, seconds: 30), bpm: 150),
      ],
    );

    final zones = record.heartRateZoneDurations(190);
    expect(zones[HeartRateZone.recovery], const Duration(seconds: 10));
    expect(zones[HeartRateZone.easy], const Duration(seconds: 15));
    expect(zones[HeartRateZone.aerobic], const Duration(seconds: 30));
    expect(zones[HeartRateZone.threshold], const Duration(seconds: 20));
    expect(zones[HeartRateZone.high], const Duration(seconds: 10));
  });

  test('Training profile maximum heart rate persists locally', () async {
    SharedPreferences.setMockInitialValues({});
    final original = TrainingProfileStore();
    await original.restore();
    await original.setMaximumHeartRate(190);

    final restored = TrainingProfileStore();
    await restored.restore();
    expect(restored.profile.maximumHeartRateBpm, 190);

    await restored.setMaximumHeartRate(null);
    final cleared = TrainingProfileStore();
    await cleared.restore();
    expect(cleared.profile.maximumHeartRateBpm, isNull);
  });

  test('ActiveWorkoutStore restores an unfinished GPS workout', () async {
    SharedPreferences.setMockInitialValues({});
    final persistence = SharedPreferencesActiveWorkoutPersistence();
    final original = ActiveWorkoutStore(persistence: persistence);
    final startedAt = DateTime(2026, 9, 16, 7, 30);
    final updatedAt = startedAt.add(const Duration(minutes: 18));

    await original.save(ActiveWorkoutDraft(
      activity: ActivityType.run,
      startedAt: startedAt,
      updatedAt: updatedAt,
      pausedDuration: const Duration(minutes: 2),
      distanceMeters: 2650,
      routeId: 'park-loop',
      discardedLocationSamples: 2,
      routePoints: const [
        LocationPoint(latitude: 31.2304, longitude: 121.4737),
        LocationPoint(latitude: 31.2322, longitude: 121.4780),
      ],
    ));

    final restored = ActiveWorkoutStore(persistence: persistence);
    await restored.restore();
    expect(restored.draft, isNotNull);
    expect(restored.draft!.activity, ActivityType.run);
    expect(restored.draft!.routeId, 'park-loop');
    expect(restored.draft!.routePoints, hasLength(2));
    expect(restored.draft!.discardedLocationSamples, 2);
    expect(restored.draft!.savedElapsed, const Duration(minutes: 16));

    await restored.clear();
    final cleared = ActiveWorkoutStore(persistence: persistence);
    await cleared.restore();
    expect(cleared.draft, isNull);
  });

  test('ActiveWorkoutStore coalesces GPS drafts and clears after writes',
      () async {
    final persistence = _GatedActiveWorkoutPersistence();
    final store = ActiveWorkoutStore(persistence: persistence);
    final startedAt = DateTime(2026, 9, 16, 7, 30);
    ActiveWorkoutDraft draft(int pointCount) => ActiveWorkoutDraft(
          activity: ActivityType.run,
          startedAt: startedAt,
          updatedAt: startedAt.add(Duration(seconds: pointCount)),
          pausedDuration: Duration.zero,
          distanceMeters: pointCount * 10,
          routePoints: List.generate(
            pointCount,
            (index) => LocationPoint(
              latitude: 31.2304 + index * .0001,
              longitude: 121.4737,
            ),
          ),
        );

    final firstSave = store.save(draft(1));
    await Future<void>.delayed(Duration.zero);
    final supersededSave = store.save(draft(2));
    final clear = store.clear();
    persistence.writeGate.complete();
    await Future.wait([firstSave, supersededSave, clear]);

    expect(persistence.writes, 1);
    expect(persistence.clears, 1);
    expect(persistence.stored, isNull);
    expect(store.draft, isNull);
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

  test('RouteSummary derives difficulty, shape, pace and hydration guidance',
      () {
    const route = RouteSummary(
      id: 'route-insight',
      name: '测试环线',
      distanceMeters: 5000,
      estimatedMinutes: 30,
      elevationMeters: 80,
      tags: ['简单'],
      points: [
        LocationPoint(latitude: 31.2304, longitude: 121.4737),
        LocationPoint(latitude: 31.2340, longitude: 121.4780),
        LocationPoint(latitude: 31.2304, longitude: 121.4737),
      ],
    );

    expect(route.difficultyLabel, '轻松');
    expect(route.shapeLabel, '环线');
    expect(route.estimatedPaceLabel, "6'00\" /km");
    expect(route.climbPerKilometer, 16);
    expect(route.hydrationAdvice, contains('出发前补水'));

    const challenge = RouteSummary(
      id: 'route-challenge',
      name: '长距离爬升',
      distanceMeters: 15000,
      estimatedMinutes: 95,
      elevationMeters: 420,
    );
    expect(challenge.difficultyLabel, '挑战');
    expect(challenge.shapeLabel, '点到点');
    expect(challenge.hydrationAdvice, contains('能量补给'));
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
      perceivedEffort: WorkoutEffort.moderate,
    );

    expect(record.averageSpeedMetersPerSecond, 2.5);
    expect(record.elevationGainMeters, 18);
    expect(record.averageAccuracyMeters, 10);
    expect(record.gpsQualityLabel, '优秀');
    expect(record.subjectiveTrainingLoad, 40);
  });

  test('Route guidance projects progress and finds the next right turn', () {
    const route = [
      LocationPoint(latitude: 0, longitude: 0),
      LocationPoint(latitude: 0.001, longitude: 0),
      LocationPoint(latitude: 0.001, longitude: 0.001),
    ];

    final guidance = calculateRouteGuidance(
      const LocationPoint(latitude: 0.0005, longitude: 0),
      route,
    );

    expect(guidance.isOffRoute, isFalse);
    expect(guidance.maneuver, RouteManeuver.right);
    expect(guidance.distanceToManeuverMeters, closeTo(55.6, 2));
    expect(guidance.progress, closeTo(.25, .02));
    expect(guidance.remainingMeters, closeTo(166.8, 4));
  });

  test('Route guidance distinguishes off-route and arrival states', () {
    const route = [
      LocationPoint(latitude: 0, longitude: 0),
      LocationPoint(latitude: 0.001, longitude: 0),
      LocationPoint(latitude: 0.001, longitude: 0.001),
    ];

    final offRoute = calculateRouteGuidance(
      const LocationPoint(latitude: 0.0005, longitude: 0.002),
      route,
    );
    final arriving = calculateRouteGuidance(
      const LocationPoint(latitude: 0.001, longitude: 0.0009),
      route,
    );

    expect(offRoute.isOffRoute, isTrue);
    expect(offRoute.distanceToRouteMeters, greaterThan(80));
    expect(arriving.isOffRoute, isFalse);
    expect(arriving.maneuver, RouteManeuver.arrive);
    expect(arriving.remainingMeters, lessThan(25));
  });

  test('Route guidance cues trigger once for turns and route transitions', () {
    final tracker = RouteGuidanceCueTracker();
    RouteGuidance guidance({
      required double distanceToRoute,
      required double distanceToManeuver,
      required RouteManeuver maneuver,
      int segment = 0,
    }) =>
        RouteGuidance(
          distanceToRouteMeters: distanceToRoute,
          progress: .4,
          remainingMeters: 200,
          distanceToManeuverMeters: distanceToManeuver,
          maneuver: maneuver,
          segmentIndex: segment,
        );

    expect(
      tracker.update(guidance(
        distanceToRoute: 5,
        distanceToManeuver: 100,
        maneuver: RouteManeuver.right,
      )),
      isNull,
    );
    expect(
      tracker.update(guidance(
        distanceToRoute: 5,
        distanceToManeuver: 50,
        maneuver: RouteManeuver.right,
      )),
      RouteGuidanceCue.turnRight,
    );
    expect(
      tracker.update(guidance(
        distanceToRoute: 5,
        distanceToManeuver: 30,
        maneuver: RouteManeuver.right,
      )),
      isNull,
    );
    expect(
      tracker.update(guidance(
        distanceToRoute: 120,
        distanceToManeuver: 20,
        maneuver: RouteManeuver.right,
      )),
      RouteGuidanceCue.offRoute,
    );
    expect(
      tracker.update(guidance(
        distanceToRoute: 110,
        distanceToManeuver: 20,
        maneuver: RouteManeuver.right,
      )),
      isNull,
    );
    expect(
      tracker.update(guidance(
        distanceToRoute: 8,
        distanceToManeuver: 20,
        maneuver: RouteManeuver.right,
      )),
      RouteGuidanceCue.backOnRoute,
    );
    expect(
      tracker.update(guidance(
        distanceToRoute: 4,
        distanceToManeuver: 12,
        maneuver: RouteManeuver.arrive,
        segment: 1,
      )),
      RouteGuidanceCue.arriving,
    );
    expect(
      tracker.update(guidance(
        distanceToRoute: 4,
        distanceToManeuver: 8,
        maneuver: RouteManeuver.arrive,
        segment: 1,
      )),
      isNull,
    );
  });

  test('Location samples reject invalid coordinates and Null Island', () {
    expect(
      const LocationPoint(latitude: 31.2304, longitude: 121.4737)
          .hasUsableCoordinate,
      isTrue,
    );
    expect(
      const LocationPoint(latitude: 0, longitude: 0).hasUsableCoordinate,
      isFalse,
    );
    expect(
      const LocationPoint(latitude: 95, longitude: 121).hasUsableCoordinate,
      isFalse,
    );
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
    await tester.scrollUntilVisible(
      find.text('分段配速'),
      400,
      scrollable: find.byType(Scrollable).first,
    );

    expect(find.text('分段配速'), findsOneWidget);
    expect(find.text('1 km'), findsOneWidget);
    expect(find.text('最后'), findsOneWidget);
  });

  testWidgets('Workout detail renders real heart rate samples', (tester) async {
    final record = WorkoutRecord(
      id: 'heart-rate-detail',
      activity: ActivityType.run,
      startedAt: DateTime(2026, 9, 15, 8),
      duration: const Duration(minutes: 30),
      distanceMeters: 5000,
      dataSource: WorkoutDataSource.healthKit,
      sourceWorkoutId: 'heart-rate-detail',
      averageHeartRateBpm: 145,
      maximumHeartRateBpm: 169,
      heartRateSamples: const [
        HeartRateSample(offset: Duration.zero, bpm: 112),
        HeartRateSample(offset: Duration(minutes: 5), bpm: 132),
        HeartRateSample(offset: Duration(minutes: 12), bpm: 148),
        HeartRateSample(offset: Duration(minutes: 20), bpm: 165),
        HeartRateSample(offset: Duration(minutes: 29), bpm: 142),
      ],
    );

    await tester
        .pumpWidget(MaterialApp(home: WorkoutDetailPage(record: record)));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('设备心率曲线'),
      320,
      scrollable: find.byType(Scrollable).first,
    );

    expect(find.text('设备心率曲线'), findsOneWidget);
    expect(find.text('5 个 HealthKit 采样点'), findsOneWidget);
    expect(find.text('轻松'), findsOneWidget);
    expect(find.text('高强'), findsOneWidget);
  });

  testWidgets('Workout detail uses configured personalized heart rate zones',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final profileStore = TrainingProfileStore();
    await profileStore.restore();
    await profileStore.setMaximumHeartRate(190);
    final record = WorkoutRecord(
      id: 'personalized-heart-rate-detail',
      activity: ActivityType.run,
      startedAt: DateTime(2026, 9, 16, 8),
      duration: const Duration(minutes: 30),
      distanceMeters: 5000,
      dataSource: WorkoutDataSource.healthKit,
      heartRateSamples: const [
        HeartRateSample(offset: Duration.zero, bpm: 105),
        HeartRateSample(offset: Duration(seconds: 10), bpm: 120),
        HeartRateSample(offset: Duration(seconds: 20), bpm: 140),
        HeartRateSample(offset: Duration(seconds: 30), bpm: 160),
        HeartRateSample(offset: Duration(seconds: 40), bpm: 180),
        HeartRateSample(offset: Duration(seconds: 50), bpm: 150),
      ],
    );

    await tester.pumpWidget(
      TrainingProfileScope(
        notifier: profileStore,
        child: MaterialApp(home: WorkoutDetailPage(record: record)),
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('设备心率曲线'),
      320,
      scrollable: find.byType(Scrollable).first,
    );

    expect(find.text('恢复'), findsOneWidget);
    expect(find.text('阈值'), findsOneWidget);
    expect(find.textContaining('最大心率 190 bpm'), findsOneWidget);
  });

  testWidgets('Workout feedback persists subjective training load',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final store = WorkoutStore();
    await store.restore();
    final record = WorkoutRecord(
      id: 'effort-test',
      activity: ActivityType.strength,
      startedAt: DateTime(2026, 9, 16, 18),
      duration: const Duration(minutes: 12),
      distanceMeters: 0,
    );
    await store.addAndPersist(record);

    await tester.pumpWidget(MaterialApp(
      home: WorkoutDetailPage(record: record, workoutStore: store),
    ));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('适中'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(find.text('适中'));
    await tester.pump();
    await tester.tap(find.text('适中'));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pumpAndSettle();

    expect(find.text('主观负荷 48'), findsOneWidget);
    expect(store.records.single.perceivedEffort, WorkoutEffort.moderate);
    expect(store.records.single.subjectiveTrainingLoad, 48);
  });
}
