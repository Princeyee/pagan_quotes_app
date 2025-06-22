// lib/main.dart - ОБНОВЛЕННАЯ ВЕРСИЯ
import 'package:flutter/material.dart';
import 'ui/screens/splash_screen.dart';
import 'services/sound_manager.dart';
import 'utils/custom_cache.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Инициализируем кэш и звуковой менеджер
  await CustomCache.prefs.init();
  await SoundManager().init();
  
  // Очищаем кеш контекстов при запуске для предотвращения проблем с неправильными данными
  await CustomCache.prefs.clearAllQuoteContexts();
  print('🧹 Очищен кеш контекстов при запуске приложения');
  
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    SoundManager().dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
        // Приложение свернуто или неактивно - приостанавливаем звуки
        SoundManager().pauseAll();
        break;
      case AppLifecycleState.resumed:
        // Приложение развернуто - возобновляем звуки
        SoundManager().resumeAll();
        break;
      case AppLifecycleState.detached:
        // Приложение закрывается - останавливаем все звуки
        SoundManager().stopAll();
        break;
      case AppLifecycleState.hidden:
        // Приложение скрыто (новое состояние в Flutter 3)
        SoundManager().pauseAll();
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Sacral - Цитаты дня',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: Colors.black,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        primaryColor: Colors.white,
        colorScheme: const ColorScheme.dark(
          primary: Colors.white,
          secondary: Colors.white70,
          surface: Colors.black,
        ),
      ),
      home: const SplashScreen(),
    );
  }
}