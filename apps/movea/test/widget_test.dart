import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movea_data/movea_data.dart';
import 'package:movea_domain/movea_domain.dart';
import 'package:movea/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> pumpMobile(WidgetTester tester) async {
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

  testWidgets('Movea can open the activity page', (tester) async {
    await pumpMobile(tester);
    await tester.tap(find.text('运动').last);
    await tester.pumpAndSettle();

    expect(find.text('准备好了吗？'), findsOneWidget);
    expect(find.text('开始跑步'), findsOneWidget);
  });

  testWidgets('Movea can switch every primary tab', (tester) async {
    await pumpMobile(tester);

    await tester.tap(find.text('健康').last);
    await tester.pumpAndSettle();
    expect(find.text('昨晚睡眠'), findsOneWidget);

    await tester.tap(find.text('路线').last);
    await tester.pumpAndSettle();
    expect(find.text('公园环线'), findsOneWidget);
    expect(find.byType(FlutterMap), findsNWidgets(2));

    await tester.tap(find.text('学习').last);
    await tester.pumpAndSettle();
    expect(find.text('跑前热身'), findsOneWidget);
  });

  testWidgets('Movea activity flow supports type, pause, finish and history',
      (tester) async {
    await pumpMobile(tester);
    await tester.tap(find.text('运动').last);
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(ChoiceChip, '🚴 骑行'));
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
    await tester.pumpAndSettle();
    expect(find.text('查看全部运动记录'), findsOneWidget);

    await tester.tap(find.text('查看全部运动记录'));
    await tester.pumpAndSettle();
    expect(find.text('全部运动记录'), findsOneWidget);
    expect(find.text('骑行'), findsNWidgets(2));
    expect(find.byType(ListTile), findsOneWidget);
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
    await tester.pumpAndSettle();
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
    ));
    await Future<void>.delayed(Duration.zero);

    final restored = WorkoutStore(persistence: persistence);
    await restored.restore();
    expect(restored.records, hasLength(1));
    expect(restored.records.single.activity, ActivityType.ride);
    expect(restored.records.single.duration, const Duration(minutes: 42));
    expect(restored.records.single.distanceMeters, 12300);
  });
}
