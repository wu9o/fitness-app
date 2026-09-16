import 'dart:async';

import 'package:flutter/material.dart';
import 'package:movea_data/movea_data.dart';
import 'package:movea_design/movea_design.dart';

import 'src/app.dart';

void main() {
  runApp(const MoveaApp());
}

class MoveaApp extends StatefulWidget {
  const MoveaApp({super.key});

  @override
  State<MoveaApp> createState() => _MoveaAppState();
}

class _MoveaAppState extends State<MoveaApp> {
  final TrainingProfileStore trainingProfileStore = TrainingProfileStore();
  final RouteGuidancePreferencesStore routeGuidancePreferencesStore =
      RouteGuidancePreferencesStore();
  int _dataGeneration = 0;

  @override
  void initState() {
    super.initState();
    unawaited(trainingProfileStore.restore());
    unawaited(routeGuidancePreferencesStore.restore());
  }

  @override
  void dispose() {
    trainingProfileStore.dispose();
    routeGuidancePreferencesStore.dispose();
    super.dispose();
  }

  Future<void> _reloadAfterBackupRestore() async {
    await Future.wait([
      trainingProfileStore.restore(force: true),
      routeGuidancePreferencesStore.restore(force: true),
    ]);
    if (!mounted) return;
    setState(() => _dataGeneration++);
  }

  @override
  Widget build(BuildContext context) {
    return TrainingProfileScope(
      notifier: trainingProfileStore,
      child: RouteGuidancePreferencesScope(
        notifier: routeGuidancePreferencesStore,
        child: MaterialApp(
          title: '动迹 Movea',
          debugShowCheckedModeBanner: false,
          theme: moveaTheme(),
          home: MoveaShell(
            key: ValueKey(_dataGeneration),
            onBackupRestored: _reloadAfterBackupRestore,
          ),
        ),
      ),
    );
  }
}
