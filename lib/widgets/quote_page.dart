import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:palette_generator/palette_generator.dart';
import 'package:share_plus/share_plus.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/quote.dart';
import '../services/favorites_service.dart';
import '../services/cache_manager.dart';


class QuotePage extends StatefulWidget {
  const QuotePage({super.key});
  @override
  State<QuotePage> createState() => _QuotePageState();
}

class _QuotePageState extends State<QuotePage>
    with SingleTickerProviderStateMixin {
  late List<Quote> _all;
  late Quote _today;
  late FavoritesService _favSvc;
  bool _loading = true;
  Color _textColor = Colors.white;
  bool _isLiked = false;
  double _scale = 1.0;

  late AnimationController _ctrl;
  late Animation<Offset> _offsetAnim;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 800));
    _offsetAnim = Tween(begin: const Offset(0, 0.3), end: Offset.zero).animate(
        CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
    _fadeAnim =
        CurvedAnimation(parent: _ctrl, curve: Curves.easeIn);

    _init().then((_) => _loadQuotes());
    _ctrl.forward();
  }

  Future<void> _init() async {
    final prefs = await SharedPreferences.getInstance();
    _favSvc = FavoritesService(prefs);
  }

  Future<void> _loadQuotes() async {
    final jsonStr = await rootBundle.loadString('assets/quotes.json');
    final data = jsonDecode(jsonStr) as List;
    _all = data.map((e) => Quote.fromJson(e)).toList();
    _selectToday();
    await _pickTextColor();
    _isLiked = _favSvc.isFavorite(_today.id);
    setState(() => _loading = false);
    await _precacheTomorrow();

    
  }

  void _selectToday() {
    final idx = DateTime.now().day % _all.length;
    _today = _all[idx];
  }

  Future<void> _pickTextColor() async {
    final provider = CachedNetworkImageProvider(
  _today.image,
  cacheManager: CustomCache.instance,
);
    final palette = await PaletteGenerator.fromImageProvider(
      provider,
      size: const Size(64, 64),
    );
    final dominant = palette.dominantColor?.color;
    if (dominant != null) {
      _textColor =
          dominant.computeLuminance() < 0.5 ? Colors.white : Colors.black;
    }
  }

Future<void> _precacheTomorrow() async {
  final tomorrowIdx = (DateTime.now().day + 1) % _all.length;
  final Quote tomorrow = _all[tomorrowIdx];
  final provider = CachedNetworkImageProvider(
  tomorrow.image,
  cacheManager: CustomCache.instance,
);
  await provider.obtainKey(const ImageConfiguration()); // безопасно получаем ключ
  await precacheImage(provider, context);               // кешируем картинку
}
  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    // Анимация «лайка» сбрасываем перед рендером*
    final likeScale = _scale;

    return Scaffold(
      body: Stack(fit: StackFit.expand, children: [
        // фон из сети + кэш*
        CachedNetworkImage(
  imageUrl: _today.image,
  cacheManager: CustomCache.instance,
  placeholder: (_, __) => Container(color: Colors.black12),
  errorWidget: (_, __, ___) => const Center(child: Icon(Icons.error)),
  fit: BoxFit.cover,
),
        // затемнение*
        Container(color: Colors.black.withAlpha(77)),

        SafeArea(
          child: Stack(children: [
            // градиент снизу*
            Positioned.fill(
              child: IgnorePointer(
                child: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.transparent, Colors.black54],
                    ),
                  ),
                ),
              ),
            ),

            // текст + кнопки*
            Positioned(
              bottom: 80,
              left: 16,
              right: 16,
              child: SlideTransition(
                position: _offsetAnim,
                child: FadeTransition(
                  opacity: _fadeAnim,
                  child: Column(
                    children: [
                      Text(
                        _today.author.toUpperCase(),
                        style: GoogleFonts.merriweather(
                          textStyle: TextStyle(
                            color: _textColor.withAlpha(204),
                            fontSize: 16,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        '"${_today.text}"',
                        style: GoogleFonts.merriweather(
                          textStyle: TextStyle(
                            color: _textColor,
                            fontSize: 22,
                            height: 1.4,
                          ),
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      Row(
                        mainAxisAlignment:
                            MainAxisAlignment.center,
                        children: [
                          GestureDetector(
                            onTap: () async {
                              await _favSvc
                                  .toggleFavorite(_today.id);
                              _isLiked =
                                  _favSvc.isFavorite(_today.id);
                              setState(() {
                                _scale = 1.3;
                                Future.delayed(
                                    const Duration(
                                        milliseconds: 200),
                                    () {
                                  setState(
                                      () => _scale = 1.0);
                                });
                              });
                            },
                            child: AnimatedScale(
                              scale: likeScale,
                              duration:
                                  const Duration(milliseconds: 200),
                              child: AnimatedSwitcher(
                                duration:
                                    const Duration(milliseconds: 300),
                                child: Icon(
                                  _isLiked
                                      ? Icons.favorite
                                      : Icons
                                          .favorite_border,
                                  key: ValueKey<bool>(
                                      _isLiked),
                                  color: _isLiked
                                      ? Colors.redAccent
                                      : _textColor,
                                  size: 30,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 24),
                          IconButton(
                            icon: const Icon(Icons.share),
                            color: _textColor,
                            iconSize: 28,
                            onPressed: () {
                              Share.share(
                                '"${_today.text}"\n— ${_today.author}',
                                subject: 'Цитата дня',
                              );
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ]),
        ),
      ]),
    );
  }
}