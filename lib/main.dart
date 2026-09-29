import 'package:flutter/material.dart';
import 'package:rutina_fit/screens/home.dart';
import 'package:rutina_fit/theme/AppTheme.dart';

void main() => runApp(const App());

class App extends StatelessWidget {
  const App({super.key});
  @override
  Widget build(BuildContext c) => MaterialApp(
        title: 'Rutina',
        debugShowCheckedModeBanner: false,
        theme: buildTheme(),
        home: const Home(),
      );
}