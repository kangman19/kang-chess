import 'package:flutter/material.dart';

import 'src/app.dart';
import 'src/engine/engine_service.dart';
import 'src/engine/stockfish_transport.dart';
import 'src/settings/settings_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final settings = await SettingsController.load();
  final engine = EngineService(StockfishTransport());
  runApp(KangChessApp(engine: engine, settings: settings));
}
