import 'package:flutter/material.dart';

class CronuxTheme {
  static const bg      = Color(0xFF0D0D10);
  static const bgSide  = Color(0xFF111115);
  static const bgCard  = Color(0xFF18181D);
  static const bgInput = Color(0xFF1C1C22);
  static const bgHov   = Color(0xFF1F1F27);
  static const border  = Color(0xFF2A2A35);
  static const t1      = Color(0xFFEEEEF3);
  static const t2      = Color(0xFF8888A0);
  static const t3      = Color(0xFF48485A);
  static const a1      = Color(0xFF7C3AED);
  static const a2      = Color(0xFF8B5CF6);
  static const a3      = Color(0xFFA78BFA);
  static const a4      = Color(0xFFC4B5FD);

  static const gradPurple = LinearGradient(
    colors: [Color(0xFF7C3AED), Color(0xFFA855F7)],
    begin: Alignment.topLeft, end: Alignment.bottomRight,
  );
  static const gradPink = LinearGradient(
    colors: [Color(0xFFFF1CF7), Color(0xFF00F0FF)],
    begin: Alignment.topLeft, end: Alignment.bottomRight,
  );

  static ThemeData get dark => ThemeData(
    brightness: Brightness.dark,
    scaffoldBackgroundColor: bg,
    colorScheme: const ColorScheme.dark(
      primary: a1, secondary: a2, surface: bgCard,
    ),
    fontFamily: 'Roboto',
    appBarTheme: const AppBarTheme(
      backgroundColor: bgSide, elevation: 0,
      titleTextStyle: TextStyle(color: t1, fontSize: 16, fontWeight: FontWeight.w600),
      iconTheme: IconThemeData(color: t2),
    ),
    dividerColor: border,
  );
}
