

// lib/ui/screens/context_page.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
    with TickerProviderStateMixin {
  final QuoteExtractionService _quoteService = QuoteExtractionService();
  final CustomCache _cache = CustomCache();

  late AnimationController _fadeController;
  late AnimationController _highlightController;
  late Animation<double> _fadeAnimation;
  late Animation<Color?> _highlightAnimation;

  QuoteContext? _context;
  bool _isLoading = true;
  String? _error;
  bool _isFavorite = false;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _loadContext();
    _checkFavoriteStatus();
  }

  void _initializeAnimations() {
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _highlightController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    ));

    _highlightAnimation = ColorTween(
      begin: Colors.transparent,
      end: Theme.of(context).primaryColor.withOpacity(0.1),
    ).animate(CurvedAnimation(
      parent: _highlightController,
      curve: Curves.easeInOut,
    ));
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
        _startAnimations();
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
        _startAnimations();
      } else {
        setState(() {
          _error = 'Не удалось загрузить контекст';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Ошибка загрузки контекста: $e';
        _isLoading = false;
      });
    }
  }

  void _checkFavoriteStatus() {
    _isFavorite = _cache.isFavorite(widget.dailyQuote.quote.id);
  }

  void _startAnimations() {
    _fadeController.forward();
    
    // Запускаем подсветку цитаты через секунду
    Future.delayed(const Duration(milliseconds: 1000), () {
      if (mounted) {
        _highlightController.forward().then((_) {
          _highlightController.reverse();
        });
      }
    });
  }

  Future<void> _toggleFavorite() async {
    HapticFeedback.lightImpact();

    if (_isFavorite) {
      await _cache.removeFromFavorites(widget.dailyQuote.quote.id);
    } else {
      await _cache.addToFavorites(widget.dailyQuote.quote);
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
  }

  void _navigateToFullText() async {
    if (_context == null) return;

    // Отмечаем контекст как просмотренный
    await _cache.markDailyQuoteAsViewed(
      widget.dailyQuote.date,
      contextViewed: true,
    );

    if (mounted) {
      Navigator.of(context).push(
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) => 
              FullTextPage(context: _context!),
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

  void _goBack() {
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
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
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TextButton(
                  onPressed: _goBack,
                  child: const Text('Назад'),
                ),
                const SizedBox(width: 16),
                ElevatedButton(
                  onPressed: _loadContext,
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
        if (details.primaryVelocity != null) {
          // Свайп вверх для перехода к полному тексту
          if (details.primaryVelocity! < -500) {
            _navigateToFullText();
          }
          // Свайп вниз для возврата
          else if (details.primaryVelocity! > 500) {
            _goBack();
          }
        }
      },
      child: Container(
        width: double.infinity,
        height: double.infinity,
        child: Column(
          children: [
            // Header
            _buildHeader(),
            
            // Контент с контекстом
            Expanded(
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Заголовок секции
                      _buildSectionTitle(),
                      
                      const SizedBox(height: 24),
                      
                      // Контекст с выделенной цитатой
                      _buildContextText(),
                      
                      const SizedBox(height: 32),
                      
                      // Информация об источнике
                      _buildSourceInfo(),
                      
                      const SizedBox(height: 32),
                      
                      // Кнопка для перехода к полному тексту
                      _buildFullTextButton(),
                      
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        children: [
          IconButton(
            onPressed: _goBack,
            icon: const Icon(Icons.arrow_back),
            tooltip: 'Назад',
          ),
          const Expanded(
            child: Text(
              'Контекст',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          IconButton(
            onPressed: _toggleFavorite,
            icon: Icon(
              _isFavorite ? Icons.favorite : Icons.favorite_border,
              color: _isFavorite ? Colors.red : null,
            ),
            tooltip: _isFavorite ? 'Удалить из избранного' : 'Добавить в избранное',
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Расширенный контекст',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Theme.of(context).primaryColor,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Цитата в контексте оригинального произведения',
          style: TextStyle(
            fontSize: 14,
            color: Theme.of(context).textTheme.bodySmall?.color,
            fontWeight: FontWeight.w300,
          ),
        ),
      ],
    );
  }

  Widget _buildContextText() {
    if (_context == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(20.0),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: Theme.of(context).cardColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Контекст до цитаты
          if (_context!.beforeContext.isNotEmpty) ...[
            ...(_context!.beforeContext.map((paragraph) => 
              _buildContextParagraph(paragraph, false))),
            const SizedBox(height: 16),
          ],
          
          // Сама цитата (выделенная)
          AnimatedBuilder(
            animation: _highlightAnimation,
            builder: (context, child) {
              return Container(
                padding: const EdgeInsets.all(16.0),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: _highlightAnimation.value,
                  border: Border.all(
                    color: Theme.of(context).primaryColor.withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: _buildContextParagraph(_context!.quoteParentalph, true),
              );
            },
          ),
          
          // Контекст после цитаты
          if (_context!.afterContext.isNotEmpty) ...[
            const SizedBox(height: 16),
            ...(_context!.afterContext.map((paragraph) => 
              _buildContextParagraph(paragraph, false))),
          ],
        ],
      ),
    );
  }

  Widget _buildContextParagraph(String text, bool isQuoteParagraph) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: RichText(
        text: TextSpan(
          style: TextStyle(
            fontSize: 16,
            height: 1.6,
            color: Theme.of(context).textTheme.bodyLarge?.color,
            fontWeight: isQuoteParagraph ? FontWeight.w500 : FontWeight.w400,
          ),
          children: isQuoteParagraph 
              ? _highlightQuoteInText(text)
              : [TextSpan(text: text)],
        ),
      ),
    );
  }

  List<TextSpan> _highlightQuoteInText(String text) {
    final quoteText = widget.dailyQuote.quote.text.toLowerCase();
    final textLower = text.toLowerCase();
    
    final index = textLower.indexOf(quoteText);
    if (index == -1) {
      return [TextSpan(text: text)];
    }

    final spans = <TextSpan>[];
    
    // Текст до цитаты
    if (index > 0) {
      spans.add(TextSpan(text: text.substring(0, index)));
    }
    
    // Сама цитата (выделенная)
    spans.add(TextSpan(
      text: text.substring(index, index + quoteText.length),
      style: TextStyle(
        backgroundColor: Theme.of(context).primaryColor.withOpacity(0.2),
        fontWeight: FontWeight.w600,
      ),
    ));
    
    // Текст после цитаты
    if (index + quoteText.length < text.length) {
      spans.add(TextSpan(text: text.substring(index + quoteText.length)));
    }
    
    return spans;
  }

  Widget _buildSourceInfo() {
    final quote = widget.dailyQuote.quote;
    
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: Theme.of(context).cardColor.withOpacity(0.5),
        border: Border.all(
          color: Theme.of(context).dividerColor,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Источник',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).primaryColor,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            quote.author,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            quote.source,
            style: TextStyle(
              fontSize: 14,
              fontStyle: FontStyle.italic,
              color: Theme.of(context).textTheme.bodySmall?.color,
            ),
          ),
          if (quote.translation != null) ...[
            const SizedBox(height: 4),
            Text(
              'Перевод: ${quote.translation}',
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).textTheme.bodySmall?.color,
              ),
            ),
          ],
          const SizedBox(height: 8),
          Text(
            'Позиция: ${quote.position}',
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).textTheme.bodySmall?.color,
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFullTextButton() {
    return SizedBox(
      width: double.infinity,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Theme.of(context).primaryColor.withOpacity(0.3),
            width: 1,
          ),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: _navigateToFullText,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 24,
                vertical: 16,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.menu_book,
                    size: 20,
                    color: Theme.of(context).primaryColor,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Читать полный текст',
                    style: TextStyle(
                      fontSize: 16,
                      color: Theme.of(context).primaryColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    Icons.arrow_upward,
                    size: 16,
                    color: Theme.of(context).primaryColor,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _highlightController.dispose();
    super.dispose();
  }
}
