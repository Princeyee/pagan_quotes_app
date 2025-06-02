// lib/ui/screens/splash_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';

import '../../services/quote_extraction_service.dart';
import '../../services/favorites_service.dart';
import '../../services/sound_manager.dart';
import '../../utils/custom_cache.dart';
import 'quote_page.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  bool _visible = true;
  final SoundManager _soundManager = SoundManager();

  @override
  void initState() {
    super.initState();
    _startSplash();
  }

  Future<void> _startSplash() async {
    try {
      // Инициализируем кэш
      await CustomCache.prefs.init();
      
      // Инициализируем сервис избранного
      await FavoritesService.init();
      
      // 🔥 Звук костра (только если звук не отключен)
      if (!_soundManager.isMuted) {
        await _soundManager.playSound(
          'fire_splash',
          'assets/sounds/fire.mp3',
          loop: true,
        );
      }

      // ⏳ Генерируем или получаем сегодняшнюю цитату
      await _ensureTodayQuote();

      // ⏳ Ожидание для красивого splash экрана
      await Future.delayed(const Duration(seconds: 2));

      // 🔔 Звук удара (только если звук не отключен)
      if (!_soundManager.isMuted) {
        await _soundManager.playSound(
          'chime_splash',
          'assets/sounds/chime.mp3',
        );
      }

      // 🌑 Затухание
      if (mounted) {
        setState(() => _visible = false);
        await Future.delayed(const Duration(milliseconds: 600));
      }

      // 🚪 Переход к основному экрану
      if (mounted) {
        // Останавливаем звуки сплэша
        await _soundManager.stopSound('fire_splash');
        await _soundManager.stopSound('chime_splash');
        
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
      
      // В случае ошибки все равно переходим к основному экрану
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const QuotePage()),
        );
      }
    }
  }

  Future<void> _ensureTodayQuote() async {
    final quoteService = QuoteExtractionService();
    final cache = CustomCache.prefs;
    
    try {
      // Проверяем, есть ли уже цитата на сегодня
      final existingQuote = cache.getTodayQuote();
      if (existingQuote != null) {
        print('Today\'s quote already exists');
        return;
      }
      
      // Генерируем новую цитату
      final dailyQuote = await quoteService.generateDailyQuote();
      if (dailyQuote != null) {
        await cache.cacheDailyQuote(dailyQuote);
        print('Generated new daily quote: "${dailyQuote.quote.text.substring(0, 50)}..."');
      } else {
        print('Failed to generate daily quote');
      }
    } catch (e) {
      print('Error generating daily quote: $e');
    }
  }

  @override
  void dispose() {
    // Останавливаем звуки сплэша при выходе
    _soundManager.stopSound('fire_splash');
    _soundManager.stopSound('chime_splash');
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
            // Верхняя треть - пустая
            const Expanded(flex: 1, child: SizedBox()),
            
            // Средняя треть - огонь
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
                            Colors.orange.withOpacity(0.8),
                            Colors.red.withOpacity(0.6),
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
            
            // Нижняя треть - название
            Expanded(
              flex: 1,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  const SizedBox(height: 40),
                  
                  // Главное название
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
                  
                  // Элегантная линия
                  Container(
                    width: 100,
                    height: 1,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.transparent,
                          Colors.white.withOpacity(0.6),
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