import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../services/quote_extraction_service.dart';
import '../../services/text_file_service.dart';
import '../../services/theme_service.dart';
import '../../utils/custom_cache.dart';
import '../../models/daily_quote.dart';
import '../screens/quote_page.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  bool _visible = true;
  final _firePlayer = AudioPlayer();

  @override
  void initState() {
    super.initState();
    _startSplash();
  }

  Future<void> _startSplash() async {
    // Инициализируем кэш
    await CustomCache.prefs.init();
    
    // 🔥 Звук костра
    try {
      await _firePlayer.setAsset('assets/sounds/fire.mp3');
      _firePlayer.setLoopMode(LoopMode.one);
      _firePlayer.play();
    } catch (e) {
      print('Error playing fire sound: $e');
    }

    // ⏳ Генерируем или получаем сегодняшнюю цитату
    await _ensureTodayQuote();

    // ⏳ Ожидание
    await Future.delayed(const Duration(seconds: 2));

    // 🔔 Звук удара
    try {
      final chime = AudioPlayer();
      await chime.setAsset('assets/sounds/chime.mp3');
      chime.play();
    } catch (e) {
      print('Error playing chime sound: $e');
    }

    // 🌑 Затухание
    setState(() => _visible = false);
    await Future.delayed(const Duration(milliseconds: 600));

    // 🚪 Переход
    if (!mounted) return;
    _firePlayer.dispose();
    
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => const QuotePage(), // Новая версия без параметров
        transitionDuration: const Duration(milliseconds: 500),
        transitionsBuilder: (_, anim, __, child) => FadeTransition(opacity: anim, child: child),
      ),
    );
  }

  Future<void> _ensureTodayQuote() async {
    final quoteService = QuoteExtractionService();
    final cache = CustomCache.prefs;
    
    // Проверяем, есть ли уже цитата на сегодня
    final existingQuote = cache.getTodayQuote();
    if (existingQuote != null) {
      print('Today\'s quote already exists');
      return;
    }
    
    // Генерируем новую цитату
    try {
      final dailyQuote = await quoteService.generateDailyQuote();
      if (dailyQuote != null) {
        await cache.cacheDailyQuote(dailyQuote);
        print('Generated new daily quote');
      }
    } catch (e) {
      print('Error generating daily quote: $e');
    }
  }

  @override
  void dispose() {
    _firePlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: AnimatedOpacity(
          opacity: _visible ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 600),
          child: Image.asset(
            'assets/animations/fire.gif',
            width: 120,
            height: 120,
            errorBuilder: (context, error, stackTrace) {
              return const Icon(
                Icons.local_fire_department,
                color: Colors.orange,
                size: 120,
              );
            },
          ),
        ),
      ),
    );
  }
}
