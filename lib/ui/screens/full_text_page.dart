
// lib/ui/screens/full_text_page.dart
import 'dart:math';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:share_plus/share_plus.dart';
import '../../models/quote.dart';
import '../../models/quote_context.dart';
import '../../models/book_source.dart';
import '../../models/reading_theme.dart';
import '../../services/text_file_service.dart';
import 'package:flutter/services.dart';
import '../../services/favorites_service.dart';
import '../../services/image_picker_service.dart';
import '../screens/context_page.dart';

class PreloadedFullTextData {
  final String fullText;
  final BookSource bookSource;
  
  PreloadedFullTextData({
    required this.fullText,
    required this.bookSource,
  });
}

class FullTextPage extends StatefulWidget {
  final QuoteContext context;
  final PreloadedFullTextData? preloadedData;

  const FullTextPage({
    super.key,
    required this.context,
    this.preloadedData,
  });

  @override
  State<FullTextPage> createState() => _FullTextPageState();
}

class _FullTextPageState extends State<FullTextPage> 
    with TickerProviderStateMixin {
  final TextFileService _textService = TextFileService();
  final ScrollController _scrollController = ScrollController();

  late AnimationController _fadeController;
  late AnimationController _themeController;
  late AnimationController _settingsController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _themeAnimation;

  String? _fullText;
  BookSource? _bookSource;
  bool _isLoading = true;
  String? _error;
  bool _autoScrolled = false;
  double _fontSize = 17.0;
  double _lineHeight = 1.5;
  bool _showSettings = false;
  ReadingTheme _currentTheme = ReadingTheme.dark;

  Color? _customTextColor;
  Color? _customBackgroundColor;
  bool _useCustomColors = false;

  double _initialScrollPosition = 0.0;
  
  // Кэш для нормализованных текстов
  String? _normalizedQuoteCache;
  final Map<String, String> _normalizedTextCache = {};
  
  // Для выделения текста
  bool _isSelectionMode = false;
  String? _selectedText;

  // Диагностика и оптимизация скролла
  bool _isScrolling = false;
  bool _listViewReady = false;
  int? _targetItemIndex;
  Timer? _scrollRetryTimer;

  // Кэши для оптимизации
  List<RegExpMatch>? _positionMatches;
  Map<int, bool> _contextBlockCache = {};

  Color get _effectiveTextColor => _useCustomColors && _customTextColor != null 
      ? _customTextColor! 
      : _currentTheme.textColor;
      
  Color get _effectiveBackgroundColor => _useCustomColors && _customBackgroundColor != null 
      ? _customBackgroundColor! 
      : _currentTheme.backgroundColor;

  Color get _uiTextColor => _currentTheme.textColor;

  // Добавляем переменные для throttling
  double _lastProgress = 0.0;
  
  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _loadTheme();
    _loadFullText();
    // Инициализируем кэш нормализованной цитаты
    _normalizedQuoteCache = _normalizeText(widget.context.quote.text);
    
    // Слушаем скролл для обновления прогресса с throttling
    _scrollController.addListener(() {
      if (mounted) {
        final currentProgress = _getReadingProgress();
        // Обновляем UI только если прогресс изменился на 1% или больше
        if ((currentProgress - _lastProgress).abs() >= 0.01) {
          setState(() {
            _lastProgress = currentProgress;
          });
        }
      }
    });
  }

  void _initializeAnimations() {
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _themeController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );

    _settingsController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    ));

    _themeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _themeController,
      curve: Curves.easeInOutCubic,
    ));
  }

  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final themeType = ReadingTheme.fromString(
      prefs.getString('reading_theme') ?? 'dark'
    );
    
    final useCustom = prefs.getBool('use_custom_colors') ?? false;
    final textColorValue = prefs.getInt('custom_text_color');
    final bgColorValue = prefs.getInt('custom_background_color');
    final fontSize = prefs.getDouble('font_size') ?? 17.0;
    final lineHeight = prefs.getDouble('line_height') ?? 1.5;
    
    setState(() {
      _currentTheme = ReadingTheme.fromType(themeType);
      _useCustomColors = useCustom;
      _customTextColor = textColorValue != null ? Color(textColorValue) : null;
      _customBackgroundColor = bgColorValue != null ? Color(bgColorValue) : null;
      _fontSize = fontSize;
      _lineHeight = lineHeight;
    });
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('reading_theme', _currentTheme.typeString);
    await prefs.setBool('use_custom_colors', _useCustomColors);
    await prefs.setDouble('font_size', _fontSize);
    await prefs.setDouble('line_height', _lineHeight);
    
    if (_customTextColor != null) {
      await prefs.setInt('custom_text_color', _customTextColor!.value);
    }
    if (_customBackgroundColor != null) {
      await prefs.setInt('custom_background_color', _customBackgroundColor!.value);
    }
  }

  Future<void> _changeTheme() async {
    await _themeController.forward();
    
    final currentIndex = ReadingTheme.allThemes.indexOf(_currentTheme);
    final nextIndex = (currentIndex + 1) % ReadingTheme.allThemes.length;
    
    setState(() {
      _currentTheme = ReadingTheme.allThemes[nextIndex];
    });
    
    await _saveSettings();
    await _themeController.reverse();
  }

  // Очистка текста от артефактов
  String _cleanTextArtifacts(String text) {
    return text
        .replaceAll('>', '') // убираем только символ >
        .replaceAll('<', '') // убираем только символ <
        .replaceAll(RegExp(r'\s+'), ' ') // нормализуем пробелы
        .trim();
  }

  // Инициализация кэша позиций
  void _initializePositionCache() {
    if (_fullText == null) return;
    
    final regex = RegExp(r'\[pos:(\d+)\]([^\[]+)');
    _positionMatches = regex.allMatches(_fullText!).toList();
    _contextBlockCache.clear();
    
    print('💾 Кэш позиций инициализирован: ${_positionMatches!.length} элементов');
  }

  // Детальная диагностика позиций
  void _debugPositionAnalysis() {
    if (_fullText == null) return;
    
    print('\n🔍 === ДЕТАЛЬНАЯ ДИАГНОСТИКА ПОЗИЦИЙ ===');
    print('Ищем позицию: ${widget.context.startPosition}');
    
    final regex = RegExp(r'\[pos:(\d+)\]');
    final matches = regex.allMatches(_fullText!).toList();
    
    print('Всего найдено позиций: ${matches.length}');
    
    // Показываем позиции вокруг целевой
    final targetPos = widget.context.startPosition;
    
    for (int i = 0; i < matches.length; i++) {
      final posNumber = int.parse(matches[i].group(1)!);
      
      // Показываем позиции в диапазоне ±5 от целевой
      if ((posNumber - targetPos).abs() <= 5) {
        final marker = posNumber == targetPos ? ' <<<< ЦЕЛЬ' : '';
        print('  Индекс $i: позиция $posNumber$marker');
      }
      
      if (posNumber == targetPos) {
        _targetItemIndex = i;
        print('✅ НАЙДЕНО: Позиция $targetPos находится на индексе $i');
      }
    }
    
    if (_targetItemIndex == null) {
      print('❌ ПРОБЛЕМА: Позиция $targetPos НЕ НАЙДЕНА!');
    }
    
    print('=== КОНЕЦ ДИАГНОСТИКИ ===\n');
  }

  Future<void> _loadFullText() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Диагностика QuoteContext
      print('📊 QuoteContext информация:');
      print('   - startPosition: ${widget.context.startPosition}');
      print('   - endPosition: ${widget.context.endPosition}');
      print('   - contextParagraphs: ${widget.context.contextParagraphs.length}');
      
      if (widget.preloadedData != null) {
        setState(() {
          _bookSource = widget.preloadedData!.bookSource;
          _fullText = _cleanTextArtifacts(widget.preloadedData!.fullText);
          _isLoading = false;
        });

        _fadeController.forward();
        
        // Новая система надежной инициализации скролла
        _initializeScrollWithDiagnostics();
        
        return;
      }

      final sources = await _textService.loadBookSources();
      
      final source = sources.firstWhere(
        (s) => s.author == widget.context.quote.author && 
               s.title == widget.context.quote.source,
        orElse: () => throw Exception('Book source not found'),
      );

      final cleanedText = await _textService.loadTextFile(source.cleanedFilePath);
      
      setState(() {
        _bookSource = source;
        _fullText = _cleanTextArtifacts(cleanedText);
        _isLoading = false;
      });

      _fadeController.forward();
      
      // Новая система надежной инициализации скролла
      _initializeScrollWithDiagnostics();
      
    } catch (e) {
      setState(() {
        _error = 'Ошибка загрузки полного текста: $e';
        _isLoading = false;
      });
    }
  }

  // Основной метод для интеграции в _loadFullText
  void _initializeScrollWithDiagnostics() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _initializePositionCache();
        _findQuotePositionFastWithDebug();
        
        // Даем время на построение ListView
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) {
            _scheduleReliableScrollWithDebug();
          }
        });
      }
    });
  }

  void _findQuotePositionFastWithDebug() {
    if (_fullText == null) return;
    
    print('\n🔍 === ПОИСК ПОЗИЦИИ С ДИАГНОСТИКОЙ ===');
    _debugPositionAnalysis();
    print('=== ПОИСК ЗАВЕРШЕН ===\n');
  }

  void _scheduleReliableScrollWithDebug() {
    print('\n📍 === ПЛАНИРОВАНИЕ СКРОЛЛА ===');
    print('Целевой индекс: $_targetItemIndex');
    
    if (_targetItemIndex == null) {
      print('❌ Нет целевого индекса для скролла');
      return;
    }
    
    _showSearchAnimation();
    _waitForListViewWithDebug();
  }

  void _waitForListViewWithDebug() {
    _scrollRetryTimer?.cancel();
    int attemptCount = 0;
    
    void attemptScroll() {
      attemptCount++;
      print('⏳ Попытка $attemptCount: проверяем готовность ListView');
      
      if (!mounted || _targetItemIndex == null) {
        print('❌ Компонент размонтирован или нет целевого индекса');
        return;
      }
      
      if (_scrollController.hasClients && 
          _scrollController.position.maxScrollExtent > 0) {
        
        print('✅ ListView готов после $attemptCount попыток');
        _performPreciseScrollWithDebug();
        
      } else {
        if (attemptCount < 20) {
          _scrollRetryTimer = Timer(const Duration(milliseconds: 100), attemptScroll);
        } else {
          print('❌ ListView не готов, используем аварийный скролл');
          _emergencyScrollToPosition();
        }
      }
    }
    
    Future.delayed(const Duration(milliseconds: 200), attemptScroll);
  }

  void _performPreciseScrollWithDebug() {
    if (!mounted || _targetItemIndex == null || !_scrollController.hasClients) {
      return;
    }
    
    _isScrolling = true;
    
    print('\n🎯 === НАЧАЛО ТОЧНОГО СКРОЛЛА ===');
    
    final totalItems = _getItemCount();
    final targetIndex = _targetItemIndex!;
    
    print('Скроллим к элементу $targetIndex из $totalItems');
    
    // Используем простой и надежный метод расчета
    final progressMethod = targetIndex / totalItems;
    final maxScroll = _scrollController.position.maxScrollExtent;
    final targetOffset = maxScroll * progressMethod;
    
    print('📏 РАСЧЕТ ПОЗИЦИИ:');
    print('   - Прогресс: ${(progressMethod * 100).toStringAsFixed(1)}%');
    print('   - Целевой offset: ${targetOffset.toStringAsFixed(0)}px');
    
    // Добавляем отступ для лучшей видимости
    final screenHeight = MediaQuery.of(context).size.height;
    final adjustedOffset = (targetOffset - screenHeight * 0.2).clamp(0.0, maxScroll);
    
    print('📍 ФИНАЛЬНАЯ ПОЗИЦИЯ: ${adjustedOffset.toStringAsFixed(0)}px');
    
    // Выполняем плавный скролл
    _scrollController.animateTo(
      adjustedOffset,
      duration: const Duration(milliseconds: 800),
      curve: Curves.easeOutCubic,
    ).then((_) {
      print('✅ Скролл завершен');
      _isScrolling = false;
      _autoScrolled = true;
      
    }).catchError((error) {
      print('❌ Ошибка скролла: $error');
      _isScrolling = false;
    });
    
    print('=== СКРОЛЛ ЗАПУЩЕН ===\n');
  }

  void _emergencyScrollToPosition() {
    print('\n🚨 === АВАРИЙНЫЙ СКРОЛЛ ===');
    
    if (_targetItemIndex == null || !_scrollController.hasClients) {
      print('❌ Невозможно выполнить аварийный скролл');
      return;
    }
    
    final maxScroll = _scrollController.position.maxScrollExtent;
    final targetIndex = _targetItemIndex!;
    final totalItems = _getItemCount();
    
    final simpleProgress = targetIndex / totalItems;
    final simpleOffset = maxScroll * simpleProgress;
    
    print('📍 Аварийный скролл к ${simpleOffset.toStringAsFixed(0)}px');
    
    _scrollController.jumpTo(simpleOffset.clamp(0.0, maxScroll));
    _autoScrolled = true;
    
    print('✅ Аварийный скролл выполнен');
  }

  void _showSearchAnimation() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Material(
        color: Colors.transparent,
        child: Center(
          child: Container(
            margin: const EdgeInsets.all(40),
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: _currentTheme.backgroundColor.withOpacity(0.95),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: _currentTheme.borderColor.withOpacity(0.2),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.15),
                  blurRadius: 30,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Поиск цитаты в тексте',
                  style: TextStyle(
                    color: _effectiveTextColor,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    decoration: TextDecoration.none,
                  ),
                ),
                const SizedBox(height: 20),
                Container(
                  height: 60,
                  width: 200,
                  decoration: BoxDecoration(
                    color: _currentTheme.highlightColor.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: _SearchProgressWidget(
                    context: widget.context,
                    theme: _currentTheme,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    Future.delayed(const Duration(milliseconds: 2000), () {
      if (mounted) Navigator.of(context).pop();
    });
  }

  // Метод выделения текста для сохранения как цитаты
  void _handleTextSelection(String selectedText, int position) {
    showModalBottomSheet(
      context: context,
      backgroundColor: _currentTheme.cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Выделенный текст',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: _effectiveTextColor,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _currentTheme.highlightColor.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _currentTheme.borderColor.withOpacity(0.3),
                ),
              ),
              child: Text(
                selectedText.length > 200 
                    ? '${selectedText.substring(0, 200)}...' 
                    : selectedText,
                style: TextStyle(
                  fontSize: 14,
                  color: _effectiveTextColor,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildActionButton(
                  icon: Icons.favorite_border,
                  label: 'В избранное',
                  onTap: () => _saveAsQuote(selectedText, position),
                ),
                _buildActionButton(
                  icon: Icons.share,
                  label: 'Поделиться',
                  onTap: () => _shareSelectedText(selectedText),
                ),
                _buildActionButton(
                  icon: Icons.note_add,
                  label: 'Заметка',
                  onTap: () => _addNoteToSelection(selectedText, position),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: _currentTheme.highlightColor.withOpacity(0.3),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: _effectiveTextColor, size: 24),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: _effectiveTextColor.withOpacity(0.8),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveAsQuote(String text, int position) async {
    // Создаем новую цитату из выделенного текста
    final newQuote = Quote(
      id: 'custom_${DateTime.now().millisecondsSinceEpoch}',
      text: text.trim(),
      author: _bookSource?.author ?? '',
      source: _bookSource?.title ?? '',
      category: _bookSource?.category ?? 'custom',
      position: position,
      theme: _bookSource?.category ?? 'custom',
      dateAdded: DateTime.now(),
    );
    
    try {
      final favService = await FavoritesService.init();
      final imageUrl = ImagePickerService.getRandomImage(newQuote.category);
      
      await favService.addToFavorites(newQuote, imageUrl: imageUrl);
      
      if (mounted) {
        Navigator.of(context).pop();
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Цитата добавлена в избранное'),
            duration: Duration(seconds: 2),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop();
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _shareSelectedText(String text) {
    if (_bookSource != null) {
      Share.share(
        '"$text"\n\n— ${_bookSource!.author}, ${_bookSource!.title}',
        subject: 'Цитата из Sacral',
      );
    }
  }

  void _addNoteToSelection(String text, int position) {
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Функция заметок будет добавлена в следующей версии'),
      ),
    );
  }

  void _adjustFontSize(double delta) {
    setState(() {
      _fontSize = (_fontSize + delta).clamp(12.0, 24.0);
    });
    _saveSettings();
  }

  void _adjustLineHeight(double delta) {
    setState(() {
      _lineHeight = (_lineHeight + delta).clamp(1.2, 2.0);
    });
    _saveSettings();
  }

  void _goBack() {
    Navigator.of(context).pop();
  }

  String _normalizeText(String text) {
    if (_normalizedTextCache.containsKey(text)) {
      return _normalizedTextCache[text]!;
    }
    
    final normalized = text.toLowerCase()
        .replaceAll('«', '"')
        .replaceAll('»', '"')
        .replaceAll('"', '"')
        .replaceAll('"', '"')
        .replaceAll('„', '"')
        .replaceAll("'", '"')
        .replaceAll('`', '"')
        .replaceAll('—', '-')
        .replaceAll('–', '-')
        .replaceAll('−', '-')
        .replaceAll('…', '...')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    
    _normalizedTextCache[text] = normalized;
    return normalized;
  }

  double _getReadingProgress() {
    if (!_scrollController.hasClients) return 0.0;
    final max = _scrollController.position.maxScrollExtent;
    if (max <= 0) return 0.0;
    return (_scrollController.position.pixels / max).clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _themeAnimation,
      builder: (context, child) {
        return Scaffold(
          backgroundColor: Color.lerp(
            _effectiveBackgroundColor,
            _currentTheme.highlightColor,
            _themeAnimation.value * 0.3,
          ),
          body: SafeArea(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 600),
              switchInCurve: Curves.easeInOutCubic,
              switchOutCurve: Curves.easeInOutCubic,
              transitionBuilder: (Widget child, Animation<double> animation) {
                return FadeTransition(
                  opacity: animation,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0.0, 0.1),
                      end: Offset.zero,
                    ).animate(CurvedAnimation(
                      parent: animation,
                      curve: Curves.easeInOutCubic,
                    )),
                    child: child,
                  ),
                );
              },
              child: _isLoading 
                  ? _buildLoadingState()
                  : _error != null 
                      ? _buildErrorState()
                      : _buildFullTextContent(),
            ),
          ),
        );
      },
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: _currentTheme.quoteHighlightColor),
          const SizedBox(height: 16),
          Text(
            'Загружаем полный текст...',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w300,
              color: _currentTheme.textColor,
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
            Icon(Icons.error_outline, size: 64, color: _currentTheme.quoteHighlightColor),
            const SizedBox(height: 16),
            Text(_error!, textAlign: TextAlign.center, style: TextStyle(fontSize: 16, color: _effectiveTextColor)),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TextButton(
                  onPressed: _goBack,
                  child: Text('Назад', style: TextStyle(color: _effectiveTextColor.withOpacity(0.7))),
                ),
                const SizedBox(width: 16),
                ElevatedButton(
                  onPressed: _loadFullText,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _currentTheme.quoteHighlightColor,
                    foregroundColor: Colors.white,
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

  Widget _buildFullTextContent() {
    return Column(
      children: [
        _buildHeader(),
        if (_showSettings) _buildReadingSettings(),
        Expanded(
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: _buildTextContent(),
          ),
        ),
      ],
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: _currentTheme.cardColor,
        border: Border(bottom: BorderSide(color: _currentTheme.borderColor, width: 1)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: _goBack,
            icon: Icon(Icons.arrow_back, color: _effectiveTextColor),
            tooltip: 'Назад',
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _bookSource?.title ?? 'Полный текст',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: _effectiveTextColor),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  _bookSource?.author ?? '',
                  style: TextStyle(fontSize: 14, color: _effectiveTextColor.withOpacity(0.7)),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () {
              setState(() => _showSettings = !_showSettings);
              if (_showSettings) {
                _settingsController.forward();
              } else {
                _settingsController.reverse();
              }
            },
            icon: Icon(_showSettings ? Icons.close : Icons.settings, color: _effectiveTextColor),
            tooltip: 'Настройки чтения',
          ),
        ],
      ),
    );
  }

  Widget _buildReadingSettings() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.all(24.0),
      decoration: BoxDecoration(
        color: _currentTheme.cardColor,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(16),
          bottomRight: Radius.circular(16),
        ),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _currentTheme.highlightColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.tune, size: 20, color: _effectiveTextColor.withOpacity(0.8)),
              ),
              const SizedBox(width: 12),
              Text(
                'Настройки чтения',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: _currentTheme.textColor),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _buildModernSettingCard(
            'Размер текста',
            Icons.format_size,
            Row(
              children: [
                _buildModernButton(Icons.remove, () => _adjustFontSize(-1), _fontSize > 12),
                const SizedBox(width: 16),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: _currentTheme.highlightColor.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _currentTheme.borderColor.withOpacity(0.3)),
                  ),
                  child: Text(
                    '${_fontSize.toInt()}px',
                    style: TextStyle(fontWeight: FontWeight.w600, color: _effectiveTextColor, fontSize: 16),
                  ),
                ),
                const SizedBox(width: 16),
                _buildModernButton(Icons.add, () => _adjustFontSize(1), _fontSize < 24),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _buildModernSettingCard(
            'Межстрочный интервал',
            Icons.format_line_spacing,
            Row(
              children: [
                _buildModernButton(Icons.compress, () => _adjustLineHeight(-0.1), _lineHeight > 1.2),
                const SizedBox(width: 16),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: _currentTheme.highlightColor.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _currentTheme.borderColor.withOpacity(0.3)),
                  ),
                  child: Text(
                    '${_lineHeight.toStringAsFixed(1)}x',
                    style: TextStyle(fontWeight: FontWeight.w600, color: _effectiveTextColor, fontSize: 16),
                  ),
                ),
                const SizedBox(width: 16),
                _buildModernButton(Icons.expand, () => _adjustLineHeight(0.1), _lineHeight < 2.0),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _buildModernSettingCard(
            'Готовые темы',
            Icons.palette_outlined,
            SizedBox(
              height: 120,
              child: SingleChildScrollView(
                child: Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: ReadingTheme.allThemes.map((theme) {
                    final isSelected = theme.type == _currentTheme.type && !_useCustomColors;
                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          _currentTheme = theme;
                          _useCustomColors = false;
                        });
                        _saveSettings();
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          color: theme.backgroundColor,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isSelected 
                                ? theme.quoteHighlightColor 
                                : theme.borderColor.withOpacity(0.3),
                            width: isSelected ? 3 : 1,
                          ),
                          boxShadow: isSelected ? [
                            BoxShadow(
                              color: theme.quoteHighlightColor.withOpacity(0.3),
                              blurRadius: 12,
                              spreadRadius: 2,
                            ),
                          ] : [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 4,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                        child: Center(
                          child: Text(
                            theme.letter,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: theme.textColor,
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          _buildModernSettingCard(
            'Кастомные цвета',
            Icons.color_lens,
            Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Цвет текста',
                            style: TextStyle(
                              fontSize: 12,
                              color: _currentTheme.textColor.withOpacity(0.6),
                            ),
                          ),
                          const SizedBox(height: 8),
                          _buildColorPicker(
                            _customTextColor ?? _currentTheme.textColor,
                            (color) {
                              setState(() {
                                _customTextColor = color;
                                _useCustomColors = true;
                              });
                              _saveSettings();
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Цвет фона',
                            style: TextStyle(
                              fontSize: 12,
                              color: _currentTheme.textColor.withOpacity(0.6),
                            ),
                          ),
                          const SizedBox(height: 8),
                          _buildColorPicker(
                            _customBackgroundColor ?? _currentTheme.backgroundColor,
                            (color) {
                              setState(() {
                                _customBackgroundColor = color;
                                _useCustomColors = true;
                              });
                              _saveSettings();
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModernSettingCard(String title, IconData icon, Widget content) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _currentTheme.highlightColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _currentTheme.borderColor.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: _uiTextColor.withOpacity(0.7)),
              const SizedBox(width: 8),
              Text(title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: _uiTextColor.withOpacity(0.8))),
            ],
          ),
          const SizedBox(height: 12),
          content,
        ],
      ),
    );
  }

  Widget _buildModernButton(IconData icon, VoidCallback onTap, bool enabled) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: enabled 
              ? _currentTheme.highlightColor.withOpacity(0.8)
              : _currentTheme.highlightColor.withOpacity(0.3),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _currentTheme.borderColor.withOpacity(0.3)),
          boxShadow: enabled ? [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 4, offset: const Offset(0, 2))] : null,
        ),
        child: Icon(icon, size: 18, color: enabled ? _uiTextColor : _uiTextColor.withOpacity(0.4)),
      ),
    );
  }

  Widget _buildColorPicker(Color currentColor, Function(Color) onColorChanged) {
    final colors = [
      Colors.black,
      Colors.white,
      Colors.grey[800]!,
      Colors.grey[200]!,
      Colors.brown[800]!,
      Colors.brown[100]!,
      Colors.blue[900]!,
      Colors.blue[50]!,
      Colors.green[900]!,
      Colors.green[50]!,
    ];

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: colors.map((color) {
        final isSelected = currentColor.value == color.value;
        return GestureDetector(
          onTap: () => onColorChanged(color),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(
                color: isSelected 
                    ? _currentTheme.quoteHighlightColor 
                    : Colors.grey.withOpacity(0.3),
                width: isSelected ? 3 : 1,
              ),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 4, offset: const Offset(0, 2))],
            ),
            child: isSelected
                ? Icon(
                    Icons.check,
                    size: 16,
                    color: color.computeLuminance() > 0.5 ? Colors.black : Colors.white,
                  )
                : null,
          ),
        );
      }).toList(),
    );
  }

  Widget _buildTextContent() {
    if (_fullText == null) return const SizedBox.shrink();

    return GestureDetector(
      onVerticalDragEnd: (details) {
        if (details.primaryVelocity != null && details.primaryVelocity! > 500) {
          _goBack();
        }
      },
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.all(24.0),
        physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
        cacheExtent: 1000,
        addAutomaticKeepAlives: false,
        addRepaintBoundaries: true,
        addSemanticIndexes: false,
        itemCount: _getItemCount(),
        itemBuilder: (context, index) {
          return KeyedSubtree(
            key: ValueKey('item_$index'),
            child: _buildLazyItem(index),
          );
        },
      ),
    );
  }

  int _getItemCount() {
    if (_positionMatches != null) {
      return _positionMatches!.length;
    }
    
    if (_fullText == null) return 0;
    
    final regex = RegExp(r'\[pos:\d+\]');
    final matches = regex.allMatches(_fullText!);
    return matches.length;
  }

  Widget _buildLazyItem(int index) {
    // Используем кэш вместо повторного парсинга
    if (_positionMatches == null) {
      _initializePositionCache();
    }
    
    if (_positionMatches == null || index >= _positionMatches!.length) {
      return const SizedBox.shrink();
    }
    
    final match = _positionMatches![index];
    final position = int.parse(match.group(1)!);
    final rawText = match.group(2)!.trim();
    
    // Быстрая проверка на пустоту
    if (rawText.isEmpty) return const SizedBox.shrink();
    
    final text = _cleanTextArtifacts(rawText);
    if (text.isEmpty) return const SizedBox.shrink();
    
    // Кэшированная проверка контекстного блока
    if (_contextBlockCache.containsKey(position)) {
      if (_contextBlockCache[position]!) {
        return const SizedBox.shrink(); // Уже в контекстном блоке
      }
    } else {
      // Вычисляем и кэшируем
      final shouldSkip = _shouldSkipForContextBlock(position);
      _contextBlockCache[position] = shouldSkip;
      if (shouldSkip) return const SizedBox.shrink();
    }
    
    // Проверяем, является ли это позицией с цитатой
    final isQuotePosition = position == widget.context.startPosition;
    
    if (isQuotePosition) {
      // Отмечаем связанные позиции как обработанные
      _markContextPositionsAsProcessed();
      
      return _buildContextBlock(
        widget.context.contextParagraphs, 
        widget.context.contextParagraphs.indexOf(widget.context.quoteParagraph)
      );
    }
    
    // Обычный параграф
    return _buildOptimizedParagraph(text, position);
  }

  // Определяем нужно ли пропустить позицию для контекстного блока
  bool _shouldSkipForContextBlock(int position) {
    return position >= widget.context.startPosition && 
           position <= widget.context.endPosition &&
           position != widget.context.startPosition;
  }

  // Отмечаем позиции контекста как обработанные
  void _markContextPositionsAsProcessed() {
    for (int pos = widget.context.startPosition; pos <= widget.context.endPosition; pos++) {
      if (pos != widget.context.startPosition) {
        _contextBlockCache[pos] = true; // Пропускаем
      }
    }
  }

  // Оптимизированный виджет параграфа
  Widget _buildOptimizedParagraph(String text, int position) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16.0),
      child: SelectableText.rich(
        TextSpan(
          style: TextStyle(
            fontSize: _fontSize,
            height: _lineHeight,
            color: _effectiveTextColor,
            fontWeight: FontWeight.normal,
          ),
          children: [TextSpan(text: text)],
        ),
        onSelectionChanged: (selection, cause) {
          if (selection.baseOffset != selection.extentOffset) {
            final selectedText = text.substring(
              selection.baseOffset,
              selection.extentOffset,
            );
            if (selectedText.trim().length > 10) {
              _selectedText = selectedText;
            }
          }
        },
        contextMenuBuilder: (context, editableTextState) {
          return AdaptiveTextSelectionToolbar(
            anchors: editableTextState.contextMenuAnchors,
            children: [
              TextSelectionToolbarTextButton(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                onPressed: () {
                  editableTextState.hideToolbar();
                  if (_selectedText != null && _selectedText!.trim().length > 10) {
                    _handleTextSelection(_selectedText!, position);
                  }
                },
                child: const Text('💾 Сохранить'),
              ),
              TextSelectionToolbarTextButton(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                onPressed: () {
                  editableTextState.hideToolbar();
                  if (_selectedText != null) {
                    _shareSelectedText(_selectedText!);
                  }
                },
                child: const Text('📤 Поделиться'),
              ),
            ],
          );
        },
      ),
    );
  }

  // Строим контекстный блок из готовых данных QuoteContext
  Widget _buildContextBlock(List<String> paragraphs, int quoteIndex) {
    List<Widget> contextItems = [];
    
    // Заголовок контекстного блока
    contextItems.add(
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: _currentTheme.quoteHighlightColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.format_quote,
              size: 14,
              color: _currentTheme.quoteHighlightColor,
            ),
            const SizedBox(width: 6),
            Text(
              'Контекст цитаты (${widget.context.startPosition})',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: _currentTheme.quoteHighlightColor,
              ),
            ),
          ],
        ),
      ),
    );
    
    contextItems.add(const SizedBox(height: 16));
    
    // Контекст ДО цитаты
    for (final paragraph in widget.context.beforeContext) {
      contextItems.add(
        Container(
          margin: const EdgeInsets.only(bottom: 12),
          child: RichText(
            text: TextSpan(
              style: TextStyle(
                fontSize: _fontSize,
                height: _lineHeight,
                color: _effectiveTextColor.withOpacity(0.8),
                fontWeight: FontWeight.normal,
              ),
              children: [TextSpan(text: paragraph)],
            ),
          ),
        ),
      );
    }
    
    // Сама цитата
    contextItems.add(
      Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _getQuoteHighlightBackgroundColor(),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: _getQuoteHighlightBorderColor(),
            width: 1,
          ),
        ),
        child: RichText(
          text: TextSpan(
            style: TextStyle(
              fontSize: _fontSize + 1,
              height: _lineHeight,
              color: _effectiveTextColor,
              fontWeight: FontWeight.w500,
            ),
            children: [TextSpan(text: widget.context.quoteParagraph)],
          ),
        ),
      ),
    );
    
    // Контекст ПОСЛЕ цитаты
    for (final paragraph in widget.context.afterContext) {
      contextItems.add(
        Container(
          margin: const EdgeInsets.only(bottom: 12),
          child: RichText(
            text: TextSpan(
              style: TextStyle(
                fontSize: _fontSize,
                height: _lineHeight,
                color: _effectiveTextColor.withOpacity(0.8),
                fontWeight: FontWeight.normal,
              ),
              children: [TextSpan(text: paragraph)],
            ),
          ),
        ),
      );
    }
    
    // Возвращаем весь контекстный блок с улучшенным оформлением
    return Container(
      margin: const EdgeInsets.only(bottom: 24.0),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _getContextBlockBackgroundColor(),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _getContextBlockBorderColor(),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: contextItems,
      ),
    );
  }

  // Цвета для контекстного блока
  Color _getContextBlockBackgroundColor() {
    if (_currentTheme.type == ReadingThemeType.dark) {
      return Colors.orange.withOpacity(0.08);
    } else {
      return _currentTheme.highlightColor.withOpacity(0.1);
    }
  }

  Color _getContextBlockBorderColor() {
    if (_currentTheme.type == ReadingThemeType.dark) {
      return Colors.orange.withOpacity(0.3);
    } else {
      return Colors.grey.withOpacity(0.4);
    }
  }

  // Цвета для выделения цитаты
  Color _getQuoteHighlightBackgroundColor() {
    if (_currentTheme.type == ReadingThemeType.dark) {
      return Colors.orange.withOpacity(0.12);
    } else {
      return _currentTheme.quoteHighlightColor.withOpacity(0.08);
    }
  }

  Color _getQuoteHighlightBorderColor() {
    if (_currentTheme.type == ReadingThemeType.dark) {
      return Colors.orange.withOpacity(0.4);
    } else {
      return _currentTheme.quoteHighlightColor.withOpacity(0.2);
    }
  }

  // Проверяем является ли параграф частью уже показанного контекстного блока
  bool _isPartOfContextBlock(List<String> paragraphs, int index) {
    // Ищем ближайшую цитату
    for (int i = max(0, index - 2); i <= min(paragraphs.length - 1, index + 2); i++) {
      if (_simpleQuoteCheck(paragraphs[i].trim())) {
        // Если рядом есть цитата, этот параграф будет показан в контекстном блоке
        return true;
      }
    }
    return false;
  }

  bool _simpleQuoteCheck(String text) {
    if (_normalizedQuoteCache == null || _normalizedQuoteCache!.length < 10) return false;
    
    final normalizedText = _normalizeText(text);
    final quoteStart = _normalizedQuoteCache!.substring(0, min(30, _normalizedQuoteCache!.length));
    
    final isQuote = normalizedText.contains(quoteStart);
    
    if (isQuote) {
      print('🎯 Найдена цитата в параграфе: "${text.substring(0, min(50, text.length))}..."');
    }
    
    return isQuote;
  }

  @override
  void dispose() {
    _scrollRetryTimer?.cancel();
    _fadeController.dispose();
    _themeController.dispose();
    _settingsController.dispose();
    _scrollController.dispose();
    super.dispose();
  }
}

