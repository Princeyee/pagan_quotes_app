// lib/ui/screens/context_page.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart'; // ← Добавлен импорт
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
  
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  
  QuoteContext? _context;
  bool _isLoading = true;
  String? _error;
  bool _showSwipeHint = true;

  @override
  void initState() {
    super.initState();
    _initializeAnimation();
    _loadContext();
    _checkSwipeHint();
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
  }

  Future<void> _checkSwipeHint() async {
    final prefs = await SharedPreferences.getInstance();
    final shown = prefs.getBool('context_swipe_hint_shown') ?? false;
    if (!shown) {
      setState(() => _showSwipeHint = true);
      await prefs.setBool('context_swipe_hint_shown', true);
      
      // Скрыть подсказку через 3 секунды
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) {
          setState(() => _showSwipeHint = false);
        }
      });
    } else {
      setState(() => _showSwipeHint = false);
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

      // Загружаем контекст - ИСПРАВЛЕНО: используем правильный метод
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
          _error = 'Не удалось загрузить контекст';
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

  void _navigateToFullText() {
    if (_context == null) return;
    
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => 
            FullTextPage(context: _context!), // ← Передаем контекст
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(widget.dailyQuote.quote.source),
        centerTitle: true,
      ),
      body: SafeArea(
        child: _isLoading
            ? _buildLoadingState()
            : _error != null
                ? _buildErrorState()
                : _buildContextContent(),
      ),
    );
  }

  Widget _buildLoadingState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text(
            'Загружаем контекст...',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w300,
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
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _loadContext,
              child: const Text('Попробовать снова'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContextContent() {
    return GestureDetector(
      onVerticalDragEnd: (details) {
        // Свайп вверх для перехода к полному тексту
        if (details.primaryVelocity != null && details.primaryVelocity! < -500) {
          _navigateToFullText();
        }
        // Свайп вниз для возврата
        if (details.primaryVelocity != null && details.primaryVelocity! > 500) {
          Navigator.of(context).pop();
        }
      },
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: Stack(
          children: [
            // Основной контент
            SingleChildScrollView(
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
                  
                  // Кнопка для перехода к полному тексту
                  _buildFullTextButton(),
                  
                  const SizedBox(height: 24),
                ],
              ),
            ),
            
            // Подсказка о свайпе
            if (_showSwipeHint)
              Positioned(
                bottom: 24,
                left: 0,
                right: 0,
                child: AnimatedOpacity(
                  opacity: _showSwipeHint ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 300),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.swipe_up,
                        color: Theme.of(context).textTheme.bodySmall?.color,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Свайп вверх для полного текста',
                        style: TextStyle(
                          color: Theme.of(context).textTheme.bodySmall?.color,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
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
              ? Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.8)
              : Theme.of(context).textTheme.bodyMedium?.color,
        ),
        textAlign: TextAlign.justify,
      ),
    );
  }

  Widget _buildQuoteParagraph() {
    final paragraph = _context!.quoteParagraph;
    final quoteText = widget.dailyQuote.quote.text;
    
    // Подсвечиваем саму цитату в абзаце
    final beforeQuote = paragraph.substring(0, paragraph.indexOf(quoteText));
    final afterQuote = paragraph.substring(
      paragraph.indexOf(quoteText) + quoteText.length,
    );
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border(
          left: BorderSide(
            color: Theme.of(context).colorScheme.primary,
            width: 3,
          ),
        ),
      ),
      child: RichText(
        text: TextSpan(
          style: TextStyle(
            fontSize: 16,
            height: 1.6,
            color: Theme.of(context).textTheme.bodyMedium?.color,
          ),
          children: [
            if (beforeQuote.isNotEmpty)
              TextSpan(text: beforeQuote),
            TextSpan(
              text: quoteText,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
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

  Widget _buildFullTextButton() {
    return OutlinedButton.icon(
      onPressed: _navigateToFullText,
      icon: const Icon(Icons.menu_book),
      label: const Text('Читать весь текст'),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      ),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }
}
