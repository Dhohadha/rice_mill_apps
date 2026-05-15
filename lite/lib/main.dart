import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'screens/main_screen.dart';
import 'services/providers.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    const ProviderScope(
      child: LiteApp(),
    ),
  );
}

class LiteApp extends ConsumerStatefulWidget {
  const LiteApp({super.key});

  @override
  ConsumerState<LiteApp> createState() => _LiteAppState();
}

class _LiteAppState extends ConsumerState<LiteApp> {
  @override
  void initState() {
    super.initState();
    // Connect to MQTT on startup
    Future.microtask(() => ref.read(mqttServiceProvider).connect());
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Rice Mill Lite',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
      ),
      // Straight to MainScreen, skipping login
      home: const MainScreen(),
    );
  }
}
