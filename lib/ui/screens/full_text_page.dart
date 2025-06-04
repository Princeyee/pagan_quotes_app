// lib/ui/screens/full_text_page.dart
import 'dart:math';
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

  // Новые поля для улучшенного поиска
  final Map<int, GlobalKey> _itemKeys = {};
  bool _useGlobalKeyScroll = false;

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
      print('📱 FullTextPage: Starting to load text...'); // Release mode visible log
      
      if (widget.preloadedData != null) {
        print('📱 Using preloaded data, length: ${widget.preloadedData!.fullText.length}'); // Release mode visible log
        
        setState(() {
          _bookSource = widget.preloadedData!.bookSource;
          _fullText = widget.preloadedData!.fullText;
          _isLoading = false;
        });

        _fadeController.forward();
        _initializeScrollSystem();
        return;
      }

      final sources = await _textService.loadBookSources();
      print('📱 Loaded ${sources.length} book sources'); // Release mode visible log
      
      final source = sources.firstWhere(
        (s) => s.author == widget.context.quote.author && 
               s.title == widget.context.quote.source,
        orElse: () => throw Exception('Book source not found'),
      );
      print('📱 Found source: ${source.title} by ${source.author}'); // Release mode visible log

      final cleanedText = await _textService.loadTextFile(source.cleanedFilePath);
      print('📱 Loaded text file, length: ${cleanedText.length}'); // Release mode visible log
      
      setState(() {
        _bookSource = source;
        _fullText = cleanedText;
        _isLoading = false;
      });

      _fadeController.forward();
      _initializeScrollSystem();
      
    } catch (e, stackTrace) {
      print('❌ ERROR in FullTextPage._loadFullText: $e'); // Release mode visible log
      print('❌ Stack trace: $stackTrace'); // Release mode visible log
      setState(() {
        _error = 'Ошибка загрузки полного текста: $e';
        _isLoading = false;
      });
    }
  }

  // ИСПРАВЛЕННАЯ система инициализации скролла
  void _initializeScrollSystem() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _fullText != null) {
        _parseTextOnce();
        _findTargetQuoteIndex();
        
        // Показываем анимацию поиска и запускаем скролл
        _showSearchAnimation();
        
        // Даем больше времени на построение ListView
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) {
            _scheduleScrollToQuote();
          }
        });
      }
    });
  }

  void _parseTextOnce() {
    if (_fullText == null) {
      _logger.error('Cannot parse: text is null');
      return;
    }
    
    _parsedItems.clear();
    
    _logger.info('Starting text parsing, length: ${_fullText!.length}');
    
    try {
      // Используем TextFileService для парсинга, чтобы гарантировать единообразие
      final paragraphs = _textService.extractParagraphsWithPositions(_fullText!);
      
      _logger.info('Found ${paragraphs.length} paragraphs to parse');
      
      if (paragraphs.isEmpty) {
        _logger.error('No paragraphs found in text');
        return;
      }
      
      _logger.info('Position range: ${paragraphs.first['position']} - ${paragraphs.last['position']}');
      _logger.info('Target quote position: ${widget.context.quote.position}');
      
      // Преобразуем параграфы в ParsedTextItem
      for (final paragraph in paragraphs) {
        final position = paragraph['position'] as int;
        final content = paragraph['content'] as String;
        
        if (content.isEmpty) {
          _logger.warning('Empty content at position $position');
          continue;
        }
        
        // Skip chapter headers
        if (_isChapterHeader(content)) {
          _logger.debug('Skipping chapter header at position $position');
          continue;
        }
        
        // Add the item
        _parsedItems.add(ParsedTextItem(
          position: position,
          content: content,
          isQuoteBlock: position == widget.context.quote.position,
          isContextBefore: false,
          isContextAfter: false,
        ));
      }
      
      _logger.info('Parsing completed. Total items: ${_parsedItems.length}');
      
      // Проверяем, что позиция цитаты находится в допустимом диапазоне
      final minPos = _parsedItems.first.position;
      final maxPos = _parsedItems.last.position;
      
      if (widget.context.quote.position < minPos || widget.context.quote.position > maxPos) {
        _logger.error('Quote position ${widget.context.quote.position} is outside valid range ($minPos - $maxPos)');
      }
      
    } catch (e, stackTrace) {
      _logger.error('Error parsing text', error: e, stackTrace: stackTrace);
    }
  }

  bool _isChapterHeader(String text) {
    final headerPattern = RegExp(r'^ГЛАВА\s+', caseSensitive: true);
    return headerPattern.hasMatch(text.trim());
  }

  void _findTargetQuoteIndex() {
    _logger.info('=== ADVANCED QUOTE SEARCH ===');
    _logger.info('Quote position: [1m${widget.context.quote.position}[0m');
    _logger.info('Quote text: "${widget.context.quote.text}"');
    _logger.info('Full paragraph text available: ${widget.context.quote.fullParagraphText != null}');
    
    _targetItemIndex = null;
    
    if (_parsedItems.isEmpty) {
      _logger.error('No parsed items available');
      return;
    }
    
    // Метод 1: Точный поиск по позиции
    for (int i = 0; i < _parsedItems.length; i++) {
      if (_parsedItems[i].position == widget.context.quote.position) {
        _targetItemIndex = i;
        _logger.info('Found exact position match at index $i');
        
        // Проверяем совпадение текста
        final itemContent = _parsedItems[i].content;
        final quoteText = widget.context.quote.text;
        final fullText = widget.context.quote.fullParagraphText;
        
        // Если есть полный текст параграфа, сравниваем с ним
        if (fullText != null) {
          if (_normalizeForComparison(itemContent) == _normalizeForComparison(fullText)) {
            _logger.success('Full paragraph text matched perfectly!');
            return;
          }
        }
        
        // Проверяем, содержит ли параграф текст цитаты
        if (_paragraphContainsQuote(itemContent, quoteText)) {
          _logger.success('Quote text found in paragraph');
          return;
        }
        
        _logger.warning('Position matched but text verification failed');
        // Продолжаем использовать эту позицию как основную
        break;
      }
    }
    
    // Метод 2: Поиск ближайшей позиции
    if (_targetItemIndex == null) {
      _logger.info('No exact position match, searching for closest');
      _targetItemIndex = _findClosestPosition(widget.context.quote.position);
      _logger.info('Using closest position at index $_targetItemIndex');
    }
    
    // Метод 3: Интеллектуальный поиск текста в окрестности
    final betterMatch = _intelligentTextSearch(
      widget.context.quote.text,
      _targetItemIndex!,
      searchRadius: 10
    );
    
    if (betterMatch != null && betterMatch != _targetItemIndex) {
      _logger.info('Found better match through text search at index $betterMatch');
      _targetItemIndex = betterMatch;
    }
    
    // Метод 4: Fallback - полнотекстовый поиск
    if (_targetItemIndex == null || !_verifyTargetIndex(_targetItemIndex!)) {
      _logger.warning('Primary search failed, attempting full text search');
      _targetItemIndex = _fullTextSearch(widget.context.quote.text);
    }
    
    _logger.info('Final target index: $_targetItemIndex');
  }

  // Новый метод для проверки, содержит ли параграф цитату
  bool _paragraphContainsQuote(String paragraphText, String quoteText) {
    final normalizedParagraph = _normalizeForComparison(paragraphText);
    final normalizedQuote = _normalizeForComparison(quoteText);
    
    // Проверяем точное вхождение
    if (normalizedParagraph.contains(normalizedQuote)) {
      return true;
    }
    
    // Проверяем частичное совпадение (80% слов)
    final quoteWords = normalizedQuote.split(' ').where((w) => w.length > 2).toSet();
    final paragraphWords = normalizedParagraph.split(' ').toSet();
    
    final commonWords = quoteWords.intersection(paragraphWords);
    final matchRatio = commonWords.length / quoteWords.length;
    
    return matchRatio >= 0.8;
  }

  // Поиск ближайшей позиции
  int _findClosestPosition(int targetPosition) {
    int closestIndex = 0;
    int minDiff = (_parsedItems[0].position - targetPosition).abs();
    
    for (int i = 1; i < _parsedItems.length; i++) {
      final diff = (_parsedItems[i].position - targetPosition).abs();
      if (diff < minDiff) {
        minDiff = diff;
        closestIndex = i;
      }
    }
    
    return closestIndex;
  }

  // Интеллектуальный поиск текста
  int? _intelligentTextSearch(String quoteText, int centerIndex, {int searchRadius = 10}) {
    final normalizedQuote = _normalizeForComparison(quoteText);
    final quoteWords = normalizedQuote.split(' ').where((w) => w.length > 2).toList();
    
    if (quoteWords.isEmpty) return null;
    
    int bestMatchIndex = centerIndex;
    double bestMatchScore = 0.0;
    
    final searchStart = (centerIndex - searchRadius).clamp(0, _parsedItems.length - 1);
    final searchEnd = (centerIndex + searchRadius).clamp(0, _parsedItems.length - 1);
    
    for (int i = searchStart; i <= searchEnd; i++) {
      final normalizedContent = _normalizeForComparison(_parsedItems[i].content);
      
      // Расчет оценки совпадения
      double score = 0.0;
      
      // 1. Проверка точного вхождения
      if (normalizedContent.contains(normalizedQuote)) {
        score = 1.0;
      } else {
        // 2. Проверка по словам
        final contentWords = normalizedContent.split(' ').toSet();
        final commonWords = quoteWords.toSet().intersection(contentWords);
        score = commonWords.length / quoteWords.length;
        
        // 3. Бонус за последовательность слов
        if (score > 0.5) {
          int sequenceBonus = _countWordSequences(quoteWords, normalizedContent);
          score += sequenceBonus * 0.1;
        }
      }
      
      // 4. Штраф за расстояние от ожидаемой позиции
      final distancePenalty = (i - centerIndex).abs() / searchRadius * 0.2;
      score -= distancePenalty;
      
      if (score > bestMatchScore) {
        bestMatchScore = score;
        bestMatchIndex = i;
      }
    }
    
    return bestMatchScore > 0.6 ? bestMatchIndex : null;
  }

  // Подсчет последовательностей слов
  int _countWordSequences(List<String> quoteWords, String content) {
    int maxSequence = 0;
    
    for (int start = 0; start < quoteWords.length; start++) {
      for (int length = 2; length <= quoteWords.length - start; length++) {
        final sequence = quoteWords.sublist(start, start + length).join(' ');
        if (content.contains(sequence)) {
          maxSequence = max(maxSequence, length);
        }
      }
    }
    
    return maxSequence;
  }

  // Полнотекстовый поиск как последний вариант
  int? _fullTextSearch(String quoteText) {
    final normalizedQuote = _normalizeForComparison(quoteText);
    
    for (int i = 0; i < _parsedItems.length; i++) {
      final normalizedContent = _normalizeForComparison(_parsedItems[i].content);
      if (normalizedContent.contains(normalizedQuote)) {
        return i;
      }
    }
    
    return null;
  }

  // Проверка корректности найденного индекса
  bool _verifyTargetIndex(int index) {
    if (index < 0 || index >= _parsedItems.length) return false;
    
    final item = _parsedItems[index];
    final quoteText = widget.context.quote.text;
    
    return _paragraphContainsQuote(item.content, quoteText);
  }

  // Улучшенная нормализация текста
  String _normalizeForComparison(String text) {
    return text
        .toLowerCase()
        .replaceAll(RegExp(r'\s+'), ' ')
        .replaceAll(RegExp(r'[^\w\sа-яёА-ЯЁ]', unicode: true), '')
        .trim();
  }

  void _scheduleScrollToQuote() {
    if (_targetItemIndex == null) {
      _logger.error('No target index for scroll');
      return;
    }
    
    if (_autoScrolled) {
      _logger.info('Scroll already performed, skipping');
      return;
    }
    
    // Даем время на полное построение ListView
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) {
        _performScrollToQuote();
      }
    });
  }

  void _performScrollToQuote() {
    if (!mounted || _targetItemIndex == null || !_scrollController.hasClients) {
      _logger.error('Cannot perform scroll: mounted=$mounted, targetIndex=$_targetItemIndex, hasClients=${_scrollController.hasClients}');
      return;
    }
    
    _logger.info('=== SCROLL TO QUOTE ===');
    
    final targetIndex = _targetItemIndex!;
    final targetPosition = _parsedItems[targetIndex].position;
    
    _logger.info('Target index: $targetIndex');
    _logger.info('Target position: $targetPosition');
    _logger.info('Total items: ${_parsedItems.length}');

    // Сначала выделяем цитату
    setState(() {
      for (var item in _parsedItems) {
        item.isQuoteBlock = item.position == targetPosition;
      }
    });

    // Ensure ListView is ready
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;

      // Используем пошаговый скролл для более точного позиционирования
      _progressiveScrollToTarget(targetIndex);
    });
  }

  void _progressiveScrollToTarget(int targetIndex) {
    if (!mounted || !_scrollController.hasClients) return;
    
    // Попробуем использовать GlobalKey для точного скролла
    if (_useGlobalKeyScroll && _itemKeys.containsKey(targetIndex)) {
      _scrollToGlobalKey(targetIndex);
      return;
    }
    
    // Fallback на расчетный скролл
    _calculatedScroll(targetIndex);
  }

  // Скролл с использованием GlobalKey
  void _scrollToGlobalKey(int targetIndex) {
    final key = _itemKeys[targetIndex];
    if (key?.currentContext != null) {
      Scrollable.ensureVisible(
        key!.currentContext!,
        duration: const Duration(milliseconds: 800),
        curve: Curves.easeOutCubic,
        alignment: 0.5, // Центрировать элемент
      ).then((_) {
        if (mounted) {
          setState(() => _autoScrolled = true);
          _logger.success('GlobalKey scroll completed');
        }
      });
    } else {
      // Если GlobalKey не готов, используем расчетный метод
      _calculatedScroll(targetIndex);
    }
  }

  // Улучшенный расчетный скролл
  void _calculatedScroll(int targetIndex) {
    final viewportHeight = _scrollController.position.viewportDimension;
    final maxScroll = _scrollController.position.maxScrollExtent;
    
    // Более точный расчет высоты элементов
    double targetOffset = 0;
    final itemPadding = 24.0 * 2; // padding из ListView
    
    // Считаем высоту каждого элемента до целевого
    for (int i = 0; i < targetIndex && i < _parsedItems.length; i++) {
      final item = _parsedItems[i];
      
      if (item.isQuoteBlock) {
        // Примерная высота контекстного блока
        targetOffset += _estimateContextBlockHeight(i);
      } else {
        // Высота обычного параграфа
        targetOffset += _estimateParagraphHeight(item.content);
      }
    }
    
    // Добавляем отступы
    targetOffset += itemPadding;
    
    // Центрируем элемент в viewport
    targetOffset = (targetOffset - (viewportHeight / 2)).clamp(0.0, maxScroll);
    
    _logger.info('Calculated scroll offset: $targetOffset for index: $targetIndex');
    
    // Выполняем скролл с промежуточными проверками
    _scrollController.animateTo(
      targetOffset,
      duration: const Duration(milliseconds: 800),
      curve: Curves.easeOutCubic,
    ).then((_) {
      if (mounted) {
        setState(() => _autoScrolled = true);
        
        // Финальная корректировка
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _finetuneScrollPosition(targetIndex);
        });
      }
    });
  }

  // Оценка высоты контекстного блока
  double _estimateContextBlockHeight(int quoteIndex) {
    double height = 0;
    
    // Заголовок
    height += 40;
    
    // Контекст до (если есть)
    if (quoteIndex > 0) {
      height += _estimateParagraphHeight(_parsedItems[quoteIndex - 1].content);
      height += 12; // margin
    }
    
    // Сама цитата с оформлением
    height += _estimateParagraphHeight(_parsedItems[quoteIndex].content);
    height += 40; // padding и decorations
    
    // Контекст после (если есть)
    if (quoteIndex < _parsedItems.length - 1) {
      height += _estimateParagraphHeight(_parsedItems[quoteIndex + 1].content);
      height += 12; // margin
    }
    
    // Общие отступы блока
    height += 88; // padding (20*2) + margin (24*2)
    
    return height;
  }

  // Оценка высоты параграфа
  double _estimateParagraphHeight(String text) {
    // Средняя ширина символа относительно размера шрифта
    final avgCharWidth = _fontSize * 0.55;
    final viewportWidth = MediaQuery.of(context).size.width - 48; // minus padding
    final charsPerLine = (viewportWidth / avgCharWidth).floor();
    final lines = (text.length / charsPerLine).ceil();
    
    return lines * (_fontSize * _lineHeight) + 16; // + margin
  }

  // Финальная корректировка позиции
  void _finetuneScrollPosition(int targetIndex) {
    if (!mounted || !_scrollController.hasClients) return;
    
    // Получаем текущую позицию элемента на экране
    final RenderBox? renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox == null) return;
    
    // Здесь можно добавить дополнительную логику корректировки
    // если элемент не полностью видим
    
    _logger.success('Scroll finalized at position: ${_scrollController.offset}');
  }

  Widget _buildTextItem(int index) {
    final item = _parsedItems[index];
    
    // Создаем GlobalKey для целевого элемента и соседних
    if (_targetItemIndex != null && 
        (index - _targetItemIndex!).abs() <= 2) {
      _itemKeys[index] ??= GlobalKey();
      _useGlobalKeyScroll = true;
    }
    
    final widget = item.isQuoteBlock 
        ? _buildQuoteContextBlock(index)
        : _buildOptimizedParagraph(item.content, item.position);
    
    // Оборачиваем в KeyedSubtree с GlobalKey если нужно
    if (_itemKeys.containsKey(index)) {
      return KeyedSubtree(
        key: _itemKeys[index],
        child: widget,
      );
    }
    
    return KeyedSubtree(
      key: ValueKey('item_$index'),
      child: widget,
    );
  }

  // Добавьте метод для сброса поиска при необходимости
  void _resetSearch() {
    setState(() {
      _targetItemIndex = null;
      _autoScrolled = false;
      _itemKeys.clear();
      _useGlobalKeyScroll = false;
    });
    
    _findTargetQuoteIndex();
    _scheduleScrollToQuote();
  }

  void _showSearchAnimation() {
    // Сохраняем контекст диалога для последующего закрытия
    BuildContext? dialogContext;
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        dialogContext = context;
        return Material(
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
                      onSearchComplete: () {
                        // Закрываем диалог и запускаем скролл
                        if (dialogContext != null) {
                          Navigator.of(dialogContext!).pop();
                          _scheduleScrollToQuote();
                        }
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
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
            onPressed: _showDebugInfo,
            icon: Icon(Icons.bug_report, color: _effectiveTextColor),
            tooltip: 'Отладка',
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

  void _showDebugInfo() {
    showDialog(
      context: context,
      builder: (context) => Material(
        color: Colors.transparent,
        child: Container(
          margin: const EdgeInsets.all(24),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _currentTheme.cardColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _currentTheme.borderColor),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Отладочная информация',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: _effectiveTextColor,
                    ),
                  ),
                  IconButton(
                    onPressed: _exportDebugInfo,
                    icon: Icon(Icons.copy_all, color: _effectiveTextColor),
                    tooltip: 'Копировать все',
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _buildCopyableDebugItem('Целевая позиция', widget.context.quote.position.toString()),
              _buildCopyableDebugItem('Целевой индекс', _targetItemIndex?.toString() ?? 'не найден'),
              _buildCopyableDebugItem('Всего элементов', _parsedItems.length.toString()),
              _buildCopyableDebugItem('Текущий скролл', _scrollController.hasClients 
                ? _scrollController.offset.toStringAsFixed(1) 
                : 'нет данных'),
              _buildCopyableDebugItem('Макс. скролл', _scrollController.hasClients 
                ? _scrollController.position.maxScrollExtent.toStringAsFixed(1) 
                : 'нет данных'),
              _buildCopyableDebugItem('Размер экрана', _scrollController.hasClients 
                ? _scrollController.position.viewportDimension.toStringAsFixed(1) 
                : 'нет данных'),
              const SizedBox(height: 8),
              const Divider(),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Позиции элементов:',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: _effectiveTextColor,
                    ),
                  ),
                  IconButton(
                    onPressed: () => _copyPositionsToClipboard(),
                    icon: Icon(Icons.copy, color: _effectiveTextColor),
                    tooltip: 'Копировать позиции',
                  ),
                ],
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 200,
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (int i = 0; i < _parsedItems.length; i++)
                        _buildCopyableDebugItem(
                          'Индекс $i',
                          'Позиция ${_parsedItems[i].position}${_targetItemIndex == i ? ' (ЦЕЛЬ)' : ''}',
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(
                      'Закрыть',
                      style: TextStyle(color: _effectiveTextColor),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCopyableDebugItem(String label, String value) {
    return InkWell(
      onTap: () => _copyToClipboard('$label: $value'),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Expanded(
              child: Row(
                children: [
                  Text(
                    '$label: ',
                    style: TextStyle(
                      fontSize: 14,
                      color: _effectiveTextColor.withOpacity(0.7),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      value,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: _effectiveTextColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              iconSize: 16,
              visualDensity: VisualDensity.compact,
              onPressed: () => _copyToClipboard('$label: $value'),
              icon: Icon(Icons.copy, color: _effectiveTextColor.withOpacity(0.5)),
              tooltip: 'Копировать',
            ),
          ],
        ),
      ),
    );
  }

  void _copyToClipboard(String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Скопировано в буфер обмена'),
        duration: const Duration(seconds: 1),
        backgroundColor: _currentTheme.quoteHighlightColor,
      ),
    );
  }

  void _copyPositionsToClipboard() {
    final buffer = StringBuffer();
    buffer.writeln('=== Позиции элементов ===');
    for (int i = 0; i < _parsedItems.length; i++) {
      buffer.writeln('Индекс $i: Позиция ${_parsedItems[i].position}${_targetItemIndex == i ? ' (ЦЕЛЬ)' : ''}');
    }
    _copyToClipboard(buffer.toString());
  }

  void _exportDebugInfo() {
    final buffer = StringBuffer();
    buffer.writeln('=== ОТЛАДОЧНАЯ ИНФОРМАЦИЯ ===');
    buffer.writeln('Время: ${DateTime.now()}');
    buffer.writeln();
    
    buffer.writeln('=== ОСНОВНЫЕ ПАРАМЕТРЫ ===');
    buffer.writeln('Целевая позиция: ${widget.context.quote.position}');
    buffer.writeln('Целевой индекс: ${_targetItemIndex?.toString() ?? 'не найден'}');
    buffer.writeln('Всего элементов: ${_parsedItems.length}');
    
    if (_scrollController.hasClients) {
      buffer.writeln('Текущий скролл: ${_scrollController.offset.toStringAsFixed(1)}');
      buffer.writeln('Макс. скролл: ${_scrollController.position.maxScrollExtent.toStringAsFixed(1)}');
      buffer.writeln('Размер экрана: ${_scrollController.position.viewportDimension.toStringAsFixed(1)}');
    } else {
      buffer.writeln('Скролл: нет данных');
    }
    
    buffer.writeln();
    buffer.writeln('=== ЦИТАТА ===');
    buffer.writeln('Текст: "${widget.context.quote.text}"');
    buffer.writeln('Автор: ${widget.context.quote.author}');
    buffer.writeln('Источник: ${widget.context.quote.source}');
    
    buffer.writeln();
    buffer.writeln('=== ПОЗИЦИИ ЭЛЕМЕНТОВ ===');
    for (int i = 0; i < _parsedItems.length; i++) {
      final item = _parsedItems[i];
      buffer.writeln('Индекс $i: Позиция ${item.position}${_targetItemIndex == i ? ' (ЦЕЛЬ)' : ''}');
      if (_targetItemIndex == i || i == 0 || i == _parsedItems.length - 1) {
        buffer.writeln('  Контент: "${item.content.substring(0, min(50, item.content.length))}..."');
      }
    }
    
    _copyToClipboard(buffer.toString());
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
    if (_parsedItems.isEmpty) {
      _logger.error('No items to display', tag: 'UI');
      return Center(
        child: Text(
          'Нет текста для отображения',
          style: TextStyle(color: _effectiveTextColor),
        ),
      );
    }

    _logger.info('Building list with ${_parsedItems.length} items', tag: 'UI');

    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification is ScrollEndNotification) {
          _logger.debug('Scroll ended at: ${_scrollController.offset}');
        }
        return true;
      },
      child: ListView.builder(
        key: const PageStorageKey('full_text_list'),
        controller: _scrollController,
        padding: const EdgeInsets.all(24.0),
        physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
        cacheExtent: 3000, // Увеличиваем кэш для лучшей производительности
        addAutomaticKeepAlives: false,
        addRepaintBoundaries: true,
        addSemanticIndexes: false,
        itemCount: _parsedItems.length,
        itemBuilder: (context, index) {
          final item = _parsedItems[index];
          
          // Skip rendering context paragraphs in the main flow
          if (!item.isQuoteBlock && 
              (item.isContextBefore || item.isContextAfter)) {
            return const SizedBox.shrink();
          }
          
          return KeyedSubtree(
            key: ValueKey('item_$index'),
            child: _buildTextItem(index),
          );
        },
      ),
    );
  }

  Widget _buildQuoteContextBlock(int quoteIndex) {
    final quote = _parsedItems[quoteIndex];
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
              'Контекст цитаты (${quote.position})',
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
    
    // Добавляем контекст ДО цитаты
    if (quoteIndex > 0) {
      final prevItem = _parsedItems[quoteIndex - 1];
      if (!_isChapterHeader(prevItem.content)) {
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
                children: [TextSpan(text: prevItem.content)],
              ),
            ),
          ),
        );
      }
    }
    
    // Сама цитата с улучшенным выделением
    contextItems.add(
      Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _getQuoteHighlightBackgroundColor(),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: _getQuoteHighlightBorderColor(),
            width: 2, // Увеличили толщину границы
          ),
          boxShadow: [
            BoxShadow(
              color: _currentTheme.quoteHighlightColor.withOpacity(0.1),
              blurRadius: 8,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            RichText(
              text: TextSpan(
                style: TextStyle(
                  fontSize: _fontSize + 1,
                  height: _lineHeight,
                  color: _effectiveTextColor,
                  fontWeight: FontWeight.w500,
                ),
                children: [TextSpan(text: quote.content)],
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: _currentTheme.quoteHighlightColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                '${widget.context.quote.author}, ${widget.context.quote.source}',
                style: TextStyle(
                  fontSize: _fontSize - 2,
                  color: _currentTheme.quoteHighlightColor,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          ],
        ),
      ),
    );
    
    // Добавляем контекст ПОСЛЕ цитаты
    if (quoteIndex < _parsedItems.length - 1) {
      final nextItem = _parsedItems[quoteIndex + 1];
      if (!_isChapterHeader(nextItem.content)) {
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
                children: [TextSpan(text: nextItem.content)],
              ),
            ),
          ),
        );
      }
    }
    
    // Возвращаем весь контекстный блок с улучшенным оформлением
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 24.0),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _getContextBlockBackgroundColor(),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _getContextBlockBorderColor(),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
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

  @override
  void dispose() {
    _fadeController.dispose();
    _themeController.dispose();
    _settingsController.dispose();
    _scrollController.dispose();
    _itemKeys.clear(); // Очистка GlobalKeys
    super.dispose();
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