import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:latlong2/latlong.dart' show LatLng;
import 'package:maplibre/maplibre.dart' as ml;
import 'package:movea_data/movea_data.dart';
import 'package:movea_design/movea_design.dart';
import 'package:movea_domain/movea_domain.dart';

import 'platform/platform_adapters.dart';
import 'exercise_catalog.dart';

bool get _isFlutterTest => WidgetsBinding.instance.runtimeType
    .toString()
    .contains('TestWidgetsFlutterBinding');

class ActivitySessionSnapshot {
  const ActivitySessionSnapshot({
    required this.activity,
    required this.elapsed,
    required this.distanceMeters,
    required this.paused,
  });

  final ActivityType activity;
  final Duration elapsed;
  final double distanceMeters;
  final bool paused;
}

class MoveaShell extends StatefulWidget {
  const MoveaShell({super.key});

  @override
  State<MoveaShell> createState() => _MoveaShellState();
}

class _MoveaShellState extends State<MoveaShell> {
  final WorkoutStore store = WorkoutStore();
  final TrainingPlanStore planStore = TrainingPlanStore();
  final ExerciseCatalogStore exerciseStore = ExerciseCatalogStore();
  final RouteStore routeStore = RouteStore();
  final ActiveWorkoutStore activeWorkoutStore = ActiveWorkoutStore();
  late final HealthStore healthStore;
  int selectedIndex = 0;
  RouteSummary? selectedRoute;
  ActivityType? selectedActivity;
  ActivitySessionSnapshot? activeSession;
  bool activityFullscreen = false;
  late final LocationRepository locationRepository;

  @override
  void initState() {
    super.initState();
    unawaited(store.restore());
    unawaited(planStore.restore());
    if (!_isFlutterTest) unawaited(exerciseStore.load());
    unawaited(routeStore.restore());
    locationRepository = _isFlutterTest
        ? UnsupportedLocationRepository()
        : GeolocatorLocationRepository();
    healthStore = HealthStore(
      repository: _isFlutterTest
          ? UnsupportedHealthRepository()
          : PlatformHealthRepository(),
    );
    unawaited(healthStore.restore());
    unawaited(_restoreActiveWorkout());
  }

  Future<void> _restoreActiveWorkout() async {
    await Future.wait([
      activeWorkoutStore.restore(),
      routeStore.restore(),
    ]);
    final draft = activeWorkoutStore.draft;
    if (!mounted || draft == null) return;
    RouteSummary? route;
    if (draft.routeId != null) {
      for (final item in routeStore.routes) {
        if (item.id == draft.routeId) {
          route = item;
          break;
        }
      }
    }
    setState(() {
      selectedActivity = draft.activity;
      selectedRoute = route;
      activeSession = ActivitySessionSnapshot(
        activity: draft.activity,
        elapsed: draft.savedElapsed,
        distanceMeters: draft.distanceMeters,
        paused: true,
      );
      activityFullscreen = false;
    });
  }

  void openActivity() {
    if (selectedActivity != null) {
      restoreActivity();
      return;
    }
    setState(() {
      selectedIndex = 1;
      selectedRoute = null;
      selectedActivity = null;
      activityFullscreen = true;
    });
  }

  void openRoute(RouteSummary route) => setState(() {
        selectedRoute = route;
        selectedIndex = 1;
        selectedActivity = ActivityType.run;
        activityFullscreen = true;
      });

  void chooseActivity(ActivityType type) => setState(() {
        selectedActivity = type;
        activityFullscreen = true;
      });

  void clearRoute() => setState(() => selectedRoute = null);

  void openRouteLibrary() => setState(() {
        selectedIndex = 3;
        activityFullscreen = false;
      });

  void openHealth() => setState(() => selectedIndex = 2);

  void selectTab(int index) => setState(() {
        selectedIndex = index;
      });

  void minimizeActivity() => setState(() => activityFullscreen = false);

  void restoreActivity() => setState(() {
        selectedIndex = 1;
        activityFullscreen = true;
      });

  void updateActivitySession(ActivitySessionSnapshot? snapshot) {
    if (!mounted) return;
    setState(() => activeSession = snapshot);
  }

  void openHistory() {
    Navigator.of(context).push(MaterialPageRoute(
        builder: (_) =>
            WorkoutHistoryPage(store: store, routeStore: routeStore)));
  }

  Future<void> openSettings() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const SettingsPage(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      HomePage(
          store: store,
          routeStore: routeStore,
          onStart: openActivity,
          onHistory: openHistory,
          onHealth: openHealth,
          onSettings: openSettings,
          exerciseStore: exerciseStore,
          healthStore: healthStore),
      SportsDashboardPage(
          store: store,
          routeStore: routeStore,
          planStore: planStore,
          exerciseStore: exerciseStore,
          onStart: openActivity),
      HealthPage(store: healthStore),
      RoutesPage(store: routeStore, onFollow: openRoute),
      const LearnPage(),
    ];
    final isWide = MediaQuery.sizeOf(context).width >= 700;
    final activityOverlay = _ActivityOverlay(
      selectedActivity: selectedActivity,
      selectedRoute: selectedRoute,
      store: store,
      routeStore: routeStore,
      planStore: planStore,
      exerciseStore: exerciseStore,
      activeWorkoutStore: activeWorkoutStore,
      locationRepository: locationRepository,
      onSelectActivity: chooseActivity,
      onMinimize: minimizeActivity,
      onSessionChanged: updateActivitySession,
      onClearRoute: clearRoute,
      onChooseRoute: openRouteLibrary,
      onChangeActivity: () => setState(() => selectedActivity = null),
    );

    final content = isWide
        ? Row(
            children: [
              if (!activityFullscreen) ...[
                _MoveaWideNavigation(
                    selectedIndex: selectedIndex, onSelected: selectTab),
                const VerticalDivider(width: 1),
              ],
              Expanded(
                child: SafeArea(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1280),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          IndexedStack(index: selectedIndex, children: pages),
                          if (selectedActivity != null || activityFullscreen)
                            Offstage(
                              offstage: !activityFullscreen,
                              child: activityOverlay,
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          )
        : SafeArea(
            child: Stack(
              fit: StackFit.expand,
              children: [
                IndexedStack(index: selectedIndex, children: pages),
                if (selectedActivity != null || activityFullscreen)
                  Offstage(
                    offstage: !activityFullscreen,
                    child: activityOverlay,
                  ),
              ],
            ),
          );
    final showNavigation = !activityFullscreen;

    return Scaffold(
      body: Stack(
        children: [
          content,
          if (activeSession != null && !activityFullscreen)
            Positioned(
              left: isWide
                  ? (MediaQuery.sizeOf(context).width >= 1100 ? 248 : 104)
                  : 16,
              right: 16,
              bottom: 16,
              child: Align(
                alignment: Alignment.bottomRight,
                child: ConstrainedBox(
                  constraints:
                      BoxConstraints(maxWidth: isWide ? 420 : double.infinity),
                  child: _GlobalActivityMiniPlayer(
                    snapshot: activeSession!,
                    onTap: restoreActivity,
                  ),
                ),
              ),
            ),
        ],
      ),
      bottomNavigationBar: isWide || !showNavigation
          ? null
          : NavigationBar(
              selectedIndex: selectedIndex,
              onDestinationSelected: selectTab,
              destinations: const [
                NavigationDestination(
                    icon: Icon(Icons.home_outlined),
                    selectedIcon: Icon(Icons.home),
                    label: '首页'),
                NavigationDestination(
                    icon: Icon(Icons.directions_run_outlined),
                    selectedIcon: Icon(Icons.directions_run),
                    label: '运动'),
                NavigationDestination(
                    icon: Icon(Icons.favorite_border),
                    selectedIcon: Icon(Icons.favorite),
                    label: '健康'),
                NavigationDestination(
                    icon: Icon(Icons.map_outlined),
                    selectedIcon: Icon(Icons.map),
                    label: '路线'),
                NavigationDestination(
                    icon: Icon(Icons.menu_book_outlined),
                    selectedIcon: Icon(Icons.menu_book),
                    label: '学习'),
              ],
            ),
    );
  }
}

class _ActivityOverlay extends StatelessWidget {
  const _ActivityOverlay({
    required this.selectedActivity,
    required this.selectedRoute,
    required this.store,
    required this.routeStore,
    required this.planStore,
    required this.exerciseStore,
    required this.activeWorkoutStore,
    required this.locationRepository,
    required this.onSelectActivity,
    required this.onMinimize,
    required this.onSessionChanged,
    required this.onClearRoute,
    required this.onChooseRoute,
    required this.onChangeActivity,
  });

  final ActivityType? selectedActivity;
  final RouteSummary? selectedRoute;
  final WorkoutStore store;
  final RouteStore routeStore;
  final TrainingPlanStore planStore;
  final ExerciseCatalogStore exerciseStore;
  final ActiveWorkoutStore activeWorkoutStore;
  final LocationRepository locationRepository;
  final ValueChanged<ActivityType> onSelectActivity;
  final VoidCallback onMinimize;
  final ValueChanged<ActivitySessionSnapshot?> onSessionChanged;
  final VoidCallback onClearRoute;
  final VoidCallback onChooseRoute;
  final VoidCallback onChangeActivity;

  @override
  Widget build(BuildContext context) {
    final activity = selectedActivity;
    if (activity == null) {
      return ActivityPickerPage(
        onSelect: onSelectActivity,
        onMinimize: onMinimize,
      );
    }
    return ActivityPage(
      store: store,
      routeStore: routeStore,
      planStore: planStore,
      exerciseStore: exerciseStore,
      activeWorkoutStore: activeWorkoutStore,
      locationRepository: locationRepository,
      selectedRoute: selectedRoute,
      initialActivity: activity,
      fullscreen: true,
      onMinimize: onMinimize,
      onSessionChanged: onSessionChanged,
      onClearRoute: onClearRoute,
      onChooseRoute: onChooseRoute,
      onChangeActivity: onChangeActivity,
      showMap: true,
    );
  }
}

class ActivityPickerPage extends StatelessWidget {
  const ActivityPickerPage({
    required this.onSelect,
    required this.onMinimize,
    super.key,
  });

  final ValueChanged<ActivityType> onSelect;
  final VoidCallback onMinimize;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('开始运动'),
        actions: [
          IconButton(
            onPressed: onMinimize,
            tooltip: '返回运动概览',
            icon: const Icon(Icons.close),
          ),
        ],
      ),
      body: MoveaContentFrame(
        maxWidth: 920,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 32),
          children: [
            const Text('选择今天的运动',
                style: TextStyle(fontSize: 25, fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            const Text('选定运动类型后，再进入对应的准备和记录页面。',
                style: TextStyle(color: Colors.black54)),
            const SizedBox(height: 22),
            const Text('户外运动',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
            const SizedBox(height: 10),
            LayoutBuilder(
              builder: (context, constraints) {
                final columns = constraints.maxWidth >= 680 ? 2 : 1;
                return GridView.count(
                  crossAxisCount: columns,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: columns == 2 ? 2.7 : 3.2,
                  children: [
                    _ActivityOptionCard(
                      activity: ActivityType.run,
                      title: '户外跑',
                      subtitle: '记录 GPS 轨迹、距离和配速',
                      color: moveaCoral,
                      onTap: () => onSelect(ActivityType.run),
                    ),
                    _ActivityOptionCard(
                      activity: ActivityType.ride,
                      title: '户外骑行',
                      subtitle: '记录骑行路线、速度和爬升',
                      color: const Color(0xFF69C58A),
                      onTap: () => onSelect(ActivityType.ride),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 24),
            const Text('室内训练',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
            const SizedBox(height: 10),
            LayoutBuilder(
              builder: (context, constraints) {
                final columns = constraints.maxWidth >= 680 ? 2 : 1;
                return GridView.count(
                  crossAxisCount: columns,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: columns == 2 ? 2.7 : 3.2,
                  children: [
                    _ActivityOptionCard(
                      activity: ActivityType.strength,
                      title: '力量训练',
                      subtitle: '开始一套训练计划或自由训练',
                      color: moveaLavender,
                      onTap: () => onSelect(ActivityType.strength),
                    ),
                    _ActivityOptionCard(
                      activity: ActivityType.stretch,
                      title: '拉伸恢复',
                      subtitle: '记录一段拉伸和恢复时间',
                      color: moveaMint,
                      onTap: () => onSelect(ActivityType.stretch),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 20),
            const Card(
              color: moveaLemon,
              child: ListTile(
                leading: Icon(Icons.route_outlined),
                title: Text('路线是可选项'),
                subtitle: Text('进入户外运动准备页后，可选择已保存路线进行跟随。'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActivityOptionCard extends StatelessWidget {
  const _ActivityOptionCard({
    required this.activity,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  final ActivityType activity;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: color,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: Colors.white.withValues(alpha: .78),
                child:
                    Text(activity.icon, style: const TextStyle(fontSize: 20)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(fontWeight: FontWeight.w800)),
                    const SizedBox(height: 3),
                    Text(subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 12, color: Colors.black54)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}

class _MoveaWideNavigation extends StatelessWidget {
  const _MoveaWideNavigation(
      {required this.selectedIndex, required this.onSelected});

  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final extended = MediaQuery.sizeOf(context).width >= 1100;
    return Container(
      width: extended ? 232 : 88,
      color: Colors.white,
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(
                  extended ? 22 : 16, 20, extended ? 22 : 16, 16),
              child: Row(
                mainAxisAlignment: extended
                    ? MainAxisAlignment.start
                    : MainAxisAlignment.center,
                children: [
                  const CircleAvatar(
                      radius: 18,
                      backgroundColor: moveaCoral,
                      child: Icon(Icons.route, color: Colors.white, size: 20)),
                  if (extended) ...[
                    const SizedBox(width: 10),
                    const Text('动迹',
                        style: TextStyle(
                            color: moveaInk,
                            fontSize: 20,
                            fontWeight: FontWeight.w800)),
                  ],
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 16),
                children: [
                  _WideNavigationItem(
                      icon: Icons.home_outlined,
                      selectedIcon: Icons.home,
                      label: '首页',
                      selected: selectedIndex == 0,
                      extended: extended,
                      onTap: () => onSelected(0)),
                  _WideNavigationItem(
                      icon: Icons.directions_run_outlined,
                      selectedIcon: Icons.directions_run,
                      label: '运动',
                      selected: selectedIndex == 1,
                      extended: extended,
                      onTap: () => onSelected(1)),
                  _WideNavigationItem(
                      icon: Icons.favorite_border,
                      selectedIcon: Icons.favorite,
                      label: '健康',
                      selected: selectedIndex == 2,
                      extended: extended,
                      onTap: () => onSelected(2)),
                  _WideNavigationItem(
                      icon: Icons.map_outlined,
                      selectedIcon: Icons.map,
                      label: '路线',
                      selected: selectedIndex == 3,
                      extended: extended,
                      onTap: () => onSelected(3)),
                  _WideNavigationItem(
                      icon: Icons.menu_book_outlined,
                      selectedIcon: Icons.menu_book,
                      label: '学习',
                      selected: selectedIndex == 4,
                      extended: extended,
                      onTap: () => onSelected(4)),
                ],
              ),
            ),
            if (extended)
              const Padding(
                padding: EdgeInsets.all(20),
                child: Text('个人运动与健康',
                    style: TextStyle(fontSize: 12, color: Colors.black45)),
              ),
          ],
        ),
      ),
    );
  }
}

class _WideNavigationItem extends StatelessWidget {
  const _WideNavigationItem(
      {required this.icon,
      required this.selectedIcon,
      required this.label,
      required this.selected,
      required this.extended,
      required this.onTap});

  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final bool selected;
  final bool extended;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Tooltip(
        message: label,
        child: Material(
          color: Colors.white,
          child: ListTile(
            onTap: onTap,
            selected: selected,
            selectedColor: moveaCoral,
            tileColor: selected ? const Color(0xFFFFE8E2) : null,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            contentPadding: EdgeInsets.symmetric(
                horizontal: extended ? 14 : 20, vertical: 4),
            leading: Icon(selected ? selectedIcon : icon),
            title: extended
                ? Text(label,
                    style: const TextStyle(fontWeight: FontWeight.w700))
                : null,
          ),
        ),
      ),
    );
  }
}

class _GlobalActivityMiniPlayer extends StatelessWidget {
  const _GlobalActivityMiniPlayer({
    required this.snapshot,
    required this.onTap,
  });

  final ActivitySessionSnapshot snapshot;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      elevation: 8,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
          child: Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: moveaCoral.withValues(alpha: .14),
                child: Text(snapshot.activity.icon),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      snapshot.paused
                          ? '${snapshot.activity.label} · 已暂停'
                          : '${snapshot.activity.label} · 正在记录',
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${formatDuration(snapshot.elapsed)}  ·  ${(snapshot.distanceMeters / 1000).toStringAsFixed(2)} km',
                      style:
                          const TextStyle(fontSize: 12, color: Colors.black54),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.open_in_full, color: moveaBlue),
            ],
          ),
        ),
      ),
    );
  }
}

class MoveaContentFrame extends StatelessWidget {
  const MoveaContentFrame(
      {required this.child, this.maxWidth = 760, super.key});

  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}

class SportsDashboardPage extends StatelessWidget {
  const SportsDashboardPage({
    required this.store,
    required this.routeStore,
    required this.planStore,
    required this.exerciseStore,
    required this.onStart,
    super.key,
  });

  final WorkoutStore store;
  final RouteStore routeStore;
  final TrainingPlanStore planStore;
  final ExerciseCatalogStore exerciseStore;
  final VoidCallback onStart;

  void openHistory(BuildContext context) {
    Navigator.of(context).push(MaterialPageRoute(
        builder: (_) =>
            WorkoutHistoryPage(store: store, routeStore: routeStore)));
  }

  void openPlans(BuildContext context) {
    Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => TrainingPlansPage(
            store: planStore,
            workoutStore: store,
            exerciseStore: exerciseStore)));
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([store, planStore]),
      builder: (context, _) {
        final records = store.records;
        final weekStart = DateTime.now()
            .subtract(Duration(days: DateTime.now().weekday - DateTime.monday));
        final weekRecords = records
            .where((record) => !record.startedAt.isBefore(
                DateTime(weekStart.year, weekStart.month, weekStart.day)))
            .toList(growable: false);
        final weekMinutes = weekRecords.fold<int>(
            0, (total, record) => total + record.duration.inMinutes);
        final weekDistance = weekRecords.fold<double>(
                0, (total, record) => total + record.distanceMeters) /
            1000;
        final outdoorCount =
            weekRecords.where((record) => record.activity.usesLocation).length;

        return MoveaContentFrame(
          maxWidth: 1120,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 22, 20, 32),
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text('运动',
                        style: TextStyle(
                            fontSize: 30, fontWeight: FontWeight.w800)),
                  ),
                  FilledButton.icon(
                    onPressed: onStart,
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('开始运动'),
                    style: FilledButton.styleFrom(
                      backgroundColor: moveaCoral,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 5),
              const Text('记录每一次训练，看看身体正在变得怎样。',
                  style: TextStyle(color: Colors.black54)),
              const SizedBox(height: 18),
              Row(
                children: [
                  const Expanded(child: MoveaSectionTitle('运动记录')),
                  TextButton(
                    onPressed: () => openHistory(context),
                    child: Text(
                        records.isEmpty ? '查看全部' : '全部 ${records.length} 条'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (records.isEmpty)
                Card(
                  color: moveaLavender,
                  child: ListTile(
                    leading: const CircleAvatar(
                      backgroundColor: Colors.white,
                      child: Icon(Icons.route_outlined, color: moveaBlue),
                    ),
                    title: const Text('还没有运动记录',
                        style: TextStyle(fontWeight: FontWeight.w800)),
                    subtitle: const Text('点击右上角“开始运动”，完成后会在这里生成记录。'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: onStart,
                  ),
                )
              else
                for (final record in records.take(3))
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _RecentWorkoutCard(
                      record: record,
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => WorkoutDetailPage(
                            record: record,
                            routeStore: routeStore,
                          ),
                        ),
                      ),
                    ),
                  ),
              const SizedBox(height: 20),
              const MoveaSectionTitle('本周运动概览'),
              const SizedBox(height: 10),
              LayoutBuilder(
                builder: (context, constraints) {
                  final columns = constraints.maxWidth >= 760 ? 4 : 2;
                  return GridView.count(
                    crossAxisCount: columns,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    childAspectRatio: columns == 4 ? 1.65 : 1.8,
                    children: [
                      _SportsStatCard(
                          label: '运动次数',
                          value: '${weekRecords.length}',
                          note: '本周',
                          color: moveaLavender),
                      _SportsStatCard(
                          label: '运动时长',
                          value: '$weekMinutes',
                          note: '分钟',
                          color: moveaMint),
                      _SportsStatCard(
                          label: '户外距离',
                          value: weekDistance == 0
                              ? '--'
                              : weekDistance.toStringAsFixed(1),
                          note: weekDistance == 0 ? '等待记录' : '公里',
                          color: moveaLemon),
                      _SportsStatCard(
                          label: '户外运动',
                          value: '$outdoorCount',
                          note: '次',
                          color: const Color(0xFFFFE8E2)),
                    ],
                  );
                },
              ),
              const SizedBox(height: 20),
              const MoveaSectionTitle('运动分析'),
              const SizedBox(height: 10),
              LayoutBuilder(
                builder: (context, constraints) {
                  final columns = constraints.maxWidth >= 760 ? 3 : 1;
                  return GridView.count(
                    crossAxisCount: columns,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    childAspectRatio: columns == 3 ? 2.2 : 4.2,
                    children: [
                      _SportsHubLink(
                          icon: Icons.calendar_month_outlined,
                          title: '训练日历',
                          subtitle: '查看计划与完成情况',
                          onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                  builder: (_) => TrainingCalendarPage(
                                      store: store,
                                      planStore: planStore,
                                      exerciseStore: exerciseStore,
                                      routeStore: routeStore)))),
                      _SportsHubLink(
                          icon: Icons.bar_chart_outlined,
                          title: '运动周报',
                          subtitle: '汇总本周运动趋势',
                          onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                  builder: (_) => WorkoutWeeklyReportPage(
                                      store: store, routeStore: routeStore)))),
                      _SportsHubLink(
                          icon: Icons.insights_outlined,
                          title: '运动状态',
                          subtitle: '频率、距离与恢复提醒',
                          onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                  builder: (_) =>
                                      WorkoutStatusPage(store: store)))),
                    ],
                  );
                },
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  const Expanded(child: MoveaSectionTitle('训练计划')),
                  TextButton(
                      onPressed: () => openPlans(context),
                      child: const Text('管理计划')),
                ],
              ),
              const SizedBox(height: 8),
              if (planStore.plans.isEmpty)
                Card(
                  color: moveaMint,
                  child: ListTile(
                    leading: const Icon(Icons.playlist_add),
                    title: const Text('创建一套可重复训练的计划'),
                    subtitle: const Text('选择动作、组数、每组时长和休息时间'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => openPlans(context),
                  ),
                )
              else
                for (final plan in planStore.plans.take(2))
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Card(
                      child: ListTile(
                        leading: const CircleAvatar(
                            backgroundColor: moveaLavender,
                            child: Icon(Icons.fitness_center, color: moveaInk)),
                        title: Text(plan.name,
                            style:
                                const TextStyle(fontWeight: FontWeight.w800)),
                        subtitle: Text(
                            '${plan.actions.length} 个动作 · ${plan.estimatedMinutes} 分钟 · ${plan.difficulty}'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                                builder: (_) => TrainingPlanDetailPage(
                                    store: planStore,
                                    workoutStore: store,
                                    exerciseStore: exerciseStore,
                                    plan: plan))),
                      ),
                    ),
                  ),
            ],
          ),
        );
      },
    );
  }
}

