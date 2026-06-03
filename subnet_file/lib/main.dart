import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'providers/providers.dart';
import 'screens/splash_screen.dart';
import 'screens/main_screen.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  await Hive.openBox('identity');
  await Hive.openBox('reports');
  await Hive.openBox('settings');

  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(appSettingsServiceProvider);
    final hasOnboarded = ref.read(identityServiceProvider).hasOnboarded;

    return MaterialApp(
      title: 'Subnet',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark(
        primaryAccent: settings.accentColor,
        fontScale: settings.fontScale,
      ),
      home: hasOnboarded ? const MainScreen() : const SplashScreen(),
    );
  }
}
