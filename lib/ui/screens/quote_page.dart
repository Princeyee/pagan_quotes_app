// lib/ui/screens/quote_page.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/rendering.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:ui' as ui;
import 'dart:typed_data';

import '../../models/daily_quote.dart';
import '../../models/quote.dart';
import '../../services/quote_extraction_service.dart';
import '../../services/favorites_service.dart';
import '../../services/image_picker_service.dart';
import '../../utils/custom_cache.dart';
import '../widgets/nav_drawer.dart';
import 'context_page.dart';

class QuotePage extends StatefulWidget {
  const QuotePage({super.key});

  @override
  State<QuotePage> createState() => _QuotePageState();
}

class _QuotePageState extends State<QuotePage> with TickerProviderStateMixin {
  final QuoteExtractionService _quoteService = QuoteExtractionService();
  final CustomCachePrefs _cache = CustomCache.prefs;
  final GlobalKey _quoteCardKey = GlobalKey();

  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  DailyQuote? _currentDailyQuote;
  String? _backgroundImageUrl;
  bool _isLoading = true;
  bool _isFavorite = false;
  String? _error;
  Color _textColor = Colors.white;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _loadTodayQuote();
  }

  void _initializeAnimations() {
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    
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
      // Сначала проверяем кэш
      final cached = _cache.getTodayQuote();
      if (cached != null) {
        await _setupQuoteDisplay(cached);
        return;
      }

      // Генерируем новую цитату только если её нет в кэше
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

  Future<void> _setupQuoteDisplay(DailyQuote dailyQuote) async {
    // Получаем случайное изображение для категории цитаты
    final imageUrl = ImagePickerService.getRandomImage(dailyQuote.quote.category);
    
    // Определяем цвет текста (можно улучшить анализом изображения)
    final textColor = _determineTextColor(dailyQuote.quote.category);

    // Проверяем статус избранного
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
  }
    

  Color _determineTextColor(String category) {
    // Простая логика определения цвета текста по категории
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

  Future<void> _toggleFavorite() async {
    if (_currentDailyQuote == null) return;

    final quote = _currentDailyQuote!.quote;
    
    // Haptic feedback
    HapticFeedback.lightImpact();

    try {
      final favSvc = await FavoritesService.init();
      
      if (_isFavorite) {
        await favSvc.removeFromFavorites(quote.id);
      } else {
        // Сохраняем цитату с URL изображения
        await favSvc.addToFavorites(quote, imageUrl: _backgroundImageUrl);
      }

      setState(() {
        _isFavorite = !_isFavorite;
      });

      // Показываем снэкбар
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
      // Показываем индикатор загрузки
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const Center(
            child: CircularProgressIndicator(),
          ),
        );
      }

      // Создаем изображение с цитатой
      final imageBytes = await _createQuoteImage();
      
      // Закрываем индикатор загрузки
      if (mounted) Navigator.of(context).pop();

      if (imageBytes != null) {
        // Сохраняем временный файл и делимся им
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
      // Закрываем индикатор загрузки в случае ошибки
      if (mounted) Navigator.of(context).pop();
      
      // Fallback: делимся просто текстом
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

    // Отмечаем цитату как просмотренную
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
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      drawer: const NavDrawer(),
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
        // Свайп вверх для перехода к контексту
        if (details.primaryVelocity != null && details.primaryVelocity! < -500) {
          _navigateToContext();
        }
      },
      child: RepaintBoundary(
        key: _quoteCardKey,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Фоновое изображение
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
            
            // Темный оверлей для читаемости текста
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
            
            // Основной контент
            Container(
              width: double.infinity,
              height: double.infinity,
              padding: const EdgeInsets.all(24.0),
              child: Column(
                children: [
                  // Header с датой и меню
                  _buildHeader(),
                  
                  // Основной контент с цитатой
                  Expanded(
                    child: FadeTransition(
                      opacity: _fadeAnimation,
                      child: SlideTransition(
                        position: _slideAnimation,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // Цитата
                            _buildQuoteText(quote),
                            
                            const SizedBox(height: 32),
                            
                            // Автор и источник
                            _buildQuoteAttribution(quote),
                            
                            const SizedBox(height: 48),
                            
                            // Кнопки лайка и поделиться
                            _buildActionButtons(),
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

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Меню
        Builder(
          builder: (context) => IconButton(
            icon: Icon(Icons.menu, color: _textColor),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        
        // Дата
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
        
        // Пустое место для симметрии
        const SizedBox(width: 48),
      ],
    );
  }

  Widget _buildQuoteText(Quote quote) {
    // Автоматически подбираем размер шрифта в зависимости от длины цитаты
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
        // Кнопка лайка
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
        
        // Кнопка поделиться
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
    _fadeController.dispose();
    _slideController.dispose();
    super.dispose();
  }
}