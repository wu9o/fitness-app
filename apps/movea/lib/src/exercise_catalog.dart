import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:movea_design/movea_design.dart';
import 'package:movea_domain/movea_domain.dart';

const _exerciseManifestAsset = 'assets/exercises/manifest.json';

class ExerciseCatalogStore extends ChangeNotifier {
  List<ExerciseDefinition> _exercises = const [];
  bool _isLoading = true;
  String? _error;
  Future<void>? _loadFuture;

  List<ExerciseDefinition> get exercises => List.unmodifiable(_exercises);
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> load() => _loadFuture ??= _loadInternal();

  ExerciseDefinition? find(String id) {
    final normalized = _exerciseAliases[id] ?? id;
    for (final exercise in _exercises) {
      if (exercise.slug == normalized ||
          exercise.id == normalized ||
          exercise.slug == id ||
          exercise.id == id) {
        return exercise;
      }
    }
    return null;
  }

  List<ExerciseDefinition> search({
    String query = '',
    String muscle = '全部',
    String type = '全部',
  }) {
    final normalizedQuery = query.trim().toLowerCase();
    return _exercises.where((exercise) {
      final matchesQuery = normalizedQuery.isEmpty ||
          <String>[
            exercise.displayName,
            exercise.name,
            exercise.slug,
            exercise.equipment,
            exercise.primaryMuscle,
          ].any((value) => value.toLowerCase().contains(normalizedQuery));
      final matchesMuscle =
          muscle == '全部' || localizedMuscle(exercise.primaryMuscle) == muscle;
      final matchesType = type == '全部' ||
          localizedExerciseType(exercise.exerciseType, exercise.isStretch) ==
              type;
      return matchesQuery && matchesMuscle && matchesType;
    }).toList(growable: false);
  }

