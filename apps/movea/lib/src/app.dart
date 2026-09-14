import 'dart:async';

import 'package:flutter/material.dart';
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

  void openActivity() => setState(() => selectedIndex = 1);

  void openHistory() {
    Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => WorkoutHistoryPage(store: store)));
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      HomePage(onStart: openActivity, onHistory: openHistory),
      ActivityPage(store: store),
      const HealthPage(),
      RoutesPage(onFollow: openActivity),
      const LearnPage(),
    ];

    return Scaffold(
      body:
          SafeArea(child: IndexedStack(index: selectedIndex, children: pages)),
      bottomNavigationBar: NavigationBar(
        selectedIndex: selectedIndex,
        onDestinationSelected: (index) => setState(() => selectedIndex = index),
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

class HomePage extends StatelessWidget {
  const HomePage({required this.onStart, required this.onHistory, super.key});

  final VoidCallback onStart;
  final VoidCallback onHistory;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 24),
      children: [
        Text('今天想动一动吗？',
            style: Theme.of(context)
                .textTheme
                .headlineMedium
                ?.copyWith(fontWeight: FontWeight.w800, color: moveaInk)),
        const SizedBox(height: 4),
        const Text('更健康的你，从今天开始', style: TextStyle(color: Colors.black54)),
        const SizedBox(height: 20),
        FilledButton.icon(
          onPressed: onStart,
          icon: const Icon(Icons.play_arrow),
          label:
              const Text('开始运动', style: TextStyle(fontWeight: FontWeight.w800)),
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
                child: const _MetricCard(
                    title: '本周运动',
                    value: '18.4 km',
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
                    (index) =>
                        _DayDot(label: '一二三四五六日'[index], active: index < 4))),
          ),
        ),
        const SizedBox(height: 24),
        const MoveaSectionTitle('为你推荐'),
        const SizedBox(height: 10),
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
          ),
        ),
      ],
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
  Timer? timer;
  Duration elapsed = Duration.zero;
  bool paused = false;

  bool get recording => startedAt != null;

  void start() {
    setState(() {
      startedAt = DateTime.now();
      elapsed = Duration.zero;
      paused = false;
    });
    timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || startedAt == null || paused) return;
      setState(() => elapsed = DateTime.now().difference(startedAt!));
    });
  }

  void togglePause() => setState(() => paused = !paused);

  void finish() {
    final startTime = startedAt;
    if (startTime == null) return;
    widget.store.add(WorkoutRecord(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        activity: activity,
        startedAt: startTime,
        duration: elapsed,
        distanceMeters: 0));
    timer?.cancel();
    setState(() {
      startedAt = null;
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
          const _MapPreview()
        else
          const ColoredBox(color: moveaPaper),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Row(children: [
                  Text(activity.usesLocation ? 'GPS 待接入' : '室内训练',
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
                                      label: Text('${type.icon} ${type.label}'),
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
                    Text(activity.icon, style: const TextStyle(fontSize: 42)),
                  const SizedBox(height: 10),
                  Text(formatDuration(elapsed),
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 16),
                  Row(children: [
                    Expanded(
                        child: FilledButton.icon(
                            onPressed: togglePause,
                            icon: Icon(paused ? Icons.play_arrow : Icons.pause),
                            label: Text(paused ? '继续' : '暂停'),
                            style: FilledButton.styleFrom(
                                backgroundColor: moveaCoral))),
                    const SizedBox(width: 10),
                    OutlinedButton(onPressed: finish, child: const Text('结束')),
                  ]),
                ] else ...[
                  Icon(Icons.directions_run, size: 48, color: moveaCoral),
                  const SizedBox(height: 8),
                  const Text('准备好了吗？',
                      style:
                          TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
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
      ],
    );
  }
}

String formatDuration(Duration duration) =>
    '${duration.inMinutes.toString().padLeft(2, '0')}:${(duration.inSeconds % 60).toString().padLeft(2, '0')}';

class _MapPreview extends StatelessWidget {
  const _MapPreview();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFE8EEF0),
      child: Center(
          child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
            Icon(Icons.map, size: 64, color: moveaBlue),
            SizedBox(height: 10),
            Text('地图适配层待接入', style: TextStyle(color: Colors.black54))
          ])),
    );
  }
}

class WorkoutHistoryPage extends StatelessWidget {
  const WorkoutHistoryPage({required this.store, super.key});

  final WorkoutStore store;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('全部运动记录')),
      body: AnimatedBuilder(
        animation: store,
        builder: (context, _) {
          if (store.records.isEmpty)
            return const Center(child: Text('还没有运动记录'));
          return ListView.separated(
            padding: const EdgeInsets.all(20),
            itemCount: store.records.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final record = store.records[index];
              return Card(
                child: ListTile(
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
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      Text(
                        record.distanceLabel,
                        style: const TextStyle(
                            fontSize: 12, color: Colors.black54),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class HealthPage extends StatelessWidget {
  const HealthPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(padding: const EdgeInsets.all(20), children: [
      Text('健康',
          style: Theme.of(context)
              .textTheme
              .headlineMedium
              ?.copyWith(fontWeight: FontWeight.w800, color: moveaInk)),
      const Text('了解身体，跑得更远', style: TextStyle(color: Colors.black54)),
      const SizedBox(height: 18),
      Card(
          color: moveaMint,
          child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text('昨晚睡眠', style: TextStyle(fontWeight: FontWeight.w700)),
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
    ]);
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
    return ListView(padding: const EdgeInsets.all(20), children: [
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
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const SizedBox(height: 130, child: _MapPreview()),
              Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          Text(route.$1,
                              style: const TextStyle(
                                  fontSize: 18, fontWeight: FontWeight.w800)),
                          const Spacer(),
                          Text(route.$2,
                              style: const TextStyle(
                                  fontSize: 18, fontWeight: FontWeight.w800))
                        ]),
                        const SizedBox(height: 5),
                        Text(route.$3,
                            style: const TextStyle(color: Colors.black54)),
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
    ]);
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

    return ListView(padding: const EdgeInsets.all(20), children: [
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
                          onSelected: (_) => setState(() => category = type))))
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
    ]);
  }
}
