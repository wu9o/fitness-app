import 'package:flutter/material.dart';

const moveaCoral = Color(0xFFFF654A);
const moveaBlue = Color(0xFF4E7CF7);
const moveaInk = Color(0xFF19212D);
const moveaPaper = Color(0xFFF9F7F2);
const moveaMint = Color(0xFFDDF2E8);
const moveaLavender = Color(0xFFE9E2FF);
const moveaLemon = Color(0xFFFFF0BF);

ThemeData moveaTheme() {
  return ThemeData(
    useMaterial3: true,
    scaffoldBackgroundColor: moveaPaper,
    colorScheme: ColorScheme.fromSeed(
        seedColor: moveaCoral, brightness: Brightness.light),
    navigationBarTheme: const NavigationBarThemeData(
      backgroundColor: Colors.white,
      indicatorColor: Color(0xFFFFE2DB),
      labelTextStyle: WidgetStatePropertyAll(
          TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
    ),
    cardTheme: CardThemeData(
      color: Colors.white,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(20))),
    ),
  );
}

class MoveaSectionTitle extends StatelessWidget {
  const MoveaSectionTitle(this.title, {this.action, super.key});

  final String title;
  final String? action;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(title,
            style: Theme.of(context)
                .textTheme
                .titleLarge
                ?.copyWith(fontWeight: FontWeight.w800, color: moveaInk)),
        const Spacer(),
        if (action != null)
          Text(action!,
              style: const TextStyle(
                  color: Colors.black54, fontWeight: FontWeight.w600)),
      ],
    );
  }
}