  Future<void> _loadInternal() async {
    try {
      final payload = await rootBundle.loadString(_exerciseManifestAsset);
      final decoded = jsonDecode(payload);
      if (decoded is! List) throw const FormatException('动作目录格式不正确');
      final parsed = decoded
          .whereType<Map>()
          .map((item) => _parseExercise(Map<String, dynamic>.from(item)))
          .whereType<ExerciseDefinition>()
          .toList(growable: false);
      if (parsed.isEmpty) throw const FormatException('动作目录为空');
      _exercises = parsed;
      _error = null;
    } on Object catch (error) {
      _error = error.toString().replaceFirst('FormatException: ', '');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  ExerciseDefinition? _parseExercise(Map<String, dynamic> json) {
    final slug = json['slug'] as String?;
    final name = json['name'] as String?;
    if (slug == null || name == null) return null;
    final editorial = _exerciseEditorial[slug];
    final frames = (json['frames'] as List<dynamic>? ?? const [])
        .whereType<Map>()
        .map((frame) => frame['path'] as String?)
        .whereType<String>()
        .map(_assetPath)
        .toList(growable: false);
    final isStretch = json['isStretch'] as bool? ?? false;
    return ExerciseDefinition(
      id: json['id'] as String? ?? 'exercise-$slug',
      slug: slug,
      name: name,
      displayName: _exerciseNames[slug] ?? name,
      exerciseType: json['exerciseType'] as String? ?? 'weight_reps',
      equipment: json['equipment'] as String? ?? 'Bodyweight',
      primaryMuscle: json['primaryMuscle'] as String? ?? 'Full Body',
      secondaryMuscles: (json['secondaryMuscles'] as List<dynamic>? ?? const [])
          .whereType<String>()
          .toList(growable: false),
      isStretch: isStretch,
      framePaths: frames,
      steps: editorial?.steps ??
          const [
            '保持身体稳定，先完成动作的准备姿势。',
            '沿自然活动轨迹完成动作，避免借力和突然弹动。',
            '回到起始姿势，确认呼吸和身体控制都保持稳定。',
          ],
      breathing:
          editorial?.breathing ?? (isStretch ? '保持自然呼吸，不要憋气。' : '发力时呼气，回程时吸气。'),
      commonMistakes:
          editorial?.commonMistakes ?? const ['动作速度过快', '为了完成次数而牺牲动作幅度'],
      safety: editorial?.safety ?? '以无痛范围为准；出现疼痛或眩晕时立即停止。',
      easierVariant: editorial?.easierVariant,
      harderVariant: editorial?.harderVariant,
    );
  }

  static String _assetPath(String manifestPath) {
    final sourcePath = manifestPath.startsWith('assets/')
        ? manifestPath.substring('assets/'.length)
        : manifestPath;
    final separator = sourcePath.indexOf('/');
    if (separator > 0) {
      final slug = sourcePath.substring(0, separator);
      final frame = sourcePath.substring(separator + 1);
      return 'assets/exercises/${slug}__$frame';
    }
    return 'assets/exercises/$manifestPath';
  }
}

class ExerciseLibraryPage extends StatefulWidget {
  const ExerciseLibraryPage({
    required this.store,
    this.selectionMode = false,
    super.key,
  });

  final ExerciseCatalogStore store;
  final bool selectionMode;

  @override
  State<ExerciseLibraryPage> createState() => _ExerciseLibraryPageState();
}

class _ExerciseLibraryPageState extends State<ExerciseLibraryPage> {
  final queryController = TextEditingController();
  String muscle = '全部';
  String type = '全部';

  @override
  void initState() {
    super.initState();
    unawaited(widget.store.load());
  }

  @override
  void dispose() {
    queryController.dispose();
    super.dispose();
  }

  void openExercise(ExerciseDefinition exercise) {
    if (widget.selectionMode) {
      Navigator.pop(context, exercise);
      return;
    }
    Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => ExerciseDetailPage(exercise: exercise)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.selectionMode ? '选择动作' : '动作库'),
        actions: [
          if (!widget.selectionMode)
            const Padding(
              padding: EdgeInsets.only(right: 16),
              child: Center(child: Text('302 个动作')),
            ),
        ],
      ),
      body: AnimatedBuilder(
        animation: widget.store,
        builder: (context, _) {
          final exercises = widget.store
              .search(query: queryController.text, muscle: muscle, type: type);
          return _ExerciseContentFrame(
            maxWidth: 1040,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                  child: TextField(
                    controller: queryController,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      labelText: '搜索动作、部位或器械',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: queryController.text.isEmpty
                          ? null
                          : IconButton(
                              tooltip: '清空搜索',
                              onPressed: () {
                                queryController.clear();
                                setState(() {});
                              },
                              icon: const Icon(Icons.clear),
                            ),
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ),
                SizedBox(
                  height: 44,
                  child: ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    scrollDirection: Axis.horizontal,
                    children: [
                      _FilterChip(
                        label: '全部部位',
                        selected: muscle == '全部',
                        onTap: () => setState(() => muscle = '全部'),
                      ),
                      for (final item in const [
                        '胸部',
                        '背部',
                        '肩部',
                        '腿部',
                        '核心',
                        '臀部',
                      ])
                        _FilterChip(
                          label: item,
                          selected: muscle == item,
                          onTap: () => setState(() => muscle = item),
                        ),
                      const SizedBox(width: 8),
                      _FilterChip(
                        label: type == '全部' ? '训练类型' : type,
                        selected: type != '全部',
                        onTap: () => _showTypeFilter(),
                      ),
                    ],
                  ),
                ),
                if (widget.store.error != null)
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Text('动作库加载失败：${widget.store.error}'),
                  ),
                if (widget.store.isLoading)
                  const Expanded(
                      child: Center(child: CircularProgressIndicator()))
                else if (exercises.isEmpty)
                  const Expanded(child: Center(child: Text('没有匹配的动作，换个关键词试试。')))
                else
                  Expanded(
                    child: GridView.builder(
                      padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
                      gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                        maxCrossAxisExtent:
                            MediaQuery.sizeOf(context).width >= 700 ? 330 : 420,
                        mainAxisExtent: 198,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                      ),
                      itemCount: exercises.length,
                      itemBuilder: (context, index) => _ExerciseCard(
                        exercise: exercises[index],
                        onTap: () => openExercise(exercises[index]),
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

  Future<void> _showTypeFilter() async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            const ListTile(title: Text('训练类型')),
            for (final item in const ['全部', '力量', '拉伸', '有氧', '灵活性'])
              ListTile(
                title: Text(item),
                trailing: type == item ? const Icon(Icons.check) : null,
                onTap: () => Navigator.pop(context, item),
              ),
          ],
        ),
      ),
    );
    if (selected != null && mounted) setState(() => type = selected);
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => onTap(),
        visualDensity: VisualDensity.compact,
      ),
    );
  }
}