class _SportsStatCard extends StatelessWidget {
  const _SportsStatCard(
      {required this.label,
      required this.value,
      required this.note,
      required this.color});

  final String label;
  final String value;
  final String note;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: color,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(label,
                style: const TextStyle(fontSize: 12, color: Colors.black54)),
            const SizedBox(height: 7),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(value,
                    style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: moveaInk)),
                const SizedBox(width: 5),
                Padding(
                  padding: const EdgeInsets.only(bottom: 3),
                  child: Text(note,
                      style:
                          const TextStyle(fontSize: 11, color: Colors.black54)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SportsHubLink extends StatelessWidget {
  const _SportsHubLink(
      {required this.icon,
      required this.title,
      required this.subtitle,
      required this.onTap});

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              CircleAvatar(
                  backgroundColor: moveaLavender,
                  child: Icon(icon, color: moveaInk)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w800)),
                    const SizedBox(height: 4),
                    Text(subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 11, color: Colors.black54)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, size: 19),
            ],
          ),
        ),
      ),
    );
  }
}

class TrainingCalendarPage extends StatefulWidget {
  const TrainingCalendarPage({
    required this.store,
    required this.planStore,
    required this.exerciseStore,
    required this.routeStore,
    super.key,
  });

  final WorkoutStore store;
  final TrainingPlanStore planStore;
  final ExerciseCatalogStore exerciseStore;
  final RouteStore routeStore;

  @override
  State<TrainingCalendarPage> createState() => _TrainingCalendarPageState();
}

class _TrainingCalendarPageState extends State<TrainingCalendarPage> {
  late DateTime visibleMonth = _monthOf(DateTime.now());
  late DateTime selectedDate = _dateOf(DateTime.now());

  static DateTime _dateOf(DateTime date) =>
      DateTime(date.year, date.month, date.day);

  static DateTime _monthOf(DateTime date) => DateTime(date.year, date.month);

  bool _sameDate(DateTime left, DateTime right) =>
      left.year == right.year &&
      left.month == right.month &&
      left.day == right.day;

  List<WorkoutRecord> _recordsFor(DateTime date) => widget.store.records
      .where((record) => _sameDate(record.startedAt, date))
      .toList(growable: false);

  List<TrainingPlan> _plansFor(DateTime date) => widget.planStore.plans
      .where((plan) => plan.isScheduledOn(date))
      .toList(growable: false);

  bool _planCompletedOn(TrainingPlan plan, DateTime date) =>
      _recordsFor(date).any((record) => record.trainingPlanId == plan.id);

