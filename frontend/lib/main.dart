import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/theme/app_theme.dart';
import 'ui/screens/launch_gate_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ProviderScope(child: ZhouyiApp()));
}

class ZhouyiApp extends StatelessWidget {
  const ZhouyiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '宽窄·Orbit',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      // LaunchGateScreen 会检查是否完成引导，决定显示引导页还是 MainShell
      home: const LaunchGateScreen(),
    );
  }
}
