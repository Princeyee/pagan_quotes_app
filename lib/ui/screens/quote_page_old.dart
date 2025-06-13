import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:share_plus/share_plus.dart';


import '../../models/quote.dart';
import '../../services/favorites_service.dart';
import '../../utils/custom_cache.dart';
import '../widgets/nav_drawer.dart';

// Эта версия QuotePage для обратной совместимости со старой архитектурой
class QuotePageOld extends StatefulWidget {
  final Quote quote;
  final String imageUrl;
  final Color textColor;

  const QuotePageOld({
    super.key,
    required this.quote,
    required this.imageUrl,
    required this.textColor,
  });

  @override
  State<QuotePageOld> createState() => _QuotePageOldState();
}

class _QuotePageOldState extends State<QuotePageOld> with SingleTickerProviderStateMixin {
  late FavoritesService _favSvc;
  late bool _isLiked;
  double _likeScale = 1.0;
  bool _loading = true;

  late AnimationController _animCtrl;
  late Animation<Offset> _slideAnim;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
    _slideAnim = Tween(begin: const Offset(0, 0.3), end: Offset.zero).animate(
      CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut),
    );
    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeIn);
    _initFavorites();
  }

  Future<void> _initFavorites() async {
    _favSvc = await FavoritesService.init();
    _isLiked = _favSvc.isFavorite(widget.quote.id);
    setState(() => _loading = false);
    _animCtrl.forward();
  }

  void _toggleFavorite() async {
    await _favSvc.toggleFavorite(widget.quote.id);
    if (!_isLiked) {
      await _favSvc.saveFavoriteQuote(widget.quote);
    }
    setState(() {
      _isLiked = _favSvc.isFavorite(widget.quote.id);
      _likeScale = 1.3;
      Future.delayed(const Duration(milliseconds: 200), () {
        if (mounted) {
          setState(() => _likeScale = 1.0);
        }
      });
    });
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
      backgroundColor: Colors.black,
      body: Stack(
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
          Container(color: Colors.black.withAlpha((0.3 * 255).round())),

          SafeArea(
            child: Stack(
              children: [
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
                              color: widget.textColor.withAlpha((0.8 * 255).round()),
                              fontSize: 16,
                              fontStyle: FontStyle.italic,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            '"${widget.quote.text}"',
                            style: GoogleFonts.merriweather(
                              color: widget.textColor,
                              fontSize: 22,
                              height: 1.4,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 32),
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
    );
  }
}