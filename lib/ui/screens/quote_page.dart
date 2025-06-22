// lib/ui/screens/quote_page.dart - АДАПТИВНАЯ ВЕРСИЯ
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/rendering.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:share_plus/share_plus.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:ui' as ui;
import 'dart:math' show sin, cos;
import 'package:just_audio/just_audio.dart';
import 'onboarding_overlay.dart';


import '../../models/daily_quote.dart';
import '../../models/quote.dart';
import '../../services/quote_extraction_service.dart';
import '../../services/favorites_service.dart';
import '../../services/image_picker_service.dart';
import '../../services/sound_manager.dart';
import '../../utils/custom_cache.dart';
import '../widgets/nav_drawer.dart';
import '../widgets/note_modal.dart';
import 'context_page.dart';

// [Все остальные классы остаются такими же: StrikeThroughPainter, AnimatedHeartButton, AnimatedShareButton, TutorialOverlay]

class StrikeThroughPainter extends CustomPainter {
  final double progress;

  StrikeThroughPainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;

    final startX = size.width * 0.15;
    final startY = size.height * 0.15;
    final endX = size.width * 0.85;
    final endY = size.height * 0.85;

    final currentEndX = startX + (endX - startX) * progress;
    final currentEndY = startY + (endY - startY) * progress;

    canvas.drawLine(
      Offset(startX, startY),
      Offset(currentEndX, currentEndY),
      paint,
    );
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => true;
}

class AnimatedHeartButton extends StatefulWidget {
  final bool isLiked;
  final VoidCallback onTap;
  final Color color;

  const AnimatedHeartButton({
    Key? key,
    required this.isLiked,
    required this.onTap,
    required this.color,
  }) : super(key: key);

  @override
  State<AnimatedHeartButton> createState() => _AnimatedHeartButtonState();
}

