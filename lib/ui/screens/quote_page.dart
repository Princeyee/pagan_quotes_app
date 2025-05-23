import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:share_plus/share_plus.dart';
import 'package:just_audio/just_audio.dart';
import 'package:lottie/lottie.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'context_page.dart';
import '../../models/quote.dart';
import '../../services/favorites_service.dart';
import '../../utils/custom_cache.dart';
import '../widgets/nav_drawer.dart';

class QuotePage extends StatefulWidget {
  final Quote quote;
  final String imageUrl;
  final Color textColor;

  const QuotePage({
    super.key,
    required this.quote,
    required this.imageUrl,
    required this.textColor,
  });

  @override
  State<QuotePage> createState() => _QuotePageState();
}

class _QuotePageState extends State<QuotePage> with SingleTickerProviderStateMixin {
  late FavoritesService _favSvc;
  late bool _isLiked;
  double _likeScale = 1.0;
  bool _loading = true;
  bool _showHint = true;

  late AnimationController _animCtrl;
  late Animation<Offset> _slideAnim;
  late Animation<double> _fadeAnim;
  late Animation<double> _revealAnim;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
    _slideAnim = Tween(begin: const Offset(0, 0.3), end: Offset.zero).animate(
      CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut),
    );
    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeIn);
    _revealAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animCtrl, curve: Curves.easeInOut),
    );
    _initFavorites();
  }

  Future<void> _initFavorites() async {
    _favSvc = await FavoritesService.init();
    _isLiked = _favSvc.isFavorite(widget.quote.id);
    final prefs = await SharedPreferences.getInstance();
    _showHint = prefs.getBool('show_swipe_hint') ?? true;
    setState(() => _loading = false);
    _animCtrl.forward();
  }

  void _toggleFavorite() async {
    await _favSvc.toggleFavorite(widget.quote.id);
    setState(() {
      _isLiked = _favSvc.isFavorite(widget.quote.id);
      _likeScale = 1.3;
      Future.delayed(const Duration(milliseconds: 200), () {
        setState(() => _likeScale = 1.0);
      });
    });
  }

  void _navigateToContext() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('show_swipe_hint', false);
    final player = AudioPlayer();
    await player.setAsset('assets/sounds/page_turn.mp3');
    player.play();

    if (!mounted) return;
    Navigator.of(context).push(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 600),
        pageBuilder: (_, __, ___) => ContextPage(
          quote: widget.quote,
          textColor: widget.textColor,
          imageUrl: widget.imageUrl,
        ),
        transitionsBuilder: (_, animation, __, child) {
          final slide = Tween<Offset>(
            begin: const Offset(0, 1),
            end: Offset.zero,
          ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic));
          final fade = CurvedAnimation(parent: animation, curve: Curves.easeIn);
          return SlideTransition(position: slide, child: FadeTransition(opacity: fade, child: child));
        },
      ),
    );
  }

  String _getLottiePath() {
    final theme = widget.quote.theme;
    switch (theme) {
      case 'greece':
        return 'assets/animations/greece.json';
      case 'nordic':
        return 'assets/animations/nordic.json';
      case 'philosophy':
        return 'assets/animations/philosophy.json';
      case 'pagan':
        return 'assets/animations/pagan.json';
      default:
        return 'assets/animations/default.json';
    }
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator(color: Colors.white)),
      );
    }

    return Scaffold(
      drawer: const NavDrawer(),
      body: GestureDetector(
        onVerticalDragEnd: (details) {
          if (details.primaryVelocity != null && details.primaryVelocity! < -300) {
            _navigateToContext();
          }
        },
        child: Stack(
          fit: StackFit.expand,
          children: [
            // 📷 Фоновое изображение
            CachedNetworkImage(
              imageUrl: widget.imageUrl,
              cacheManager: CustomCache.instance,
              placeholder: (_, __) => Container(color: Colors.black12),
              errorWidget: (_, __, ___) => const Icon(Icons.error),
              fit: BoxFit.cover,
            ),

            // 🌒 Тёмный фильтр
            Container(color: Colors.black.withOpacity(0.3)),

            // 🌌 Анимация по теме
            IgnorePointer(
              child: Lottie.asset(
                _getLottiePath(),
                fit: BoxFit.cover,
                repeat: true,
                animate: true,
              ),
            ),

            SafeArea(
              child: Stack(
                children: [
                  // 🌘 Доп. затемнение
                  Positioned.fill(
                    child: IgnorePointer(
                      child: Container(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Colors.transparent, Colors.black87],
                          ),
                        ),
                      ),
                    ),
                  ),

                  // 🍔 Меню
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Builder(
                      builder: (context) => IconButton(
                        icon: Icon(Icons.menu, color: widget.textColor),
                        onPressed: () => Scaffold.of(context).openDrawer(),
                      ),
                    ),
                  ),

                  // 💬 Цитата и автор
                  Positioned(
                    bottom: 80,
                    left: 16,
                    right: 16,
                    child: SlideTransition(
                      position: _slideAnim,
                      child: FadeTransition(
                        opacity: _fadeAnim,
                        child: Column(
                          children: [
                            Text(
                              widget.quote.author.toUpperCase(),
                              style: GoogleFonts.merriweather(
                                color: widget.textColor.withOpacity(0.8),
                                fontSize: 16,
                                fontStyle: FontStyle.italic,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 12),
                            AnimatedBuilder(
                              animation: _revealAnim,
                              builder: (context, child) {
                                return ShaderMask(
                                  shaderCallback: (bounds) {
                                    return LinearGradient(
                                      begin: Alignment.centerLeft,
                                      end: Alignment.centerRight,
                                      stops: [_revealAnim.value, _revealAnim.value],
                                      colors: [Colors.white, Colors.transparent],
                                    ).createShader(Rect.fromLTWH(0, 0, bounds.width, bounds.height));
                                  },
                                  blendMode: BlendMode.dstIn,
                                  child: child,
                                );
                              },
                              child: Text(
                                '"${widget.quote.text}"',
                                style: GoogleFonts.merriweather(
                                  color: widget.textColor,
                                  fontSize: 22,
                                  height: 1.4,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                            const SizedBox(height: 20),

                            if (_showHint)
                              const Icon(Icons.keyboard_arrow_up, color: Colors.white54, size: 32),

                            const SizedBox(height: 24),

                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                GestureDetector(
                                  onTap: _toggleFavorite,
                                  child: AnimatedScale(
                                    scale: _likeScale,
                                    duration: const Duration(milliseconds: 200),
                                    child: Icon(
                                      _isLiked ? Icons.favorite : Icons.favorite_border,
                                      color: _isLiked ? Colors.redAccent : widget.textColor,
                                      size: 30,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 24),
                                IconButton(
                                  icon: const Icon(Icons.share),
                                  color: widget.textColor,
                                  iconSize: 28,
                                  onPressed: () {
                                    Share.share(
                                      '"${widget.quote.text}"\n— ${widget.quote.author}',
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
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}