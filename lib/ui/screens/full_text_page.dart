// lib/ui/screens/full_text_page.dart
import 'dart:math' as math;
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:share_plus/share_plus.dart';
import '../../models/quote_context.dart';
import '../../models/book_source.dart';
import '../../models/reading_theme.dart';
import '../../services/text_file_service.dart';
import 'package:flutter/services.dart';
import '../../services/logger_service.dart';
import 'package:flutter/rendering.dart';


// ПРОСТАЯ СТРУКТУРА ЭЛЕМЕНТА ТЕКСТА
class ParsedTextItem {
  final int position;
  final String content;
  bool isQuoteBlock;
  final bool isContextBefore;
  final bool isContextAfter;
  
  ParsedTextItem({
    required this.position,
    required this.content,
    this.isQuoteBlock = false,
    this.isContextBefore = false,
    this.isContextAfter = false,
  });
}

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
  final _logger = LoggerService();

  late AnimationController _fadeController;
  late AnimationController _themeController;
  late AnimationController _settingsController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _themeAnimation;

  // УПРОЩЕННАЯ СТРУКТУРА ДАННЫХ
  String? _fullText;
  BookSource? _bookSource;
  List<ParsedTextItem> _parsedItems = [];
  int? _targetItemIndex;
  
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

  // Для выделения текста
  String? _selectedText;

  // Новые поля для стабильного скролла
  bool _isScrolling = false;
  bool _scrollCompleted = false;

  Color get _effectiveTextColor => _useCustomColors && _customTextColor != null 
      ? _customTextColor! 
      : _currentTheme.textColor;
      
  Color get _effectiveBackgroundColor => _useCustomColors && _customBackgroundColor != null 
      ? _customBackgroundColor! 
      : _currentTheme.backgroundColor;

  Color get _uiTextColor => _currentTheme.textColor;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _loadTheme();
    _loadFullText();
    
    // Добавляем листенер для отладки
    _scrollController.addListener(() {
      if (_scrollController.hasClients && !_isScrolling) {
        // Логируем только ручной скролл
        debugPrint('Manual scroll offset: [1m${_scrollController.offset}[0m');
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

  Future<void> _loadFullText() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      if (widget.preloadedData != null) {
        setState(() {
          _bookSource = widget.preloadedData!.bookSource;
          _fullText = widget.preloadedData!.fullText;
          _isLoading = false;
        });
        
        // Сразу инициализируем систему скролла
        _initializeScrollSystem();
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
        _fullText = cleanedText;
        _isLoading = false;
      });

      _initializeScrollSystem();
      
    } catch (e) {
      setState(() {
        _error = 'Ошибка загрузки: $e';
        _isLoading = false;
      });
    }
  }

  void _initializeScrollSystem() {
    if (!mounted || _fullText == null) return;
    
    _parseTextOnce();
    _findTargetQuoteIndex();
    
    if (_targetItemIndex != null) {
      // Даем время на построение всего списка
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted && !_scrollCompleted) {
            _scrollToTargetOnce();
          }
        });
      });
    }
  }

  void _parseTextOnce() {
    if (_fullText == null) {
      _logger.error('Cannot parse: text is null');
      return;
    }
    
    _parsedItems.clear();
    
    _logger.info('Starting text parsing, length: [1m${_fullText!.length}[0m');
    
    try {
      final paragraphs = _textService.extractParagraphsWithPositions(_fullText!);
      
      _logger.info('Found ${paragraphs.length} paragraphs to parse');
      
      if (paragraphs.isEmpty) {
        _logger.error('No paragraphs found in text');
        return;
      }
      
      // ВАЖНО: Сохраняем ВСЕ параграфы для корректного поиска
      for (final paragraph in paragraphs) {
        final position = paragraph['position'] as int;
        final content = paragraph['content'] as String;
        
        if (content.isEmpty) {
          _logger.warning('Empty content at position $position');
          continue;
        }
        
        // Добавляем ВСЕ элементы, включая главы
        _parsedItems.add(ParsedTextItem(
          position: position,
          content: content,
          isQuoteBlock: position == widget.context.quote.position,
          isContextBefore: false,
          isContextAfter: false,
        ));
      }
      
      _logger.info('Parsing completed. Total items: ${_parsedItems.length}');
      
    } catch (e, stackTrace) {
      _logger.error('Error parsing text', error: e, stackTrace: stackTrace);
    }
  }

  void _findTargetQuoteIndex() {
    _targetItemIndex = null;
    
    if (_parsedItems.isEmpty) return;
    
    // Простой поиск по позиции
    for (int i = 0; i < _parsedItems.length; i++) {
      if (_parsedItems[i].position == widget.context.quote.position) {
        _targetItemIndex = i;
        debugPrint('Found quote at index $i, position ${_parsedItems[i].position}');
        return;
      }
    }
    
    // Если не нашли по позиции, ищем по тексту
    final quoteTextNorm = _normalizeText(widget.context.quote.text);
    
    for (int i = 0; i < _parsedItems.length; i++) {
      final itemTextNorm = _normalizeText(_parsedItems[i].content);
      
      if (itemTextNorm.contains(quoteTextNorm)) {
        _targetItemIndex = i;
        debugPrint('Found quote by text at index $i');
        return;
      }
    }
    
    debugPrint('Quote not found!');
  }

  void _scrollToTargetOnce() {
    if (!mounted || _targetItemIndex == null || !_scrollController.hasClients) {
      return;
    }
    if (_isScrolling || _scrollCompleted) {
      debugPrint('Scroll already in progress or completed, skipping');
      return;
    }
    setState(() => _isScrolling = true);
    final viewportHeight = _scrollController.position.viewportDimension;
    final maxScroll = _scrollController.position.maxScrollExtent;
    debugPrint('=== ADVANCED SCROLL CALCULATION ===');
    debugPrint('Target index: $_targetItemIndex of ${_parsedItems.length}');
    debugPrint('Target position: ${widget.context.quote.position}');
    debugPrint('Viewport: $viewportHeight, MaxScroll: $maxScroll');
    // Подсчитываем видимые элементы
    int visibleItemsBefore = 0;
    int totalVisibleItems = 0;
    int headersBeforeTarget = 0;
    for (int i = 0; i < _parsedItems.length; i++) {
      final isHeader = TextFileService.isHeader(_parsedItems[i].content);
      if (isHeader && i < _targetItemIndex!) {
        headersBeforeTarget++;
      }
      if (!isHeader) {
        totalVisibleItems++;
        if (i < _targetItemIndex!) {
          visibleItemsBefore++;
        }
      }
    }
    debugPrint('Headers before target: $headersBeforeTarget');
    debugPrint('Visible items before: $visibleItemsBefore');
    debugPrint('Total visible items: $totalVisibleItems');
    // НОВЫЙ АЛГОРИТМ: учитываем реальное распределение контента
    double targetOffset;
    // Для Аристотеля (много глав в начале) используем специальную формулу
    if (_bookSource?.author == "Аристотель") {
      // Эмпирическая формула для Метафизики
      final adjustedIndex = _targetItemIndex! - headersBeforeTarget;
      final adjustedTotal = _parsedItems.length - (_parsedItems.length * 0.1); // ~10% это главы
      final progressPercent = adjustedIndex / adjustedTotal;
      // Нелинейная интерполяция для учета неравномерного распределения
      if (progressPercent < 0.5) {
        // Первая половина книги занимает меньше места из-за глав
        targetOffset = maxScroll * progressPercent * 0.8;
      } else {
        // Вторая половина более плотная
        targetOffset = maxScroll * 0.4 + (maxScroll * 0.6 * (progressPercent - 0.5) * 2);
      }
    } else {
      // Стандартный расчет для других книг
      final visiblePercent = visibleItemsBefore / totalVisibleItems;
      targetOffset = maxScroll * visiblePercent;
    }
    // Финальная корректировка для центрирования
    targetOffset = (targetOffset - viewportHeight / 2).clamp(0.0, maxScroll);
    // Для элементов в конце списка делаем дополнительную коррекцию
    if (_targetItemIndex! > _parsedItems.length * 0.8) {
      // Сдвигаем вниз для компенсации
      targetOffset = math.min(targetOffset + viewportHeight, maxScroll - viewportHeight);
    }
    debugPrint('Final offset: $targetOffset (${(targetOffset/maxScroll*100).toStringAsFixed(1)}% of max)');
    // Выполняем скролл
    _scrollController.animateTo(
      targetOffset,
      duration: const Duration(milliseconds: 1000),
      curve: Curves.easeOutCubic,
    ).then((_) {
      setState(() {
        _isScrolling = false;
        _scrollCompleted = true;
        _autoScrolled = true;
      });
      _highlightQuoteOnce();
      // Делаем финальную проверку и корректировку
      Future.delayed(const Duration(milliseconds: 800), () {
        if (mounted) {
          _performFinalAdjustment();
        }
      });
    }).catchError((error) {
      debugPrint('Scroll error: $error');
      setState(() {
        _isScrolling = false;
        _scrollCompleted = true;
      });
    });
  }

  void _performFinalAdjustment() {
    if (!_scrollController.hasClients || _targetItemIndex == null) return;
    final currentOffset = _scrollController.offset;
    final viewportHeight = _scrollController.position.viewportDimension;
    final maxScroll = _scrollController.position.maxScrollExtent;
    // Используем RenderBox для точного определения позиции
    final targetKey = ValueKey('quote_$_targetItemIndex');
    final contextElement = _findElementByKey(context, targetKey);
    if (contextElement != null) {
      final renderObject = contextElement.findRenderObject();
      if (renderObject != null && renderObject is RenderBox) {
        final position = renderObject.localToGlobal(Offset.zero);
        final itemTop = position.dy;
        final itemHeight = renderObject.size.height;
        debugPrint('=== FINAL ADJUSTMENT CHECK ===');
        debugPrint('Item position on screen: $itemTop');
        debugPrint('Item height: $itemHeight');
        debugPrint('Viewport height: $viewportHeight');
        // Если элемент не в центре экрана, корректируем
        if (itemTop < 100 || itemTop > viewportHeight - 100) {
          final idealPosition = (viewportHeight - itemHeight) / 2;
          final adjustment = idealPosition - itemTop;
          final newOffset = (currentOffset - adjustment).clamp(0.0, maxScroll);
          debugPrint('Adjusting by: $adjustment pixels');
          _scrollController.animateTo(
            newOffset,
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeOut,
          );
        }
        return;
      }
    }
    // Fallback: показываем подсказку
    _showScrollHint();
  }

  // Вспомогательная функция для поиска элемента по ключу
  Element? _findElementByKey(BuildContext root, Key key) {
    Element? result;
    void search(Element element) {
      if (element.widget.key == key) {
        result = element;
        return;
      }
      element.visitChildren(search);
    }
    (root as Element).visitChildren(search);
    return result;
  }

  void _showScrollHint() {
    if (!mounted) return;
    final currentOffset = _scrollController.offset;
    final maxScroll = _scrollController.position.maxScrollExtent;
    final scrollPercent = (currentOffset / (maxScroll == 0 ? 1 : maxScroll) * 100).toStringAsFixed(0);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Цитата находится на ~$scrollPercent% страницы. Прокрутите немного для поиска выделенного текста.'),
        duration: const Duration(seconds: 4),
        backgroundColor: _currentTheme.quoteHighlightColor,
        action: SnackBarAction(
          label: 'Искать вручную',
          textColor: Colors.white,
          onPressed: () {},
        ),
      ),
    );
  }

  void _checkScrollAccuracy() {
    if (!_scrollController.hasClients || _targetItemIndex == null) return;
    final currentOffset = _scrollController.offset;
    final viewportHeight = _scrollController.position.viewportDimension;
    // Более точная оценка видимого диапазона
    // Учитываем, что главы пропускаются
    final avgVisibleItemHeight = viewportHeight / 3; // примерно 3 параграфа на экран
    final scrolledItems = (currentOffset / avgVisibleItemHeight).round();
    debugPrint('=== SCROLL ACCURACY CHECK ===');
    debugPrint('Current offset: $currentOffset');
    debugPrint('Estimated scrolled items: $scrolledItems');
    debugPrint('Target index: $_targetItemIndex');
    // Оцениваем, насколько далеко цель
    final distance = (_targetItemIndex! - scrolledItems).abs();
    if (distance > 10) {
      final direction = _targetItemIndex! < scrolledItems ? "вверх" : "вниз";
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Цитата выделена в тексте. Прокрутите $direction для поиска.'),
          duration: const Duration(seconds: 3),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  Widget _buildTextContent() {
    if (_parsedItems.isEmpty) {
      return Center(
        child: Text(
          'Нет текста для отображения',
          style: TextStyle(color: _effectiveTextColor),
        ),
      );
    }
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(24.0),
      physics: const ClampingScrollPhysics(),
      itemCount: _parsedItems.length,
      itemBuilder: (context, i) => _buildStaticTextItem(i),
    );
  }

  Widget _buildStaticTextItem(int index) {
    final item = _parsedItems[index];
    // Пропускаем главы
    if (TextFileService.isHeader(item.content)) {
      return const SizedBox.shrink();
    }
    // Если это цитата
    if (item.isQuoteBlock && index == _targetItemIndex) {
      return Container(
        key: ValueKey('quote_[1m$index'),
        margin: const EdgeInsets.symmetric(vertical: 24.0),
        padding: const EdgeInsets.all(16.0),
        decoration: BoxDecoration(
          color: _currentTheme.quoteHighlightColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _currentTheme.quoteHighlightColor,
            width: 2,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.format_quote,
                  color: _currentTheme.quoteHighlightColor,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'Искомая цитата',
                  style: TextStyle(
                    color: _currentTheme.quoteHighlightColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SelectableText(
              item.content,
              style: TextStyle(
                fontSize: _fontSize + 1,
                height: _lineHeight,
                color: _effectiveTextColor,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }
    // Обычный параграф
    return Container(
      key: ValueKey('paragraph_$index'),
      margin: const EdgeInsets.only(bottom: 16.0),
      child: SelectableText(
        item.content,
        style: TextStyle(
          fontSize: _fontSize,
          height: _lineHeight,
          color: _effectiveTextColor,
        ),
      ),
    );
  }

  void _scheduleScrollToQuote() {
    // Упрощенная версия
    if (_targetItemIndex == null || _scrollCompleted) return;
    
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) {
        _scrollToTargetOnce();
      }
    });
  }

  void _showSearchAnimation() {
    // Упрощенная версия без диалога
    Future.delayed(const Duration(milliseconds: 1000), () {
      if (mounted && !_scrollCompleted) {
        _scheduleScrollToQuote();
      }
    });
  }

  void _goBack() {
    Navigator.of(context).pop();
  }

  void _adjustFontSize(double delta) {
    setState(() {
      _fontSize = (_fontSize + delta).clamp(12.0, 24.0);
    });
  }

  void _adjustLineHeight(double delta) {
    setState(() {
      _lineHeight = (_lineHeight + delta).clamp(1.2, 2.0);
    });
  }

  void _handleTextSelection(String text, int position) {
    // Показываем меню выбора действий
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
                text.length > 200 ? '${text.substring(0, 200)}...' : text,
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
                GestureDetector(
                  onTap: () => _shareSelectedText(text),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: _currentTheme.highlightColor.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        Icon(Icons.share, color: _effectiveTextColor),
                        const SizedBox(height: 4),
                        Text(
                          'Поделиться',
                          style: TextStyle(
                            fontSize: 12,
                            color: _effectiveTextColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _shareSelectedText(String text) {
    if (_bookSource != null) {
      Share.share(
        '"$text"\n\n— ${_bookSource!.author}, ${_bookSource!.title}',
        subject: 'Цитата из книги',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _effectiveBackgroundColor,
      body: SafeArea(
        child: Stack(
          children: [
            _isLoading
                ? _buildLoadingState()
                : _error != null
                    ? _buildErrorState()
                    : _buildFullTextContent(),
            _buildDebugControls(),
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
          child: _buildTextContent(),
        ),
      ],
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Text(
        'ТЕКСТ СТРОИТСЯ',
        style: TextStyle(fontSize: 28, color: Colors.white, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildReadingSettings() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Text(
            'Настройки чтения',
            style: TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              IconButton(
                onPressed: () => _adjustFontSize(-0.5),
                icon: const Icon(Icons.zoom_out),
              ),
              Text(
                '${_fontSize.toStringAsFixed(1)}',
                style: const TextStyle(fontSize: 16, color: Colors.white),
              ),
              IconButton(
                onPressed: () => _adjustFontSize(0.5),
                icon: const Icon(Icons.zoom_in),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              IconButton(
                onPressed: () => _adjustLineHeight(-0.1),
                icon: const Icon(Icons.format_line_spacing),
              ),
              Text(
                '${_lineHeight.toStringAsFixed(2)}',
                style: const TextStyle(fontSize: 16, color: Colors.white),
              ),
              IconButton(
                onPressed: () => _adjustLineHeight(0.1),
                icon: const Icon(Icons.format_line_spacing),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          Text(
            'Загрузка текста...',
            style: TextStyle(color: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'Ошибка загрузки: $_error',
            style: const TextStyle(color: Colors.red, fontSize: 18),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _loadFullText,
            child: const Text('Повторить загрузку'),
          ),
        ],
      ),
    );
  }

  Widget _buildDebugControls() {
    return Positioned(
      left: 10,
      right: 10,
      bottom: 10,
      child: Material(
        color: Colors.black.withOpacity(0.7),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('ДИАГНОСТИКА', style: TextStyle(color: Colors.yellow, fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: 4),
              Text(
                'isLoading: $_isLoading',
                style: const TextStyle(color: Colors.white, fontSize: 11, fontFamily: 'monospace'),
              ),
              const SizedBox(height: 6),
              Text(
                'error: ${_error ?? "нет"}',
                style: const TextStyle(color: Colors.white, fontSize: 11, fontFamily: 'monospace'),
              ),
              const SizedBox(height: 6),
              Text(
                '_fullText: ${_fullText == null ? "нет" : "есть (${_fullText!.length} символов)"}',
                style: const TextStyle(color: Colors.white, fontSize: 11, fontFamily: 'monospace'),
              ),
              const SizedBox(height: 6),
              Text(
                '_parsedItems: ${_parsedItems.length}',
                style: const TextStyle(color: Colors.white, fontSize: 11, fontFamily: 'monospace'),
              ),
              const SizedBox(height: 6),
              Text(
                'targetItemIndex: ${_targetItemIndex ?? "нет"}',
                style: const TextStyle(color: Colors.white, fontSize: 11, fontFamily: 'monospace'),
              ),
              const SizedBox(height: 6),
              Text(
                'targetPosition: ${widget.context.quote.position}',
                style: const TextStyle(color: Colors.white, fontSize: 11, fontFamily: 'monospace'),
              ),
              const SizedBox(height: 6),
              Text(
                'scroll: ${_scrollController.hasClients ? _scrollController.offset.toStringAsFixed(1) : "нет"}',
                style: const TextStyle(color: Colors.white, fontSize: 11, fontFamily: 'monospace'),
              ),
              const SizedBox(height: 6),
              Text(
                'maxScroll: ${_scrollController.hasClients ? _scrollController.position.maxScrollExtent.toStringAsFixed(1) : "нет"}',
                style: const TextStyle(color: Colors.white, fontSize: 11, fontFamily: 'monospace'),
              ),
              const SizedBox(height: 6),
              Text(
                'viewport: ${_scrollController.hasClients ? _scrollController.position.viewportDimension.toStringAsFixed(1) : "нет"}',
                style: const TextStyle(color: Colors.white, fontSize: 11, fontFamily: 'monospace'),
              ),
              const SizedBox(height: 6),
              if (_parsedItems.isNotEmpty) ...[
                Text(
                  '--- Первый элемент:',
                  style: const TextStyle(color: Colors.white, fontSize: 11, fontFamily: 'monospace'),
                ),
                Text(
                  'pos: ${_parsedItems.first.position}, isHeader: ${TextFileService.isHeader(_parsedItems.first.content)}, text: "${_parsedItems.first.content.substring(0, _parsedItems.first.content.length > 50 ? 50 : _parsedItems.first.content.length)}"',
                  style: const TextStyle(color: Colors.white, fontSize: 11, fontFamily: 'monospace'),
                ),
                Text(
                  '--- Последний элемент:',
                  style: const TextStyle(color: Colors.white, fontSize: 11, fontFamily: 'monospace'),
                ),
                Text(
                  'pos: ${_parsedItems.last.position}, isHeader: ${TextFileService.isHeader(_parsedItems.last.content)}, text: "${_parsedItems.last.content.substring(0, _parsedItems.last.content.length > 50 ? 50 : _parsedItems.last.content.length)}"',
                  style: const TextStyle(color: Colors.white, fontSize: 11, fontFamily: 'monospace'),
                ),
                if (_targetItemIndex != null && _targetItemIndex! >= 0 && _targetItemIndex! < _parsedItems.length) ...[
                  Text(
                    '--- Целевой элемент:',
                    style: const TextStyle(color: Colors.white, fontSize: 11, fontFamily: 'monospace'),
                  ),
                  Text(
                    'pos: ${_parsedItems[_targetItemIndex!].position}, isHeader: ${TextFileService.isHeader(_parsedItems[_targetItemIndex!].content)}, text: "${_parsedItems[_targetItemIndex!].content.substring(0, _parsedItems[_targetItemIndex!].content.length > 50 ? 50 : _parsedItems[_targetItemIndex!].content.length)}"',
                    style: const TextStyle(color: Colors.white, fontSize: 11, fontFamily: 'monospace'),
                  ),
                ],
              ],
              const SizedBox(height: 6),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  style: TextButton.styleFrom(foregroundColor: Colors.yellow),
                  onPressed: _copyPersistentDebugInfo,
                  child: const Text('Скопировать диагностику'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _copyPersistentDebugInfo() {
    final buffer = StringBuffer();
    buffer.writeln('=== ДИАГНОСТИКА FULL_TEXT_PAGE ===');
    buffer.writeln('isLoading: $_isLoading');
    buffer.writeln('error: ${_error ?? "нет"}');
    buffer.writeln('_fullText: ${_fullText == null ? "нет" : "есть (${_fullText!.length} символов)"}');
    buffer.writeln('_parsedItems: ${_parsedItems.length}');
    buffer.writeln('targetItemIndex: ${_targetItemIndex ?? "нет"}');
    buffer.writeln('targetPosition: ${widget.context.quote.position}');
    buffer.writeln('scroll: ${_scrollController.hasClients ? _scrollController.offset.toStringAsFixed(1) : "нет"}');
    buffer.writeln('maxScroll: ${_scrollController.hasClients ? _scrollController.position.maxScrollExtent.toStringAsFixed(1) : "нет"}');
    buffer.writeln('viewport: ${_scrollController.hasClients ? _scrollController.position.viewportDimension.toStringAsFixed(1) : "нет"}');
    if (_parsedItems.isNotEmpty) {
      buffer.writeln('--- Первый элемент:');
      buffer.writeln('pos: ${_parsedItems.first.position}, isHeader: ${TextFileService.isHeader(_parsedItems.first.content)}, text: "${_parsedItems.first.content.substring(0, _parsedItems.first.content.length > 50 ? 50 : _parsedItems.first.content.length)}"');
      buffer.writeln('--- Последний элемент:');
      buffer.writeln('pos: ${_parsedItems.last.position}, isHeader: ${TextFileService.isHeader(_parsedItems.last.content)}, text: "${_parsedItems.last.content.substring(0, _parsedItems.last.content.length > 50 ? 50 : _parsedItems.last.content.length)}"');
      if (_targetItemIndex != null && _targetItemIndex! >= 0 && _targetItemIndex! < _parsedItems.length) {
        final t = _parsedItems[_targetItemIndex!];
        buffer.writeln('--- Целевой элемент:');
        buffer.writeln('pos: ${t.position}, isHeader: ${TextFileService.isHeader(t.content)}, text: "${t.content.substring(0, t.content.length > 50 ? 50 : t.content.length)}"');
      }
    }
    _copyToClipboard(buffer.toString());
  }

  void _copyToClipboard(String text) {
    Clipboard.setData(ClipboardData(text: text));
  }

  @override
  void dispose() {
    _scrollController.removeListener(() {});
    _scrollController.dispose();
    _fadeController.dispose();
    _themeController.dispose();
    _settingsController.dispose();
    super.dispose();
  }

  // Нормализация текста для поиска и сравнения
  String _normalizeText(String text) {
    return text
        .toLowerCase()
        .replaceAll(RegExp(r'\s+'), ' ')
        .replaceAll(RegExp(r'[^\w\sа-яё]', unicode: true), '')
        .trim();
  }

  void _highlightQuoteOnce() {
    if (_targetItemIndex == null) return;
    setState(() {
      for (var item in _parsedItems) {
        item.isQuoteBlock = false;
      }
      _parsedItems[_targetItemIndex!].isQuoteBlock = true;
    });
  }
}

class _SearchProgressWidget extends StatefulWidget {
  final QuoteContext context;
  final ReadingTheme theme;
  final VoidCallback onSearchComplete;

  const _SearchProgressWidget({
    required this.context,
    required this.theme,
    required this.onSearchComplete,
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
    
    await _progressController.forward();
    
    if (mounted) {
      widget.onSearchComplete();
    }
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