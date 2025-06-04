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

  bool _isChapterHeader(String text) {
    final headerPattern = RegExp(r'^ГЛАВА\s+', caseSensitive: true);
    return headerPattern.hasMatch(text.trim());
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
    
    // Предотвращаем множественные вызовы
    if (_isScrolling || _scrollCompleted) {
      debugPrint('Scroll already in progress or completed, skipping');
      return;
    }
    
    setState(() => _isScrolling = true);
    
    final viewportHeight = _scrollController.position.viewportDimension;
    final maxScroll = _scrollController.position.maxScrollExtent;
    
    // Простой расчет позиции
    final totalItems = _parsedItems.length;
    final targetPercent = _targetItemIndex! / totalItems;
    
    // Линейная интерполяция для начальной позиции
    double targetOffset = maxScroll * targetPercent;
    
    // Небольшая коррекция для центрирования
    targetOffset = (targetOffset - viewportHeight / 3).clamp(0.0, maxScroll);
    
    debugPrint('Scrolling to index $_targetItemIndex at offset $targetOffset');
    
    // Выполняем ОДИН скролл
    _scrollController.animateTo(
      targetOffset,
      duration: const Duration(milliseconds: 800),
      curve: Curves.easeOutCubic,
    ).then((_) {
      setState(() {
        _isScrolling = false;
        _scrollCompleted = true;
        _autoScrolled = true;
      });
      
      // Подсвечиваем цитату ОДИН раз
      _highlightQuoteOnce();
    }).catchError((error) {
      debugPrint('Scroll error: $error');
      setState(() {
        _isScrolling = false;
        _scrollCompleted = true;
      });
    });
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

  Widget _buildTextContent() {
    debugPrint('Building text content, parsed items: [1m${_parsedItems.length}[0m');
    if (_parsedItems.isEmpty) {
      return Center(
        child: Text(
          'Нет текста для отображения',
          style: TextStyle(color: _effectiveTextColor),
        ),
      );
    }

    // Используем ListView.builder для поддержки больших текстов
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
    if (_isChapterHeader(item.content)) {
      return const SizedBox.shrink();
    }
    
    // Если это цитата
    if (item.isQuoteBlock && index == _targetItemIndex) {
      return Container(
        key: ValueKey('quote_$index'),
        margin: const EdgeInsets.symmetric(vertical: 24.0),
        child: _buildHighlightedQuote(item),
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

  Widget _buildHighlightedQuote(ParsedTextItem item) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _currentTheme.quoteHighlightColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _currentTheme.quoteHighlightColor.withOpacity(0.3),
          width: 2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Маркер цитаты
          Row(
            children: [
              Icon(
                Icons.format_quote,
                size: 20,
                color: _currentTheme.quoteHighlightColor,
              ),
              const SizedBox(width: 8),
              Text(
                'Искомая цитата',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: _currentTheme.quoteHighlightColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          
          // Текст цитаты
          SelectableText(
            item.content,
            style: TextStyle(
              fontSize: _fontSize + 1,
              height: _lineHeight,
              color: _effectiveTextColor,
              fontWeight: FontWeight.w500,
            ),
          ),
          
          const SizedBox(height: 12),
          
          // Информация об источнике
          Text(
            '${widget.context.quote.author}, ${widget.context.quote.source}',
            style: TextStyle(
              fontSize: _fontSize - 2,
              color: _currentTheme.quoteHighlightColor.withOpacity(0.8),
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
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
    return AnimatedBuilder(
      animation: _themeAnimation,
      builder: (context, child) {
        return Scaffold(
          backgroundColor: _effectiveBackgroundColor,
          body: SafeArea(
            child: Stack(
              children: [
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 600),
                  child: _isLoading 
                      ? _buildLoadingState()
                      : _error != null 
                          ? _buildErrorState()
                          : _buildFullTextContent(),
                ),
                _buildDebugControls(), // Добавляем отладочные кнопки
              ],
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
        buffer.writeln('  Контент: "${item.content.substring(0, math.min(50, item.content.length))}..."');
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

  Widget _buildDebugControls() {
    // Оставляем только кнопку отладки
    return Positioned(
      bottom: 20,
      right: 20,
      child: FloatingActionButton.small(
        onPressed: _showDebugInfo,
        child: const Icon(Icons.bug_report),
        tooltip: 'Отладка',
      ),
    );
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