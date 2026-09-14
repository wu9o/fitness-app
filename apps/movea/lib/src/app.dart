import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' show LatLng;
import 'package:movea_data/movea_data.dart';
import 'package:movea_design/movea_design.dart';
import 'package:movea_domain/movea_domain.dart';

class MoveaShell extends StatefulWidget {
  const MoveaShell({super.key});

  @override
  State<MoveaShell> createState() => _MoveaShellState();
}

class _MoveaShellState extends State<MoveaShell> {
  final WorkoutStore store = WorkoutStore();
  int selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    unawaited(store.restore());
  }

  void openActivity() => setState(() => selectedIndex = 1);

  void openHistory() {
    Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => WorkoutHistoryPage(store: store)));
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      HomePage(store: store, onStart: openActivity, onHistory: openHistory),
      ActivityPage(store: store),
      const HealthPage(),
      RoutesPage(onFollow: openActivity),
      const LearnPage(),
    ];
    final isWide = MediaQuery.sizeOf(context).width >= 700;

    return Scaffold(
      body: isWide
          ? Row(
              children: [
                _MoveaWideNavigation(
                    selectedIndex: selectedIndex,
                    onSelected: (index) =>
                        setState(() => selectedIndex = index)),
                const VerticalDivider(width: 1),
                Expanded(
                  child: SafeArea(
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1280),
                        child:
                            IndexedStack(index: selectedIndex, children: pages),
                      ),
                    ),
                  ),
                ),
              ],
            )
          : SafeArea(
              child: IndexedStack(index: selectedIndex, children: pages)),
      bottomNavigationBar: isWide
          ? null
          : NavigationBar(
              selectedIndex: selectedIndex,
              onDestinationSelected: (index) =>
                  setState(() => selectedIndex = index),
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

class HomePage extends StatelessWidget {
  const HomePage(
      {required this.store,
      required this.onStart,
      required this.onHistory,
      super.key});

  final WorkoutStore store;
  final VoidCallback onStart;
  final VoidCallback onHistory;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: store,
      builder: (context, _) {
        final records = store.records;
        final outdoorDistance = store.outdoorDistanceMeters / 1000;
        final weeklyValue = outdoorDistance > 0
            ? '${outdoorDistance.toStringAsFixed(1)} km'
            : '${store.recordCount} 次';

        return MoveaContentFrame(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 22, 20, 24),
            children: [
              Text('今天想动一动吗？',
                  style: Theme.of(context)
                      .textTheme
                      .headlineMedium
                      ?.copyWith(fontWeight: FontWeight.w800, color: moveaInk)),
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
              const SizedBox(height: 14),
              Row(
                children: [
                  const Expanded(
                      child: _MetricCard(
                          title: '昨晚睡眠',
                          value: '7h 32m',
                          note: '睡得不错',
                          color: moveaMint)),
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
                    child: _RecentWorkoutCard(record: record),
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
  const _RecentWorkoutCard({required this.record});

  final WorkoutRecord record;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
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

class ActivityPage extends StatefulWidget {
  const ActivityPage({required this.store, super.key});

  final WorkoutStore store;

  @override
  State<ActivityPage> createState() => _ActivityPageState();
}

class _ActivityPageState extends State<ActivityPage> {
  ActivityType activity = ActivityType.run;
  DateTime? startedAt;
  DateTime? pausedAt;
  Duration pausedDuration = Duration.zero;
  Timer? timer;
  Duration elapsed = Duration.zero;
  bool paused = false;

  bool get recording => startedAt != null;

  void start() {
    setState(() {
      startedAt = DateTime.now();
      pausedAt = null;
      pausedDuration = Duration.zero;
      elapsed = Duration.zero;
      paused = false;
    });
    timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || startedAt == null || paused) return;
      setState(() => elapsed = activeElapsed());
    });
  }

  Duration activeElapsed() {
    final startTime = startedAt;
    if (startTime == null) return Duration.zero;
    final currentPause =
        pausedAt == null ? Duration.zero : DateTime.now().difference(pausedAt!);
    return DateTime.now().difference(startTime) - pausedDuration - currentPause;
  }

  void togglePause() {
    final now = DateTime.now();
    setState(() {
      if (paused) {
        if (pausedAt != null) pausedDuration += now.difference(pausedAt!);
        pausedAt = null;
        paused = false;
        elapsed = activeElapsed();
      } else {
        pausedAt = now;
        paused = true;
      }
    });
  }

  void finish() {
    final startTime = startedAt;
    if (startTime == null) return;
    widget.store.add(WorkoutRecord(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        activity: activity,
        startedAt: startTime,
        duration: activeElapsed(),
        distanceMeters: 0));
    timer?.cancel();
    setState(() {
      startedAt = null;
      pausedAt = null;
      pausedDuration = Duration.zero;
      elapsed = Duration.zero;
      paused = false;
    });
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.bottomCenter,
      children: [
        if (activity.usesLocation)
          const _MapPreview(points: _demoRoute)
        else
          const ColoredBox(color: moveaPaper),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Align(
            alignment: Alignment.bottomCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Row(children: [
                      Text(activity.usesLocation ? '地图已接入 · 定位授权后记录路线' : '室内训练',
                          style: const TextStyle(fontWeight: FontWeight.w700)),
                      const Spacer(),
                      Text(activity.label,
                          style: const TextStyle(fontWeight: FontWeight.w700)),
                    ]),
                    if (!recording) ...[
                      const SizedBox(height: 14),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                            children: ActivityType.values
                                .map((type) => Padding(
                                      padding: const EdgeInsets.only(right: 8),
                                      child: ChoiceChip(
                                          label: Text(
                                              '${type.icon} ${type.label}'),
                                          selected: activity == type,
                                          onSelected: (_) =>
                                              setState(() => activity = type)),
                                    ))
                                .toList()),
                      ),
                    ],
                    const SizedBox(height: 18),
                    if (recording) ...[
                      if (activity.usesLocation)
                        const Text('0.00 km',
                            style: TextStyle(
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
                      const SizedBox(height: 16),
                      Row(children: [
                        Expanded(
                            child: FilledButton.icon(
                                onPressed: togglePause,
                                icon: Icon(
                                    paused ? Icons.play_arrow : Icons.pause),
                                label: Text(paused ? '继续' : '暂停'),
                                style: FilledButton.styleFrom(
                                    backgroundColor: moveaCoral))),
                        const SizedBox(width: 10),
                        OutlinedButton(
                            onPressed: finish, child: const Text('结束')),
                      ]),
                    ] else ...[
                      Text(activity.icon, style: const TextStyle(fontSize: 44)),
                      const SizedBox(height: 8),
                      const Text('准备好了吗？',
                          style: TextStyle(
                              fontSize: 22, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 5),
                      Text(
                          activity.usesLocation
                              ? '开始后将记录你的路线和运动数据'
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
                                  builder: (_) =>
                                      WorkoutHistoryPage(store: widget.store))),
                          icon: const Icon(Icons.list_alt),
                          label: const Text('查看全部运动记录')),
                    ],
                  ]),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

String formatDuration(Duration duration) =>
    '${duration.inMinutes.toString().padLeft(2, '0')}:${(duration.inSeconds % 60).toString().padLeft(2, '0')}';

const _demoRoute = <LatLng>[
  LatLng(31.2304, 121.4737),
  LatLng(31.2322, 121.4780),
  LatLng(31.2290, 121.4835),
  LatLng(31.2258, 121.4790),
  LatLng(31.2244, 121.4720),
  LatLng(31.2280, 121.4705),
];

class _MapPreview extends StatelessWidget {
  const _MapPreview({required this.points});

  final List<LatLng> points;

  @override
  Widget build(BuildContext context) {
    final start = points.first;
    final finish = points.last;
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: FlutterMap(
        options: MapOptions(
          initialCenter: start,
          initialZoom: 13.7,
          minZoom: 11,
          maxZoom: 17,
          interactionOptions: const InteractionOptions(
            flags: InteractiveFlag.all,
          ),
        ),
        children: [
          TileLayer(
            urlTemplate: 'https://tile.openstreetmap.de/{z}/{x}/{y}.png',
            userAgentPackageName: 'com.wu9o.movea',
          ),
          const Positioned.fill(
            child: IgnorePointer(
              child: ColoredBox(color: Color(0xB3F2F5F3)),
            ),
          ),
          PolylineLayer(
            polylines: [
              Polyline(
                points: points,
                color: moveaBlue,
                strokeWidth: 5,
                borderColor: Colors.white,
                borderStrokeWidth: 2,
              ),
            ],
          ),
          MarkerLayer(
            markers: [
              Marker(
                point: start,
                width: 36,
                height: 36,
                child:
                    const _MapMarker(color: moveaCoral, icon: Icons.play_arrow),
              ),
              Marker(
                point: finish,
                width: 36,
                height: 36,
                child: const _MapMarker(color: moveaBlue, icon: Icons.flag),
              ),
            ],
          ),
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
                  Text('可缩放 · 可拖动',
                      style:
                          TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                ]),
              ),
            ),
          ),
          const RichAttributionWidget(
            attributions: [
              TextSourceAttribution('© OpenStreetMap contributors'),
            ],
          ),
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

class _RouteThumbnail extends StatelessWidget {
  const _RouteThumbnail({required this.points});

  final List<LatLng> points;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: CustomPaint(
        key: const ValueKey('route-thumbnail'),
        painter: _RouteThumbnailPainter(points),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _RouteThumbnailPainter extends CustomPainter {
  _RouteThumbnailPainter(this.points);

  final List<LatLng> points;

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
    final latRange = (maxLat - minLat).abs();
    final lonRange = (maxLon - minLon).abs();
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
      ..color = moveaBlue
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
    canvas.drawCircle(finish, 10, Paint()..color = moveaBlue);
    canvas.drawCircle(finish, 5, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(covariant _RouteThumbnailPainter oldDelegate) =>
      oldDelegate.points != points;
}

class WorkoutHistoryPage extends StatefulWidget {
  const WorkoutHistoryPage({required this.store, super.key});

  final WorkoutStore store;

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

class HealthPage extends StatelessWidget {
  const HealthPage({super.key});

  @override
  Widget build(BuildContext context) {
    return MoveaContentFrame(
      maxWidth: 820,
      child: ListView(padding: const EdgeInsets.all(20), children: [
        Text('健康',
            style: Theme.of(context)
                .textTheme
                .headlineMedium
                ?.copyWith(fontWeight: FontWeight.w800, color: moveaInk)),
        const Text('了解身体，跑得更远', style: TextStyle(color: Colors.black54)),
        const SizedBox(height: 18),
        const Card(
            color: moveaMint,
            child: Padding(
                padding: EdgeInsets.all(18),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('昨晚睡眠',
                          style: TextStyle(fontWeight: FontWeight.w700)),
                      SizedBox(height: 8),
                      Text('7h 32m',
                          style: TextStyle(
                              fontSize: 42,
                              fontWeight: FontWeight.w800,
                              color: moveaInk)),
                      Text('睡眠质量：不错', style: TextStyle(color: Colors.black54))
                    ]))),
        const SizedBox(height: 18),
        const MoveaSectionTitle('近 7 天睡眠时长', action: '平均 7h 12m'),
        const SizedBox(height: 12),
        Card(
            child: Padding(
                padding: const EdgeInsets.all(18),
                child: SizedBox(
                    height: 150,
                    child: Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          for (final height in [
                            62.0,
                            78.0,
                            92.0,
                            70.0,
                            84.0,
                            90.0,
                            100.0
                          ])
                            Container(
                                width: 25,
                                height: height,
                                decoration: BoxDecoration(
                                    color: moveaMint,
                                    borderRadius: BorderRadius.circular(8)))
                        ])))),
      ]),
    );
  }
}

class RoutesPage extends StatefulWidget {
  const RoutesPage({required this.onFollow, super.key});

  final VoidCallback onFollow;

  @override
  State<RoutesPage> createState() => _RoutesPageState();
}

class _RoutesPageState extends State<RoutesPage> {
  int tab = 0;
  final routes = const [
    ('公园环线', '5.2 km', '约 32 分钟  ·  爬升 80 m'),
    ('河岸风景线', '8.1 km', '约 54 分钟  ·  爬升 120 m')
  ];

  @override
  Widget build(BuildContext context) {
    final visible = tab == 2 ? <(String, String, String)>[] : routes;
    return MoveaContentFrame(
      maxWidth: 980,
      child: ListView(padding: const EdgeInsets.all(20), children: [
        Text('路线',
            style: Theme.of(context)
                .textTheme
                .headlineMedium
                ?.copyWith(fontWeight: FontWeight.w800, color: moveaInk)),
        const Text('把喜欢的路线留给下一次', style: TextStyle(color: Colors.black54)),
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
                            color: tab == index ? moveaBlue : Colors.black54))))
        ]),
        if (visible.isEmpty)
          const Padding(
              padding: EdgeInsets.symmetric(vertical: 80),
              child: Center(child: Text('还没有保存的路线'))),
        for (final route in visible)
          Card(
              margin: const EdgeInsets.only(bottom: 14),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(
                        height: 180,
                        child: _RouteThumbnail(points: _demoRoute)),
                    Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(children: [
                                Text(route.$1,
                                    style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w800)),
                                const Spacer(),
                                Text(route.$2,
                                    style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w800))
                              ]),
                              const SizedBox(height: 5),
                              Text(route.$3,
                                  style:
                                      const TextStyle(color: Colors.black54)),
                              const SizedBox(height: 12),
                              SizedBox(
                                  width: double.infinity,
                                  child: FilledButton.icon(
                                      onPressed: widget.onFollow,
                                      icon: const Icon(Icons.navigation),
                                      label: const Text('跟随路线'),
                                      style: FilledButton.styleFrom(
                                          backgroundColor: moveaBlue)))
                            ]))
                  ])),
      ]),
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