class _ExerciseCard extends StatelessWidget {
  const _ExerciseCard({required this.exercise, required this.onTap});

  final ExerciseDefinition exercise;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Row(
          children: [
            SizedBox(
              width: 116,
              height: double.infinity,
              child: DecoratedBox(
                decoration: const BoxDecoration(
                  color: _exerciseVisualBackground,
                  borderRadius: BorderRadius.horizontal(
                    left: Radius.circular(18),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: _exerciseVisualBackground,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: exercise.framePaths.isEmpty
                        ? const Icon(Icons.fitness_center,
                            size: 34, color: Colors.white)
                        : SvgPicture.asset(exercise.framePaths.first,
                            fit: BoxFit.contain),
                  ),
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 10, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(exercise.displayName,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w800)),
                    const SizedBox(height: 6),
                    Text(localizedMuscle(exercise.primaryMuscle),
                        style: const TextStyle(
                            fontSize: 12, color: Colors.black54)),
                    const Spacer(),
                    Text(
                      '${localizedExerciseType(exercise.exerciseType, exercise.isStretch)} · ${localizedEquipment(exercise.equipment)}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style:
                          const TextStyle(fontSize: 11, color: Colors.black54),
                    ),
                    const SizedBox(height: 5),
                    const Row(
                      children: [
                        Text('查看演示',
                            style: TextStyle(
                                color: moveaBlue,
                                fontSize: 12,
                                fontWeight: FontWeight.w700)),
                        SizedBox(width: 4),
                        Icon(Icons.arrow_forward, size: 14, color: moveaBlue),
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

class ExerciseDetailPage extends StatelessWidget {
  const ExerciseDetailPage({
    required this.exercise,
    this.openedDuringWorkout = false,
    super.key,
  });

  final ExerciseDefinition exercise;
  final bool openedDuringWorkout;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(exercise.displayName)),
      body: _ExerciseContentFrame(
        maxWidth: 760,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 30),
          children: [
            if (openedDuringWorkout)
              const Card(
                color: moveaLemon,
                child: ListTile(
                  leading: Icon(Icons.pause_circle_outline),
                  title: Text('已暂停训练计时'),
                  subtitle: Text('查看完动作后返回训练页面即可继续。'),
                ),
              ),
            Card(
              color: moveaPaper,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: ExerciseAnimation(exercise: exercise),
              ),
            ),
            const SizedBox(height: 14),
            Text(exercise.displayName,
                style:
                    const TextStyle(fontSize: 27, fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            Text(exercise.name,
                style: const TextStyle(color: Colors.black45, fontSize: 13)),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _InfoChip(localizedMuscle(exercise.primaryMuscle)),
                _InfoChip(localizedEquipment(exercise.equipment)),
                _InfoChip(localizedExerciseType(
                    exercise.exerciseType, exercise.isStretch)),
                for (final muscle in exercise.secondaryMuscles.take(2))
                  _InfoChip(localizedMuscle(muscle)),
              ],
            ),
            const SizedBox(height: 20),
            _DetailSection(
              title: '动作步骤',
              child: Column(
                children: [
                  for (var index = 0; index < exercise.steps.length; index++)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: CircleAvatar(
                        radius: 14,
                        backgroundColor: moveaLavender,
                        child: Text('${index + 1}',
                            style:
                                const TextStyle(fontWeight: FontWeight.w800)),
                      ),
                      title: Text(exercise.steps[index]),
                    ),
                ],
              ),
            ),
            _DetailSection(
              title: '呼吸节奏',
              child: Text(exercise.breathing),
            ),
            _DetailSection(
              title: '常见错误',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final mistake in exercise.commonMistakes)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 7),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('·  ',
                              style: TextStyle(fontWeight: FontWeight.w800)),
                          Expanded(child: Text(mistake)),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            if (exercise.easierVariant != null ||
                exercise.harderVariant != null)
              _DetailSection(
                title: '动作变式',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (exercise.easierVariant != null)
                      Text('更简单：${exercise.easierVariant}'),
                    if (exercise.harderVariant != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 7),
                        child: Text('更进阶：${exercise.harderVariant}'),
                      ),
                  ],
                ),
              ),
            Card(
              color: const Color(0xFFFFF4EF),
              child: ListTile(
                leading: const Icon(Icons.health_and_safety_outlined,
                    color: moveaCoral),
                title: const Text('安全提示'),
                subtitle: Text(exercise.safety),
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.arrow_back),
              label: Text(openedDuringWorkout ? '返回训练' : '返回动作库'),
              style: FilledButton.styleFrom(backgroundColor: moveaCoral),
            ),
          ],
        ),
      ),
    );
  }
}

