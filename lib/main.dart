import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'screens/home_screen.dart';
import 'screens/share_screen.dart';
import 'widgets/received_data_tab.dart';
import 'theme/app_theme_mode.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  await Hive.openBox<String>('received_snapshots');
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    const seed = Colors.grey;

    return ValueListenableBuilder<ThemeMode>(
      valueListenable: AppThemeMode.mode,
      builder: (_, mode, __) {
        return MaterialApp(
          title: 'PulseLink',
          debugShowCheckedModeBanner: false,

          theme: ThemeData(
            useMaterial3: true,
            colorSchemeSeed: seed,
            brightness: Brightness.light,
          ),
          darkTheme: ThemeData(
            useMaterial3: true,
            colorSchemeSeed: seed,
            brightness: Brightness.dark,
          ),

          themeMode: mode,

          home: const HomeScreen(),
          routes: {
            '/share': (_) => const ShareScreen(),
            '/received': (_) => const ReceivedDataTab(),
          },
        );
      },
    );
  }
}
