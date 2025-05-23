import 'dart:async';
import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:cached_network_image/cached_network_image.dart';

import '../../models/quote.dart';
import '../../services/favorites_service.dart';
import '../../services/image_picker_service.dart';
import '../../services/session_data.dart';
import '../../utils/custom_cache.dart';
import '../screens/quote_page.dart';
import '../../services/theme_service.dart';
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
    await _firePlayer.setAsset('assets/sounds/fire.mp3');
    _firePlayer.setLoopMode(LoopMode.one);
    _firePlayer.play();

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
    await Future.wait([
      Future.delayed(const Duration(seconds: 2)),
    ]);

    // 🔔 Звук удара
    final chime = AudioPlayer();
    await chime.setAsset('assets/sounds/chime.mp3');
    chime.play();

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
  final favService = await FavoritesService.init();
  final allQuotes = await favService.loadAllQuotes();

  // ⏳ Получаем только цитаты из включённых тем
  final enabledThemes = await ThemeService.getEnabledThemes();
  final quotes = allQuotes.where((q) => enabledThemes.contains(q.theme)).toList();

  if (quotes.isEmpty) {
    throw Exception('Нет доступных цитат для выбранных тем');
  }

  final now = DateTime.now();
  final key = 'quote_${now.year}-${now.month}-${now.day}';
  final imgKey = 'image_${now.year}-${now.month}-${now.day}';

  late Quote quote;
  late String imageUrl;

  if (prefs.containsKey(key) && prefs.containsKey(imgKey)) {
    final id = prefs.getString(key);
    quote = quotes.firstWhere((q) => q.id == id, orElse: () => quotes.first);
    imageUrl = prefs.getString(imgKey)!;
  } else {
    final seed = now.difference(DateTime(2025, 1, 1)).inDays.abs();
    final rng = Random(seed);
    quote = quotes[rng.nextInt(quotes.length)];
    imageUrl = ImagePickerService.getRandomImage(quote.theme);

    await prefs.setString(key, quote.id);
    await prefs.setString(imgKey, imageUrl);
  }

  return {
    'quote': quote,
    'imageUrl': imageUrl,
  };
}

  Future<Color> _estimateTextColorFromRegion(ImageProvider imageProvider) async {
    final config = ImageConfiguration(size: const Size(300, 300));
    final stream = imageProvider.resolve(config);
    final completer = Completer<ui.Image>();

    late final ImageStreamListener listener;
    listener = ImageStreamListener((info, _) {
      completer.complete(info.image);
      stream.
removeListener(listener);
    });

    stream.addListener(listener);

    final image = await completer.future;

    // Читаем пиксели только из нижней центральной части изображения
    final byteData = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    final bytes = byteData!.buffer.asUint8List();
    final width = image.width;
    final height = image.height;

    // Берем небольшой регион в центре снизу (например, 20x20 пикселей)
    int count = 0;
    int r = 0, g = 0, b = 0;
    for (int y = height - 60; y < height - 40; y++) {
      for (int x = width ~/ 2 - 10; x < width ~/ 2 + 10; x++) {
        final index = (y * width + x) * 4;
        r += bytes[index];
        g += bytes[index + 1];
        b += bytes[index + 2];
        count++;
      }
    }

    final avgR = r ~/ count;
    final avgG = g ~/ count;
    final avgB = b ~/ count;
    final color = Color.fromARGB(255, avgR, avgG, avgB);

    // Возвращаем белый или черный в зависимости от яркости
    return color.computeLuminance() < 0.5 ? Colors.white : Colors.black;
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
          ),
        ),
      ),
    );
  }
}