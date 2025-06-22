// lib/ui/screens/context_page.dart
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/daily_quote.dart';
import '../../models/quote_context.dart';
import '../../services/quote_extraction_service.dart';
import '../../services/sound_manager.dart';
import '../../utils/custom_cache.dart';
// import 'full_text_page.dart';
import 'full_text_page_2.dart';

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
  final SoundManager _soundManager = SoundManager();
  
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
    if (!_soundManager.isMuted) {
      _startCandleSound();
    }
    _loadContext();
    _checkHints();
  }

  Future<void> _startCandleSound() async {
    if (_soundManager.isMuted) return;
    
    await _soundManager.playSound(
      'candle_sound',
      'assets/sounds/candle.mp3',
      loop: true,
    );
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
    
    final swipeHintShown = prefs.getBool('context_swipe_hint_shown') ?? false;
    if (!swipeHintShown) {
      setState(() => _showSwipeHint = true);
      await prefs.setBool('context_swipe_hint_shown', true);
      
      Future.delayed(const Duration(seconds: 4), () {
        if (mounted) {
          setState(() => _showSwipeHint = false);
        }
      });
    } else {
      setState(() => _showSwipeHint = false);
    }

    final tapHintShown = prefs.getBool('fulltext_tap_hint_shown') ?? false;
    if (!tapHintShown) {
      setState(() => _showTapHint = true);
      await prefs.setBool('fulltext_tap_hint_shown', true);
      
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
      // Очищаем старый кэш контекста для этой цитаты перед загрузкой нового
      await _cache.clearQuoteContext(widget.dailyQuote.quote.id);
      
      // ВСЕГДА загружаем свежий контекст, не полагаясь на кэш
      // Это гарантирует, что контекст соответствует текущей цитате
      final context = await _quoteService.getQuoteContext(widget.dailyQuote.quote);
      if (context != null) {
        // ДОПОЛНИТЕЛЬНАЯ ПРОВЕРКА: убеждаемся, что контекст действительно содержит цитату
        final quoteText = widget.dailyQuote.quote.text.toLowerCase();
        final contextText = context.contextText.toLowerCase();
        
        // Проверяем, содержится ли цитата в контексте
        if (!contextText.contains(quoteText.substring(0, min(50, quoteText.length)))) {
          print('⚠️ Контекст не содержит цитату! Очищаем кеш и пробуем снова...');
          await _cache.clearAllQuoteContexts();
          
          // Пробуем загрузить контекст еще раз
          final retryContext = await _quoteService.getQuoteContext(widget.dailyQuote.quote);
          if (retryContext != null) {
            await _cache.cacheQuoteContext(retryContext);
            setState(() {
              _context = retryContext;
              _isLoading = false;
            });
            _animationController.forward();
          } else {
            setState(() {
              _error = 'Контекст не найден. Возможно, текст был изменен или поврежден.';
              _isLoading = false;
            });
          }
        } else {
          // ДОПОЛНИТЕЛЬНАЯ ПРОВЕРКА: убеждаемся, что контекст соответствует правильному источнику
          final expectedSource = widget.dailyQuote.quote.source.toLowerCase();
          final contextSource = context.quote.source.toLowerCase();
          
          if (expectedSource != contextSource) {
            print('⚠️ Контекст из неправильного источника! Ожидалось: $expectedSource, получено: $contextSource');
            await _cache.clearAllQuoteContexts();
            
            // Пробуем загрузить контекст еще раз
            final retryContext = await _quoteService.getQuoteContext(widget.dailyQuote.quote);
            if (retryContext != null) {
              await _cache.cacheQuoteContext(retryContext);
              setState(() {
                _context = retryContext;
                _isLoading = false;
              });
              _animationController.forward();
            } else {
              setState(() {
                _error = 'Контекст не найден. Возможно, текст был изменен или поврежден.';
                _isLoading = false;
              });
            }
          } else {
            // ДОПОЛНИТЕЛЬНАЯ ПРОВЕРКА ДЛЯ АВТОРОВ С НЕСКОЛЬКИМИ КНИГАМИ
            final multiBookAuthors = [
              'аристотель', 'ницше', 'платон', 'хайдеггер', 'шопенгауэр', 
              'эвола', 'элиаде', 'askr svarte', 'де бенуа'
            ];
            
            if (multiBookAuthors.contains(widget.dailyQuote.quote.author.toLowerCase())) {
              print('🔍 Проверяем контекст для автора с несколькими книгами: ${widget.dailyQuote.quote.author}');
              
              // Проверяем, что контекст действительно содержит цитату из правильной книги
              final quoteText = widget.dailyQuote.quote.text.toLowerCase();
              final contextText = context.contextText.toLowerCase();
              
              // Ищем первые 30 символов цитаты в контексте
              final quoteStart = quoteText.substring(0, min(30, quoteText.length));
              if (!contextText.contains(quoteStart)) {
                print('⚠️ Контекст не содержит цитату! Очищаем кеш и пробуем снова...');
                await _cache.clearAllQuoteContexts();
                
                final retryContext = await _quoteService.getQuoteContext(widget.dailyQuote.quote);
                if (retryContext != null) {
                  await _cache.cacheQuoteContext(retryContext);
                  setState(() {
                    _context = retryContext;
                    _isLoading = false;
                  });
                  _animationController.forward();
                } else {
                  setState(() {
                    _error = 'Контекст не найден. Возможно, текст был изменен или поврежден.';
                    _isLoading = false;
                  });
                }
              } else {
                // Кэшируем новый контекст
                await _cache.cacheQuoteContext(context);
                setState(() {
                  _context = context;
                  _isLoading = false;
                });
                _animationController.forward();
              }
            } else {
              // Кэшируем новый контекст
              await _cache.cacheQuoteContext(context);
              setState(() {
                _context = context;
                _isLoading = false;
              });
              _animationController.forward();
            }
          }
        }
      } else {
        setState(() {
          _error = 'Контекст не найден. Возможно, текст был изменен или поврежден.';
          _isLoading = false;
        });
      }

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
    _soundManager.stopSound('candle_sound');
    Navigator.of(context).pop();
  }

  void _navigateToFullText() async {
    if (_context == null) return;
    await _soundManager.stopSound('candle_sound');
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => 
            FullTextPage2(
              context: _context!,
            ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 1),
              end: Offset.zero,
            ).animate(CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
            )),
            child: FadeTransition(
              opacity: animation,
              child: child,
            ),
          );
        },
        transitionDuration: const Duration(milliseconds: 300),
      ),
    ).then((_) {
      _startCandleSound();
    });
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
            Container(
              decoration: const BoxDecoration(
                image: DecorationImage(
                  image: AssetImage('assets/images/book_background.jpg'),
                  fit: BoxFit.cover,
                ),
              ),
            ),
            
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.black.withAlpha((0.7 * 255).round()),
                    Colors.black.withAlpha((0.8 * 255).round()),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
            
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
        if (details.primaryVelocity != null && details.primaryVelocity! > 500) {
          _goBack();
        }
      },
      onTap: () {
        _navigateToFullText();
      },
      child: Stack(
        children: [
          FadeTransition(
            opacity: _fadeAnimation,
            child: SlideTransition(
              position: _slideAnimation,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  children: [
                    if (_context!.beforeContext.isNotEmpty) ...[
                      ..._context!.beforeContext.map((paragraph) => 
                        _buildParagraph(paragraph, isContext: true)),
                      const SizedBox(height: 24),
                    ],
                    
                    _buildQuoteParagraph(),
                    
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
                    color: Colors.black.withAlpha((0.8 * 255).round()),
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
                    color: Colors.black.withAlpha((0.8 * 255).round()),
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
              ? Colors.white.withAlpha((0.8 * 255).round())
              : Colors.white,
        ),
        textAlign: TextAlign.justify,
      ),
    );
  }

  Widget _buildQuoteParagraph() {
    final paragraph = _context!.quoteParagraph;
    final quoteText = widget.dailyQuote.quote.text;
    
    final quoteLower = quoteText.toLowerCase().replaceAll(RegExp(r'[^\w\s]'), '');
    final paragraphLower = paragraph.toLowerCase().replaceAll(RegExp(r'[^\w\s]'), '');
    
    int quoteIndex = paragraphLower.indexOf(quoteLower);
    
    if (quoteIndex == -1) {
      final quoteWords = quoteLower.split(' ').take(5).join(' ');
      quoteIndex = paragraphLower.indexOf(quoteWords);
    }
    
    if (quoteIndex == -1) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withAlpha((0.1 * 255).round()),
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
    
    final beforeQuote = paragraph.substring(0, quoteIndex);
    final afterQuoteStart = quoteIndex + quoteText.length;
    final afterQuote = afterQuoteStart < paragraph.length 
        ? paragraph.substring(afterQuoteStart)
        : '';
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha((0.1 * 255).round()),
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
    _soundManager.stopSound('candle_sound');
    super.dispose();
  }
}