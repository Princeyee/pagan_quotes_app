// lib/ui/screens/context_page.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:just_audio/just_audio.dart';
import '../../models/daily_quote.dart';
import '../../models/quote_context.dart';
import '../../services/quote_extraction_service.dart';
import '../../utils/custom_cache.dart';
import 'full_text_page.dart';

class ContextPage extends StatefulWidget {
  final DailyQuote dailyQuote;

  const ContextPage({
    super.key,
    required this.dailyQuote,
  });

  @override
  State<ContextPage> createState() => _ContextPageState();
}

class _ContextPageState extends State<ContextPage> 
    with SingleTickerProviderStateMixin {
  final QuoteExtractionService _quoteService = QuoteExtractionService();
  final CustomCachePrefs _cache = CustomCache.prefs;
  final AudioPlayer _candlePlayer = AudioPlayer();
  
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  
  QuoteContext? _context;
  bool _isLoading = true;
  String? _error;
  bool _showSwipeHint = true;
  bool _showTapHint = true;

  @override
  void initState() {
    super.initState();
    _initializeAnimation();
    _startCandleSound();
    _loadContext();
    _checkHints();
  }

  Future<void> _startCandleSound() async {
    try {
      await _candlePlayer.setAsset('assets/sounds/candle.mp3');
      _candlePlayer.setLoopMode(LoopMode.one);
      await _candlePlayer.play();
      print('Candle sound started');
    } catch (e) {
      print('Candle sound not available: $e');
    }
  }

  void _initializeAnimation() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    ));
  }

  Future<void> _checkHints() async {
    final prefs = await SharedPreferences.getInstance();
    
    // Проверяем подсказку для свайпа назад
    final swipeHintShown = prefs.getBool('context_swipe_hint_shown') ?? false;
    if (!swipeHintShown) {
      setState(() => _showSwipeHint = true);
      await prefs.setBool('context_swipe_hint_shown', true);
      
      // Скрыть подсказку через 4 секунды
      Future.delayed(const Duration(seconds: 4), () {
        if (mounted) {
          setState(() => _showSwipeHint = false);
        }
      });
    } else {
      setState(() => _showSwipeHint = false);
    }

    // Проверяем подсказку для тапа на полный текст
    final tapHintShown = prefs.getBool('fulltext_tap_hint_shown') ?? false;
    if (!tapHintShown) {
      setState(() => _showTapHint = true);
      await prefs.setBool('fulltext_tap_hint_shown', true);
      
      // Скрыть подсказку через 5 секунд
      Future.delayed(const Duration(seconds: 5), () {
        if (mounted) {
          setState(() => _showTapHint = false);
        }
      });
    } else {
      setState(() => _showTapHint = false);
    }
  }

  Future<void> _loadContext() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Проверяем кэш
      final cachedContext = _cache.getCachedQuoteContext(widget.dailyQuote.quote.id);
      if (cachedContext != null) {
        setState(() {
          _context = cachedContext;
          _isLoading = false;
        });
        _animationController.forward();
        return;
      }

      // Загружаем контекст
      final context = await _quoteService.getQuoteContext(widget.dailyQuote.quote);
      if (context != null) {
        await _cache.cacheQuoteContext(context);
        setState(() {
          _context = context;
          _isLoading = false;
        });
        _animationController.forward();
      } else {
        setState(() {
          _error = 'Контекст не найден. Возможно, текст был изменен или поврежден.';
          _isLoading = false;
        });
      }

      // Отмечаем контекст как просмотренный
      await _cache.markDailyQuoteAsViewed(
        widget.dailyQuote.date,
        contextViewed: true,
      );
    } catch (e) {
      setState(() {
        _error = 'Ошибка загрузки контекста: $e';
        _isLoading = false;
      });
    }
  }

  void _goBack() {
    _candlePlayer.stop();
    Navigator.of(context).pop();
  }

  void _navigateToFullText() {
    if (_context == null) return;
    
    _candlePlayer.stop(); // Останавливаем звук при переходе к полному тексту
    
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => 
            FullTextPage(context: _context!),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          // Анимация расширения из центра экрана
          return ScaleTransition(
            scale: Tween<double>(
              begin: 0.0,
              end: 1.0,
            ).animate(CurvedAnimation(
              parent: animation,
              curve: Curves.easeInOutCubic,
            )),
            child: FadeTransition(
              opacity: animation,
              child: child,
            ),
          );
        },
        transitionDuration: const Duration(milliseconds: 500),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          widget.dailyQuote.quote.source,
          style: const TextStyle(color: Colors.white),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: _goBack,
        ),
      ),
      body: SafeArea(
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Фоновое изображение для книжного контекста
            Container(
              decoration: const BoxDecoration(
                image: DecorationImage(
                  image: AssetImage('assets/images/book_background.jpg'),
                  fit: BoxFit.cover,
                ),
              ),
            ),
            
            // Темный оверлей для читаемости
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.black.withOpacity(0.7),
                    Colors.black.withOpacity(0.8),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
            
            // Основной контент
            _isLoading
                ? _buildLoadingState()
                : _error != null
                    ? _buildErrorState()
                    : _buildContextContent(),
          ],
        ),
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
            'Загружаем контекст...',
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
              style: const TextStyle(
                fontSize: 16,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TextButton(
                  onPressed: _goBack,
                  child: const Text(
                    'Назад',
                    style: TextStyle(color: Colors.white70),
                  ),
                ),
                const SizedBox(width: 16),
                ElevatedButton(
                  onPressed: _loadContext,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black,
                  ),
                  child: const Text('Попробовать снова'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContextContent() {
    return GestureDetector(
      onVerticalDragEnd: (details) {
        // Свайп вниз для возврата
        if (details.primaryVelocity != null && details.primaryVelocity! > 500) {
          _goBack();
        }
      },
      onTap: () {
        // Тап для перехода к полному тексту
        _navigateToFullText();
      },
      child: Stack(
        children: [
          // Основной контент
          FadeTransition(
            opacity: _fadeAnimation,
            child: SlideTransition(
              position: _slideAnimation,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  children: [
                    // Контекст до цитаты
                    if (_context!.beforeContext.isNotEmpty) ...[
                      ..._context!.beforeContext.map((paragraph) => 
                        _buildParagraph(paragraph, isContext: true)),
                      const SizedBox(height: 24),
                    ],
                    
                    // Сама цитата
                    _buildQuoteParagraph(),
                    
                    // Контекст после цитаты
                    if (_context!.afterContext.isNotEmpty) ...[
                      const SizedBox(height: 24),
                      ..._context!.afterContext.map((paragraph) => 
                        _buildParagraph(paragraph, isContext: true)),
                    ],
                    
                    const SizedBox(height: 48),
                  ],
                ),
              ),
            ),
          ),
          
          // Подсказка о свайпе вниз
          if (_showSwipeHint)
            Positioned(
              top: 16,
              left: 0,
              right: 0,
              child: AnimatedOpacity(
                opacity: _showSwipeHint ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 300),
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 24),
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.8),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white24),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.swipe_down,
                        color: Colors.white70,
                        size: 16,
                      ),
                      SizedBox(width: 8),
                      Text(
                        'Свайп вниз для возврата',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // Подсказка о тапе для полного текста
          if (_showTapHint)
            Positioned(
              bottom: 16,
              left: 0,
              right: 0,
              child: AnimatedOpacity(
                opacity: _showTapHint ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 300),
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 24),
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.8),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white24),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.touch_app,
                        color: Colors.white70,
                        size: 16,
                      ),
                      SizedBox(width: 8),
                      Text(
                        'Нажмите для чтения полного текста',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildParagraph(String text, {bool isContext = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 16,
          height: 1.6,
          color: isContext 
              ? Colors.white.withOpacity(0.8)
              : Colors.white,
        ),
        textAlign: TextAlign.justify,
      ),
    );
  }

  Widget _buildQuoteParagraph() {
    final paragraph = _context!.quoteParagraph;
    final quoteText = widget.dailyQuote.quote.text;
    
    // Находим позицию цитаты в абзаце (более надежный поиск)
    final quoteLower = quoteText.toLowerCase().replaceAll(RegExp(r'[^\w\s]'), '');
    final paragraphLower = paragraph.toLowerCase().replaceAll(RegExp(r'[^\w\s]'), '');
    
    int quoteIndex = paragraphLower.indexOf(quoteLower);
    
    if (quoteIndex == -1) {
      // Если точное совпадение не найдено, ищем по первым словам
      final quoteWords = quoteLower.split(' ').take(5).join(' ');
      quoteIndex = paragraphLower.indexOf(quoteWords);
    }
    
    if (quoteIndex == -1) {
      // Fallback: выделяем весь абзац
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border(
            left: BorderSide(
              color: Colors.white,
              width: 3,
            ),
          ),
        ),
        child: Text(
          paragraph,
          style: const TextStyle(
            fontSize: 16,
            height: 1.6,
            color: Colors.white,
            fontWeight: FontWeight.w500,
          ),
          textAlign: TextAlign.justify,
        ),
      );
    }
    
    // Выделяем цитату в контексте
    final beforeQuote = paragraph.substring(0, quoteIndex);
    final afterQuoteStart = quoteIndex + quoteText.length;
    final afterQuote = afterQuoteStart < paragraph.length 
        ? paragraph.substring(afterQuoteStart)
        : '';
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border(
          left: BorderSide(
            color: Colors.white,
            width: 3,
          ),
        ),
      ),
      child: RichText(
        text: TextSpan(
          style: const TextStyle(
            fontSize: 16,
            height: 1.6,
            color: Colors.white,
          ),
          children: [
            if (beforeQuote.isNotEmpty)
              TextSpan(text: beforeQuote),
            TextSpan(
              text: quoteText,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: Colors.white,
                backgroundColor: Colors.orange.withOpacity(0.3),
              ),
            ),
            if (afterQuote.isNotEmpty)
              TextSpan(text: afterQuote),
          ],
        ),
        textAlign: TextAlign.justify,
      ),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    _candlePlayer.dispose(); // Не забываем освободить ресурсы
    super.dispose();
  }
}