  void _changeMonth(int offset) {
    setState(() {
      visibleMonth = DateTime(visibleMonth.year, visibleMonth.month + offset);
      selectedDate = DateTime(visibleMonth.year, visibleMonth.month, 1);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('训练日历')),
      body: AnimatedBuilder(
        animation: Listenable.merge([widget.store, widget.planStore]),
        builder: (context, _) {
          final firstDay = DateTime(visibleMonth.year, visibleMonth.month, 1);
          final dayCount =
              DateTime(visibleMonth.year, visibleMonth.month + 1, 0).day;
          final cells = <Widget>[
            for (var index = 0; index < firstDay.weekday - 1; index++)
              const SizedBox.shrink(),
            for (var day = 1; day <= dayCount; day++)
              _CalendarDayCell(
                date: DateTime(visibleMonth.year, visibleMonth.month, day),
                selected: _sameDate(selectedDate,
                    DateTime(visibleMonth.year, visibleMonth.month, day)),
                records: _recordsFor(
                    DateTime(visibleMonth.year, visibleMonth.month, day)),
                plannedPlanCount: _plansFor(
                        DateTime(visibleMonth.year, visibleMonth.month, day))
                    .length,
                onTap: () => setState(() => selectedDate =
                    DateTime(visibleMonth.year, visibleMonth.month, day)),
              ),
          ];
          final selectedRecords = _recordsFor(selectedDate);
          final selectedMinutes = selectedRecords.fold<int>(
              0, (total, record) => total + record.duration.inMinutes);

          return MoveaContentFrame(
            maxWidth: 760,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 30),
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text('训练日历',
                          style: TextStyle(
                              fontSize: 24, fontWeight: FontWeight.w800)),
                    ),
                    IconButton(
                        onPressed: () => _changeMonth(-1),
                        tooltip: '上个月',
                        icon: const Icon(Icons.chevron_left)),
                    IconButton(
                        onPressed: () => _changeMonth(1),
                        tooltip: '下个月',
                        icon: const Icon(Icons.chevron_right)),
                  ],
                ),
                Text('${visibleMonth.year} 年 ${visibleMonth.month} 月',
                    style: const TextStyle(color: Colors.black54)),
                const SizedBox(height: 6),
                const Text('点选日期查看记录；蓝点是计划日，珊瑚色是已完成运动。',
                    style: TextStyle(color: Colors.black54)),
                const SizedBox(height: 18),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        const Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              Text('一'),
                              Text('二'),
                              Text('三'),
                              Text('四'),
                              Text('五'),
                              Text('六'),
                              Text('日'),
                            ]),
                        const SizedBox(height: 10),
                        GridView.count(
                          crossAxisCount: 7,
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          childAspectRatio: 1.05,
                          children: cells,
                        ),
                        const SizedBox(height: 12),
                        const Row(
                          children: [
                            CircleAvatar(
                                radius: 5, backgroundColor: moveaCoral),
                            SizedBox(width: 7),
                            Text('已完成运动'),
                            SizedBox(width: 18),
                            CircleAvatar(radius: 5, backgroundColor: moveaBlue),
                            SizedBox(width: 7),
                            Text('计划日'),
                            SizedBox(width: 18),
                            Icon(Icons.touch_app_outlined,
                                size: 16, color: Colors.black45),
                            SizedBox(width: 5),
                            Text('点选日期',
                                style: TextStyle(color: Colors.black54)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                if (_plansFor(selectedDate).isNotEmpty) ...[
                  const MoveaSectionTitle('今日计划'),
                  const SizedBox(height: 8),
                  for (final plan in _plansFor(selectedDate))
                    Card(
                      child: ListTile(
                        leading: const Icon(Icons.event_note_outlined,
                            color: moveaBlue),
                        title: Text(plan.name),
                        subtitle: Text(
                            '${plan.actions.length} 个动作 · ${plan.estimatedMinutes} 分钟 · ${plan.scheduleLabel}'),
                        trailing: _planCompletedOn(plan, selectedDate)
                            ? const Chip(
                                label: Text('已完成'),
                                backgroundColor: moveaMint,
                                side: BorderSide.none,
                              )
                            : const Icon(Icons.chevron_right),
                        onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                                builder: (_) => TrainingPlanDetailPage(
                                    store: widget.planStore,
                                    workoutStore: widget.store,
                                    exerciseStore: widget.exerciseStore,
                                    plan: plan))),
                      ),
                    ),
                  const SizedBox(height: 10),
                ],
                Card(
                  color: moveaMint,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${selectedDate.month} 月 ${selectedDate.day} 日',
                            style: const TextStyle(
                                fontSize: 18, fontWeight: FontWeight.w800)),
                        const SizedBox(height: 8),
                        if (selectedRecords.isEmpty)
                          const Text('当天还没有运动记录。')
                        else ...[
                          Text(
                              '${selectedRecords.length} 次运动 · $selectedMinutes 分钟'),
                          const SizedBox(height: 10),
                          for (final record in selectedRecords)
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: Text(record.activity.icon,
                                  style: const TextStyle(fontSize: 22)),
                              title: Text(record.activity.label),
                              subtitle: Text(
                                  '${formatDuration(record.duration)} · ${record.distanceLabel}'),
                              trailing: const Icon(Icons.chevron_right),
                              onTap: () => Navigator.of(context).push(
                                  MaterialPageRoute(
                                      builder: (_) => WorkoutDetailPage(
                                          record: record,
                                          routeStore: widget.routeStore))),
                            ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                const MoveaSectionTitle('训练计划'),
                const SizedBox(height: 8),
                if (widget.planStore.plans.isEmpty)
                  const Card(
                      child: Padding(
                          padding: EdgeInsets.all(18),
                          child: Text('还没有可排期的训练计划。')))
                else
                  for (final plan in widget.planStore.plans)
                    Card(
                      child: ListTile(
                        leading: const Icon(Icons.event_note_outlined),
                        title: Text(plan.name),
                        subtitle: Text(
                            '${plan.actions.length} 个动作 · ${plan.estimatedMinutes} 分钟 · ${plan.scheduleLabel}'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                                builder: (_) => TrainingPlanDetailPage(
                                    store: widget.planStore,
                                    workoutStore: widget.store,
                                    exerciseStore: widget.exerciseStore,
                                    plan: plan))),
                      ),
                    ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _CalendarDayCell extends StatelessWidget {
  const _CalendarDayCell({
    required this.date,
    required this.selected,
    required this.records,
    required this.plannedPlanCount,
    required this.onTap,
  });

  final DateTime date;
  final bool selected;
  final List<WorkoutRecord> records;
  final int plannedPlanCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final completed = records.isNotEmpty;
    final planned = plannedPlanCount > 0;
    return Padding(
      padding: const EdgeInsets.all(2),
      child: Material(
        color: selected
            ? moveaBlue.withValues(alpha: .14)
            : completed
                ? moveaCoral
                : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('${date.day}',
                  style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: completed && !selected ? Colors.white : moveaInk)),
              if (completed || planned)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (planned)
                      Container(
                          width: 5,
                          height: 5,
                          margin: const EdgeInsets.only(right: 3),
                          decoration: const BoxDecoration(
                              color: moveaBlue, shape: BoxShape.circle)),
                    if (completed)
                      Text('${records.length} 次',
                          style: TextStyle(
                              fontSize: 9,
                              color: completed && !selected
                                  ? Colors.white70
                                  : moveaBlue)),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class WorkoutWeeklyReportPage extends StatelessWidget {
  const WorkoutWeeklyReportPage({
    required this.store,
    required this.routeStore,
    super.key,
  });

  final WorkoutStore store;
  final RouteStore routeStore;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final weekStart = DateTime(now.year, now.month, now.day)
        .subtract(Duration(days: now.weekday - 1));
    final records = store.records
        .where((record) => !record.startedAt.isBefore(weekStart))
        .toList(growable: false);
    final minutes = records.fold<int>(
        0, (total, record) => total + record.duration.inMinutes);
    final distance = records.fold<double>(
            0, (total, record) => total + record.distanceMeters) /
        1000;
    final dailyMinutes = List<int>.generate(7, (index) {
      final day = weekStart.add(Duration(days: index));
      return records
          .where((record) =>
              record.startedAt.year == day.year &&
              record.startedAt.month == day.month &&
              record.startedAt.day == day.day)
          .fold<int>(0, (total, record) => total + record.duration.inMinutes);
    });
    final activityCounts = <ActivityType, int>{
      for (final type in ActivityType.values)
        type: records.where((record) => record.activity == type).length,
    };
    return Scaffold(
      appBar: AppBar(title: const Text('运动周报')),
      body: MoveaContentFrame(
        maxWidth: 760,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 30),
          children: [
            const Text('本周运动报告',
                style: TextStyle(fontSize: 25, fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            Text('${weekStart.month} 月 ${weekStart.day} 日起 · 基于已保存的运动记录',
                style: const TextStyle(color: Colors.black54)),
            const SizedBox(height: 18),
            Card(
              color: moveaInk,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    Expanded(
                        child: _ReportMetric(
                            value: '${records.length}', label: '运动次数')),
                    Expanded(
                        child: _ReportMetric(value: '$minutes', label: '运动分钟')),
                    Expanded(
                        child: _ReportMetric(
                            value: distance == 0
                                ? '--'
                                : distance.toStringAsFixed(1),
                            label: '户外公里')),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('每日运动时长',
                        style: TextStyle(fontWeight: FontWeight.w800)),
                    const SizedBox(height: 14),
                    _WeeklyMinutesChart(
                        weekStart: weekStart, dailyMinutes: dailyMinutes),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('运动类型分布',
                        style: TextStyle(fontWeight: FontWeight.w800)),
                    const SizedBox(height: 10),
                    if (records.isEmpty)
                      const Text('完成运动后，这里会显示跑步、骑行和训练的分布。',
                          style: TextStyle(color: Colors.black54))
                    else
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final entry in activityCounts.entries)
                            if (entry.value > 0)
                              Chip(
                                avatar: Text(entry.key.icon),
                                label:
                                    Text('${entry.key.label} ${entry.value} 次'),
                                backgroundColor: moveaLavender,
                                side: BorderSide.none,
                              ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              color: moveaMint,
              child: ListTile(
                leading: const Icon(Icons.auto_graph),
                title: Text(records.isEmpty ? '还没有本周运动' : '保持你的节奏'),
                subtitle: Text(records.isEmpty
                    ? '完成一次运动后，这里会生成你的周报。'
                    : '本周已经完成 ${records.length} 次运动，继续保持。'),
              ),
            ),
            if (records.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Text('本周记录',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              for (final record in records.take(3))
                Card(
                  child: ListTile(
                    leading: Text(record.activity.icon,
                        style: const TextStyle(fontSize: 21)),
                    title: Text(record.activity.label),
                    subtitle: Text(
                        '${record.startedAt.month} 月 ${record.startedAt.day} 日 · ${record.distanceLabel}'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => WorkoutDetailPage(
                            record: record, routeStore: routeStore))),
                  ),
                ),
            ],
            const SizedBox(height: 16),
            const Text('数据说明',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            const Card(
              child: ListTile(
                leading: Icon(Icons.info_outline),
                title: Text('只统计已保存的真实记录'),
                subtitle: Text('没有 GPS、心率或其他设备数据时，不会用演示数字填充。'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WeeklyMinutesChart extends StatelessWidget {
  const _WeeklyMinutesChart({
    required this.weekStart,
    required this.dailyMinutes,
  });

  final DateTime weekStart;
  final List<int> dailyMinutes;

  @override
  Widget build(BuildContext context) {
    final maxMinutes = dailyMinutes.fold<int>(
        0, (maximum, minutes) => minutes > maximum ? minutes : maximum);
    final scale = maxMinutes == 0 ? 1 : maxMinutes;
    const labels = '一二三四五六日';

    return SizedBox(
      height: 128,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var index = 0; index < dailyMinutes.length; index++)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: Column(
                  children: [
                    SizedBox(
                      height: 18,
                      child: Text(
                        dailyMinutes[index] == 0
                            ? ''
                            : '${dailyMinutes[index]}′',
                        style: const TextStyle(
                            fontSize: 10, color: Colors.black54),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    Expanded(
                      child: Align(
                        alignment: Alignment.bottomCenter,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 250),
                          width: 20,
                          height: 76 * dailyMinutes[index] / scale,
                          decoration: BoxDecoration(
                            color: dailyMinutes[index] == 0
                                ? Colors.black12
                                : moveaBlue,
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(labels[index],
                        style: const TextStyle(
                            fontSize: 11, color: Colors.black54)),
                    Text('${weekStart.add(Duration(days: index)).day}',
                        style: const TextStyle(
                            fontSize: 9, color: Colors.black38)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ReportMetric extends StatelessWidget {
  const _ReportMetric({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 26,
                fontWeight: FontWeight.w800)),
        const SizedBox(height: 5),
        Text(label, style: const TextStyle(color: Colors.white70)),
      ],
    );
  }
}

class WorkoutStatusPage extends StatelessWidget {
  const WorkoutStatusPage({required this.store, super.key});

  final WorkoutStore store;

  @override
  Widget build(BuildContext context) {
    final records = store.records;
    final last = records.isEmpty ? null : records.first;
    final outdoorDistance = store.outdoorDistanceMeters / 1000;
    return Scaffold(
      appBar: AppBar(title: const Text('运动状态')),
      body: MoveaContentFrame(
        maxWidth: 760,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 30),
          children: [
            const Text('运动状态',
                style: TextStyle(fontSize: 25, fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            const Text('先从实际运动记录开始，逐步形成你的个人趋势。',
                style: TextStyle(color: Colors.black54)),
            const SizedBox(height: 18),
            _StatusCard(
                icon: Icons.repeat,
                title: '运动频率',
                value: '${records.length} 次',
                note: records.isEmpty ? '完成一次运动后开始统计' : '累计已保存记录'),
            _StatusCard(
                icon: Icons.route_outlined,
                title: '户外距离',
                value: outdoorDistance == 0
                    ? '--'
                    : '${outdoorDistance.toStringAsFixed(1)} km',
                note: '来自 GPS 运动记录'),
            _StatusCard(
                icon: Icons.schedule,
                title: '最近一次运动',
                value: last == null ? '--' : last.activity.label,
                note: last == null
                    ? '还没有运动记录'
                    : '${last.startedAt.month} 月 ${last.startedAt.day} 日 · ${formatDuration(last.duration)}'),
            const SizedBox(height: 12),
            const Card(
              color: moveaLemon,
              child: ListTile(
                leading: Icon(Icons.health_and_safety_outlined),
                title: Text('心率、训练负荷和恢复状态'),
                subtitle: Text('等待接入 HealthKit 或运动设备数据后再进行计算。'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard(
      {required this.icon,
      required this.title,
      required this.value,
      required this.note});

  final IconData icon;
  final String title;
  final String value;
  final String note;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: CircleAvatar(
            backgroundColor: moveaLavender, child: Icon(icon, color: moveaInk)),
        title: Text(title),
        subtitle: Text(note),
        trailing: Text(value,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
      ),
    );
  }
}

class HomePage extends StatelessWidget {
  const HomePage(
      {required this.store,
      required this.routeStore,
      required this.exerciseStore,
      required this.onStart,
      required this.onHistory,
      required this.onHealth,
      required this.onSettings,
      required this.healthStore,
      super.key});

  final WorkoutStore store;
  final RouteStore routeStore;
  final ExerciseCatalogStore exerciseStore;
  final VoidCallback onStart;
  final VoidCallback onHistory;
  final VoidCallback onHealth;
  final VoidCallback onSettings;
  final HealthStore healthStore;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([store, healthStore]),
      builder: (context, _) {
        final records = store.records;
        final health = healthStore.snapshot;
        final outdoorDistance = store.outdoorDistanceMeters / 1000;
        final weeklyValue = outdoorDistance > 0
            ? '${outdoorDistance.toStringAsFixed(1)} km'
            : '${store.recordCount} 次';

        return MoveaContentFrame(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 22, 20, 24),
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text('今天想动一动吗？',
                        style: Theme.of(context)
                            .textTheme
                            .headlineMedium
                            ?.copyWith(
                                fontWeight: FontWeight.w800, color: moveaInk)),
                  ),
                  IconButton(
                    onPressed: onSettings,
                    tooltip: '设置',
                    icon: const Icon(Icons.settings_outlined),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              const Text('更健康的你，从今天开始',
                  style: TextStyle(color: Colors.black54)),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: onStart,
                icon: const Icon(Icons.play_arrow),
                label: const Text('开始运动',
                    style: TextStyle(fontWeight: FontWeight.w800)),
                style: FilledButton.styleFrom(
                    backgroundColor: moveaCoral,
                    minimumSize: const Size.fromHeight(58),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18))),
              ),
              const SizedBox(height: 10),
              Card(
                color: moveaLavender,
                child: ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Colors.white,
                    child: Icon(Icons.fitness_center, color: moveaInk),
                  ),
                  title: const Text('动作库',
                      style: TextStyle(fontWeight: FontWeight.w800)),
                  subtitle: const Text('浏览动作演示，找到适合今天的训练'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) =>
                          ExerciseLibraryPage(store: exerciseStore))),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: onHealth,
                      borderRadius: BorderRadius.circular(20),
                      child: _MetricCard(
                          title: '昨晚睡眠',
                          value: formatHoursMinutes(health.sleep.duration),
                          note:
                              '${health.sleep.quality} · ${health.sourceLabel}',
                          color: moveaMint),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: InkWell(
                      onTap: onHistory,
                      borderRadius: BorderRadius.circular(20),
                      child: _MetricCard(
                          title: '本周运动',
                          value: weeklyValue,
                          note: '查看全部记录',
                          color: moveaLemon),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: onHealth,
                      borderRadius: BorderRadius.circular(20),
                      child: _MetricCard(
                          title: '当前体重',
                          value: '${health.weightKg.toStringAsFixed(1)} kg',
                          note:
                              '较上周 ${health.weightChangeKg.toStringAsFixed(1)} kg · ${health.sourceLabel}',
                          color: moveaLavender),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: InkWell(
                      onTap: onHealth,
                      borderRadius: BorderRadius.circular(20),
                      child: _MetricCard(
                          title: '静息心率',
                          value: '${health.restingHeartRate} bpm',
                          note: '步数 ${health.steps} · ${health.sourceLabel}',
                          color: const Color(0xFFFFE8BF)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              const MoveaSectionTitle('本周进度', action: '4 / 7 天'),
              const SizedBox(height: 10),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: List.generate(
                          7,
                          (index) => _DayDot(
                              label: '一二三四五六日'[index], active: index < 4))),
                ),
              ),
              const SizedBox(height: 24),
              MoveaSectionTitle(records.isEmpty ? '为你推荐' : '最近运动',
                  action: records.isEmpty ? null : '共 ${records.length} 次'),
              const SizedBox(height: 10),
              if (records.isEmpty)
                Card(
                  color: moveaLemon,
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(16),
                    leading: const CircleAvatar(
                        backgroundColor: moveaCoral,
                        child: Icon(Icons.directions_run, color: Colors.white)),
                    title: const Text('轻松跑 30 分钟',
                        style: TextStyle(fontWeight: FontWeight.w800)),
                    subtitle: const Text('放松身体，保持节奏'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: onStart,
                  ),
                )
              else
                for (final record in records.take(3))
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _RecentWorkoutCard(
                      record: record,
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => WorkoutDetailPage(
                              record: record, routeStore: routeStore),
                        ),
                      ),
                    ),
                  ),
              if (records.isNotEmpty)
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: onHistory,
                    icon: const Icon(Icons.arrow_forward),
                    label: const Text('查看全部运动记录'),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _RecentWorkoutCard extends StatelessWidget {
  const _RecentWorkoutCard({required this.record, this.onTap});

  final WorkoutRecord record;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: CircleAvatar(
          backgroundColor: moveaLavender,
          child: Text(record.activity.icon),
        ),
        title: Text(record.activity.label,
            style: const TextStyle(fontWeight: FontWeight.w800)),
        subtitle: Text(
            '${record.startedAt.month}月${record.startedAt.day}日 · ${record.sourceDevice}'),
        trailing: Text(formatDuration(record.duration),
            style: const TextStyle(fontWeight: FontWeight.w800)),
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard(
      {required this.title,
      required this.value,
      required this.note,
      required this.color});

  final String title;
  final String value;
  final String note;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: color,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title,
              style: const TextStyle(
                  fontSize: 13,
                  color: Colors.black54,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 10),
          Text(value,
              style: const TextStyle(
                  fontSize: 22, fontWeight: FontWeight.w800, color: moveaInk)),
          const SizedBox(height: 4),
          Text(note,
              style: const TextStyle(fontSize: 12, color: Colors.black54)),
        ]),
      ),
    );
  }
}

class _DayDot extends StatelessWidget {
  const _DayDot({required this.label, required this.active});

  final String label;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      CircleAvatar(
          radius: 11, backgroundColor: active ? moveaCoral : Colors.black12),
      const SizedBox(height: 5),
      Text(label, style: const TextStyle(fontSize: 11, color: Colors.black54)),
    ]);
  }
}

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: MoveaContentFrame(
        maxWidth: 720,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
          children: [
            const Text('地图服务',
                style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: moveaInk)),
            const SizedBox(height: 6),
            const Text('Movea 使用 MapLibre 渲染地图，底图来自 OpenFreeMap。',
                style: TextStyle(color: Colors.black54)),
            const SizedBox(height: 18),
            const Card(
              color: moveaMint,
              child: ListTile(
                leading: Icon(Icons.public, color: moveaBlue),
                title: Text('OpenFreeMap 已启用'),
                subtitle: Text('无需 Key；地图样式和路线叠加由 Movea 自己控制'),
              ),
            ),
            const SizedBox(height: 16),
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('当前地图能力',
                        style: TextStyle(fontWeight: FontWeight.w800)),
                    SizedBox(height: 12),
                    _SettingRow(
                        icon: Icons.layers_outlined, text: '运动友好的自定义底图样式'),
                    _SettingRow(
                        icon: Icons.route_outlined, text: '路线、起点和终点独立渲染'),
                    _SettingRow(
                        icon: Icons.devices_outlined,
                        text: 'iPhone、iPad、Mac 共用地图配置'),
                    _SettingRow(
                        icon: Icons.download_outlined,
                        text: '后续可接入 Protomaps 离线地图'),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SettingRow extends StatelessWidget {
  const _SettingRow({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(children: [
        Icon(icon, size: 18, color: Colors.black54),
        const SizedBox(width: 10),
        Expanded(
          child: Text(text, style: const TextStyle(color: Colors.black87)),
        ),
      ]),
    );
  }
}

class ActivityPage extends StatefulWidget {
  const ActivityPage({
    required this.store,
    required this.routeStore,
    required this.planStore,
    required this.exerciseStore,
    required this.activeWorkoutStore,
    required this.locationRepository,
    required this.selectedRoute,
    required this.initialActivity,
    required this.fullscreen,
    required this.onMinimize,
    required this.onSessionChanged,
    required this.onClearRoute,
    required this.onChooseRoute,
    required this.onChangeActivity,
    required this.showMap,
    super.key,
  });

  final WorkoutStore store;
  final RouteStore routeStore;
  final TrainingPlanStore planStore;
  final ExerciseCatalogStore exerciseStore;
  final ActiveWorkoutStore activeWorkoutStore;
  final LocationRepository locationRepository;
  final RouteSummary? selectedRoute;
  final ActivityType initialActivity;
  final bool fullscreen;
  final VoidCallback onMinimize;
  final ValueChanged<ActivitySessionSnapshot?> onSessionChanged;
  final VoidCallback onClearRoute;
  final VoidCallback onChooseRoute;
  final VoidCallback onChangeActivity;
  final bool showMap;

  @override
  State<ActivityPage> createState() => _ActivityPageState();
}

class _ActivityPageState extends State<ActivityPage> {
  late ActivityType activity;
  DateTime? startedAt;
  DateTime? pausedAt;
  Duration pausedDuration = Duration.zero;
  Timer? timer;
  Duration elapsed = Duration.zero;
  bool paused = false;
  bool panelExpanded = true;
  bool locationStarting = false;
  bool recoveredSession = false;
  String? locationError;
  double distanceMeters = 0;
  final List<LocationPoint> livePoints = [];
  StreamSubscription<LocationPoint>? locationSubscription;

  @override
  void initState() {
    super.initState();
    activity = widget.initialActivity;
    final draft = widget.activeWorkoutStore.draft;
    if (draft != null && draft.activity == activity) {
      startedAt = draft.startedAt;
      pausedAt = draft.pausedAt ?? draft.updatedAt;
      pausedDuration = draft.pausedDuration;
      elapsed = draft.savedElapsed;
      paused = true;
      panelExpanded = true;
      recoveredSession = true;
      distanceMeters = draft.distanceMeters;
      livePoints.addAll(draft.routePoints);
      _startTicker();
      WidgetsBinding.instance.addPostFrameCallback((_) => _emitSessionState());
    }
  }

  bool get recording => startedAt != null;

  void _emitSessionState() {
    if (!mounted) return;
    widget.onSessionChanged(
      recording
          ? ActivitySessionSnapshot(
              activity: activity,
              elapsed: activeElapsed(),
              distanceMeters: distanceMeters,
              paused: paused,
            )
          : null,
    );
  }

  Future<void> start() async {
    timer?.cancel();
    locationError = null;
    setState(() {
      startedAt = DateTime.now();
      pausedAt = null;
      pausedDuration = Duration.zero;
      elapsed = Duration.zero;
      paused = false;
      recoveredSession = false;
      panelExpanded = false;
      locationStarting = activity.usesLocation;
      distanceMeters = 0;
      livePoints.clear();
    });
    _emitSessionState();
    unawaited(_persistDraft());

    if (activity.usesLocation) {
      locationSubscription ??=
          widget.locationRepository.points.listen(_onLocation);
      try {
        await widget.locationRepository.start();
      } on Object catch (error) {
        await _cancelLocationSubscription();
        if (!mounted) return;
        setState(() {
          startedAt = null;
          locationStarting = false;
          locationError = _locationErrorMessage(error);
        });
        unawaited(widget.activeWorkoutStore.clear());
        _emitSessionState();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(locationError!)),
        );
        return;
      }
      if (!mounted) return;
      setState(() => locationStarting = false);
      _emitSessionState();
    }

    _startTicker();
  }

  void _startTicker() {
    timer?.cancel();
    timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || startedAt == null || paused) return;
      setState(() => elapsed = activeElapsed());
      _emitSessionState();
    });
  }

  Future<void> _persistDraft() async {
    final startTime = startedAt;
    if (startTime == null) return;
    await widget.activeWorkoutStore.save(ActiveWorkoutDraft(
      activity: activity,
      startedAt: startTime,
      updatedAt: DateTime.now(),
      pausedAt: pausedAt,
      pausedDuration: pausedDuration,
      distanceMeters: distanceMeters,
      routeId: widget.selectedRoute?.id,
      routePoints: List.unmodifiable(livePoints),
    ));
  }

  String _locationErrorMessage(Object error) {
    final message = error is StateError ? error.message : error.toString();
    return message.toString().replaceFirst('Bad state: ', '');
  }

  double _currentPace() {
    if (livePoints.length < 2) {
      return _paceFromPoint(livePoints.isEmpty ? null : livePoints.last);
    }
    final startIndex = livePoints.length > 6 ? livePoints.length - 6 : 0;
    final window = livePoints.sublist(startIndex);
    final first = window.first;
    final last = window.last;
    final startTime = first.timestamp;
    final endTime = last.timestamp;
    if (startTime != null && endTime != null) {
      var distance = 0.0;
      for (var index = 1; index < window.length; index++) {
        distance += _distanceBetween(window[index - 1], window[index]);
      }
      final seconds = endTime.difference(startTime).inMilliseconds / 1000;
      if (distance >= 2 && seconds > 0) {
        return 1000 / (distance / seconds) / 60;
      }
    }
    return _paceFromPoint(last);
  }

  void _onLocation(LocationPoint point) {
    if (!mounted || startedAt == null || paused || !activity.usesLocation) {
      return;
    }
    final previous = livePoints.isEmpty ? null : livePoints.last;
    var step = 0.0;
    if (previous != null) {
      step = _distanceBetween(previous, point);
      // A sudden multi-hundred-metre jump is usually a bad GPS sample, not a
      // real running step. Keep the marker/track continuous instead.
      if (step > 250) return;
    }
    setState(() {
      livePoints.add(point);
      if (step >= 2) distanceMeters += step;
    });
    _emitSessionState();
    unawaited(_persistDraft());
  }

  Duration activeElapsed() {
    final startTime = startedAt;
    if (startTime == null) return Duration.zero;
    final currentPause =
        pausedAt == null ? Duration.zero : DateTime.now().difference(pausedAt!);
    return DateTime.now().difference(startTime) - pausedDuration - currentPause;
  }

  Future<void> togglePause() async {
    final now = DateTime.now();
    final shouldResume = paused;
    setState(() {
      if (shouldResume) {
        if (pausedAt != null) pausedDuration += now.difference(pausedAt!);
        pausedAt = null;
        paused = false;
        recoveredSession = false;
        elapsed = activeElapsed();
      } else {
        pausedAt = now;
        paused = true;
      }
    });
    _emitSessionState();
    if (!activity.usesLocation) {
      await _persistDraft();
      return;
    }
    if (shouldResume) {
      try {
        await widget.locationRepository.start();
      } on Object catch (error) {
        if (!mounted) return;
        setState(() {
          paused = true;
          pausedAt = DateTime.now();
          locationError = _locationErrorMessage(error);
        });
        _emitSessionState();
      }
    } else {
      await widget.locationRepository.stop();
    }
    await _persistDraft();
  }

  void finish() {
    final startTime = startedAt;
    if (startTime == null) return;
    if (activity.usesLocation) {
      unawaited(widget.locationRepository.stop());
    }
    final record = WorkoutRecord(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        activity: activity,
        startedAt: startTime,
        duration: activeElapsed(),
        distanceMeters: distanceMeters,
        routePoints: List.unmodifiable(livePoints));
    widget.store.add(record);
    unawaited(widget.activeWorkoutStore.clear());
    unawaited(_cancelLocationSubscription());
    timer?.cancel();
    setState(() {
      startedAt = null;
      pausedAt = null;
      pausedDuration = Duration.zero;
      elapsed = Duration.zero;
      paused = false;
      recoveredSession = false;
      panelExpanded = false;
      locationStarting = false;
      distanceMeters = 0;
      livePoints.clear();
    });
    _emitSessionState();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(activity.usesLocation
            ? '已保存${record.activity.label} · ${record.distanceLabel}'
            : '已保存${record.activity.label} · ${formatDuration(record.duration)}'),
      ),
    );
    widget.onMinimize();
  }

  Future<void> _cancelLocationSubscription() async {
    await locationSubscription?.cancel();
    locationSubscription = null;
  }

  Widget _buildLocationStatus() {
    final String label;
    final IconData icon;
    final Color color;
    if (locationError != null) {
      label = locationError!;
      icon = Icons.location_disabled_outlined;
      color = Colors.redAccent;
    } else if (recoveredSession && paused) {
      label = '已恢复上次运动 · 点击继续恢复 GPS 记录';
      icon = Icons.restore;
      color = moveaBlue;
    } else if (locationStarting || livePoints.isEmpty) {
      label = locationStarting ? '正在获取 GPS 定位…' : '等待 GPS 定位…';
      icon = Icons.gps_fixed;
      color = Colors.black54;
    } else if (widget.selectedRoute != null) {
      final guidance = _routeGuidance(widget.selectedRoute!, livePoints.last);
      label = guidance;
      icon = guidance.startsWith('偏离')
          ? Icons.near_me_disabled_outlined
          : Icons.navigation_outlined;
      color = guidance.startsWith('偏离') ? Colors.deepOrange : moveaBlue;
    } else {
      final accuracy = livePoints.last.accuracy;
      label = accuracy == null
          ? 'GPS 已定位 · 正在记录实时轨迹'
          : 'GPS 已定位 · 精度约 ${accuracy.round()} m';
      icon = Icons.gps_fixed;
      color = moveaBlue;
    }
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Row(
        children: [
          Icon(icon, size: 17, color: color),
          const SizedBox(width: 7),
          Expanded(
            child: Text(label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12, color: color)),
          ),
        ],
      ),
    );
  }

  String _routeGuidance(RouteSummary route, LocationPoint current) {
    final points = route.points;
    if (points.length < 2) return '已载入路线 · 等待更多路线点';
    final progress = _routeProgress(current, points);
    if (progress.distanceMeters > 80) {
      return '偏离计划路线 · ${_formatMeters(progress.distanceMeters)}';
    }
    return '沿计划路线 · 约 ${(progress.progress * 100).round()}% · '
        '${_formatMeters(progress.distanceMeters)}';
  }

  @override
  void dispose() {
    timer?.cancel();
    unawaited(widget.locationRepository.stop());
    unawaited(_cancelLocationSubscription());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Row(
            children: [
              Text(recording ? '正在记录' : activity.label,
                  style: const TextStyle(
                      fontSize: 20, fontWeight: FontWeight.w800)),
              const Spacer(),
              if (!recording)
                IconButton(
                  onPressed: widget.onChangeActivity,
                  tooltip: '更换运动',
                  icon: const Icon(Icons.swap_horiz),
                ),
              IconButton(
                onPressed: widget.onMinimize,
                tooltip: recording ? '缩小运动' : '退出全屏',
                icon: const Icon(Icons.fullscreen_exit),
              ),
            ],
          ),
        ),
        Expanded(
          child: _buildOutdoor(),
        ),
      ],
    );
  }

  Widget _buildOutdoor() {
    final plannedPoints = widget.selectedRoute?.points.isNotEmpty == true
        ? _toLatLngs(widget.selectedRoute!.points)
        : widget.selectedRoute == null
            ? const <LatLng>[]
            : _demoRoute;
    return Stack(
      alignment: Alignment.bottomCenter,
      children: [
        if (activity.usesLocation && widget.showMap)
          _MapPreview(
              plannedPoints: plannedPoints, livePoints: _toLatLngs(livePoints))
        else
          const ColoredBox(color: moveaPaper),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Align(
            alignment: Alignment.bottomCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: Card(
                clipBehavior: Clip.antiAlias,
                child: AnimatedSize(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOutCubic,
                  alignment: Alignment.bottomCenter,
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                        panelExpanded ? 18 : 14,
                        panelExpanded ? 16 : 10,
                        panelExpanded ? 18 : 14,
                        panelExpanded ? 12 : 10),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      InkWell(
                        onTap: () =>
                            setState(() => panelExpanded = !panelExpanded),
                        borderRadius: BorderRadius.circular(12),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: Row(children: [
                            Icon(
                                panelExpanded
                                    ? Icons.keyboard_arrow_down
                                    : Icons.keyboard_arrow_up,
                                color: moveaCoral),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                  activity.usesLocation
                                      ? (recording
                                          ? widget.selectedRoute == null
                                              ? '正在记录 · GPS 轨迹'
                                              : '正在跟随 · ${widget.selectedRoute!.name}'
                                          : widget.selectedRoute == null
                                              ? '地图已接入 · 尚未开始'
                                              : '跟随路线 · ${widget.selectedRoute!.name}')
                                      : '室内训练',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w700)),
                            ),
                            if (recording && activity.usesLocation)
                              Text(
                                  '${formatDuration(elapsed)}  ·  ${(distanceMeters / 1000).toStringAsFixed(2)} km',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w700)),
                            if (!recording)
                              Text(activity.label,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w700)),
                            if (!recording && widget.selectedRoute != null)
                              IconButton(
                                onPressed: widget.onClearRoute,
                                tooltip: '取消路线',
                                icon: const Icon(Icons.close, size: 18),
                                visualDensity: VisualDensity.compact,
                              ),
                          ]),
                        ),
                      ),
                      if (recording && !panelExpanded) ...[
                        if (activity.usesLocation) _buildLocationStatus(),
                        const SizedBox(height: 8),
                        Row(children: [
                          Expanded(
                              child: FilledButton.icon(
                                  onPressed: togglePause,
                                  icon: Icon(
                                      paused ? Icons.play_arrow : Icons.pause),
                                  label: Text(paused ? '继续' : '暂停'),
                                  style: FilledButton.styleFrom(
                                      backgroundColor: moveaCoral))),
                          const SizedBox(width: 8),
                          OutlinedButton(
                              onPressed: finish, child: const Text('结束')),
                        ]),
                      ],
                      if (panelExpanded) ...[
                        if (!recording) ...[
                          const SizedBox(height: 14),
                          if (activity.usesLocation) ...[
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                const Icon(Icons.alt_route,
                                    size: 18, color: moveaBlue),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    widget.selectedRoute == null
                                        ? '未选择计划路线'
                                        : widget.selectedRoute!.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.black54),
                                  ),
                                ),
                                TextButton.icon(
                                  onPressed: widget.onChooseRoute,
                                  style: TextButton.styleFrom(
                                      visualDensity: VisualDensity.compact,
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8)),
                                  icon:
                                      const Icon(Icons.map_outlined, size: 16),
                                  label: Text(widget.selectedRoute == null
                                      ? '选择路线'
                                      : '更换路线'),
                                ),
                              ],
                            ),
                            if (widget.selectedRoute != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: _RouteGuidanceCard(
                                  title: '路线引导已准备',
                                  description:
                                      '开始后将用 GPS 比较当前位置与“${widget.selectedRoute!.name}”，并提示沿线或偏离状态。',
                                ),
                              ),
                          ],
                        ],
                        const SizedBox(height: 18),
                        if (recording) ...[
                          if (recoveredSession) ...[
                            const _RecoveredWorkoutCard(),
                            const SizedBox(height: 14),
                          ],
                          if (activity.usesLocation)
                            Text(
                                '${(distanceMeters / 1000).toStringAsFixed(2)} km',
                                style: const TextStyle(
                                    fontSize: 46,
                                    fontWeight: FontWeight.w800,
                                    color: moveaInk))
                          else
                            Text(activity.icon,
                                style: const TextStyle(fontSize: 42)),
                          const SizedBox(height: 10),
                          Text(formatDuration(elapsed),
                              style: const TextStyle(
                                  fontSize: 18, fontWeight: FontWeight.w700)),
                          if (activity.usesLocation && livePoints.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text('当前配速 ${_formatPace(_currentPace())}',
                                      style: const TextStyle(
                                          fontSize: 13, color: Colors.black54)),
                                  const SizedBox(width: 12),
                                  Text(
                                      '精度 ${livePoints.last.accuracy == null ? '--' : '${livePoints.last.accuracy!.round()} m'}',
                                      style: const TextStyle(
                                          fontSize: 13, color: Colors.black54)),
                                ],
                              ),
                            ),
                          if (activity.usesLocation) _buildLocationStatus(),
                          const SizedBox(height: 16),
                          Row(children: [
                            Expanded(
                                child: FilledButton.icon(
                                    onPressed: togglePause,
                                    icon: Icon(paused
                                        ? Icons.play_arrow
                                        : Icons.pause),
                                    label: Text(paused ? '继续' : '暂停'),
                                    style: FilledButton.styleFrom(
                                        backgroundColor: moveaCoral))),
                            const SizedBox(width: 10),
                            OutlinedButton(
                                onPressed: finish, child: const Text('结束')),
                          ]),
                        ] else ...[
                          Text(activity.icon,
                              style: const TextStyle(fontSize: 44)),
                          const SizedBox(height: 8),
                          const Text('准备好了吗？',
                              style: TextStyle(
                                  fontSize: 22, fontWeight: FontWeight.w800)),
                          const SizedBox(height: 5),
                          Text(
                              activity.usesLocation
                                  ? widget.selectedRoute == null
                                      ? '开始后将记录你的路线和运动数据'
                                      : '沿计划路线记录运动数据'
                                  : '开始后将记录你的训练时长',
                              style: const TextStyle(color: Colors.black54)),
                          const SizedBox(height: 14),
                          FilledButton.icon(
                              onPressed: start,
                              icon: const Icon(Icons.play_arrow),
                              label: Text('开始${activity.label}'),
                              style: FilledButton.styleFrom(
                                  backgroundColor: moveaCoral,
                                  minimumSize: const Size.fromHeight(50))),
                          TextButton.icon(
                              onPressed: () => Navigator.of(context).push(
                                  MaterialPageRoute(
                                      builder: (_) => WorkoutHistoryPage(
                                          store: widget.store,
                                          routeStore: widget.routeStore))),
                              icon: const Icon(Icons.list_alt),
                              label: const Text('查看全部运动记录')),
                        ],
                      ],
                    ]),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _RecoveredWorkoutCard extends StatelessWidget {
  const _RecoveredWorkoutCard();

  @override
  Widget build(BuildContext context) {
    return const Card(
      margin: EdgeInsets.zero,
      color: Color(0xFFF1F5FF),
      child: ListTile(
        dense: true,
        leading: Icon(Icons.restore, color: moveaBlue),
        title: Text('已恢复未完成运动', style: TextStyle(fontWeight: FontWeight.w800)),
        subtitle: Text('恢复后默认暂停，点击“继续”才会重新记录时间和 GPS。'),
      ),
    );
  }
}

