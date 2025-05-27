
// lib/ui/screens/quote_page.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/daily_quote.dart';
import '../../models/quote.dart';
import '../../models/quote_context.dart';
import '../../services/quote_extraction_service.dart';
import '../../services/text_file_service.dart';
import '../../utils/custom_cache.dart';
import '../widgets/nav_drawer.dart';
import 'context_page.dart';

class QuotePage extends StatefulWidget {
  const QuotePage({super.key});

  @override
  State<QuotePage> createState() => _QuotePageState();
}

class _QuotePageState extends State<QuotePage> with TickerProviderStateMixin {
  final PageController _pageController = PageController();
  final QuoteExtractionService _quoteService = QuoteExtractionService();
  final CustomCachePrefs _cache = CustomCache.prefs;

  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  DailyQuote? _currentDailyQuote;
  bool _isLoading = true;
  bool _isFavorite = false;
  String? _error;

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
        setState(() {
          _currentDailyQuote = cached;
          _isFavorite = _cache.isFavorite(cached.quote.id);
          _isLoading = false;
        });
        _startAnimations();
        return;
      }

      // Генерируем новую цитату
      final dailyQuote = await _quoteService.generateDailyQuote();
      if (dailyQuote != null) {
        await _cache.cacheDailyQuote(dailyQuote);
        setState(() {
          _currentDailyQuote = dailyQuote;
          _isFavorite = _cache.isFavorite(dailyQuote.quote.id);
          _isLoading = false;
        });
        _startAnimations();
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

    if (_isFavorite) {
      await _cache.removeFromFavorites(quote.id);
    } else {
      await _cache.addToFavorites(quote);
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

  Future<void> _refreshQuote() async {
    // Генерируем новую случайную цитату (не привязанную к дате)
    try {
      setState(() => _isLoading = true);
      
      final sources = await TextFileService().loadBookSources();
      if (sources.isNotEmpty) {
        final randomSource = sources[DateTime.now().millisecondsSinceEpoch % sources.length];
        final quote = await _quoteService.extractRandomQuote(randomSource);
        
        if (quote != null) {
          final newDailyQuote = DailyQuote(
            quote: quote,
            date: DateTime.now(),
          );
          
          setState(() {
            _currentDailyQuote = newDailyQuote;
            _isFavorite = _cache.isFavorite(quote.id);
            _isLoading = false;
          });
          
          // Restart animations
          _fadeController.reset();
          _slideController.reset();
          _startAnimations();
        }
      }
    } catch (e) {
      setState(() {
        _error = 'Ошибка обновления: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
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
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text(
            'Загружаем мудрость...',
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
      child: Container(
        width: double.infinity,
        height: double.infinity,
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            // Header с датой и действиями
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
                      
                      // Кнопка для перехода к контексту
                      _buildContextButton(),
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
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Меню
        Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu),
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
                color: Theme.of(context).textTheme.bodySmall?.color,
                fontWeight: FontWeight.w300,
              ),
            ),
            Text(
              _currentDailyQuote!.formattedDate,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        
        // Действия
        Row(
          children: [
            IconButton(
              onPressed: _refreshQuote,
              icon: const Icon(Icons.refresh),
              tooltip: 'Новая цитата',
            ),
            IconButton(
              onPressed: _toggleFavorite,
              icon: Icon(
                _isFavorite ? Icons.favorite : Icons.favorite_border,
                color: _isFavorite ? Colors.red : null,
              ),
              tooltip: 'В избранное',
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildQuoteText(Quote quote) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      decoration: BoxDecoration(
        border: Border(
          left: BorderSide(
            color: Theme.of(context).colorScheme.primary,
            width: 3,
          ),
        ),
      ),
      child: Text(
        '"${quote.text}"',
        style: const TextStyle(
          fontSize: 24,
          height: 1.5,
          fontWeight: FontWeight.w300,
          fontStyle: FontStyle.italic,
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
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          quote.source,
          style: TextStyle(
            fontSize: 16,
            color: Theme.of(context).textTheme.bodySmall?.color,
            fontStyle: FontStyle.italic,
          ),
        ),
      ],
    );
  }

  Widget _buildContextButton() {
    return OutlinedButton.icon(
      onPressed: _navigateToContext,
      icon: const Icon(Icons.auto_stories),
      label: const Text('Читать в контексте'),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      ),
    );
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    _pageController.dispose();
    super.dispose();
  }
}
