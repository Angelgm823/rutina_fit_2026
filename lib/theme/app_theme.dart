import 'package:flutter/material.dart';

const cMist = Color(0xFFEDEDED);
const cSlate = Color(0xFF9CA3AF);
const cSteel = Color(0xFF4B5563);
const cNight = Color(0xFF1F2937);
const cInk = Color(0xFF111827);
const cGo = Color(0xFF16A34A); // verde: acción lista (guardar)
 
ThemeData buildTheme() => ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: cInk,
      colorScheme: const ColorScheme.dark(
        primary: cMist,
        onPrimary: cInk,
        secondary: cSlate,
        onSecondary: cInk,
        surface: cInk,
        onSurface: cMist,
        onSurfaceVariant: cSlate,
        outline: cSteel,
        outlineVariant: cSteel,
        surfaceContainerLow: cNight,
        surfaceContainer: cNight,
        surfaceContainerHigh: cNight,
        surfaceContainerHighest: cSteel,
      ),
    );