class ExerciseAnimation extends StatefulWidget {
  const ExerciseAnimation({required this.exercise, super.key});

  final ExerciseDefinition exercise;

  @override
  State<ExerciseAnimation> createState() => _ExerciseAnimationState();
}

class _ExerciseAnimationState extends State<ExerciseAnimation> {
  Timer? timer;
  int frameIndex = 0;
  bool playing = true;

  @override
  void initState() {
    super.initState();
    timer = Timer.periodic(const Duration(milliseconds: 720), (_) {
      if (!mounted || !playing || widget.exercise.framePaths.isEmpty) return;
      setState(() =>
          frameIndex = (frameIndex + 1) % widget.exercise.framePaths.length);
    });
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final frames = widget.exercise.framePaths;
    if (frames.isEmpty) {
      return const SizedBox(
          height: 240,
          child: Center(child: Icon(Icons.fitness_center, size: 56)));
    }
    return Column(
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            color: _exerciseVisualBackground,
            borderRadius: BorderRadius.circular(20),
          ),
          child: SizedBox(
            height: 240,
            child: Semantics(
              label: '${widget.exercise.displayName}动作演示',
              image: true,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                child: SvgPicture.asset(frames[frameIndex],
                    key: ValueKey(frames[frameIndex]), fit: BoxFit.contain),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              tooltip: playing ? '暂停演示' : '播放演示',
              onPressed: () => setState(() => playing = !playing),
              icon: Icon(playing ? Icons.pause : Icons.play_arrow),
            ),
            Text('${frameIndex + 1} / ${frames.length}',
                style: const TextStyle(color: Colors.black54)),
            IconButton(
              tooltip: '重新演示',
              onPressed: () => setState(() => frameIndex = 0),
              icon: const Icon(Icons.replay),
            ),
          ],
        ),
      ],
    );
  }
}

const _exerciseVisualBackground = Color(0xFF2A3B35);

class _DetailSection extends StatelessWidget {
  const _DetailSection({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
            const SizedBox(height: 10),
            child,
          ],
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip(this.label);

  final String label;

  @override
  Widget build(BuildContext context) => DecoratedBox(
        decoration: BoxDecoration(
            color: const Color(0xFFF0F6F1),
            borderRadius: BorderRadius.circular(9)),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          child: Text(label,
              style: const TextStyle(fontSize: 12, color: Colors.black54)),
        ),
      );
}