class _RouteGuidanceCard extends StatelessWidget {
  const _RouteGuidanceCard({required this.title, required this.description});

  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      color: const Color(0xFFF1F5FF),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.navigation_outlined, color: moveaBlue, size: 19),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 3),
                  Text(description,
                      style:
                          const TextStyle(fontSize: 12, color: Colors.black54)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class TrainingPlansPage extends StatelessWidget {
  const TrainingPlansPage(
      {required this.store,
      required this.workoutStore,
      required this.exerciseStore,
      super.key});

  final TrainingPlanStore store;
  final WorkoutStore workoutStore;
  final ExerciseCatalogStore exerciseStore;

  Future<void> _newPlan(BuildContext context) async {
    await Navigator.of(context).push<TrainingPlan>(MaterialPageRoute(
        builder: (_) => TrainingPlanEditorPage(
            store: store, exerciseStore: exerciseStore)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('训练计划'),
        actions: [
          IconButton(
              tooltip: '新建训练计划',
              onPressed: () => _newPlan(context),
              icon: const Icon(Icons.add)),
        ],
      ),
      body: AnimatedBuilder(
        animation: Listenable.merge([store, workoutStore]),
        builder: (context, _) => MoveaContentFrame(
          maxWidth: 960,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 28),
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('把动作和节奏保存下来，下一次直接开始。',
                            style: TextStyle(color: Colors.black54)),
                        SizedBox(height: 5),
                        Text('你的训练模板',
                            style: TextStyle(
                                fontSize: 22, fontWeight: FontWeight.w800)),
                      ],
                    ),
                  ),
                  FilledButton.icon(
                    onPressed: () => _newPlan(context),
                    icon: const Icon(Icons.add),
                    label: const Text('新建计划'),
                    style: FilledButton.styleFrom(backgroundColor: moveaCoral),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              if (store.plans.isEmpty)
                const Card(
                    child: Padding(
                        padding: EdgeInsets.all(24), child: Text('还没有训练计划')))
              else
                for (final plan in store.plans)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _TrainingPlanCard(
                      plan: plan,
                      completionCount: workoutStore.records
                          .where((record) => record.trainingPlanId == plan.id)
                          .length,
                      onTap: () => Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) => TrainingPlanDetailPage(
                              store: store,
                              workoutStore: workoutStore,
                              exerciseStore: exerciseStore,
                              plan: plan))),
                    ),
                  ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TrainingPlanCard extends StatelessWidget {
  const _TrainingPlanCard({
    required this.plan,
    required this.completionCount,
    required this.onTap,
  });

  final TrainingPlan plan;
  final int completionCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(plan.name,
                        style: const TextStyle(
                            fontSize: 17, fontWeight: FontWeight.w800)),
                  ),
                  const Icon(Icons.chevron_right),
                ],
              ),
              const SizedBox(height: 5),
              Text(plan.description,
                  style: const TextStyle(color: Colors.black54)),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _PlanChip('${plan.actions.length} 个动作'),
                  _PlanChip('${plan.estimatedMinutes} 分钟'),
                  _PlanChip('组间休息 ${plan.restBetweenRoundsSeconds} 秒'),
                  _PlanChip(plan.difficulty),
                  _PlanChip(plan.scheduleLabel),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Text(
                    completionCount == 0 ? '还没有完成记录' : '已完成 $completionCount 次',
                    style: const TextStyle(fontSize: 12, color: Colors.black54),
                  ),
                  const Spacer(),
                  const Text('查看计划',
                      style: TextStyle(
                          color: moveaBlue, fontWeight: FontWeight.w700)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PlanChip extends StatelessWidget {
  const _PlanChip(this.label);

  final String label;

  @override
  Widget build(BuildContext context) => DecoratedBox(
        decoration: BoxDecoration(
            color: const Color(0xFFF0F6F1),
            borderRadius: BorderRadius.circular(9)),
        child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
            child: Text(label,
                style: const TextStyle(fontSize: 11, color: Colors.black54))),
      );
}