class _SearchProgressWidget extends StatefulWidget {
  final QuoteContext context;
  final ReadingTheme theme;

  const _SearchProgressWidget({
    required this.context,
    required this.theme,
  });

  @override
  State<_SearchProgressWidget> createState() => _SearchProgressWidgetState();
}

class _SearchProgressWidgetState extends State<_SearchProgressWidget>
    with TickerProviderStateMixin {
  late AnimationController _scanController;
  late AnimationController _progressController;
  late Animation<double> _scanAnimation;
  late Animation<double> _progressAnimation;

  late List<String> _searchSteps;
  int _currentStep = 0;

  @override
  void initState() {
    super.initState();
    
    _searchSteps = [
      widget.context.quote.category == 'greece' ? 'Греция' : 
      widget.context.quote.category == 'nordic' ? 'Север' : 
      widget.context.quote.category == 'philosophy' ? 'Философия' : 
      widget.context.quote.category == 'pagan' ? 'Язычество' : 'Неизвестная тема',
      
      widget.context.quote.author,
      widget.context.quote.source,
      'Локализация фрагмента',
      'Найдено',
    ];
    
    _scanController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );
    
    _progressController = AnimationController(
      duration: const Duration(milliseconds: 1800),
      vsync: this,
    );
    
    _scanAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _scanController, curve: Curves.easeInOut),
    );
    
    _progressAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _progressController, curve: Curves.easeOut),
    );
    
    _startAnimation();
  }

  void _startAnimation() async {
    _scanController.repeat();
    
    for (int i = 0; i < _searchSteps.length; i++) {
      await Future.delayed(const Duration(milliseconds: 400));
      if (mounted) {
        setState(() => _currentStep = i);
      }
    }
    
    _progressController.forward();
  }

  @override
  void dispose() {
    _scanController.dispose();
    _progressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            height: 3,
            decoration: BoxDecoration(
              color: widget.theme.borderColor,
              borderRadius: BorderRadius.circular(2),
            ),
            child: AnimatedBuilder(
              animation: _progressAnimation,
              builder: (context, child) {
                return FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: _progressAnimation.value,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          widget.theme.quoteHighlightColor,
                          widget.theme.quoteHighlightColor.withOpacity(0.7),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                );
              },
            ),
          ),
          
          const SizedBox(height: 16),
          
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: Container(
              key: ValueKey(_currentStep),
              child: Text(
                _currentStep < _searchSteps.length ? _searchSteps[_currentStep] : 'Операция завершена',
                style: TextStyle(
                  color: widget.theme.textColor.withOpacity(0.8),
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  decoration: TextDecoration.none,
                ),
              ),
            ),
          ),
          
          const SizedBox(height: 12),
          
          AnimatedBuilder(
            animation: _scanAnimation,
            builder: (context, child) {
              return Stack(
                children: [
                  Container(
                    height: 2,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: widget.theme.borderColor.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(1),
                    ),
                  ),
                  Positioned(
                    left: _scanAnimation.value * 160,
                    child: Container(
                      height: 2,
                      width: 40,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.transparent,
                            widget.theme.quoteHighlightColor.withOpacity(0.8),
                            Colors.transparent,
                          ],
                        ),
                        borderRadius: BorderRadius.circular(1),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}