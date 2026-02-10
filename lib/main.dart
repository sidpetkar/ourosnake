import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'src/core/theme/app_theme.dart';
import 'src/features/game/logic/game_provider.dart';
import 'src/features/game/presentation/game_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // Pin to portrait for phone layout
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => GameProvider()),
      ],
      child: MaterialApp(
        title: 'Snake',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.theme,
        home: const GameScreen(),
      ),
    );
  }
}