class TrainingPlanDetailPage extends StatefulWidget {
  const TrainingPlanDetailPage(
      {required this.store,
      required this.workoutStore,
      required this.exerciseStore,
      required this.plan,
      super.key});

  final TrainingPlanStore store;
  final WorkoutStore workoutStore;
  final ExerciseCatalogStore exerciseStore;
  final TrainingPlan plan;

  @override
  State<TrainingPlanDetailPage> createState() => _TrainingPlanDetailPageState();
}

class _TrainingPlanDetailPageState extends State<TrainingPlanDetailPage> {
  late TrainingPlan plan = widget.plan;

  @override
  void initState() {
    super.initState();
    unawaited(widget.exerciseStore.load());
    widget.exerciseStore.addListener(_onExerciseCatalogChanged);
  }

  void _onExerciseCatalogChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    widget.exerciseStore.removeListener(_onExerciseCatalogChanged);
    super.dispose();
  }

  Future<void> edit() async {
    final updated = await Navigator.of(context).push<TrainingPlan>(
        MaterialPageRoute(
            builder: (_) => TrainingPlanEditorPage(
                store: widget.store,
                exerciseStore: widget.exerciseStore,
                existing: plan)));
    if (updated != null && mounted) setState(() => plan = updated);
  }

  Future<void> startPlan() async {
    await widget.store.markUsed(plan);
    if (!mounted) return;
    Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => TrainingPlanRunnerPage(
            store: widget.store,
            workoutStore: widget.workoutStore,
            exerciseStore: widget.exerciseStore,
            plan: plan.copyWith(lastUsedAt: DateTime.now()))));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('计划详情')),
      body: MoveaContentFrame(
        maxWidth: 820,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 30),
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(plan.name,
                          style: const TextStyle(
                              fontSize: 24, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 5),
                      Text(plan.description,
                          style: const TextStyle(color: Colors.black54)),
                    ],
                  ),
                ),
                OutlinedButton.icon(
                    onPressed: edit,
                    icon: const Icon(Icons.edit_outlined),
                    label: const Text('编辑')),
              ],
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _PlanChip('${plan.actions.length} 个动作'),
                _PlanChip('${plan.rounds} 组'),
                _PlanChip('${plan.estimatedMinutes} 分钟'),
                _PlanChip('组间休息 ${plan.restBetweenRoundsSeconds} 秒'),
                _PlanChip(plan.difficulty),
                _PlanChip(plan.scheduleLabel),
              ],
            ),
            const SizedBox(height: 18),
            Card(
              color: moveaMint,
              child: ListTile(
                leading: const Icon(Icons.event_available_outlined,
                    color: moveaBlue),
                title: Text(plan.scheduledWeekdays.isEmpty
                    ? '未设置每周排期'
                    : '每周 ${plan.scheduleLabel} 训练'),
                subtitle: Text(
                    '已完成 ${widget.workoutStore.records.where((record) => record.trainingPlanId == plan.id).length} 次 · 可在训练日历查看计划日'),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('动作顺序与节奏',
                        style: TextStyle(
                            fontSize: 17, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 10),
                    for (var index = 0; index < plan.actions.length; index++)
                      _PlanActionRow(
                          index: index,
                          action: plan.actions[index],
                          last: index == plan.actions.length - 1,
                          exercise: widget.exerciseStore
                              .find(plan.actions[index].catalogId),
                          onTap: () {
                            final exercise = widget.exerciseStore
                                .find(plan.actions[index].catalogId);
                            if (exercise == null) return;
                            Navigator.of(context).push(MaterialPageRoute(
                                builder: (_) =>
                                    ExerciseDetailPage(exercise: exercise)));
                          }),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: startPlan,
                            icon: const Icon(Icons.play_arrow),
                            label: const Text('开始这套计划'),
                            style: FilledButton.styleFrom(
                                backgroundColor: moveaCoral,
                                minimumSize: const Size.fromHeight(50)),
                          ),
                        ),
                        const SizedBox(width: 10),
                        OutlinedButton.icon(
                            onPressed: () => Navigator.pop(context),
                            icon: const Icon(Icons.bookmark_border),
                            label: const Text('返回列表')),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlanActionRow extends StatelessWidget {
  const _PlanActionRow(
      {required this.index,
      required this.action,
      required this.last,
      required this.exercise,
      required this.onTap});

  final int index;
  final TrainingAction action;
  final bool last;
  final ExerciseDefinition? exercise;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 13),
      decoration: BoxDecoration(
          border: last
              ? null
              : const Border(bottom: BorderSide(color: Color(0xFFE6ECE8)))),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Row(
          children: [
            CircleAvatar(
                radius: 15,
                backgroundColor: moveaLavender,
                child: Text('${index + 1}',
                    style: const TextStyle(fontWeight: FontWeight.w800))),
            const SizedBox(width: 12),
            if (exercise != null && exercise!.framePaths.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: const Color(0xFF2A3B35),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: SizedBox(
                    width: 34,
                    height: 34,
                    child: SvgPicture.asset(exercise!.framePaths.first),
                  ),
                ),
              ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(exercise?.displayName ?? action.name,
                      style: const TextStyle(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 3),
                  Text(
                      '${localizedMuscle(exercise?.primaryMuscle ?? action.muscle)} · 每组 ${action.workSeconds} 秒',
                      style:
                          const TextStyle(fontSize: 12, color: Colors.black54)),
                ],
              ),
            ),
            Text('休息 ${action.restSeconds} 秒',
                style: const TextStyle(fontSize: 12, color: Colors.black54)),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right, size: 18, color: Colors.black45),
          ],
        ),
      ),
    );
  }
}

class TrainingPlanEditorPage extends StatefulWidget {
  const TrainingPlanEditorPage({
    required this.store,
    required this.exerciseStore,
    this.existing,
    super.key,
  });

  final TrainingPlanStore store;
  final ExerciseCatalogStore exerciseStore;
  final TrainingPlan? existing;

  @override
  State<TrainingPlanEditorPage> createState() => _TrainingPlanEditorPageState();
}

class _TrainingPlanEditorPageState extends State<TrainingPlanEditorPage> {
  late final TextEditingController nameController =
      TextEditingController(text: widget.existing?.name ?? '我的核心训练');
  late int rounds = widget.existing?.rounds ?? 3;
  late int restBetweenRounds = widget.existing?.restBetweenRoundsSeconds ?? 45;
  late String difficulty = widget.existing?.difficulty ?? '初级';
  late Set<int> scheduledWeekdays = {
    ...(widget.existing?.scheduledWeekdays ?? const <int>[]),
  };
  late List<TrainingAction> actions = [
    ...(widget.existing?.actions ??
        const [
          TrainingAction(
              id: 'plank',
              name: '平板支撑',
              muscle: '核心稳定',
              workSeconds: 40,
              restSeconds: 20),
          TrainingAction(
              id: 'dead-bug',
              name: '死虫式',
              muscle: '核心控制',
              workSeconds: 40,
              restSeconds: 20),
          TrainingAction(
              id: 'glute-bridge',
              name: '臀桥',
              muscle: '臀部激活',
              workSeconds: 45,
              restSeconds: 20),
        ])
  ];

  @override
  void dispose() {
    nameController.dispose();
    super.dispose();
  }

  Future<void> addAction() async {
    final selected = await Navigator.of(context).push<ExerciseDefinition>(
        MaterialPageRoute(
            builder: (_) => ExerciseLibraryPage(
                store: widget.exerciseStore, selectionMode: true)));
    if (selected == null || !mounted) return;
    setState(() => actions.add(TrainingAction(
        id: 'action-${DateTime.now().microsecondsSinceEpoch}',
        exerciseId: selected.slug,
        name: selected.displayName,
        muscle: localizedMuscle(selected.primaryMuscle),
        workSeconds: 40,
        restSeconds: 20)));
  }

  Future<void> save() async {
    if (actions.isEmpty || nameController.text.trim().isEmpty) return;
    final plan = TrainingPlan(
      id: widget.existing?.id ??
          'plan-${DateTime.now().microsecondsSinceEpoch}',
      name: nameController.text.trim(),
      description:
          widget.existing?.description ?? '自定义训练计划 · ${actions.length} 个动作',
      rounds: rounds,
      restBetweenRoundsSeconds: restBetweenRounds,
      difficulty: difficulty,
      actions: List.unmodifiable(actions),
      lastUsedAt: widget.existing?.lastUsedAt,
      scheduledWeekdays: scheduledWeekdays.toList()..sort(),
    );
    await widget.store.save(plan);
    if (mounted) Navigator.pop(context, plan);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.existing == null ? '新建训练计划' : '编辑训练计划'),
        actions: [
          TextButton(onPressed: save, child: const Text('保存')),
        ],
      ),
      body: MoveaContentFrame(
        maxWidth: 960,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 30),
          children: [
            const Text('设置动作、组数、每组时长和休息时间。',
                style: TextStyle(color: Colors.black54)),
            const SizedBox(height: 16),
            LayoutBuilder(builder: (context, constraints) {
              final compact = constraints.maxWidth < 700;
              final settings = _PlanSettingsCard(
                controller: nameController,
                rounds: rounds,
                restBetweenRounds: restBetweenRounds,
                difficulty: difficulty,
                scheduledWeekdays: scheduledWeekdays,
                onRoundsChanged: (value) => setState(() => rounds = value),
                onRestChanged: (value) =>
                    setState(() => restBetweenRounds = value),
                onDifficultyChanged: (value) =>
                    setState(() => difficulty = value),
                onScheduleChanged: (day) => setState(() {
                  if (!scheduledWeekdays.add(day)) {
                    scheduledWeekdays.remove(day);
                  }
                }),
                onSave: save,
              );
              final actionsCard = _PlanActionsEditor(
                actions: actions,
                onAdd: addAction,
                onDelete: (index) => setState(() => actions.removeAt(index)),
                onChanged: (index, action) =>
                    setState(() => actions[index] = action),
              );
              if (compact) {
                return Column(children: [
                  settings,
                  const SizedBox(height: 16),
                  actionsCard
                ]);
              }
              return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: settings),
                    const SizedBox(width: 16),
                    Expanded(flex: 2, child: actionsCard),
                  ]);
            }),
          ],
        ),
      ),
    );
  }
}

class _PlanSettingsCard extends StatelessWidget {
  const _PlanSettingsCard({
    required this.controller,
    required this.rounds,
    required this.restBetweenRounds,
    required this.difficulty,
    required this.scheduledWeekdays,
    required this.onRoundsChanged,
    required this.onRestChanged,
    required this.onDifficultyChanged,
    required this.onScheduleChanged,
    required this.onSave,
  });

  final TextEditingController controller;
  final int rounds;
  final int restBetweenRounds;
  final String difficulty;
  final Set<int> scheduledWeekdays;
  final ValueChanged<int> onRoundsChanged;
  final ValueChanged<int> onRestChanged;
  final ValueChanged<String> onDifficultyChanged;
  final ValueChanged<int> onScheduleChanged;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('计划设置',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
          const SizedBox(height: 16),
          TextField(
              controller: controller,
              decoration: const InputDecoration(
                  labelText: '计划名称', border: OutlineInputBorder())),
          const SizedBox(height: 12),
          DropdownButtonFormField<int>(
              initialValue: rounds,
              decoration: const InputDecoration(
                  labelText: '循环组数', border: OutlineInputBorder()),
              items: [2, 3, 4, 5]
                  .map((value) =>
                      DropdownMenuItem(value: value, child: Text('$value 组')))
                  .toList(),
              onChanged: (value) {
                if (value != null) onRoundsChanged(value);
              }),
          const SizedBox(height: 12),
          DropdownButtonFormField<int>(
              initialValue: restBetweenRounds,
              decoration: const InputDecoration(
                  labelText: '组间休息', border: OutlineInputBorder()),
              items: [30, 45, 60, 90]
                  .map((value) =>
                      DropdownMenuItem(value: value, child: Text('$value 秒')))
                  .toList(),
              onChanged: (value) {
                if (value != null) onRestChanged(value);
              }),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
              initialValue: difficulty,
              decoration: const InputDecoration(
                  labelText: '训练难度', border: OutlineInputBorder()),
              items: ['初级', '中级', '进阶']
                  .map((value) =>
                      DropdownMenuItem(value: value, child: Text(value)))
                  .toList(),
              onChanged: (value) {
                if (value != null) onDifficultyChanged(value);
              }),
          const SizedBox(height: 14),
          const Text('每周排期',
              style: TextStyle(fontSize: 12, color: Colors.black54)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (var day = 1; day <= 7; day++)
                FilterChip(
                  label:
                      Text('周${['一', '二', '三', '四', '五', '六', '日'][day - 1]}'),
                  selected: scheduledWeekdays.contains(day),
                  onSelected: (_) => onScheduleChanged(day),
                  selectedColor: const Color(0xFFFFE0D8),
                  checkmarkColor: moveaCoral,
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(scheduledWeekdays.isEmpty ? '不排期，只在需要时手动开始' : '将在训练日历中标记计划日',
              style: const TextStyle(fontSize: 11, color: Colors.black54)),
          const SizedBox(height: 16),
          SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                  onPressed: onSave,
                  icon: const Icon(Icons.check),
                  label: const Text('保存训练计划'),
                  style: FilledButton.styleFrom(backgroundColor: moveaCoral))),
        ]),
      ),
    );
  }
}

class _PlanActionsEditor extends StatelessWidget {
  const _PlanActionsEditor({
    required this.actions,
    required this.onAdd,
    required this.onDelete,
    required this.onChanged,
  });

  final List<TrainingAction> actions;
  final VoidCallback onAdd;
  final ValueChanged<int> onDelete;
  final void Function(int index, TrainingAction action) onChanged;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('动作编排',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          for (var index = 0; index < actions.length; index++)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _EditableActionRow(
                index: index,
                action: actions[index],
                onDelete: () => onDelete(index),
                onChanged: (action) => onChanged(index, action),
              ),
            ),
          OutlinedButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add),
              label: const Text('添加动作'),
              style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(44),
                  foregroundColor: const Color(0xFF648A73))),
        ]),
      ),
    );
  }
}

class _EditableActionRow extends StatelessWidget {
  const _EditableActionRow({
    required this.index,
    required this.action,
    required this.onDelete,
    required this.onChanged,
  });

  final int index;
  final TrainingAction action;
  final VoidCallback onDelete;
  final ValueChanged<TrainingAction> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
          color: const Color(0xFFFBFDFB),
          border: Border.all(color: const Color(0xFFE1EAE4)),
          borderRadius: BorderRadius.circular(14)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                  radius: 13,
                  backgroundColor: moveaLavender,
                  child: Text('${index + 1}',
                      style: const TextStyle(fontSize: 11))),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(action.name,
                        style: const TextStyle(fontWeight: FontWeight.w800)),
                    Text(action.muscle,
                        style: const TextStyle(
                            fontSize: 11, color: Colors.black54)),
                  ],
                ),
              ),
              IconButton(
                  tooltip: '删除动作',
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete_outline, color: Colors.brown)),
            ],
          ),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(
              child: DropdownButtonFormField<int>(
                  initialValue: action.workSeconds,
                  isDense: true,
                  decoration: const InputDecoration(
                      labelText: '每组时长', border: OutlineInputBorder()),
                  items: [30, 40, 45, 60]
                      .map((value) => DropdownMenuItem(
                          value: value, child: Text('$value 秒')))
                      .toList(),
                  onChanged: (value) {
                    if (value != null) {
                      onChanged(action.copyWith(workSeconds: value));
                    }
                  }),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: DropdownButtonFormField<int>(
                  initialValue: action.restSeconds,
                  isDense: true,
                  decoration: const InputDecoration(
                      labelText: '动作间休息', border: OutlineInputBorder()),
                  items: [15, 20, 30, 45]
                      .map((value) => DropdownMenuItem(
                          value: value, child: Text('$value 秒')))
                      .toList(),
                  onChanged: (value) {
                    if (value != null) {
                      onChanged(action.copyWith(restSeconds: value));
                    }
                  }),
            ),
          ]),
        ],
      ),
    );
  }
}

