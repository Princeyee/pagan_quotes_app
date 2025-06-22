// lib/ui/screens/splash_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';

import '../../services/quote_extraction_service.dart';
import '../../services/favorites_service.dart';
import '../../services/sound_manager.dart';
import '../../utils/custom_cache.dart';
import 'quote_page.dart';
import 'package:just_audio/just_audio.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  bool _visible = true;
  final SoundManager _soundManager = SoundManager();
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    // Запускаем инициализацию асинхронно, чтобы не блокировать UI
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startSplash();
    });
  }

  Future<void> _startSplash() async {
    if (_isInitialized) return;
    _isInitialized = true;

    try {
      // Показываем анимацию сразу
      setState(() => _visible = true);

      // Инициализируем сервисы параллельно
      await Future.wait([
        _initializeServices(),
        _playFireSound(),
        Future.delayed(const Duration(milliseconds: 1500)), // Минимальное время показа
      ]);

      // Генерируем цитату
      await _ensureTodayQuote();

      await _ensureTodayQuote();

// 🔔 Звук удара (не через SoundManager — чтобы не обрывался)
if (!_soundManager.isMuted) {
  final chimePlayer = AudioPlayer();
  await chimePlayer.setAsset('assets/sounds/chime.mp3');
  chimePlayer.play(); // Не await — он доиграет сам
}

      // Небольшая пауза перед переходом
      await Future.delayed(const Duration(milliseconds: 800));

      // 🌑 Затухание
      if (mounted) {
        setState(() => _visible = false);
        await Future.delayed(const Duration(milliseconds: 600));
      }

      // 🚪 Переход к основному экрану
      if (mounted) {
        await  _soundManager.stopSound('fire_splash');
        
        Navigator.of(context).pushReplacement(
          PageRouteBuilder(
            pageBuilder: (_, __, ___) => const QuotePage(),
            transitionDuration: const Duration(milliseconds: 500),
            transitionsBuilder: (_, anim, __, child) => 
                FadeTransition(opacity: anim, child: child),
          ),
        );
      }
    } catch (e) {
      print('Error during splash initialization: $e');
      _navigateToMainScreen();
    }
  }

  Future<void> _initializeServices() async {
    await CustomCache.prefs.init();
    await FavoritesService.init();
  }

  Future<void> _playFireSound() async {
  if (_soundManager.isMuted) return;

  // НЕ await, чтобы не блокировать UI (особенно при loop: true)
  _soundManager.playSound(
    'fire_splash',
    'assets/sounds/fire.mp3',
    loop: true,
  ).catchError((e) {
    print('Could not play fire sound: $e');
  });
}

  Future<void> _ensureTodayQuote() async {
    final quoteService = QuoteExtractionService();
    final cache = CustomCache.prefs;
    
    try {
      final existingQuote = cache.getTodayQuote();
      if (existingQuote != null) {
        print('Today\'s quote already exists');
        return;
      }
      
      // Очищаем кэш контекстов перед генерацией новой цитаты
      // Это предотвращает проблемы с несоответствием контекста и цитаты
      await cache.clearAllQuoteContexts();
      print('🧹 Очищен кэш контекстов для предотвращения несоответствий');
      
      final dailyQuote = await quoteService.generateDailyQuote();
      if (dailyQuote != null) {
        await cache.cacheDailyQuote(dailyQuote);
        print('Generated new daily quote');
      } else {
        print('Failed to generate daily quote');
      }
    } catch (e) {
      print('Error generating daily quote: $e');
    }
  }

  void _navigateToMainScreen() {
    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const QuotePage()),
      );
    }
  }

  @override
  void dispose() {
    _soundManager.stopAll();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: AnimatedOpacity(
        opacity: _visible ? 1.0 : 0.0,
        duration: const Duration(milliseconds: 600),
        child: Column(
          children: [
            const Expanded(flex: 1, child: SizedBox()),
            
            Expanded(
              flex: 1,
              child: Center(
                child: Image.asset(
                  'assets/animations/fire.gif',
                  width: 140,
                  height: 140,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      width: 140,
                      height: 140,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            Colors.orange.withAlpha((0.8 * 255).round()),
                            Colors.red.withAlpha((0.6 * 255).round()),
                            Colors.transparent,
                          ],
                        ),
                      ),
                      child: const Icon(
                        Icons.local_fire_department, 
                        color: Colors.white, 
                        size: 70
                      ),
                    );
                  },
                ),
              ),
            ),
            
            Expanded(
              flex: 1,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  const SizedBox(height: 40),
                  
                  const Text(
                    'SACRAL',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 36,
                      fontWeight: FontWeight.w300,
                      letterSpacing: 4,
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  Container(
                    width: 100,
                    height: 1,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.transparent,
                          Colors.white.withAlpha((0.6 * 255).round()),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}