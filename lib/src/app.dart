import 'package:flutter/material.dart';

import 'engine/engine_service.dart';
import 'settings/settings_controller.dart';
import 'ui/screens/home_screen.dart';

/// App-wide services: one engine instance and the user's settings.
class AppScope extends InheritedWidget {
  const AppScope({
    super.key,
    required this.engine,
    required this.settings,
    required super.child,
  });

  final EngineService engine;
  final SettingsController settings;

  static AppScope of(BuildContext context) =>
      context.getInheritedWidgetOfExactType<AppScope>()!;

  @override
  bool updateShouldNotify(AppScope oldWidget) =>
      engine != oldWidget.engine || settings != oldWidget.settings;
}

class KangChessApp extends StatefulWidget {
  const KangChessApp({super.key, required this.engine, required this.settings});

  final EngineService engine;
  final SettingsController settings;

  @override
  State<KangChessApp> createState() => _KangChessAppState();
}

class _KangChessAppState extends State<KangChessApp> {
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    // Release the native engine when the app is torn down.
    _lifecycle = AppLifecycleListener(onDetach: widget.engine.dispose);
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    widget.engine.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const seed = Color(0xFF6F9A57);
    return AppScope(
      engine: widget.engine,
      settings: widget.settings,
      child: MaterialApp(
        title: 'Kang Chess',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: seed),
          useMaterial3: true,
        ),
        darkTheme: ThemeData(
          colorScheme:
              ColorScheme.fromSeed(seedColor: seed, brightness: Brightness.dark),
          useMaterial3: true,
        ),
        themeMode: ThemeMode.dark,
        home: const HomeScreen(),
      ),
    );
  }
}