class TrainingPlanRunnerPage extends StatefulWidget {
  const TrainingPlanRunnerPage(
      {required this.store,
      required this.workoutStore,
      required this.exerciseStore,
      required this.plan,
      super.key});

  final TrainingPlanStore store;
  final WorkoutStore workoutStore;
  final ExerciseCatalogStore exerciseStore;
  final TrainingPlan plan;

  @override
  State<TrainingPlanRunnerPage> createState() => _TrainingPlanRunnerPageState();
}

class _TrainingPlanRunnerPageState extends State<TrainingPlanRunnerPage> {
  Timer? timer;
  late DateTime startedAt;
  late int remainingSeconds;
  int actionIndex = 0;
  int round = 1;
  bool paused = false;
  bool resting = false;
  bool completed = false;
  Duration activeElapsed = Duration.zero;
  bool savedRecord = false;

  @override
  void initState() {
    super.initState();
    unawaited(widget.exerciseStore.load());
    widget.exerciseStore.addListener(_onExerciseCatalogChanged);
    startedAt = DateTime.now();
    remainingSeconds = action.workSeconds;
    timer = Timer.periodic(const Duration(seconds: 1), (_) => tick());
  }

  void _onExerciseCatalogChanged() {
    if (mounted) setState(() {});
  }

  TrainingAction get action => widget.plan.actions[actionIndex];

  int get totalPlannedActions =>
      widget.plan.actions.length * widget.plan.rounds;

  int get completedActionCount {
    if (completed) return totalPlannedActions;
    final completedRounds = (round - 1) * widget.plan.actions.length;
    return math.min(totalPlannedActions,
        completedRounds + (resting ? actionIndex + 1 : actionIndex));
  }

  ExerciseDefinition? exerciseFor(TrainingAction item) =>
      widget.exerciseStore.find(item.catalogId);

  Future<void> openExercise(TrainingAction item) async {
    final exercise = exerciseFor(item);
    if (exercise == null || !mounted) return;
    final resumeOnReturn = !paused && !completed;
    if (resumeOnReturn) setState(() => paused = true);
    await Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => ExerciseDetailPage(
              exercise: exercise,
              openedDuringWorkout: true,
            )));
    if (mounted && resumeOnReturn && !completed) {
      setState(() => paused = false);
    }
  }

  void tick() {
    if (!mounted || paused || completed) return;
    setState(() {
      activeElapsed += const Duration(seconds: 1);
      remainingSeconds -= 1;
      if (remainingSeconds <= 0) advancePhase();
    });
  }

  void advancePhase() {
    if (!resting && action.restSeconds > 0) {
      resting = true;
      remainingSeconds = action.restSeconds;
      return;
    }
    if (actionIndex < widget.plan.actions.length - 1) {
      actionIndex += 1;
      resting = false;
      remainingSeconds = action.workSeconds;
      return;
    }
    if (round < widget.plan.rounds) {
      round += 1;
      actionIndex = 0;
      resting = false;
      remainingSeconds = action.workSeconds;
      return;
    }
    completed = true;
    timer?.cancel();
    saveRecord();
  }

  void skip() {
    setState(advancePhase);
  }

  void saveRecord() {
    if (savedRecord) return;
    savedRecord = true;
    widget.workoutStore.add(WorkoutRecord(
      id: 'training-${startedAt.microsecondsSinceEpoch}',
      activity: ActivityType.strength,
      startedAt: startedAt,
      duration: activeElapsed,
      distanceMeters: 0,
      trainingPlanId: widget.plan.id,
      completedActions: completedActionCount,
      plannedActions: totalPlannedActions,
    ));
  }

  void finish() {
    timer?.cancel();
    if (!savedRecord && activeElapsed > Duration.zero) saveRecord();
    if (mounted) Navigator.pop(context);
  }

  String formatSeconds(int seconds) =>
      '${(seconds ~/ 60).toString().padLeft(2, '0')}:${(seconds % 60).toString().padLeft(2, '0')}';

  @override
  void dispose() {
    timer?.cancel();
    widget.exerciseStore.removeListener(_onExerciseCatalogChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentLabel = resting ? '休息中' : '进行中';
    final currentExercise = exerciseFor(action);
    final currentName = currentExercise?.displayName ?? action.name;
    return Scaffold(
      appBar: AppBar(
        title: const Text('开始训练'),
        actions: [
          TextButton(onPressed: finish, child: const Text('结束训练')),
        ],
      ),
      body: MoveaContentFrame(
        maxWidth: 700,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 30),
          children: [
            if (completed)
              Card(
                color: moveaMint,
                child: Padding(
                  padding: const EdgeInsets.all(28),
                  child: Column(children: [
                    const Icon(Icons.check_circle,
                        color: Color(0xFF648A73), size: 48),
                    const SizedBox(height: 12),
                    const Text('训练完成',
                        style: TextStyle(
                            fontSize: 24, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 6),
                    Text('${widget.plan.name} · 第 ${widget.plan.rounds} 组',
                        style: const TextStyle(color: Colors.black54)),
                    const SizedBox(height: 18),
                    FilledButton(
                        onPressed: () => Navigator.pop(context),
                        style:
                            FilledButton.styleFrom(backgroundColor: moveaCoral),
                        child: const Text('返回计划详情')),
                  ]),
                ),
              )
            else
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(children: [
                    Text(
                        '${widget.plan.name} · 第 $round / ${widget.plan.rounds} 组',
                        style: const TextStyle(
                            color: moveaBlue, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 10),
                    Text(resting ? '准备下一个动作' : currentName,
                        style: const TextStyle(
                            fontSize: 26, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 5),
                    Text(
                        resting
                            ? '调整呼吸，准备继续'
                            : localizedMuscle(currentExercise?.primaryMuscle ??
                                action.muscle),
                        style: const TextStyle(color: Colors.black54)),
                    const SizedBox(height: 24),
                    Text(formatSeconds(remainingSeconds),
                        style: const TextStyle(
                            fontSize: 64,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -3,
                            color: moveaInk)),
                    const SizedBox(height: 5),
                    Text(currentLabel,
                        style: TextStyle(
                            color: resting ? moveaBlue : moveaCoral,
                            fontWeight: FontWeight.w800)),
                    const SizedBox(height: 5),
                    Text('动作进度 $completedActionCount / $totalPlannedActions',
                        style: const TextStyle(
                            fontSize: 12, color: Colors.black54)),
                    if (!resting && currentExercise != null)
                      TextButton.icon(
                        onPressed: () => openExercise(action),
                        icon:
                            const Icon(Icons.ondemand_video_outlined, size: 18),
                        label: const Text('查看动作演示'),
                      ),
                    const SizedBox(height: 22),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: LinearProgressIndicator(
                        minHeight: 8,
                        value: (actionIndex + 1) / widget.plan.actions.length,
                        color: moveaCoral,
                        backgroundColor: const Color(0xFFEAF0EC),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Row(children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => setState(() => paused = !paused),
                          icon: Icon(paused ? Icons.play_arrow : Icons.pause),
                          label: Text(paused ? '继续' : '暂停'),
                          style: OutlinedButton.styleFrom(
                              minimumSize: const Size.fromHeight(48)),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: skip,
                          icon: const Icon(Icons.skip_next),
                          label: Text(resting ? '跳过休息' : '下一个动作'),
                          style: FilledButton.styleFrom(
                              backgroundColor: moveaCoral,
                              minimumSize: const Size.fromHeight(48)),
                        ),
                      ),
                    ]),
                  ]),
                ),
              ),
            if (!completed) ...[
              const SizedBox(height: 14),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('动作顺序',
                          style: TextStyle(fontWeight: FontWeight.w800)),
                      const SizedBox(height: 8),
                      for (var index = 0;
                          index < widget.plan.actions.length;
                          index++)
                        ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          onTap: () => openExercise(widget.plan.actions[index]),
                          leading: CircleAvatar(
                              radius: 14,
                              backgroundColor: index == actionIndex
                                  ? const Color(0xFFFFE8E2)
                                  : moveaLavender,
                              child: Text('${index + 1}',
                                  style: const TextStyle(fontSize: 11))),
                          title: Text(
                              exerciseFor(widget.plan.actions[index])
                                      ?.displayName ??
                                  widget.plan.actions[index].name,
                              style: TextStyle(
                                  fontWeight: index == actionIndex
                                      ? FontWeight.w800
                                      : FontWeight.w500)),
                          trailing: Text(
                              '${widget.plan.actions[index].workSeconds} 秒',
                              style: const TextStyle(
                                  fontSize: 12, color: Colors.black54)),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

String formatDuration(Duration duration) =>
    '${duration.inMinutes.toString().padLeft(2, '0')}:${(duration.inSeconds % 60).toString().padLeft(2, '0')}';

String formatHoursMinutes(Duration duration) {
  final hours = duration.inHours;
  final minutes = duration.inMinutes % 60;
  return hours > 0 ? '${hours}h ${minutes}m' : '${minutes}m';
}

List<LatLng> _toLatLngs(Iterable<LocationPoint> points) => points
    .map((point) => LatLng(point.latitude, point.longitude))
    .toList(growable: false);

double _paceFromPoint(LocationPoint? point) {
  final speed = point?.speedMetersPerSecond;
  if (speed == null || !speed.isFinite || speed <= 0.4) return 0;
  return 1000 / speed / 60;
}

String _formatPace(double minutesPerKilometer) =>
    minutesPerKilometer <= 0 || !minutesPerKilometer.isFinite
        ? '--'
        : '${minutesPerKilometer.toStringAsFixed(1)} min/km';

class _WorkoutSplit {
  const _WorkoutSplit({
    required this.label,
    required this.distanceMeters,
    required this.duration,
    required this.paceMinutesPerKilometer,
  });

  final String label;
  final double distanceMeters;
  final Duration duration;
  final double paceMinutesPerKilometer;
}

List<_WorkoutSplit> _workoutSplits(WorkoutRecord record) {
  final points = record.routePoints;
  if (!record.activity.usesLocation || points.length < 2) return const [];

  final rawDistances = <double>[];
  var rawTotal = 0.0;
  for (var index = 1; index < points.length; index++) {
    final distance = _distanceBetween(points[index - 1], points[index]);
    rawDistances.add(distance);
    rawTotal += distance;
  }
  if (rawTotal < 100) return const [];

  final distanceScale =
      record.distanceMeters > 0 ? record.distanceMeters / rawTotal : 1.0;
  final fallbackSeconds = record.duration.inMilliseconds / 1000;
  var splitDistance = 0.0;
  var splitSeconds = 0.0;
  var splitNumber = 1;
  final splits = <_WorkoutSplit>[];

  for (var index = 1; index < points.length; index++) {
    final rawDistance = rawDistances[index - 1];
    final segmentDistance = rawDistance * distanceScale;
    if (segmentDistance <= 0) continue;
    final start = points[index - 1];
    final end = points[index];
    final timestampSeconds = start.timestamp != null && end.timestamp != null
        ? end.timestamp!.difference(start.timestamp!).inMilliseconds / 1000
        : 0.0;
    final segmentSeconds = timestampSeconds > 0
        ? timestampSeconds
        : fallbackSeconds * rawDistance / rawTotal;
    var remaining = segmentDistance;
    while (remaining > 0.01) {
      final toKilometer = 1000 - splitDistance;
      final taken = math.min(remaining, toKilometer);
      final fraction = taken / segmentDistance;
      splitDistance += taken;
      splitSeconds += segmentSeconds * fraction;
      remaining -= taken;
      if (splitDistance >= 999.99) {
        splits.add(_WorkoutSplit(
          label: '$splitNumber km',
          distanceMeters: splitDistance,
          duration: Duration(milliseconds: (splitSeconds * 1000).round()),
          paceMinutesPerKilometer: splitSeconds / 60,
        ));
        splitNumber++;
        splitDistance = 0;
        splitSeconds = 0;
      }
    }
  }

  if (splitDistance >= 100) {
    final pace = splitSeconds / 60 / (splitDistance / 1000);
    splits.add(_WorkoutSplit(
      label: '最后',
      distanceMeters: splitDistance,
      duration: Duration(milliseconds: (splitSeconds * 1000).round()),
      paceMinutesPerKilometer: pace,
    ));
  }
  return splits;
}

double _distanceBetween(LocationPoint from, LocationPoint to) {
  const earthRadiusMeters = 6371000.0;
  final latitudeDelta = _radians(to.latitude - from.latitude);
  final longitudeDelta = _radians(to.longitude - from.longitude);
  final fromLatitude = _radians(from.latitude);
  final toLatitude = _radians(to.latitude);
  final haversine = math.sin(latitudeDelta / 2) * math.sin(latitudeDelta / 2) +
      math.cos(fromLatitude) *
          math.cos(toLatitude) *
          math.sin(longitudeDelta / 2) *
          math.sin(longitudeDelta / 2);
  return earthRadiusMeters *
      2 *
      math.atan2(math.sqrt(haversine), math.sqrt(1 - haversine));
}

class _RouteProgress {
  const _RouteProgress({required this.distanceMeters, required this.progress});

  final double distanceMeters;
  final double progress;
}

/// Returns the closest distance to the route polyline and the along-route
/// progress. Projecting onto a segment avoids the visible jumps that happen
/// when progress is calculated from the nearest stored vertex only.
_RouteProgress _routeProgress(
    LocationPoint current, List<LocationPoint> route) {
  if (route.length < 2) {
    return const _RouteProgress(distanceMeters: double.infinity, progress: 0);
  }

  const latitudeScale = 111320.0;
  final longitudeScale = 111320.0 * math.cos(_radians(current.latitude)).abs();
  double xFor(LocationPoint point) =>
      (point.longitude - current.longitude) * longitudeScale;
  double yFor(LocationPoint point) =>
      (point.latitude - current.latitude) * latitudeScale;

  var totalLength = 0.0;
  var distanceAlong = 0.0;
  var closestDistance = double.infinity;
  for (var index = 0; index < route.length - 1; index++) {
    final start = route[index];
    final end = route[index + 1];
    final ax = xFor(start);
    final ay = yFor(start);
    final bx = xFor(end);
    final by = yFor(end);
    final dx = bx - ax;
    final dy = by - ay;
    final segmentSquared = dx * dx + dy * dy;
    final segmentLength = _distanceBetween(start, end);
    final projection =
        segmentSquared == 0 ? 0.0 : ((-ax * dx) + (-ay * dy)) / segmentSquared;
    final t = projection.clamp(0.0, 1.0).toDouble();
    final projectedX = ax + dx * t;
    final projectedY = ay + dy * t;
    final distance =
        math.sqrt(projectedX * projectedX + projectedY * projectedY);
    if (distance < closestDistance) {
      closestDistance = distance;
      distanceAlong = totalLength + segmentLength * t;
    }
    totalLength += segmentLength;
  }
  final progress = totalLength == 0 ? 0.0 : distanceAlong / totalLength;
  return _RouteProgress(
    distanceMeters: closestDistance,
    progress: progress.clamp(0.0, 1.0),
  );
}

double _radians(double degrees) => degrees * math.pi / 180;

String _formatMeters(double meters) => meters < 1000
    ? '${meters.round()} m'
    : '${(meters / 1000).toStringAsFixed(1)} km';

const _demoRoute = <LatLng>[
  LatLng(31.2304, 121.4737),
  LatLng(31.2322, 121.4780),
  LatLng(31.2290, 121.4835),
  LatLng(31.2258, 121.4790),
  LatLng(31.2244, 121.4720),
  LatLng(31.2280, 121.4705),
];

class _MapPreview extends StatefulWidget {
  const _MapPreview({
    required this.plannedPoints,
    required this.livePoints,
  });

  final List<LatLng> plannedPoints;
  final List<LatLng> livePoints;

  @override
  State<_MapPreview> createState() => _MapPreviewState();
}

class _MapPreviewState extends State<_MapPreview> {
  late final Future<String> _styleFuture;

  @override
  void initState() {
    super.initState();
    _styleFuture = _loadStyle();
  }

  Future<String> _loadStyle() =>
      rootBundle.loadString('assets/maps/movea-minimal.json');

  @override
  Widget build(BuildContext context) {
    if (_isFlutterTest) {
      return const _MapTestSurface();
    }
    return FutureBuilder<String>(
      future: _styleFuture,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const ColoredBox(
            color: moveaPaper,
            child: Center(child: Text('地图样式加载失败，请检查网络连接')),
          );
        }
        if (!snapshot.hasData) {
          return const ColoredBox(
            color: moveaPaper,
            child: Center(child: CircularProgressIndicator()),
          );
        }
        return _MapCanvas(
          style: snapshot.data!,
          plannedPoints: widget.plannedPoints,
          livePoints: widget.livePoints,
        );
      },
    );
  }
}

class _MapTestSurface extends StatelessWidget {
  const _MapTestSurface();

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: moveaPaper,
      child: Center(child: Text('MapLibre 地图预览')),
    );
  }
}

class _MapCanvas extends StatefulWidget {
  const _MapCanvas({
    required this.style,
    required this.plannedPoints,
    required this.livePoints,
  });

  final String style;
  final List<LatLng> plannedPoints;
  final List<LatLng> livePoints;

  @override
  State<_MapCanvas> createState() => _MapCanvasState();
}

class _MapCanvasState extends State<_MapCanvas> {
  ml.MapController? _controller;