class _ExerciseContentFrame extends StatelessWidget {
  const _ExerciseContentFrame({required this.child, this.maxWidth = 760});

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

String localizedMuscle(String value) {
  const labels = {
    'Chest': '胸部',
    'Triceps': '肱三头肌',
    'Shoulders': '肩部',
    'Back': '背部',
    'Lats': '背阔肌',
    'Upper Back': '上背部',
    'Rear Delts': '后三角肌',
    'Quads': '股四头肌',
    'Hamstrings': '腿后侧',
    'Glutes': '臀部',
    'Calves': '小腿',
    'Biceps': '肱二头肌',
    'Forearms': '前臂',
    'Core': '核心',
    'Lower Back': '下背部',
    'Hips': '髋部',
    'Adductors': '内收肌',
    'Legs': '腿部',
    'Mobility': '灵活性',
    'Full Body': '全身',
  };
  return labels[value] ?? value;
}

String localizedEquipment(String value) {
  const labels = {
    'Bodyweight': '徒手',
    'Barbell': '杠铃',
    'Dumbbell': '哑铃',
    'Machine': '器械',
    'Cable': '绳索',
    'Kettlebell': '壶铃',
    'Resistance Band': '弹力带',
    'Pull-up Bar': '单杠',
    'Stability Ball': '健身球',
    'Cardio': '有氧器械',
    'Bench': '训练凳',
    'Wall': '墙面',
    'Chair': '椅子',
    'Doorway': '门框',
    'Towel': '毛巾',
    'Box': '训练箱',
    'Plate': '杠铃片',
  };
  return labels[value] ?? value;
}

String localizedExerciseType(String value, bool isStretch) {
  if (isStretch) return '拉伸';
  if (value == 'cardio') return '有氧';
  if (value == 'mobility') return '灵活性';
  return '力量';
}

const _exerciseAliases = {
  'bird-dog-core': 'bird-dog',
  'hip-stretch': 'kneeling-hip-flexor-stretch',
};

const _exerciseNames = {
  'bench-press': '卧推',
  'incline-bench-press': '上斜杠铃卧推',
  'push-up': '俯卧撑',
  'incline-push-up': '上斜俯卧撑',
  'knee-push-up': '跪姿俯卧撑',
  'overhead-press': '肩上推举',
  'lateral-raise': '侧平举',
  'deadlift': '硬拉',
  'romanian-deadlift': '罗马尼亚硬拉',
  'barbell-row': '杠铃划船',
  'dumbbell-bent-over-row': '哑铃俯身划船',
  'lat-pulldown': '高位下拉',
  'pull-up': '引体向上',
  'squat': '深蹲',
  'front-squat': '前蹲',
  'goblet-squat': '高脚杯深蹲',
  'bodyweight-squat': '徒手深蹲',
  'bulgarian-split-squat': '保加利亚分腿蹲',
  'walking-lunge': '行走弓步',
  'hip-thrust': '杠铃臀推',
  'glute-bridge': '臀桥',
  'standing-calf-raise': '站姿提踵',
  'calf-raise': '徒手提踵',
  'bicep-curl': '哑铃弯举',
  'hammer-curl': '锤式弯举',
  'tricep-pushdown': '绳索下压',
  'dip': '双杠臂屈伸',
  'plank': '平板支撑',
  'side-plank': '侧桥',
  'dead-bug': '死虫式',
  'bird-dog': '鸟狗式',
  'crunch': '卷腹',
  'russian-twist': '俄罗斯转体',
  'mountain-climber': '登山跑',
  'hanging-leg-raise': '悬垂举腿',
  'running': '跑步',
  'cycling': '骑行',
  'jump-rope': '跳绳',
  'jumping-jack': '开合跳',
  'burpee': '波比跳',
  'cat-cow-stretch': '猫牛式',
  'childs-pose': '婴儿式',
  'kneeling-hip-flexor-stretch': '跪姿髋屈肌拉伸',
  'hamstring-stretch': '腿后侧拉伸',
  'standing-quad-stretch': '站姿股四头肌拉伸',
  'wall-calf-stretch': '靠墙小腿拉伸',
};

class _ExerciseEditorial {
  const _ExerciseEditorial({
    required this.steps,
    required this.breathing,
    required this.commonMistakes,
    required this.safety,
    this.easierVariant,
    this.harderVariant,
  });

