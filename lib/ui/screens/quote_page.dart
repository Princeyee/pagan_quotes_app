import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/rendering.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:ui' as ui;
import 'dart:typed_data';
import 'package:just_audio/just_audio.dart';

import '../../models/daily_quote.dart';
import '../../models/quote.dart';
import '../../services/quote_extraction_service.dart';
import '../../services/favorites_service.dart';
import '../../services/image_picker_service.dart';
import '../../services/sound_manager.dart'; // ✅ убедись, что импорт есть
import '../../utils/custom_cache.dart';
import '../widgets/nav_drawer.dart';
import '../widgets/note_modal.dart';
import 'context_page.dart';

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

class QuotePage extends StatefulWidget {
  const QuotePage({super.key});

  @override
  State<QuotePage> createState() => _QuotePageState();
}

class _QuotePageState extends State<QuotePage>
    with TickerProviderStateMixin, WidgetsBindingObserver, RouteAware {
  final QuoteExtractionService _quoteService = QuoteExtractionService();
  final CustomCachePrefs _cache = CustomCache.prefs;
  final SoundManager _soundManager = SoundManager(); // ✅ экземпляр SoundManager
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

  String? _error;
  Color _textColor = Colors.white;
  AudioPlayer? _ambientPlayer;
  String? _currentTheme;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeAnimations();
    _initializeSound(); // ✅ запуск и загрузка состояния звука
    _loadTodayQuote();
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
      // Возобновляем звук только если мы на главном экране
      if (mounted && !_isSoundMuted) {
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
    // Возобновляем музыку только если:
    // 1. Звук не отключен пользователем
    // 2. У нас есть цитата для проигрывания
    // 3. Музыка еще не играет
    if (_currentDailyQuote != null && 
        !_isSoundMuted && 
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
    
    _startAnimations();
    
    if (!_isSoundMuted) {
      await _playAmbientSound(dailyQuote.quote.category);
    }
  }

  Future<void> _playAmbientSound(String themeId) async {
    if (_currentTheme == themeId || _isSoundMuted) return;
    
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
        return Colors.white.withOpacity(0.95);
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_isFavorite ? 'Добавлено в избранное' : 'Удалено из избранного'),
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
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
    
    // ОСТАНАВЛИВАЕМ МУЗЫКУ ПРИ ПЕРЕХОДЕ К КОНТЕКСТУ
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
        // Возобновляем фоновый звук после возврата из контекста
        if (!_isSoundMuted && mounted) {
          _resumeAmbientIfNeeded();
        }
      });
    }
  }

  // НОВЫЙ МЕТОД ДЛЯ НАВИГАЦИИ В МЕНЮ
  void _navigateToPage(Widget page) async {
    // Останавливаем музыку при переходе в любой раздел меню
    await _stopAmbientSound();
    
    if (mounted) {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => page),
      ).then((_) {
        // Возобновляем музыку при возврате на главную
        // Но только если мы не были отключены пользователем
        if (!_isSoundMuted && mounted) {
          Future.delayed(const Duration(milliseconds: 300), () {
            if (mounted && !_isSoundMuted) {
              _resumeAmbientIfNeeded();
            }
          });
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      drawerScrimColor: Colors.black.withOpacity(0.3),
      drawer: Theme(
        data: Theme.of(context).copyWith(
          canvasColor: Colors.transparent,
        ),
        child: NavDrawer(onNavigate: _navigateToPage), // Передаём callback
      ),
      onDrawerChanged: (isOpened) {
        // Убираем остановку музыки при открытии drawer'а
        // Музыка будет играть и при открытом меню
      },
      body: SafeArea(
        child: _isLoading 
            ? _buildLoadingState()
            : _error != null 
                ? _buildErrorState()
                : _buildQuoteContent(),
      ),
    );
  }

  Widget _buildLoadingState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: Colors.white),
          SizedBox(height: 16),
          Text(
            'Загружаем мудрость...',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w300,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
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
            if (_backgroundImageUrl != null)
              CachedNetworkImage(
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
            
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.black.withOpacity(0.3),
                    Colors.black.withOpacity(0.6),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
            
            Container(
              width: double.infinity,
              height: double.infinity,
              padding: const EdgeInsets.all(24.0),
              child: Column(
                children: [
                  _buildHeader(),
                  
                  Expanded(
                    child: FadeTransition(
                      opacity: _fadeAnimation,
                      child: SlideTransition(
                        position: _slideAnimation,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _buildQuoteText(quote),
                            const SizedBox(height: 32),
                            _buildQuoteAttribution(quote),
                            const SizedBox(height: 48),
                            _buildActionButtons(),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            if (_currentDailyQuote != null && !_currentDailyQuote!.isViewed)
              Positioned(
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
                      child: Column(
                        children: [
                          Icon(
                            Icons.keyboard_arrow_up,
                            color: _textColor.withOpacity(0.5),
                            size: 24,
                          ),
                          Text(
                            'Свайп для контекста',
                            style: TextStyle(
                              color: _textColor.withOpacity(0.4),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
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
            Column(
              children: [
                Text(
                  'Сегодня',
                  style: TextStyle(
                    fontSize: 14,
                    color: _textColor.withOpacity(0.8),
                    fontWeight: FontWeight.w300,
                  ),
                ),
                Text(
                  _currentDailyQuote!.formattedDate,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: _textColor,
                  ),
                ),
              ],
            ),
            const SizedBox(width: 16),
            GestureDetector(
              onTap: () async {
                setState(() {
                  _isSoundMuted = !_isSoundMuted;
                });
                
                if (!_isSoundMuted) {
  // Выключаем звук глобально
  await SoundManager().setMuted(true);
  _soundButtonController.forward();
  await _stopAmbientSound();
} else {
  // Включаем звук глобально
  await SoundManager().setMuted(false);
  _soundButtonController.reverse();
  await _resumeAmbientIfNeeded();
}
              },
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.black.withOpacity(0.3),
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
            ),
          ],
        ),
        
        Tooltip(
          message: 'Долгое нажатие для заметки',
          child: Icon(
            Icons.touch_app,
            color: _textColor.withOpacity(0.3),
            size: 20,
          ),
        ),
      ],
    );
  }

  Widget _buildQuoteText(Quote quote) {
    double fontSize = 24;
    if (quote.text.length > 200) {
      fontSize = 20;
    } else if (quote.text.length > 300) {
      fontSize = 18;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      decoration: BoxDecoration(
        border: Border(
          left: BorderSide(
            color: _textColor.withOpacity(0.8),
            width: 3,
          ),
        ),
      ),
      child: Text(
        '"${quote.text}"',
        style: TextStyle(
          fontSize: fontSize,
          height: 1.5,
          fontWeight: FontWeight.w300,
          fontStyle: FontStyle.italic,
          color: _textColor,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildQuoteAttribution(Quote quote) {
    return Column(
      children: [
        Text(
          quote.author,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: _textColor,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          quote.source,
          style: TextStyle(
            fontSize: 16,
            color: _textColor.withOpacity(0.8),
            fontStyle: FontStyle.italic,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildActionButtons() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        GestureDetector(
          onTap: _toggleFavorite,
          child: AnimatedScale(
            scale: 1.0,
            duration: const Duration(milliseconds: 200),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.black.withOpacity(0.3),
              ),
              child: Icon(
                _isFavorite ? Icons.favorite : Icons.favorite_border,
                color: _isFavorite ? Colors.red : _textColor,
                size: 32,
              ),
            ),
          ),
        ),
        
        const SizedBox(width: 32),
        
        GestureDetector(
          onTap: _shareQuoteImage,
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.black.withOpacity(0.3),
            ),
            child: Icon(
              Icons.share,
              color: _textColor,
              size: 32,
            ),
          ),
        ),
      ],
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
}