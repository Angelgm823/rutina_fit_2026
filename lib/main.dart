import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:rutina_fit/screens/home.dart';
import 'package:rutina_fit/services/notifications.dart';
import 'package:rutina_fit/theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await loadSavedTheme(); // tema que eligió el usuario
  TimerAlerts.init(); // quita avisos de temporizadores de una sesión anterior que quedaron colgados
  runApp(const App());
}

class App extends StatefulWidget {
  const App({super.key});
  @override
  State<App> createState() => _AppState();
}

class _AppState extends State<App> {
  @override
  void initState() {
    super.initState();
    themeNotifier.addListener(_onTheme);
  }

  @override
  void dispose() {
    themeNotifier.removeListener(_onTheme);
    super.dispose();
  }

  // Al cambiar de tema redibuja toda la app sin perder lo que estabas haciendo.
  void _onTheme() {
    setState(() {});
    void rebuild(Element e) {
      e.markNeedsBuild();
      e.visitChildren(rebuild);
    }

    (context as Element).visitChildren(rebuild);
  }

  @override
  Widget build(BuildContext c) => MaterialApp(
        title: 'Rutina',
        debugShowCheckedModeBanner: false,
        theme: buildTheme(themeNotifier.value),
        // Calendario y textos del sistema en español.
        locale: const Locale('es', 'MX'),
        supportedLocales: const [Locale('es', 'MX'), Locale('es')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        home: const Home(),
      );
}