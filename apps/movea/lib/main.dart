import 'package:flutter/material.dart';
import 'package:movea_design/movea_design.dart';

import 'src/app.dart';

void main() {
  runApp(const MoveaApp());
}

class MoveaApp extends StatelessWidget {
  const MoveaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '动迹 Movea',
      debugShowCheckedModeBanner: false,
      theme: moveaTheme(),
      home: const MoveaShell(),
    );
  }
}