  final List<String> steps;
  final String breathing;
  final List<String> commonMistakes;
  final String safety;
  final String? easierVariant;
  final String? harderVariant;
}

const _exerciseEditorial = {
  'squat': _ExerciseEditorial(
    steps: ['双脚与肩同宽，脚尖自然向外。', '屈髋屈膝下蹲，膝盖跟随脚尖方向。', '脚掌踩稳地面，收紧核心后站起。'],
    breathing: '下蹲吸气，站起发力时呼气。',
    commonMistakes: ['膝盖内扣', '塌腰或为了深度失去核心控制'],
    safety: '从舒适深度开始，膝盖和脚尖保持同向。',
    easierVariant: '箱式深蹲',
    harderVariant: '保加利亚分腿蹲',
  ),
  'push-up': _ExerciseEditorial(
    steps: ['双手略宽于肩，身体从头到脚保持一条线。', '屈肘下降，胸口靠近地面。', '推地回到起始位置，保持肩胛稳定。'],
    breathing: '下降吸气，推起时呼气。',
    commonMistakes: ['塌腰或抬臀', '肘部完全向外打开'],
    safety: '手腕不适时可用俯卧撑支架或改做上斜俯卧撑。',
    easierVariant: '跪姿俯卧撑',
    harderVariant: '窄距俯卧撑',
  ),
  'plank': _ExerciseEditorial(
    steps: ['前臂或双手支撑，肘部位于肩部正下方。', '收紧腹部和臀部，保持身体平直。', '稳定呼吸，坚持到设定时间。'],
    breathing: '保持均匀呼吸，不要憋气。',
    commonMistakes: ['腰部塌陷', '屏住呼吸硬撑'],
    safety: '宁可缩短时间，也不要在腰部代偿后继续坚持。',
    easierVariant: '跪姿平板支撑',
    harderVariant: '平板支撑抬腿',
  ),
  'dead-bug': _ExerciseEditorial(
    steps: ['仰卧，腰背贴地，双手向上，髋膝约九十度。', '对侧手臂和腿缓慢向外伸展。', '回到中立位后换另一侧，保持腰背贴地。'],
    breathing: '伸展时呼气，回收时吸气。',
    commonMistakes: ['腰部离地', '动作过快导致核心失去控制'],
    safety: '如果腰背无法贴地，先缩小动作幅度。',
    easierVariant: '单侧死虫式',
    harderVariant: '弹力带死虫式',
  ),
  'glute-bridge': _ExerciseEditorial(
    steps: ['仰卧屈膝，双脚踩地，脚跟靠近臀部。', '收紧腹部和臀部，抬起髋部。', '在顶部停留片刻，缓慢落回地面。'],
    breathing: '抬髋时呼气，下降时吸气。',
    commonMistakes: ['用腰部而不是臀部发力', '膝盖向外或向内偏移'],
    safety: '保持肋骨收拢，避免为了抬高而过度挺腰。',
    easierVariant: '短幅度臀桥',
    harderVariant: '单腿臀桥',
  ),
  'bird-dog': _ExerciseEditorial(
    steps: ['四点跪姿，双手在肩下，膝盖在髋下。', '对侧手臂和腿缓慢伸直。', '停留后收回，换另一侧并保持骨盆稳定。'],
    breathing: '伸展时呼气，收回时吸气。',
    commonMistakes: ['骨盆旋转', '为了抬高而塌腰'],
    safety: '先从单手或单腿开始，再逐步增加难度。',
    easierVariant: '四点跪姿单侧抬手',
    harderVariant: '鸟狗式肘膝收缩',
  ),
  'hamstring-stretch': _ExerciseEditorial(
    steps: ['坐姿或站姿保持背部延展。', '从髋部前倾，直到腿后侧有温和拉伸感。', '保持稳定，不要弹动身体。'],
    breathing: '全程保持自然、均匀呼吸。',
    commonMistakes: ['为了够远而弓背', '拉伸到疼痛仍继续加深'],
    safety: '只保持温和牵拉感，不追求疼痛范围。',
  ),
};
