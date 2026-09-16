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

  @override
  void initState() {
    super.initState();
    unawaited(trainingProfileStore.restore());
  }

  @override
  void dispose() {
    trainingProfileStore.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TrainingProfileScope(
      notifier: trainingProfileStore,
      child: MaterialApp(
        title: '动迹 Movea',
        debugShowCheckedModeBanner: false,
        theme: moveaTheme(),
        home: const MoveaShell(),
      ),
    );
  }
}
