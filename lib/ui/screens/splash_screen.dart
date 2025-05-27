import 'dart:async';
import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:cached_network_image/cached_network_image.dart';

import '../../models/quote.dart';
import '../../models/book_source.dart';
import '../../services/text_file_service.dart';
import '../../services/quote_extraction_service.dart';
import '../../services/image_picker_service.dart';
import '../../services/session_data.dart';
import '../../services/theme_service.dart';
import '../../utils/custom_cache.dart';
import '../screens/quote_page.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  bool _visible = true;
  final _firePlayer = AudioPlayer();

  late Quote _quote;
  late String _imageUrl;
  late Color _textColor;

  @override
  void initState() {
    super.initState();
    _startSplash();
  }

  Future<void> _startSplash() async {
    // 🔥 Звук костра
    try {
      await _firePlayer.setAsset('assets/sounds/fire.mp3');
      _firePlayer.setLoopMode(LoopMode.one);
      _firePlayer.play();
    } catch (e) {
      print('Error playing fire sound: $e');
    }

    // ⏳ Получаем цитату и картинку
    final data = await _getTodayQuoteAndImage();
    _quote = data['quote'];
    _imageUrl = data['imageUrl'];

    // 📸 Предзагрузка изображения
    final provider = CachedNetworkImageProvider(_imageUrl, cacheManager: CustomCache.instance);
    await precacheImage(provider, context);

    // 🎨 Определение цвета текста (анализ небольшой области изображения)
    _textColor = await _estimateTextColorFromRegion(provider);

    // 💾 Сохраняем в SessionData для повторного использования
    SessionData.quote = _quote;
    SessionData.imageUrl = _imageUrl;
    SessionData.textColor = _textColor;

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
        pageBuilder: (_, __, ___) => QuotePage(
          quote: _quote,
          imageUrl: _imageUrl,
          textColor: _textColor,
        ),
        transitionDuration: const Duration(milliseconds: 500),
        transitionsBuilder: (_, anim, __, child) => FadeTransition(opacity: anim, child: child),
      ),
    );
  }

  Future<Map<String, dynamic>> _getTodayQuoteAndImage() async {
    final prefs = await SharedPreferences.getInstance();
    final quoteService = QuoteExtractionService();
    final textService = TextFileService();
    
    // Получаем включенные темы
    final enabledThemes = await ThemeService.getEnabledThemes();
    
    final now = DateTime.now();
    final key = 'quote_${now.year}-${now.month}-${now.day}';
    final imgKey = 'image_${now.year}-${now.month}-${now.day}';

    late Quote quote;
    late String imageUrl;

    // Проверяем кэш на сегодня
    if (prefs.containsKey(key) && prefs.containsKey(imgKey)) {
      // Восстанавливаем цитату из кэша
      final cachedData = prefs.getString('${key}_data');
      if (cachedData != null) {
        try {
          final parts = cachedData.split('|||');
          quote = Quote(
            id: prefs.getString(key)!,
            text: parts[0],
            author: parts[1],
            source: parts[2],
            category: parts[3],
            position: int.parse(parts[4]),
            theme: parts[3],
            context: parts.length > 5 ? parts[5] : '',
          );
          imageUrl = prefs.getString(imgKey)!;
        } catch (e) {
          print('Error restoring cached quote: $e');
          // Если не удалось восстановить, генерируем новую
          final result = await _generateNewQuote(enabledThemes, now);
          quote = result['quote'];
          imageUrl = result['imageUrl'];
        }
      } else {
        // Генерируем новую цитату
        final result = await _generateNewQuote(enabledThemes, now);
        quote = result['quote'];
        imageUrl = result['imageUrl'];
      }
    } else {
      // Генерируем новую цитату для сегодня
      final result = await _generateNewQuote(enabledThemes, now);
      quote = result['quote'];
      imageUrl = result['imageUrl'];
      
      // Сохраняем в кэш
      await prefs.setString(key, quote.id);
      await prefs.setString(imgKey, imageUrl);
      await prefs.setString('${key}_data', 
        '${quote.text}|||${quote.author}|||${quote.source}|||${quote.category}|||${quote.position}|||${quote.context}');
    }

    return {
      'quote': quote,
      'imageUrl': imageUrl,
    };
  }

  Future<Map<String, dynamic>> _generateNewQuote(List<String> enabledThemes, DateTime date) async {
    final quoteService = QuoteExtractionService();
    final textService = TextFileService();
    
    // Загружаем источники книг
    final allSources = await textService.loadBookSources();
    final enabledSources = allSources.where((s) => enabledThemes.contains(s.category)).toList();
    
    if (enabledSources.isEmpty) {
      // Если нет источников, создаем заглушку
      return {
        'quote': Quote(
          id: 'default_${date.millisecondsSinceEpoch}',
          text: 'Мудрость начинается с удивления.',
          author: 'Сократ',
          source: 'Диалоги Платона',
          category: 'greece',
          position: 0,
          theme: 'greece',
          context: 'Философ говорил, что удивление - начало всякой мудрости.',
        ),
        'imageUrl': ImagePickerService.getRandomImage('greece'),
      };
    }
    
    // Используем дату как seed для воспроизводимости
    final seed = date.difference(DateTime(2025, 1, 1)).inDays.abs();
    final rng = Random(seed);
    
    // Выбираем случайный источник
    final randomSource = enabledSources[rng.nextInt(enabledSources.length)];
    
    try {
      // Извлекаем цитату
      final quote = await quoteService.extractRandomQuote(
        randomSource,
        minLength: 50,
        maxLength: 300,
      );
      
      if (quote == null) {
        throw Exception('Не удалось извлечь цитату');
      }
      
      // Выбираем изображение
      final imageUrl = ImagePickerService.getRandomImage(quote.category);
      
      return {
        'quote': quote,
        'imageUrl': imageUrl,
      };
    } catch (e) {
      print('Error generating quote: $e');
      // Возвращаем заглушку
      return {
        'quote': Quote(
          id: '${randomSource.category}_default_${date.millisecondsSinceEpoch}',
          text: 'Каждый день - это новая возможность для мудрости.',
          author: randomSource.author,
          source: randomSource.title,
          category: randomSource.category,
          position: 0,
          theme: randomSource.category,
          context: '',
        ),
        'imageUrl': ImagePickerService.getRandomImage(randomSource.category),
      };
    }
  }

  Future<Color> _estimateTextColorFromRegion(ImageProvider imageProvider) async {
    try {
      final config = ImageConfiguration(size: const Size(300, 300));
      final stream = imageProvider.resolve(config);
      final completer = Completer<ui.Image>();

      late final ImageStreamListener listener;
      listener = ImageStreamListener((info, _) {
        completer.complete(info.image);
        stream.removeListener(listener);
      });

      stream.addListener(listener);

      final image = await completer.future;

      // Читаем пиксели только из нижней центральной части изображения
      final byteData = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      if (byteData == null) return Colors.white;
      
      final bytes = byteData.buffer.asUint8List();
      final width = image.width;
      final height = image.height;

      // Берем небольшой регион в центре снизу (например, 20x20 пикселей)
      int count = 0;
      int r = 0, g = 0, b = 0;
      
      final startY = (height - 60).clamp(0, height);
      final endY = (height - 40).clamp(0, height);
      final startX = (width ~/ 2 - 10).clamp(0, width);
      final endX = (width ~/ 2 + 10).clamp(0, width);
      
      for (int y = startY; y < endY; y++) {
        for (int x = startX; x < endX; x++) {
          final index = (y * width + x) * 4;
          if (index + 2 < bytes.length) {
            r += bytes[index];
            g += bytes[index + 1];
            b += bytes[index + 2];
            count++;
          }
        }
      }

      if (count == 0) return Colors.white;

      final avgR = r ~/ count;
      final avgG = g ~/ count;
      final avgB = b ~/ count;
      final color = Color.fromARGB(255, avgR, avgG, avgB);

      // Возвращаем белый или черный в зависимости от яркости
      return color.computeLuminance() < 0.5 ? Colors.white : Colors.black;
    } catch (e) {
      print('Error estimating text color: $e');
      return Colors.white;
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