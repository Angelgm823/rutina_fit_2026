import 'package:flutter/material.dart';
import 'package:rutina_fit/database/db.dart';

/// Un tema de colores de la app (todos oscuros).
class AppPalette {
  final String id;
  final String name;
  final Color ink; // fondo
  final Color night; // tarjetas / superficies
  final Color steel; // bordes y líneas
  final Color slate; // texto secundario
  final Color mist; // texto principal
  final Color accent; // botones, selección, gráficas
  final Color onAccent; // texto encima del acento
  const AppPalette({
    required this.id,
    required this.name,
    required this.ink,
    required this.night,
    required this.steel,
    required this.slate,
    required this.mist,
    required this.accent,
    required this.onAccent,
  });
}

/// Temas que el usuario puede elegir. El primero es el original de la app.
const palettes = <AppPalette>[
  AppPalette(
    id: 'grafito', name: 'Grafito',
    ink: Color(0xFF111827), night: Color(0xFF1F2937), steel: Color(0xFF4B5563),
    slate: Color(0xFF9CA3AF), mist: Color(0xFFEDEDED),
    accent: Color(0xFFEDEDED), onAccent: Color(0xFF111827),
  ),
  AppPalette(
    id: 'oled', name: 'Negro absoluto',
    ink: Color(0xFF000000), night: Color(0xFF121212), steel: Color(0xFF2E2E2E),
    slate: Color(0xFF8A8A8A), mist: Color(0xFFF5F5F5),
    accent: Color(0xFFF5F5F5), onAccent: Color(0xFF000000),
  ),
  AppPalette(
    id: 'medianoche', name: 'Medianoche',
    ink: Color(0xFF0B1120), night: Color(0xFF151E33), steel: Color(0xFF334155),
    slate: Color(0xFF94A3B8), mist: Color(0xFFE2E8F0),
    accent: Color(0xFF60A5FA), onAccent: Color(0xFF0B1120),
  ),
  AppPalette(
    id: 'bosque', name: 'Bosque',
    ink: Color(0xFF0C1410), night: Color(0xFF16231C), steel: Color(0xFF2F4A3B),
    slate: Color(0xFF8FA89A), mist: Color(0xFFE3EDE6),
    accent: Color(0xFF6EE7B7), onAccent: Color(0xFF0C1410),
  ),
  AppPalette(
    id: 'carmesi', name: 'Carmesí',
    ink: Color(0xFF160B0E), night: Color(0xFF251418), steel: Color(0xFF4A2A31),
    slate: Color(0xFFB19AA0), mist: Color(0xFFF1E4E7),
    accent: Color(0xFFF87171), onAccent: Color(0xFF160B0E),
  ),
  AppPalette(
    id: 'amatista', name: 'Amatista',
    ink: Color(0xFF120E1C), night: Color(0xFF1E1830), steel: Color(0xFF3F3657),
    slate: Color(0xFFA79FC0), mist: Color(0xFFECE8F5),
    accent: Color(0xFFC084FC), onAccent: Color(0xFF120E1C),
  ),
  AppPalette(
    id: 'ambar', name: 'Ámbar',
    ink: Color(0xFF141210), night: Color(0xFF211E1A), steel: Color(0xFF47413A),
    slate: Color(0xFFADA59A), mist: Color(0xFFF0EBE3),
    accent: Color(0xFFFBBF24), onAccent: Color(0xFF141210),
  ),
];

/// Tema activo. La app se redibuja cuando cambia.
final themeNotifier = ValueNotifier<AppPalette>(palettes.first);

AppPalette get _p => themeNotifier.value;
Color get cMist => _p.mist;
Color get cSlate => _p.slate;
Color get cSteel => _p.steel;
Color get cNight => _p.night;
Color get cInk => _p.ink;
Color get cAccent => _p.accent;
Color get cOnAccent => _p.onAccent;
const cGo = Color(0xFF16A34A); // verde: acción lista (guardar)

const _themeKey = 'theme';

/// Carga el tema guardado (si hay) antes de abrir la app.
Future<void> loadSavedTheme() async {
  try {
    final id = await Db.getMeta(_themeKey);
    themeNotifier.value = palettes.firstWhere((p) => p.id == id, orElse: () => palettes.first);
  } catch (_) {
    // Si falla la lectura se queda el tema original.
  }
}

/// Cambia el tema y lo recuerda para la próxima vez.
Future<void> setTheme(AppPalette p) async {
  themeNotifier.value = p;
  try {
    await Db.setMeta(_themeKey, p.id);
  } catch (_) {}
}

ThemeData buildTheme([AppPalette? palette]) {
  final p = palette ?? _p;
  return ThemeData(
    useMaterial3: true,
    scaffoldBackgroundColor: p.ink,
    appBarTheme: AppBarTheme(backgroundColor: p.ink, foregroundColor: p.mist),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: p.night,
      indicatorColor: p.accent.withValues(alpha: 0.22),
    ),
    colorScheme: ColorScheme.dark(
      primary: p.accent,
      onPrimary: p.onAccent,
      secondary: p.slate,
      onSecondary: p.ink,
      secondaryContainer: p.steel,
      onSecondaryContainer: p.mist,
      surface: p.ink,
      onSurface: p.mist,
      onSurfaceVariant: p.slate,
      outline: p.steel,
      outlineVariant: p.steel,
      surfaceContainerLow: p.night,
      surfaceContainer: p.night,
      surfaceContainerHigh: p.night,
      surfaceContainerHighest: p.steel,
    ),
  );
}