  @override
  void didUpdateWidget(covariant _MapCanvas oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.livePoints.isEmpty ||
        widget.livePoints.length == oldWidget.livePoints.length) {
      return;
    }
    final current = widget.livePoints.last;
    unawaited(_controller?.animateCamera(
      center: ml.Geographic(lon: current.longitude, lat: current.latitude),
      nativeDuration: const Duration(milliseconds: 450),
      webMaxDuration: const Duration(milliseconds: 450),
    ));
  }

  void _recenter() {
    final points = widget.livePoints.isNotEmpty
        ? widget.livePoints
        : widget.plannedPoints.isNotEmpty
            ? widget.plannedPoints
            : const [LatLng(31.2304, 121.4737)];
    final point = points.last;
    unawaited(_controller?.animateCamera(
      center: ml.Geographic(lon: point.longitude, lat: point.latitude),
      nativeDuration: const Duration(milliseconds: 300),
      webMaxDuration: const Duration(milliseconds: 300),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final hasPlan = widget.plannedPoints.length > 1;
    final hasLive = widget.livePoints.length > 1;
    final centerPoints = widget.livePoints.isNotEmpty
        ? widget.livePoints
        : widget.plannedPoints.isNotEmpty
            ? widget.plannedPoints
            : const [LatLng(31.2304, 121.4737)];
    final center = centerPoints.first;
    final planCoordinates = widget.plannedPoints
        .map(
            (point) => ml.Geographic(lon: point.longitude, lat: point.latitude))
        .toList(growable: false);
    final liveCoordinates = widget.livePoints
        .map(
            (point) => ml.Geographic(lon: point.longitude, lat: point.latitude))
        .toList(growable: false);
    final planFeature = hasPlan
        ? ml.Feature<ml.LineString>(
            geometry: ml.LineString.from(planCoordinates),
          )
        : null;
    final liveFeature = hasLive
        ? ml.Feature<ml.LineString>(
            geometry: ml.LineString.from(liveCoordinates),
          )
        : null;
    final markers = <ml.Marker>[
      if (hasPlan)
        ml.Marker(
          point: planCoordinates.first,
          size: const Size.square(36),
          child: const _MapMarker(color: moveaCoral, icon: Icons.play_arrow),
        ),
      if (hasPlan)
        ml.Marker(
          point: planCoordinates.last,
          size: const Size.square(36),
          child: const _MapMarker(color: moveaBlue, icon: Icons.flag),
        ),
      if (widget.livePoints.isNotEmpty)
        ml.Marker(
          point: liveCoordinates.last,
          size: const Size.square(40),
          child: const _MapMarker(color: moveaCoral, icon: Icons.my_location),
        ),
    ];

    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: ml.MapLibreMap(
        options: ml.MapOptions(
          initStyle: widget.style,
          initCenter:
              ml.Geographic(lon: center.longitude, lat: center.latitude),
          initZoom: 13.7,
          minZoom: 11,
          maxZoom: 17,
        ),
        onMapCreated: (controller) => _controller = controller,
        layers: [
          if (planFeature != null) ...[
            ml.PolylineLayer(
              polylines: [planFeature],
              color: Colors.white,
              width: 9,
            ),
            ml.PolylineLayer(
              polylines: [planFeature],
              color: moveaBlue,
              width: 5,
            ),
          ],
          if (liveFeature != null) ...[
            ml.PolylineLayer(
              polylines: [liveFeature],
              color: Colors.white,
              width: 10,
            ),
            ml.PolylineLayer(
              polylines: [liveFeature],
              color: moveaCoral,
              width: 6,
            ),
          ],
        ],
        children: [
          if (markers.isNotEmpty) ml.WidgetLayer(markers: markers),
          Positioned(
            left: 12,
            top: 12,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: .92),
                borderRadius: BorderRadius.circular(14),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x22000000),
                    blurRadius: 8,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.touch_app, size: 16, color: moveaBlue),
                  SizedBox(width: 6),
                  Text('MapLibre · OpenFreeMap',
                      style:
                          TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                ]),
              ),
            ),
          ),
          Positioned(
            right: 12,
            top: 12,
            child: Material(
              color: Colors.white.withValues(alpha: .92),
              borderRadius: BorderRadius.circular(14),
              elevation: 2,
              child: IconButton(
                onPressed: _recenter,
                tooltip: '重新定位',
                icon: const Icon(Icons.my_location, color: moveaBlue),
              ),
            ),
          ),
          if (hasPlan || hasLive)
            Positioned(
              left: 12,
              bottom: 12,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: .92),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _MapLegendItem(color: moveaBlue, label: '计划路线'),
                      SizedBox(width: 10),
                      _MapLegendItem(color: moveaCoral, label: '实际轨迹'),
                    ],
                  ),
                ),
              ),
            ),
          const ml.SourceAttribution(showMapLibre: false),
        ],
      ),
    );
  }
}

class _MapMarker extends StatelessWidget {
  const _MapMarker({required this.color, required this.icon});

  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 3),
        boxShadow: const [
          BoxShadow(color: Color(0x44000000), blurRadius: 5),
        ],
      ),
      child: Icon(icon, color: Colors.white, size: 18),
    );
  }
}

class _MapLegendItem extends StatelessWidget {
  const _MapLegendItem({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 16,
          height: 4,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 5),
        Text(label,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
      ],
    );
  }
}

class _RouteThumbnail extends StatelessWidget {
  const _RouteThumbnail({required this.points, this.lineColor = moveaBlue});

  final List<LatLng> points;
  final Color lineColor;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: CustomPaint(
        key: const ValueKey('route-thumbnail'),
        painter: _RouteThumbnailPainter(points, lineColor),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _RouteThumbnailPainter extends CustomPainter {
  _RouteThumbnailPainter(this.points, this.lineColor);

  final List<LatLng> points;
  final Color lineColor;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawColor(const Color(0xFFF2F5F3), BlendMode.srcOver);

    final water = Paint()..color = const Color(0xFFDDEEF0);
    final waterPath = Path()
      ..moveTo(size.width * .84, -10)
      ..cubicTo(size.width * .77, size.height * .28, size.width * .92,
          size.height * .52, size.width * .79, size.height + 10)
      ..lineTo(size.width + 10, size.height + 10)
      ..lineTo(size.width + 10, -10)
      ..close();
    canvas.drawPath(waterPath, water);

    final localRoad = Paint()
      ..color = const Color(0xFFDCE5E2)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    for (var index = -2; index < 7; index++) {
      final x = size.width * index / 6;
      canvas.drawLine(Offset(x, -10),
          Offset(x + size.width * .28, size.height + 10), localRoad);
    }
    for (var index = 0; index < 5; index++) {
      final y = size.height * (index + 1) / 5;
      canvas.drawLine(Offset(-10, y),
          Offset(size.width + 10, y - size.height * .1), localRoad);
    }

    final minLat = points
        .map((point) => point.latitude)
        .reduce((minimum, value) => value < minimum ? value : minimum);
    final maxLat = points
        .map((point) => point.latitude)
        .reduce((maximum, value) => value > maximum ? value : maximum);
    final minLon = points
        .map((point) => point.longitude)
        .reduce((minimum, value) => value < minimum ? value : minimum);
    final maxLon = points
        .map((point) => point.longitude)
        .reduce((maximum, value) => value > maximum ? value : maximum);
    final rawLatRange = (maxLat - minLat).abs();
    final rawLonRange = (maxLon - minLon).abs();
    // A short or stationary GPS track can have identical latitude/longitude
    // values. Keep the thumbnail finite instead of dividing by zero.
    final latRange = rawLatRange == 0 ? 0.000001 : rawLatRange;
    final lonRange = rawLonRange == 0 ? 0.000001 : rawLonRange;
    const routePadding = 34.0;
    final routeWidth = size.width - routePadding * 2;
    final routeHeight = size.height - routePadding * 2;

    Offset project(LatLng point) {
      final x = (point.longitude - minLon) / lonRange;
      final y = 1 - (point.latitude - minLat) / latRange;
      return Offset(
          routePadding + x * routeWidth, routePadding + y * routeHeight);
    }

    final routePath = Path();
    final first = project(points.first);
    routePath.moveTo(first.dx, first.dy);
    for (final point in points.skip(1)) {
      final offset = project(point);
      routePath.lineTo(offset.dx, offset.dy);
    }

    final routeHalo = Paint()
      ..color = Colors.white
      ..strokeWidth = 11
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final route = Paint()
      ..color = lineColor
      ..strokeWidth = 5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(routePath, routeHalo);
    canvas.drawPath(routePath, route);

    final start = project(points.first);
    final finish = project(points.last);
    canvas.drawCircle(start, 10, Paint()..color = moveaCoral);
    canvas.drawCircle(start, 5, Paint()..color = Colors.white);
    canvas.drawCircle(finish, 10, Paint()..color = lineColor);
    canvas.drawCircle(finish, 5, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(covariant _RouteThumbnailPainter oldDelegate) =>
      oldDelegate.points != points || oldDelegate.lineColor != lineColor;
}

class WorkoutHistoryPage extends StatefulWidget {
  const WorkoutHistoryPage(
      {required this.store, required this.routeStore, super.key});

  final WorkoutStore store;
  final RouteStore routeStore;

  @override
  State<WorkoutHistoryPage> createState() => _WorkoutHistoryPageState();
}

class _WorkoutHistoryPageState extends State<WorkoutHistoryPage> {
  ActivityType? filter;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('全部运动记录')),
      body: AnimatedBuilder(
        animation: widget.store,
        builder: (context, _) {
          final records = filter == null
              ? widget.store.records
              : widget.store.records
                  .where((record) => record.activity == filter)
                  .toList();

          return MoveaContentFrame(
            maxWidth: 840,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
              children: [
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _HistoryFilter(
                        label: '全部',
                        selected: filter == null,
                        onSelected: () => setState(() => filter = null),
                      ),
                      for (final type in ActivityType.values)
                        _HistoryFilter(
                          label: type.label,
                          selected: filter == type,
                          onSelected: () => setState(() => filter = type),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                if (records.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 80),
                    child: Center(child: Text('还没有符合条件的运动记录')),
                  )
                else
                  for (final record in records)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Card(
                        child: ListTile(
                          key: ValueKey('history-record-${record.id}'),
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => WorkoutDetailPage(
                                  record: record,
                                  routeStore: widget.routeStore),
                            ),
                          ),
                          leading: CircleAvatar(
                            backgroundColor: moveaCoral.withValues(alpha: .12),
                            child: Text(record.activity.icon),
                          ),
                          title: Text(
                            record.activity.label,
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                          subtitle: Text(
                            '${record.startedAt.month}月${record.startedAt.day}日  ·  ${record.sourceDevice}',
                          ),
                          trailing: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                formatDuration(record.duration),
                                style: const TextStyle(
                                    fontWeight: FontWeight.w800),
                              ),
                              Text(
                                record.distanceLabel,
                                style: const TextStyle(
                                    fontSize: 12, color: Colors.black54),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _HistoryFilter extends StatelessWidget {
  const _HistoryFilter(
      {required this.label, required this.selected, required this.onSelected});

  final String label;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => onSelected(),
      ),
    );
  }
}

class WorkoutDetailPage extends StatelessWidget {
  const WorkoutDetailPage({required this.record, this.routeStore, super.key});

  final WorkoutRecord record;
  final RouteStore? routeStore;

  Future<void> _saveAsRoute(BuildContext context) async {
    final store = routeStore;
    if (store == null || record.routePoints.length < 2) return;
    final name = await showDialog<String>(
      context: context,
      builder: (_) => _SaveRouteDialog(
        initialName:
            '${record.activity.label} · ${record.startedAt.month}月${record.startedAt.day}日',
      ),
    );
    if (name == null || name.isEmpty) return;

    await store.save(RouteSummary(
      id: 'record-route-${record.id}',
      name: name,
      distanceMeters: record.distanceMeters,
      estimatedMinutes: math.max(1, (record.duration.inSeconds / 60).ceil()),
      elevationMeters: record.elevationGainMeters.round(),
      tags: [record.activity.label, '我的记录'],
      points: record.routePoints,
      isSaved: true,
    ));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('已保存“$name”到我的路线')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dateLabel =
        '${record.startedAt.year}年${record.startedAt.month}月${record.startedAt.day}日';
    final splits = _workoutSplits(record);
    final pace = record.distanceMeters > 0
        ? '${(record.duration.inSeconds / (record.distanceMeters / 1000) / 60).toStringAsFixed(1)} min/km'
        : '--';

    return Scaffold(
      appBar: AppBar(
        title: const Text('运动详情'),
        actions: [
          if (routeStore != null && record.routePoints.length > 1)
            IconButton(
              onPressed: () => _saveAsRoute(context),
              tooltip: '保存为路线',
              icon: const Icon(Icons.bookmark_add_outlined),
            ),
        ],
      ),
      body: MoveaContentFrame(
        maxWidth: 760,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 32),
          children: [
            Card(
              color: moveaLemon,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 28,
                      backgroundColor: Colors.white,
                      child: Text(record.activity.icon,
                          style: const TextStyle(fontSize: 25)),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(record.activity.label,
                              style: const TextStyle(
                                  fontSize: 22, fontWeight: FontWeight.w800)),
                          const SizedBox(height: 4),
                          Text('$dateLabel · ${record.sourceDevice}',
                              style: const TextStyle(color: Colors.black54)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            const MoveaSectionTitle('本次数据'),
            const SizedBox(height: 10),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 1.8,
              children: [
                _DetailMetric(
                    label: '运动时长', value: formatDuration(record.duration)),
                _DetailMetric(label: '距离', value: record.distanceLabel),
                _DetailMetric(label: '平均配速', value: pace),
                _DetailMetric(
                    label: '平均速度',
                    value: record.activity.usesLocation
                        ? '${(record.averageSpeedMetersPerSecond * 3.6).toStringAsFixed(1)} km/h'
                        : '--'),
                _DetailMetric(
                    label: '累计爬升',
                    value: record.activity.usesLocation &&
                            record.elevationGainMeters > 0
                        ? '${record.elevationGainMeters.round()} m'
                        : '--'),
                _DetailMetric(
                    label: 'GPS 点位',
                    value: record.activity.usesLocation
                        ? '${record.routePoints.length} 个'
                        : '不适用'),
                const _DetailMetric(label: '数据状态', value: '本地已保存'),
              ],
            ),
            const SizedBox(height: 18),
            const MoveaSectionTitle('实际 GPS 轨迹'),
            const SizedBox(height: 10),
            if (record.routePoints.length > 1)
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    height: 220,
                    child: _RouteThumbnail(
                      points: _toLatLngs(record.routePoints),
                      lineColor: moveaCoral,
                    ),
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed:
                        routeStore == null ? null : () => _saveAsRoute(context),
                    icon: const Icon(Icons.bookmark_add_outlined),
                    label: const Text('保存为我的路线'),
                  ),
                ],
              )
            else
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      Icon(
                          record.activity.usesLocation
                              ? Icons.route_outlined
                              : Icons.home_work_outlined,
                          size: 32,
                          color: moveaBlue),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text(
                          record.activity.usesLocation
                              ? '本次没有采集到足够的 GPS 点位，已保存时长和距离摘要。下次开始前请打开系统定位服务。'
                              : '室内训练不记录地图路线，动作明细和训练时长会保存在训练记录中。',
                          style: const TextStyle(color: Colors.black54),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            if (splits.isNotEmpty) ...[
              const SizedBox(height: 18),
              const MoveaSectionTitle('分段配速'),
              const SizedBox(height: 10),
              Card(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: Column(
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(bottom: 6),
                        child: Row(
                          children: [
                            SizedBox(
                                width: 74,
                                child: Text('分段',
                                    style: TextStyle(
                                        fontSize: 12, color: Colors.black54))),
                            Expanded(
                                child: Text('距离',
                                    style: TextStyle(
                                        fontSize: 12, color: Colors.black54))),
                            SizedBox(
                                width: 74,
                                child: Text('用时',
                                    style: TextStyle(
                                        fontSize: 12, color: Colors.black54))),
                            SizedBox(
                                width: 86,
                                child: Text('配速',
                                    textAlign: TextAlign.end,
                                    style: TextStyle(
                                        fontSize: 12, color: Colors.black54))),
                          ],
                        ),
                      ),
                      for (final split in splits)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Row(
                            children: [
                              SizedBox(
                                  width: 74,
                                  child: Text(split.label,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w700))),
                              Expanded(
                                  child: Text(
                                      '${(split.distanceMeters / 1000).toStringAsFixed(2)} km')),
                              SizedBox(
                                  width: 74,
                                  child: Text(formatDuration(split.duration))),
                              SizedBox(
                                  width: 86,
                                  child: Text(
                                      _formatPace(
                                          split.paceMinutesPerKilometer),
                                      textAlign: TextAlign.end,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                          color: moveaBlue))),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 18),
            Card(
              color: moveaMint,
              child: ListTile(
                leading: const Icon(Icons.insights_outlined, color: moveaBlue),
                title: const Text('下一步可完善',
                    style: TextStyle(fontWeight: FontWeight.w800)),
                subtitle: Text(record.activity.usesLocation
                    ? '心率区间、卡路里和后台持续记录'
                    : '动作完成度、训练负荷和恢复建议'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SaveRouteDialog extends StatefulWidget {
  const _SaveRouteDialog({required this.initialName});

  final String initialName;

  @override
  State<_SaveRouteDialog> createState() => _SaveRouteDialogState();
}

class _SaveRouteDialogState extends State<_SaveRouteDialog> {
  late final TextEditingController controller;

  @override
  void initState() {
    super.initState();
    controller = TextEditingController(text: widget.initialName);
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('保存为我的路线'),
      content: TextField(
        controller: controller,
        autofocus: true,
        decoration: const InputDecoration(labelText: '路线名称'),
        textInputAction: TextInputAction.done,
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context), child: const Text('取消')),
        FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('保存')),
      ],
    );
  }
}

class _DetailMetric extends StatelessWidget {
  const _DetailMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(label, style: const TextStyle(color: Colors.black54)),
            const SizedBox(height: 5),
            Text(value,
                style:
                    const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
          ],
        ),
      ),
    );
  }
}

class HealthPage extends StatelessWidget {
  const HealthPage({required this.store, super.key});

  final HealthStore store;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: store,
      builder: (context, _) {
        final snapshot = store.snapshot;
        final sleep = snapshot.sleep;

        return MoveaContentFrame(
          maxWidth: 820,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
            children: [
              Text('健康',
                  style: Theme.of(context)
                      .textTheme
                      .headlineMedium
                      ?.copyWith(fontWeight: FontWeight.w800, color: moveaInk)),
              const Text('了解身体，跑得更远', style: TextStyle(color: Colors.black54)),
              const SizedBox(height: 14),
              Card(
                color: snapshot.isDeviceSynced ? moveaMint : moveaLavender,
                child: ListTile(
                  leading: Icon(
                    snapshot.isDeviceSynced
                        ? Icons.cloud_done_outlined
                        : Icons.sync_problem_outlined,
                    color: snapshot.isDeviceSynced
                        ? const Color(0xFF2EAF72)
                        : moveaBlue,
                  ),
                  title: Row(
                    children: [
                      const Text('健康数据中心',
                          style: TextStyle(fontWeight: FontWeight.w800)),
                      const SizedBox(width: 8),
                      _HealthSourcePill(source: snapshot.source),
                    ],
                  ),
                  subtitle: Text(
                    store.isLoading
                        ? '正在读取健康数据…'
                        : snapshot.isDeviceSynced
                            ? '已从 ${snapshot.sourceLabel} 读取设备数据'
                            : '当前为演示数据；连接设备后才会展示真实健康指标',
                  ),
                  trailing: IconButton(
                    onPressed: store.isLoading ? null : store.refresh,
                    tooltip: '刷新健康数据',
                    icon: const Icon(Icons.refresh),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              InkWell(
                onTap: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => SleepDetailPage(summary: sleep))),
                borderRadius: BorderRadius.circular(20),
                child: Card(
                  color: moveaMint,
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          const Text('昨晚睡眠',
                              style: TextStyle(fontWeight: FontWeight.w700)),
                          const Spacer(),
                          Text('${sleep.bedtime} → ${sleep.wakeTime}',
                              style: const TextStyle(color: Colors.black54)),
                          const SizedBox(width: 6),
                          const Icon(Icons.chevron_right, size: 18),
                        ]),
                        const SizedBox(height: 8),
                        Text(formatHoursMinutes(sleep.duration),
                            style: const TextStyle(
                                fontSize: 42,
                                fontWeight: FontWeight.w800,
                                color: moveaInk)),
                        Text(
                            '睡眠质量：${sleep.quality} · 清醒 ${sleep.awakeMinutes} 分钟',
                            style: const TextStyle(color: Colors.black54)),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              const MoveaSectionTitle('身体指标', action: '最近同步'),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(
                  child: _HealthMetricCard(
                      title: '当前体重',
                      value: '${snapshot.weightKg} kg',
                      note: '较上周 -0.6 kg'),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _HealthMetricCard(
                      title: '静息心率',
                      value: '${snapshot.restingHeartRate} bpm',
                      note: '过去 7 天稳定'),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _HealthMetricCard(
                      title: '今日步数',
                      value: '${snapshot.steps}',
                      note: '目标 10,000'),
                ),
              ]),
              const SizedBox(height: 18),
              const MoveaSectionTitle('近 7 天睡眠时长', action: '平均 7h 12m'),
              const SizedBox(height: 10),
              Card(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 18, 14, 12),
                  child: SizedBox(
                    height: 160,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        for (final item in const [
                          ('一', 62.0),
                          ('二', 78.0),
                          ('三', 92.0),
                          ('四', 70.0),
                          ('五', 84.0),
                          ('六', 90.0),
                          ('日', 100.0),
                        ])
                          Column(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Container(
                                  width: 25,
                                  height: item.$2,
                                  decoration: BoxDecoration(
                                      color: item.$1 == '日'
                                          ? moveaBlue
                                          : moveaMint,
                                      borderRadius: BorderRadius.circular(8))),
                              const SizedBox(height: 5),
                              Text(item.$1,
                                  style: const TextStyle(
                                      fontSize: 11, color: Colors.black54)),
                            ],
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              const Card(
                color: moveaLemon,
                child: ListTile(
                  leading:
                      Icon(Icons.tips_and_updates_outlined, color: moveaCoral),
                  title: Text('今天的恢复提示',
                      style: TextStyle(fontWeight: FontWeight.w800)),
                  subtitle: Text('昨晚深度睡眠 1h 18m，今天适合保持轻到中等强度。'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _HealthSourcePill extends StatelessWidget {
  const _HealthSourcePill({required this.source});

  final HealthDataSource source;

  @override
  Widget build(BuildContext context) {
    final isDemo = source == HealthDataSource.demo;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: isDemo
            ? Colors.white
            : const Color(0xFF2EAF72).withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        source.label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: isDemo ? Colors.black54 : const Color(0xFF2EAF72),
        ),
      ),
    );
  }
}

class _HealthMetricCard extends StatelessWidget {
  const _HealthMetricCard(
      {required this.title, required this.value, required this.note});

  final String title;
  final String value;
  final String note;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, color: Colors.black54)),
          const SizedBox(height: 8),
          FittedBox(
            alignment: Alignment.centerLeft,
            fit: BoxFit.scaleDown,
            child: Text(value,
                style:
                    const TextStyle(fontSize: 19, fontWeight: FontWeight.w800)),
          ),
          const SizedBox(height: 4),
          Text(note,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11, color: Colors.black54)),
        ]),
      ),
    );
  }
}