class _AnimatedHeartButtonState extends State<AnimatedHeartButton>
    with TickerProviderStateMixin {
  late AnimationController _scaleController;
  late AnimationController _sparkleController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _sparkleAnimation;

  @override
  void initState() {
    super.initState();
    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _sparkleController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 1.2,
    ).animate(CurvedAnimation(
      parent: _scaleController,
      curve: Curves.elasticOut,
    ));

    _sparkleAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _sparkleController,
      curve: Curves.easeOut,
    ));
  }

  void _handleTap() {
    widget.onTap();
    _scaleController.forward().then((_) {
      _scaleController.reverse();
    });
    if (widget.isLiked) {
      _sparkleController.forward().then((_) {
        _sparkleController.reset();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _handleTap,
      child: AnimatedBuilder(
        animation: Listenable.merge([_scaleAnimation, _sparkleAnimation]),
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.black.withAlpha((0.3 * 255).round()),
                boxShadow: widget.isLiked
                    ? [
                        BoxShadow(
                          color: Colors.black.withAlpha((0.3 * 255).round()),
                          blurRadius: 8,
                          spreadRadius: 2,
                        )
                      ]
                    : null,
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  widget.isLiked 
                    ? Container(
                        child: Icon(
                          Icons.favorite,
                          color: widget.color,
                          size: 28,
                        ),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withAlpha((0.3 * 255).round()),
                              blurRadius: 8,
                              spreadRadius: 2,
                            )
                          ],
                        ),
                      )
                    : Icon(
                        Icons.favorite_border,
                        color: widget.color,
                        size: 28,
                      ),
                  if (widget.isLiked && _sparkleAnimation.value > 0)
                    ...List.generate(6, (index) {
                      final angle = (index * 60) * (3.14159 / 180);
                      final radius = 20 * _sparkleAnimation.value;
                      return Positioned(
                        left: 28 + radius * cos(angle) - 2,
                        top: 28 + radius * sin(angle) - 2,
                        child: Opacity(
                          opacity: 1 - _sparkleAnimation.value,
                          child: Container(
                            width: 4,
                            height: 4,
                            decoration: BoxDecoration(
                              color: Colors.black.withAlpha((0.5 * 255).round()),
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                      );
                    }),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    _scaleController.dispose();
    _sparkleController.dispose();
    super.dispose();
  }
}

class AnimatedShareButton extends StatefulWidget {
  final VoidCallback onTap;
  final Color color;

  const AnimatedShareButton({
    Key? key,
    required this.onTap,
    required this.color,
  }) : super(key: key);

  @override
  State<AnimatedShareButton> createState() => _AnimatedShareButtonState();
}

class _AnimatedShareButtonState extends State<AnimatedShareButton>
    with TickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _rotationAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 1.15,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    ));

    _rotationAnimation = Tween<double>(
      begin: 0.0,
      end: 0.1,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    ));
  }

  void _handleTap() {
    widget.onTap();
    _controller.forward().then((_) {
      _controller.reverse();
    });
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _handleTap,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: Transform.rotate(
              angle: _rotationAnimation.value,
              child: Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.black.withAlpha((0.3 * 255).round()),
                  border: Border.all(
                    color: widget.color.withAlpha((0.3 * 255).round()),
                    width: 1,
                  ),
                ),
                child: Icon(
                  Icons.share_outlined,
                  color: widget.color,
                  size: 28,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}

class TutorialOverlay extends StatefulWidget {
  final Widget child;
  final bool showTutorial;
  final VoidCallback onTutorialComplete;

  const TutorialOverlay({
    Key? key,
    required this.child,
    required this.showTutorial,
    required this.onTutorialComplete,
  }) : super(key: key);

  @override
  State<TutorialOverlay> createState() => _TutorialOverlayState();
}

class _TutorialOverlayState extends State<TutorialOverlay>
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  int _currentStep = 0;
  final int _totalSteps = 2;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    ));

    if (widget.showTutorial) {
      Future.delayed(const Duration(milliseconds: 1000), () {
        if (mounted) {
          _fadeController.forward();
          _showNextTip();
        }
      });
    }
  }

  void _showNextTip() {
    Future.delayed(const Duration(seconds: 4), () {
      if (mounted) {
        setState(() {
          _currentStep++;
        });
        if (_currentStep >= _totalSteps) {
          _fadeController.reverse().then((_) {
            widget.onTutorialComplete();
          });
        } else {
          _showNextTip();
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        if (widget.showTutorial)
          FadeTransition(
            opacity: _fadeAnimation,
            child: Container(
              color: Colors.black.withAlpha((0.7 * 255).round()),
              child: _buildTutorialStep(),
            ),
          ),
      ],
    );
  }

  Widget _buildTutorialStep() {
    switch (_currentStep) {
      case 0:
        return _buildSwipeUpTutorial();
      case 1:
        return _buildLongPressTutorial();
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildSwipeUpTutorial() {
    return Positioned(
      bottom: 120,
      left: 0,
      right: 0,
      child: Column(
        children: [
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.0, end: 1.0),
            duration: const Duration(seconds: 2),
            builder: (context, value, child) {
              return Transform.translate(
                offset: Offset(0, -20 * sin(value * 3.14159 * 2)),
                child: Icon(
                  Icons.keyboard_arrow_up,
                  color: Colors.white,
                  size: 40,
                ),
              );
            },
          ),
          const SizedBox(height: 16),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 40),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.black.withAlpha((0.8 * 255).round()),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withAlpha((0.2 * 255).round())),
            ),
            child: const Text(
              'Свайп вверх для просмотра контекста цитаты',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w400,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLongPressTutorial() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 1.0, end: 1.1),
            duration: const Duration(milliseconds: 800),
            builder: (context, value, child) {
              return Transform.scale(
                scale: value,
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withAlpha((0.2 * 255).round()),
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: const Icon(
                    Icons.touch_app,
                    color: Colors.white,
                    size: 40,
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 24),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 40),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.black.withAlpha((0.8 * 255).round()),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withAlpha((0.2 * 255).round())),
            ),
            child: const Text(
              'Долгое нажатие на цитату для добавления заметки',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w400,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }
}

// ============ ГЛАВНЫЙ КЛАСС С АДАПТИВНОСТЬЮ ============

class QuotePage extends StatefulWidget {
  const QuotePage({super.key});

  @override
  State<QuotePage> createState() => _QuotePageState();
}

class _QuotePageState extends State<QuotePage>
    with TickerProviderStateMixin, WidgetsBindingObserver, RouteAware {
  final QuoteExtractionService _quoteService = QuoteExtractionService();
  final CustomCachePrefs _cache = CustomCache.prefs;
  final SoundManager _soundManager = SoundManager();
  final GlobalKey _quoteCardKey = GlobalKey();

  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late AnimationController _soundButtonController;
  late Animation<double> _soundButtonAnimation;

  DailyQuote? _currentDailyQuote;
  String? _backgroundImageUrl;
  bool _isLoading = true;
  bool _isFavorite = false;
  bool _isSoundMuted = false;
  bool _showOnboarding = false;
  bool _isActive = true; // Флаг активности страницы

  String? _error;
  Color _textColor = Colors.white;
  AudioPlayer? _ambientPlayer;
  String? _currentTheme;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeAnimations();
    _initializeSound();
    _loadTodayQuote();
    _checkTutorial();
  }

  // [Все методы инициализации остаются такими же]
  Future<void> _checkTutorial() async {
  final hasSeenOnboarding = _cache.getSetting('onboarding_seen') ?? false;
  if (!hasSeenOnboarding) {
    setState(() {
      _showOnboarding = true;
    });
  }
}

  void _onOnboardingComplete() {
  _cache.setSetting('onboarding_seen', true);
  setState(() {
    _showOnboarding = false;
  });
}

  Future<void> _initializeSound() async {
    await _soundManager.init();

    setState(() {
      _isSoundMuted = _soundManager.isMuted;
    });

    if (_isSoundMuted) {
      _soundButtonController.forward();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.paused || state == AppLifecycleState.detached) {
      _stopAmbientSound();
    } else if (state == AppLifecycleState.resumed) {
      if (mounted && !_isSoundMuted && _isActive) {
        _resumeAmbientIfNeeded();
      }
    }
  }

  void _initializeAnimations() {
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    
    _soundButtonController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _soundButtonAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _soundButtonController,
      curve: Curves.easeInOut,
    ));
    
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    ));

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutCubic,
    ));
  }

  Future<void> _loadTodayQuote() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final cached = _cache.getTodayQuote();
      if (cached != null) {
        await _setupQuoteDisplay(cached);
        return;
      }

      final dailyQuote = await _quoteService.generateDailyQuote();
      if (dailyQuote != null) {
        await _cache.cacheDailyQuote(dailyQuote);
        await _setupQuoteDisplay(dailyQuote);
      } else {
        setState(() {
          _error = 'Не удалось загрузить цитату дня';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Ошибка загрузки: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _stopAmbientSound() async {
    if (_ambientPlayer != null) {
      try {
        await _ambientPlayer!.stop();
        await _ambientPlayer!.dispose();
        _ambientPlayer = null;
        _currentTheme = null;
      } catch (e) {
        print('Error stopping ambient sound: $e');
      }
    }
  }

  Future<void> _resumeAmbientIfNeeded() async {
    if (_currentDailyQuote != null && 
        !_isSoundMuted && 
        _isActive &&
        (_ambientPlayer == null || !(_ambientPlayer?.playing ?? false))) {
      await _playAmbientSound(_currentDailyQuote!.quote.category);
    }
  }

  Future<void> _setupQuoteDisplay(DailyQuote dailyQuote) async {
    String imageUrl;
    final cachedImageUrl = _cache.getSetting('daily_image_${_dateToString(DateTime.now())}');
    if (cachedImageUrl != null) {
      imageUrl = cachedImageUrl;
    } else {
      imageUrl = ImagePickerService.getRandomImage(dailyQuote.quote.category);
      await _cache.setSetting('daily_image_${_dateToString(DateTime.now())}', imageUrl);
    }
    
    final textColor = _determineTextColor(dailyQuote.quote.category);
    final favSvc = await FavoritesService.init();
    final isFavorite = favSvc.isFavorite(dailyQuote.quote.id);

    setState(() {
      _currentDailyQuote = dailyQuote;
      _backgroundImageUrl = imageUrl;
      _textColor = textColor;
      _isFavorite = isFavorite;
      _isLoading = false;
    });
    
    await Future.delayed(const Duration(milliseconds: 400));
    _startAnimations();
    
    if (!_isSoundMuted) {
      await _playAmbientSound(dailyQuote.quote.category);
    }
  }

  Future<void> _playAmbientSound(String themeId) async {
    if (_currentTheme == themeId || _isSoundMuted || !_isActive) return;
    
    await _stopAmbientSound();
    
    try {
      _ambientPlayer = AudioPlayer();
      await _ambientPlayer!.setAsset('assets/sounds/theme_${themeId}_ambient.mp3');
      _ambientPlayer!.setLoopMode(LoopMode.one);
      await _ambientPlayer!.play();
      _currentTheme = themeId;
    } catch (e) {
      print('Ambient sound not available: $e');
    }
  }

  Color _determineTextColor(String category) {
    switch (category) {
      case 'greece':
        return Colors.white;
      case 'nordic':
        return Colors.white;
      case 'philosophy':
        return Colors.white.withAlpha((0.95 * 255).round());
      case 'pagan':
        return Colors.white;
      default:
        return Colors.white;
    }
  }

  void _startAnimations() {
    _fadeController.forward();
    Future.delayed(const Duration(milliseconds: 200), () {
      _slideController.forward();
    });
  }

  String _dateToString(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  Future<void> _toggleFavorite() async {
    if (_currentDailyQuote == null) return;

    final quote = _currentDailyQuote!.quote;
    HapticFeedback.lightImpact();

    try {
      final favSvc = await FavoritesService.init();
      
      if (_isFavorite) {
        await favSvc.removeFromFavorites(quote.id);
      } else {
        await favSvc.addToFavorites(quote, imageUrl: _backgroundImageUrl);
      }

      setState(() {
        _isFavorite = !_isFavorite;
      });

      if (mounted) {
        _showFavoriteAnimation(_isFavorite);
      }
    } catch (e) {
      print('Error toggling favorite: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Ошибка при добавлении в избранное'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
  
  void _showFavoriteAnimation(bool added) {
    final overlay = Overlay.of(context);
    late final OverlayEntry overlayEntry;
    
    overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        bottom: 100,
        left: 0,
        right: 0,
        child: Center(
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.0, end: 1.0),
            duration: const Duration(milliseconds: 800),
            onEnd: () {
              Future.delayed(const Duration(milliseconds: 1200), () {
                overlayEntry.remove();
              });
            },
            builder: (context, value, child) {
              return Transform.scale(
                scale: value > 0.8 ? 1.0 : value * 1.25,
                child: Opacity(
                  opacity: value > 0.8 ? 1.0 - ((value - 0.8) * 5) : value * 1.25,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.black.withAlpha((0.7 * 255).round()),
                      borderRadius: BorderRadius.circular(30),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withAlpha((0.2 * 255).round()),
                          blurRadius: 15,
                          spreadRadius: 2,
                        )
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          added ? Icons.favorite : Icons.favorite_border,
                          color: Colors.white,
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          added ? 'В избранном' : 'Удалено из избранного',
                          style: GoogleFonts.montserrat(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
    
    overlay.insert(overlayEntry);
  }

  Future<void> _shareQuoteImage() async {
    if (_currentDailyQuote == null) return;

    try {
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const Center(
            child: CircularProgressIndicator(),
          ),
        );
      }

      final imageBytes = await _createQuoteImage();
      
      if (mounted) Navigator.of(context).pop();

      if (imageBytes != null) {
        await Share.shareXFiles([
          XFile.fromData(
            imageBytes,
            name: 'quote_${DateTime.now().millisecondsSinceEpoch}.png',
            mimeType: 'image/png',
          ),
        ], text: '"${_currentDailyQuote!.quote.text}"\n— ${_currentDailyQuote!.quote.author}');
      }
    } catch (e) {
      print('Error sharing quote image: $e');
      if (mounted) Navigator.of(context).pop();
      
      await Share.share(
        '"${_currentDailyQuote!.quote.text}"\n— ${_currentDailyQuote!.quote.author}',
        subject: 'Цитата дня',
      );
    }
  }

  Future<Uint8List?> _createQuoteImage() async {
    try {
      final RenderRepaintBoundary boundary = 
          _quoteCardKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      
      final ui.Image image = await boundary.toImage(pixelRatio: 2.0);
      final ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      
      return byteData?.buffer.asUint8List();
    } catch (e) {
      print('Ошибка создания изображения: $e');
      return null;
    }
  }

  void _navigateToContext() async {
    if (_currentDailyQuote == null) return;
    
    setState(() => _isActive = false);
    await _stopAmbientSound();

    await _cache.markQuoteAsViewed(_currentDailyQuote!.quote.id);
    await _cache.markDailyQuoteAsViewed(DateTime.now());

    if (mounted) {
      Navigator.of(context).push(
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) => 
              ContextPage(dailyQuote: _currentDailyQuote!),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            const begin = Offset(0.0, 1.0);
            const end = Offset.zero;
            const curve = Curves.easeInOutCubic;

            var tween = Tween(begin: begin, end: end).chain(
              CurveTween(curve: curve),
            );

            return SlideTransition(
              position: animation.drive(tween),
              child: child,
            );
          },
          transitionDuration: const Duration(milliseconds: 400),
        ),
      ).then((_) {
        if (mounted) {
          setState(() => _isActive = true);
          if (!_isSoundMuted) {
            _resumeAmbientIfNeeded();
          }
        }
      });
    }
  }

  void _navigateToPage(Widget page) async {
    setState(() => _isActive = false);
    await _stopAmbientSound();
    
    if (mounted) {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => page),
      ).then((_) {
        if (mounted) {
          setState(() => _isActive = true);
          if (!_isSoundMuted) {
            Future.delayed(const Duration(milliseconds: 300), () {
              if (mounted && !_isSoundMuted && _isActive) {
                _resumeAmbientIfNeeded();
              }
            });
          }
        }
      });
    }
  }



  Widget _buildLoadingState() {
    return Container(color: Colors.black);
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.red,
            ),
            const SizedBox(height: 16),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16, color: Colors.white),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _loadTodayQuote,
              child: const Text('Попробовать снова'),
            ),
          ],
        ),
      ),
    );
  }

  // ============ АДАПТИВНЫЙ КОНТЕНТ ============
  Widget _buildQuoteContent() {
    final quote = _currentDailyQuote!.quote;
    
    return GestureDetector(
      onVerticalDragEnd: (details) {
        if (details.primaryVelocity != null && details.primaryVelocity! < -500) {
          _navigateToContext();
        }
      },
      onLongPress: () {
        HapticFeedback.mediumImpact();
        showNoteModal(context, quote, onSaved: () {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Заметка сохранена'),
              duration: const Duration(seconds: 2),
              behavior: SnackBarBehavior.floating,
              backgroundColor: Colors.black87,
              margin: const EdgeInsets.all(20),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          );
        });
      },
      child: RepaintBoundary(
        key: _quoteCardKey,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Черный фон
            Container(color: Colors.black),
            
            // Картинка с анимацией
            if (_backgroundImageUrl != null)
              AnimatedOpacity(
                opacity: _isLoading ? 0.0 : 1.0,
                duration: const Duration(milliseconds: 800),
                child: CachedNetworkImage(
                  imageUrl: _backgroundImageUrl!,
                  cacheManager: CustomCache.instance,
                  fit: BoxFit.cover,
                  placeholder: (_, __) => Container(color: Colors.black),
                  errorWidget: (_, __, ___) => Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.black, Colors.grey[900]!],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                ),
              ),
            
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.black.withAlpha((0.4 * 255).round()),
                    Colors.black.withAlpha((0.7 * 255).round()),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
            
            // АДАПТИВНАЯ КОМПОНОВКА
            LayoutBuilder(
              builder: (context, constraints) {
                return Container(
                  width: double.infinity,
                  height: double.infinity,
                  padding: EdgeInsets.all(_getResponsivePadding(constraints)),
                  child: Column(
                    children: [
                      _buildHeader(constraints),
                      
                      Expanded(
                        child: FadeTransition(
                          opacity: _fadeAnimation,
                          child: SlideTransition(
                            position: _slideAnimation,
                            child: _buildAdaptiveQuoteLayout(quote, constraints),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
            
            // Подсказка внизу
            if (_currentDailyQuote != null && !_currentDailyQuote!.isViewed)
  _buildSwipeHint(),
          ],
        ),
      ),
    );
  }

  // ============ АДАПТИВНЫЕ МЕТОДЫ ============
  
  /// Получает отзывчивый отступ в зависимости от размера экрана
  double _getResponsivePadding(BoxConstraints constraints) {
    if (constraints.maxHeight < 600) return 16.0; // Маленькие экраны
    if (constraints.maxHeight < 800) return 20.0; // Средние экраны  
    return 24.0; // Большие экраны
  }

  /// Адаптивная компоновка цитаты
  Widget _buildAdaptiveQuoteLayout(Quote quote, BoxConstraints constraints) {
    final isSmallScreen = constraints.maxHeight < 700;
    final isVerySmallScreen = constraints.maxHeight < 600;
    
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Адаптивная цитата
        Flexible(
          flex: isVerySmallScreen ? 3 : 4,
          child: Center(
            child: _buildAdaptiveQuoteText(quote, constraints),
          ),
        ),
        
        SizedBox(height: isVerySmallScreen ? 16 : 24),
        
        // Адаптивная атрибуция
        _buildAdaptiveAttribution(quote, constraints),
        
        SizedBox(height: isSmallScreen ? 24 : 32),
        
        // Кнопки действий - всегда помещаются
        _buildActionButtons(constraints),
        
        // Дополнительное пространство для маленьких экранов
        if (isVerySmallScreen) const SizedBox(height: 16),
      ],
    );
  }

  /// Адаптивный текст цитаты с автоматическим размером
  Widget _buildAdaptiveQuoteText(Quote quote, BoxConstraints constraints) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: constraints.maxWidth * 0.08, // 8% от ширины экрана
        vertical: 16,
      ),
      decoration: BoxDecoration(
        border: Border(
          left: BorderSide(
            color: _textColor.withAlpha((0.8 * 255).round()),
            width: 3,
          ),
        ),
      ),
      child: LayoutBuilder(
        builder: (context, textConstraints) {
          return _buildAutoSizingText(quote.text, textConstraints, constraints);
        },
      ),
    );
  }

  /// Создает текст с автоматическим подбором размера шрифта
  Widget _buildAutoSizingText(String text, BoxConstraints textConstraints, BoxConstraints screenConstraints) {
    // Начальный размер шрифта
    double fontSize = _getAdaptiveFontSize(text, screenConstraints);
    final minFontSize = screenConstraints.maxHeight < 600 ? 12.0 : 14.0;
    final lineHeight = _getAdaptiveLineHeight(screenConstraints);
    
    // Максимальная высота для текста (оставляем место для автора и кнопок)
    final maxTextHeight = screenConstraints.maxHeight * 0.45; // 45% от высоты экрана
    
    return _buildTextWithSize(text, fontSize, lineHeight, textConstraints, maxTextHeight, minFontSize);
  }

  /// Рекурсивно подбирает размер шрифта для помещения текста
  Widget _buildTextWithSize(String text, double fontSize, double lineHeight, 
      BoxConstraints constraints, double maxHeight, double minFontSize) {
    
    final textStyle = GoogleFonts.merriweather(
      fontSize: fontSize,
      height: lineHeight,
      fontWeight: FontWeight.w300,
      fontStyle: FontStyle.italic,
      color: _textColor,
      decoration: TextDecoration.none,
    );

    final textSpan = TextSpan(
      text: '"$text"',
      style: textStyle,
    );

    final textPainter = TextPainter(
      text: textSpan,
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
      maxLines: null, // Убираем ограничение на количество строк
    );

    textPainter.layout(maxWidth: constraints.maxWidth);
    
    // Если текст помещается или достигли минимального размера - возвращаем
    if (textPainter.height <= maxHeight || fontSize <= minFontSize) {
      return Text(
        '"$text"',
        style: textStyle,
        textAlign: TextAlign.center,
      );
    }
    
    // Уменьшаем размер шрифта и пробуем снова
    return _buildTextWithSize(text, fontSize - 1, lineHeight, constraints, maxHeight, minFontSize);
  }

  /// Вычисляет адаптивный размер шрифта
  double _getAdaptiveFontSize(String text, BoxConstraints constraints) {
    // Базовые размеры в зависимости от высоты экрана
    double baseFontSize;
    if (constraints.maxHeight < 600) {
      baseFontSize = 18.0; // Очень маленькие экраны
    } else if (constraints.maxHeight < 700) {
      baseFontSize = 20.0; // Маленькие экраны
    } else if (constraints.maxHeight < 800) {
      baseFontSize = 22.0; // Средние экраны
    } else {
      baseFontSize = 24.0; // Большие экраны
    }

    // Корректировка в зависимости от длины текста
    if (text.length > 300) {
      baseFontSize -= 4;
    } else if (text.length > 200) {
      baseFontSize -= 2;
    } else if (text.length > 150) {
      baseFontSize -= 1;
    }

    // Минимальный и максимальный размер
    return baseFontSize.clamp(14.0, 28.0);
  }

  /// Получает адаптивную высоту строки
  double _getAdaptiveLineHeight(BoxConstraints constraints) {
    if (constraints.maxHeight < 600) return 1.3;
    if (constraints.maxHeight < 700) return 1.4;
    return 1.5;
  }

  
  /// Адаптивная атрибуция автора
  Widget _buildAdaptiveAttribution(Quote quote, BoxConstraints constraints) {
    final authorFontSize = constraints.maxHeight < 600 ? 16.0 : 18.0;
    final sourceFontSize = constraints.maxHeight < 600 ? 13.0 : 15.0;
    
    // Для северных цитат показываем только источник (название книги)
    if (quote.category == 'nordic') {
      return Column(
        children: [
          Text(
            quote.source,
            style: TextStyle(
              fontSize: authorFontSize,
              fontWeight: FontWeight.w600,
              color: _textColor,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      );
    }
    
    // Для остальных категорий показываем автора и источник
    return Column(
      children: [
        Text(
          quote.author,
          style: TextStyle(
            fontSize: authorFontSize,
            fontWeight: FontWeight.w600,
            color: _textColor,
          ),
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 6),
        Text(
          quote.source,
          style: TextStyle(
            fontSize: sourceFontSize,
            color: _textColor.withAlpha((0.8 * 255).round()),
            fontStyle: FontStyle.italic,
          ),
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  /// Адаптивный заголовок
  Widget _buildHeader(BoxConstraints constraints) {
    final isSmallScreen = constraints.maxHeight < 700;
    
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Builder(
          builder: (context) => IconButton(
            icon: Icon(Icons.menu, color: _textColor),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        
        Row(
          children: [
            if (!isSmallScreen) // Скрываем дату на маленьких экранах
              Column(
                children: [
                  Text(
                    'Сегодня',
                    style: TextStyle(
                      fontSize: 12,
                      color: _textColor.withAlpha((0.8 * 255).round()),
                      fontWeight: FontWeight.w300,
                    ),
                  ),
                  Text(
                    _currentDailyQuote!.formattedDate,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: _textColor,
                    ),
                  ),
                ],
              ),
            SizedBox(width: isSmallScreen ? 0 : 16),
            _buildSoundButton(),
          ],
        ),
        
        // Подсказка для заметок (адаптивная)
        if (!isSmallScreen)
  const SizedBox.shrink()
else
  const SizedBox(width: 48), // Заглушка для выравнивания
      ],
    );
  }

  /// Кнопка звука
  Widget _buildSoundButton() {
    return GestureDetector(
      onTap: () async {
        setState(() {
          _isSoundMuted = !_isSoundMuted;
        });
        
        if (_isSoundMuted) {
          await SoundManager().setMuted(true);
          _soundButtonController.forward();
          await _stopAmbientSound();
        } else {
          await SoundManager().setMuted(false);
          _soundButtonController.reverse();
          await _resumeAmbientIfNeeded();
        }
      },
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.black.withAlpha((0.3 * 255).round()),
        ),
        child: AnimatedBuilder(
          animation: _soundButtonAnimation,
          builder: (context, child) {
            return Stack(
              children: [
                Icon(
                  Icons.volume_up,
                  color: _textColor,
                  size: 20,
                ),
                if (_soundButtonAnimation.value > 0)
                  Positioned.fill(
                    child: CustomPaint(
                      painter: StrikeThroughPainter(_soundButtonAnimation.value),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  /// Подсказка для заметок
 

  /// Кнопки действий (адаптивные)
  Widget _buildActionButtons(BoxConstraints constraints) {
    final buttonSize = constraints.maxHeight < 600 ? 48.0 : 56.0;
    final spacing = constraints.maxHeight < 600 ? 24.0 : 32.0;
    
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildAdaptiveHeartButton(buttonSize),
        SizedBox(width: spacing),
        _buildAdaptiveShareButton(buttonSize),
      ],
    );
  }

  /// Адаптивная кнопка лайка
  Widget _buildAdaptiveHeartButton(double size) {
    return GestureDetector(
      onTap: _toggleFavorite,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.black.withAlpha((0.3 * 255).round()),
        ),
        child: _isFavorite 
          ? Container(
              child: Icon(
                Icons.favorite,
                color: _textColor,
                size: size * 0.5,
              ),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha((0.3 * 255).round()),
                    blurRadius: 8,
                    spreadRadius: 2,
                  )
                ],
              ),
            )
          : Icon(
              Icons.favorite_border,
              color: _textColor,
              size: size * 0.5,
            ),
      ),
    );
  }

  /// Адаптивная кнопка поделиться
  Widget _buildAdaptiveShareButton(double size) {
    return GestureDetector(
      onTap: _shareQuoteImage,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.black.withAlpha((0.3 * 255).round()),
          border: Border.all(
            color: _textColor.withAlpha((0.3 * 255).round()),
            width: 1,
          ),
        ),
        child: Icon(
          Icons.share_outlined,
          color: _textColor,
          size: size * 0.5,
        ),
      ),
    );
  }

  /// Подсказка свайпа
  Widget _buildSwipeHint() {
    return Positioned(
      bottom: 40,
      left: 0,
      right: 0,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.0, end: 1.0),
        duration: const Duration(seconds: 2),
        builder: (context, value, child) {
          return AnimatedOpacity(
            opacity: value > 0.5 ? 2.0 - (value * 2) : value * 2,
            duration: const Duration(milliseconds: 300),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 40),
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.black.withAlpha((0.7 * 255).round()),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: _textColor.withAlpha((0.2 * 255).round()),
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.keyboard_arrow_up,
                    color: _textColor.withAlpha((0.8 * 255).round()),
                    size: 18,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Свайп для контекста',
                    style: GoogleFonts.merriweather(
                      color: _textColor.withAlpha((0.8 * 255).round()),
                      fontSize: 12,
                      fontWeight: FontWeight.w300,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _fadeController.dispose();
    _slideController.dispose();
    _soundButtonController.dispose();
    _stopAmbientSound();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    final mainScaffold = Scaffold(
      backgroundColor: Colors.black,
      drawerScrimColor: Colors.black.withAlpha((0.3 * 255).round()),
      drawer: Theme(
        data: Theme.of(context).copyWith(
          canvasColor: Colors.transparent,
        ),
        child: NavDrawer(onNavigate: _navigateToPage),
      ),
      body: SafeArea(
        child: _isLoading
            ? _buildLoadingState()
            : _error != null
                ? _buildErrorState()
                : _buildQuoteContent(),
      ),
    );

    final content = _showOnboarding
        ? OnboardingOverlay(
            onComplete: _onOnboardingComplete,
            child: mainScaffold,
          )
        : mainScaffold;

    return content;
  }
    }