class SleepDetailPage extends StatelessWidget {
  const SleepDetailPage({required this.summary, super.key});

  final SleepSummary summary;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('睡眠详情')),
      body: MoveaContentFrame(
        maxWidth: 760,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 32),
          children: [
            Card(
              color: moveaMint,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      const Icon(Icons.bedtime_outlined, color: moveaBlue),
                      const SizedBox(width: 8),
                      const Text('昨晚睡眠',
                          style: TextStyle(fontWeight: FontWeight.w800)),
                      const Spacer(),
                      Text(summary.quality,
                          style: const TextStyle(
                              color: moveaBlue, fontWeight: FontWeight.w800)),
                    ]),
                    const SizedBox(height: 14),
                    Text(formatHoursMinutes(summary.duration),
                        style: const TextStyle(
                            fontSize: 44,
                            fontWeight: FontWeight.w800,
                            color: moveaInk)),
                    Text('${summary.bedtime} 入睡  ·  ${summary.wakeTime} 起床',
                        style: const TextStyle(color: Colors.black54)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 18),
            const MoveaSectionTitle('睡眠阶段'),
            const SizedBox(height: 10),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (summary.segments.isEmpty)
                      const Text('接入 HealthKit 后显示逐段睡眠数据。')
                    else
                      SizedBox(
                        height: 38,
                        child: Row(
                          children: [
                            for (final segment in summary.segments)
                              Expanded(
                                flex: segment.durationMinutes,
                                child: Container(
                                  margin: const EdgeInsets.only(right: 2),
                                  decoration: BoxDecoration(
                                    color: _sleepStageColor(segment.stage),
                                    borderRadius: BorderRadius.circular(5),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 14,
                      runSpacing: 8,
                      children: [
                        _SleepLegend(
                            stage: SleepStage.awake,
                            value: '${summary.awakeMinutes} 分钟'),
                        const _SleepLegend(
                            stage: SleepStage.core, value: '主体阶段'),
                        _SleepLegend(
                            stage: SleepStage.deep,
                            value: '${summary.deepMinutes} 分钟'),
                        _SleepLegend(
                            stage: SleepStage.rem,
                            value: '${summary.remMinutes} 分钟'),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 18),
            const MoveaSectionTitle('睡眠指标'),
            const SizedBox(height: 10),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 1.9,
              children: [
                const _DetailMetric(label: '睡眠效率', value: '92%'),
                const _DetailMetric(label: '清醒次数', value: '3 次'),
                _DetailMetric(
                    label: '深度睡眠', value: '${summary.deepMinutes} 分钟'),
                _DetailMetric(label: '快速眼动', value: '${summary.remMinutes} 分钟'),
              ],
            ),
            const SizedBox(height: 18),
            const Card(
              color: moveaLemon,
              child: ListTile(
                leading: Icon(Icons.auto_awesome_outlined, color: moveaCoral),
                title:
                    Text('睡眠解读', style: TextStyle(fontWeight: FontWeight.w800)),
                subtitle: Text('睡眠时长达标，深度睡眠集中在前半夜。建议继续保持稳定的入睡时间。'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SleepLegend extends StatelessWidget {
  const _SleepLegend({required this.stage, required this.value});

  final SleepStage stage;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
              color: _sleepStageColor(stage), shape: BoxShape.circle)),
      const SizedBox(width: 5),
      Text('${stage.label} $value',
          style: const TextStyle(fontSize: 12, color: Colors.black54)),
    ]);
  }
}

Color _sleepStageColor(SleepStage stage) {
  switch (stage) {
    case SleepStage.awake:
      return moveaCoral;
    case SleepStage.rem:
      return moveaLavender;
    case SleepStage.core:
      return moveaBlue;
    case SleepStage.deep:
      return const Color(0xFF334B86);
  }
}

class RoutesPage extends StatefulWidget {
  const RoutesPage({required this.store, required this.onFollow, super.key});

  final RouteStore store;
  final ValueChanged<RouteSummary> onFollow;

  @override
  State<RoutesPage> createState() => _RoutesPageState();
}

class _RoutesPageState extends State<RoutesPage> {
  int tab = 0;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.store,
      builder: (context, _) {
        final visible = tab == 2
            ? widget.store.routes.where((route) => route.isSaved).toList()
            : widget.store.routes;

        return MoveaContentFrame(
          maxWidth: 980,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text('路线',
                  style: Theme.of(context)
                      .textTheme
                      .headlineMedium
                      ?.copyWith(fontWeight: FontWeight.w800, color: moveaInk)),
              const Text('把喜欢的路线留给下一次',
                  style: TextStyle(color: Colors.black54)),
              const SizedBox(height: 16),
              Row(children: [
                for (var index = 0; index < 3; index++)
                  Padding(
                    padding: const EdgeInsets.only(right: 20),
                    child: TextButton(
                      onPressed: () => setState(() => tab = index),
                      child: Text(['推荐', '附近', '我的'][index],
                          style: TextStyle(
                              fontWeight: tab == index
                                  ? FontWeight.w800
                                  : FontWeight.normal,
                              color:
                                  tab == index ? moveaBlue : Colors.black54)),
                    ),
                  ),
              ]),
              if (visible.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 80),
                  child: Center(child: Text('还没有保存的路线')),
                )
              else
                for (final route in visible)
                  _RouteCard(
                    route: route,
                    onSave: () => widget.store.toggleSaved(route.id),
                    onOpen: () => Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => RouteDetailPage(
                            route: route,
                            store: widget.store,
                            onFollow: widget.onFollow))),
                    onFollow: () => widget.onFollow(route),
                  ),
            ],
          ),
        );
      },
    );
  }
}

class _RouteCard extends StatelessWidget {
  const _RouteCard({
    required this.route,
    required this.onSave,
    required this.onOpen,
    required this.onFollow,
  });

  final RouteSummary route;
  final VoidCallback onSave;
  final VoidCallback onOpen;
  final VoidCallback onFollow;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: onOpen,
            child: SizedBox(
                height: 180,
                child: _RouteThumbnail(
                    points: route.points.isEmpty
                        ? _demoRoute
                        : _toLatLngs(route.points))),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Expanded(
                    child: Text(route.name,
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.w800)),
                  ),
                  Text(route.distanceLabel,
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.w800)),
                  IconButton(
                    onPressed: onSave,
                    tooltip: route.isSaved ? '取消保存' : '保存路线',
                    icon: Icon(
                        route.isSaved ? Icons.bookmark : Icons.bookmark_border),
                  ),
                ]),
                const SizedBox(height: 4),
                Text(
                    '约 ${route.estimatedMinutes} 分钟  ·  爬升 ${route.elevationMeters} m',
                    style: const TextStyle(color: Colors.black54)),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  children: [
                    for (final tag in route.tags)
                      Chip(
                        label: Text(tag),
                        visualDensity: VisualDensity.compact,
                        backgroundColor: moveaLavender,
                        side: BorderSide.none,
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: onFollow,
                    icon: const Icon(Icons.navigation),
                    label: const Text('跟随路线'),
                    style: FilledButton.styleFrom(backgroundColor: moveaBlue),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class RouteDetailPage extends StatelessWidget {
  const RouteDetailPage({
    required this.route,
    required this.store,
    required this.onFollow,
    super.key,
  });

  final RouteSummary route;
  final RouteStore store;
  final ValueChanged<RouteSummary> onFollow;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('路线详情'),
        actions: [
          IconButton(
            onPressed: () => store.toggleSaved(route.id),
            tooltip: route.isSaved ? '取消保存' : '保存路线',
            icon: Icon(route.isSaved ? Icons.bookmark : Icons.bookmark_border),
          ),
        ],
      ),
      body: MoveaContentFrame(
        maxWidth: 760,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 32),
          children: [
            SizedBox(
              height: 240,
              child: _RouteThumbnail(
                  points: route.points.isEmpty
                      ? _demoRoute
                      : _toLatLngs(route.points)),
            ),
            const SizedBox(height: 16),
            Row(children: [
              Expanded(
                child: Text(route.name,
                    style: const TextStyle(
                        fontSize: 25, fontWeight: FontWeight.w800)),
              ),
              Text(route.distanceLabel,
                  style: const TextStyle(
                      fontSize: 22, fontWeight: FontWeight.w800)),
            ]),
            const SizedBox(height: 6),
            Text(
                '约 ${route.estimatedMinutes} 分钟  ·  爬升 ${route.elevationMeters} m',
                style: const TextStyle(color: Colors.black54)),
            const SizedBox(height: 14),
            Wrap(
              spacing: 6,
              children: [
                for (final tag in route.tags)
                  Chip(
                    label: Text(tag),
                    backgroundColor: moveaLavender,
                    side: BorderSide.none,
                  ),
              ],
            ),
            const SizedBox(height: 16),
            const Card(
              color: moveaMint,
              child: ListTile(
                leading: Icon(Icons.info_outline, color: moveaBlue),
                title:
                    Text('路线说明', style: TextStyle(fontWeight: FontWeight.w800)),
                subtitle: Text('蓝线代表计划路线。开始运动后，当前位置和真实轨迹会叠加显示。'),
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () => onFollow(route),
              icon: const Icon(Icons.navigation),
              label: const Text('开始并跟随路线'),
              style: FilledButton.styleFrom(
                  backgroundColor: moveaBlue,
                  minimumSize: const Size.fromHeight(52)),
            ),
          ],
        ),
      ),
    );
  }
}

class LearnPage extends StatefulWidget {
  const LearnPage({super.key});

  @override
  State<LearnPage> createState() => _LearnPageState();
}

class _LearnPageState extends State<LearnPage> {
  ActivityType category = ActivityType.run;

  @override
  Widget build(BuildContext context) {
    final content = {
      ActivityType.run: [
        ('跑前热身', '激活身体，跑得更轻松'),
        ('跑后拉伸', '放松肌肉，恢复更轻松'),
        ('核心训练', '更强的核心，让你跑得更稳')
      ],
      ActivityType.ride: [
        ('骑行前检查', '调整座高，检查刹车和胎压'),
        ('骑行节奏', '找到适合自己的踏频'),
        ('爬坡技巧', '用更少的力气完成爬坡')
      ],
      ActivityType.stretch: [
        ('全身唤醒', '从肩颈到髋部逐步活动开'),
        ('髋部灵活性', '提升步幅和日常活动舒适度'),
        ('恢复拉伸', '缓解紧绷，找回轻松状态')
      ],
      ActivityType.strength: [
        ('核心训练', '增强核心，让动作更稳定'),
        ('下肢力量', '循序渐进训练臀腿力量'),
        ('全身力量', '用简单动作覆盖主要肌群')
      ],
    }[category]!;

    return MoveaContentFrame(
      maxWidth: 820,
      child: ListView(padding: const EdgeInsets.all(20), children: [
        Text('学习',
            style: Theme.of(context)
                .textTheme
                .headlineMedium
                ?.copyWith(fontWeight: FontWeight.w800, color: moveaInk)),
        const Text('简单有效，陪你一直动下去', style: TextStyle(color: Colors.black54)),
        const SizedBox(height: 16),
        SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
                children: ActivityType.values
                    .map((type) => Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                            label: Text(type.label),
                            selected: category == type,
                            onSelected: (_) =>
                                setState(() => category = type))))
                    .toList())),
        const SizedBox(height: 12),
        for (final lesson in content)
          Card(
              color: [
                moveaLavender,
                moveaMint,
                moveaLemon
              ][content.indexOf(lesson)],
              margin: const EdgeInsets.only(bottom: 12),
              child: ListTile(
                  contentPadding: const EdgeInsets.all(16),
                  title: Text(lesson.$1,
                      style: const TextStyle(fontWeight: FontWeight.w800)),
                  subtitle: Text(lesson.$2),
                  trailing: const Icon(Icons.play_circle_fill,
                      color: moveaCoral, size: 32))),
      ]),
    );
  }
}
