// lib/ui/screens/full_text_page_2.dart
import 'package:flutter/material.dart';
import '../../models/quote_context.dart';
import '../../models/book_source.dart';
import '../../models/reading_theme.dart';
import '../../services/text_file_service.dart';
import '../../services/logger_service.dart';
import '../../utils/custom_cache.dart';
import 'package:flutter/services.dart';

// Экспорт для использования в ContextPage
export 'full_text_page_2.dart';

class FullTextPage2 extends StatefulWidget {
  final QuoteContext context;

  const FullTextPage2({
    super.key,
    required this.context,
  });

  @override
  State<FullTextPage2> createState() => _FullTextPage2State();
}

class _FullTextPage2State extends State<FullTextPage2> 
    with TickerProviderStateMixin {
  final TextFileService _textService = TextFileService();
  final ScrollController _scrollController = ScrollController();
  final CustomCachePrefs _cache = CustomCache.prefs;
  final _logger = LoggerService();

  late AnimationController _fadeController;
  late AnimationController _settingsController;
  late Animation<double> _fadeAnimation;

  // Данные
  String? _fullText;
  BookSource? _bookSource;
  List<TextParagraph> _paragraphs = [];
  
  // Состояние
  bool _isLoading = true;
  String? _error;
  bool _showSettings = false;
  
  // Настройки чтения
  double _fontSize = 17.0;
  double _lineHeight = 1.5;
  ReadingTheme _currentTheme = ReadingTheme.dark;
  Color? _customTextColor;
  Color? _customBackgroundColor;
  bool _useCustomColors = false;

  // Поиск цитаты
  int? _targetParagraphIndex;
  List<int> _contextIndices = [];
  bool _autoScrollCompleted = false;

  // Для точного скролла
  final Map<int, GlobalKey> _paragraphKeys = {};
  final Map<int, double> _paragraphOffsets = {};
  bool _offsetsReady = false;
  bool _findingQuote = false;

  Color get _effectiveTextColor => _useCustomColors && _customTextColor != null 
      ? _customTextColor! 
      : _currentTheme.textColor;
      
  Color get _effectiveBackgroundColor => _useCustomColors && _customBackgroundColor != null 
      ? _customBackgroundColor! 
      : _currentTheme.backgroundColor;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _loadSettings();
    _loadFullText();
  }

  void _initializeAnimations() {
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 600),
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
  }

  Future<void> _loadSettings() async {
    final fontSize = _cache.getSetting<double>('font_size') ?? 17.0;
    final lineHeight = _cache.getSetting<double>('line_height') ?? 1.5;
    final themeType = ReadingTheme.fromString(
      _cache.getSetting<String>('reading_theme') ?? 'dark'
    );
    
    final useCustom = _cache.getSetting<bool>('use_custom_colors') ?? false;
    final textColorValue = _cache.getSetting<int>('custom_text_color');
    final bgColorValue = _cache.getSetting<int>('custom_background_color');
    
    setState(() {
      _fontSize = fontSize;
      _lineHeight = lineHeight;
      _currentTheme = ReadingTheme.fromType(themeType);
      _useCustomColors = useCustom;
      _customTextColor = textColorValue != null ? Color(textColorValue) : null;
      _customBackgroundColor = bgColorValue != null ? Color(bgColorValue) : null;
    });
  }

  Future<void> _saveSettings() async {
    await _cache.setSetting('font_size', _fontSize);
    await _cache.setSetting('line_height', _lineHeight);
    await _cache.setSetting('reading_theme', _currentTheme.typeString);
    await _cache.setSetting('use_custom_colors', _useCustomColors);
    
    if (_customTextColor != null) {
      await _cache.setSetting('custom_text_color', _customTextColor!.value);
    }
    if (_customBackgroundColor != null) {
      await _cache.setSetting('custom_background_color', _customBackgroundColor!.value);
    }
  }

  Future<void> _loadFullText() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Найти источник книги
      final sources = await _textService.loadBookSources();
      
      final source = sources.firstWhere(
        (s) => s.author == widget.context.quote.author && 
               s.title == widget.context.quote.source,
        orElse: () => throw Exception('Источник книги не найден'),
      );

      _logger.info('Найден источник: ${source.title} - ${source.cleanedFilePath}');

      // Загружаем полный текст
      final cleanedText = await _textService.loadTextFile(source.cleanedFilePath);
      
      _logger.info('Загружен текст длиной: ${cleanedText.length} символов');

      setState(() {
        _bookSource = source;
        _fullText = cleanedText;
      });

      // Парсим текст на параграфы
      _parseText();
      
      // Находим цитату и контекст
      _findQuoteAndContext();
      
      setState(() {
        _isLoading = false;
      });
      
      _fadeController.forward();
      
      // Скроллим к цитате после построения UI
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToQuote();
      });
      
    } catch (e, stackTrace) {
      _logger.error('Ошибка загрузки полного текста', error: e, stackTrace: stackTrace);
      setState(() {
        _error = 'Ошибка загрузки: $e';
        _isLoading = false;
      });
    }
  }

  void _parseText() {
    if (_fullText == null) return;
    _paragraphs.clear();
    _paragraphKeys.clear();
    _paragraphOffsets.clear();
    _offsetsReady = false;
    final rawParagraphs = _textService.extractParagraphsWithPositions(_fullText!);
    _logger.info('Найдено ${rawParagraphs.length} параграфов');
    for (int i = 0; i < rawParagraphs.length; i++) {
      final raw = rawParagraphs[i];
      final position = raw['position'] as int;
      final content = raw['content'] as String;
      if (content.trim().isEmpty) continue;
      _paragraphs.add(TextParagraph(
        position: position,
        content: content,
        displayIndex: i,
        isQuote: false,
        isContext: false,
      ));
      _paragraphKeys[i] = GlobalKey();
    }
    _logger.info('Обработано ${_paragraphs.length} параграфов');
  }

  void _findQuoteAndContext() {
    if (_paragraphs.isEmpty) return;
    final quotePosition = widget.context.quote.position;
    final contextStartPos = widget.context.startPosition;
    final contextEndPos = widget.context.endPosition;
    _logger.info('Ищем цитату на позиции: $quotePosition');
    _logger.info('Контекст: $contextStartPos - $contextEndPos');
    for (int i = 0; i < _paragraphs.length; i++) {
      final para = _paragraphs[i];
      if (para.position == quotePosition) {
        _targetParagraphIndex = i;
        para.isQuote = true;
        _logger.info('Найдена цитата на индексе: $i');
      }
      if (para.position >= contextStartPos && para.position <= contextEndPos) {
        para.isContext = true;
        _contextIndices.add(i);
      }
    }
    _logger.info('Найден контекст: ${_contextIndices.length} параграфов');
    _logger.info('Индекс цитаты: $_targetParagraphIndex');
  }

  void _scrollToQuote() async {
    if (_targetParagraphIndex == null || !_scrollController.hasClients) {
      _logger.warning('Не удалось скроллить: targetIndex=$_targetParagraphIndex, hasClients=${_scrollController.hasClients}');
      return;
    }
    if (_autoScrollCompleted) return;
    // Ждём, пока построятся параграфы и появятся размеры
    await Future.delayed(const Duration(milliseconds: 500));
    if (!_offsetsReady) {
      _calculateParagraphOffsets();
      await Future.delayed(const Duration(milliseconds: 100));
    }
    final offset = _paragraphOffsets[_targetParagraphIndex!] ?? 0.0;
    final maxScroll = _scrollController.position.maxScrollExtent;
    final viewportHeight = _scrollController.position.viewportDimension;
    final clampedOffset = (offset - viewportHeight / 2).clamp(0.0, maxScroll);
    _logger.info('Точный скролл к offset: $clampedOffset (реальный offset: $offset, maxScroll: $maxScroll)');
    _scrollController.animateTo(
      clampedOffset,
      duration: const Duration(milliseconds: 1200),
      curve: Curves.easeOutCubic,
    ).then((_) {
      setState(() {
        _autoScrollCompleted = true;
      });
      _showScrollHint();
    });
  }

  void _calculateParagraphOffsets() {
    double offset = 0.0;
    for (int i = 0; i < _paragraphs.length; i++) {
      final key = _paragraphKeys[i];
      if (key != null && key.currentContext != null) {
        final box = key.currentContext!.findRenderObject() as RenderBox?;
        if (box != null && box.hasSize) {
          _paragraphOffsets[i] = offset;
          offset += box.size.height;
        }
      }
    }
    _offsetsReady = true;
    _logger.info('Построена карта offsets для ${_paragraphOffsets.length} параграфов');
  }

  void _showScrollHint() {
    if (!mounted) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Цитата выделена ниже. Контекст показан дополнительно.'),
        duration: const Duration(seconds: 3),
        backgroundColor: _currentTheme.quoteHighlightColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
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


  void _copyDebugInfo() {
    final buffer = StringBuffer();
    buffer.writeln('=== DEBUG FullTextPage2 ===');
    buffer.writeln('isLoading: $_isLoading');
    buffer.writeln('error: $_error');
    buffer.writeln('_fullText: ${_fullText == null ? "нет" : "есть (${_fullText!.length} символов)"}');
    buffer.writeln('_paragraphs: ${_paragraphs.length}');
    buffer.writeln('targetParagraphIndex: $_targetParagraphIndex');
    buffer.writeln('contextIndices: $_contextIndices');
    buffer.writeln('scroll: ${_scrollController.hasClients ? _scrollController.offset.toStringAsFixed(1) : "нет"}');
    buffer.writeln('maxScroll: ${_scrollController.hasClients ? _scrollController.position.maxScrollExtent.toStringAsFixed(1) : "нет"}');
    buffer.writeln('viewport: ${_scrollController.hasClients ? _scrollController.position.viewportDimension.toStringAsFixed(1) : "нет"}');
    buffer.writeln('fontSize: $_fontSize, lineHeight: $_lineHeight, theme: ${_currentTheme.typeString}');
    if (_paragraphs.isNotEmpty) {
      buffer.writeln('--- Первый параграф:');
      buffer.writeln('pos: ${_paragraphs.first.position}, text: "${_paragraphs.first.content.substring(0, _paragraphs.first.content.length > 50 ? 50 : _paragraphs.first.content.length)}"');
      buffer.writeln('--- Последний параграф:');
      buffer.writeln('pos: ${_paragraphs.last.position}, text: "${_paragraphs.last.content.substring(0, _paragraphs.last.content.length > 50 ? 50 : _paragraphs.last.content.length)}"');
      if (_targetParagraphIndex != null && _targetParagraphIndex! >= 0 && _targetParagraphIndex! < _paragraphs.length) {
        final t = _paragraphs[_targetParagraphIndex!];
        buffer.writeln('--- Цитата:');
        buffer.writeln('pos: ${t.position}, text: "${t.content.substring(0, t.content.length > 50 ? 50 : t.content.length)}"');
      }
    }
    Clipboard.setData(ClipboardData(text: buffer.toString()));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Диагностика скопирована!'), backgroundColor: Colors.green),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _effectiveBackgroundColor,
      body: SafeArea(
        child: _isLoading
            ? _buildLoadingState()
            : _error != null
                ? _buildErrorState()
                : _buildFullTextContent(),
      ),
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
              color: _effectiveTextColor,
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
              style: TextStyle(fontSize: 16, color: _effectiveTextColor),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(
                    'Назад',
                    style: TextStyle(color: _effectiveTextColor.withOpacity(0.7)),
                  ),
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
    return Stack(
      children: [
        Column(
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
        ),
        if (!_autoScrollCompleted && !_findingQuote)
          Positioned(
            bottom: 24,
            right: 24,
            child: FloatingActionButton.extended(
              onPressed: _findQuoteManually,
              icon: const Icon(Icons.search),
              label: const Text('Найти цитату'),
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
        border: Border(
          bottom: BorderSide(color: _currentTheme.borderColor, width: 1),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: Icon(Icons.arrow_back, color: _effectiveTextColor),
            tooltip: 'Назад',
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _bookSource?.title ?? 'Книга',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: _effectiveTextColor,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  _bookSource?.author ?? 'Автор',
                  style: TextStyle(
                    fontSize: 14,
                    color: _effectiveTextColor.withOpacity(0.7),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: _copyDebugInfo,
            icon: Icon(Icons.bug_report, color: _effectiveTextColor),
            tooltip: 'Скопировать диагностику',
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
            icon: Icon(
              _showSettings ? Icons.close : Icons.settings,
              color: _effectiveTextColor,
            ),
            tooltip: 'Настройки чтения',
          ),
        ],
      ),
    );
  }

  Widget _buildReadingSettings() {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.3,
      ),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.all(24.0),
        decoration: BoxDecoration(
          color: _currentTheme.cardColor,
          borderRadius: const BorderRadius.only(
            bottomLeft: Radius.circular(16),
            bottomRight: Radius.circular(16),
          ),
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Настройки чтения',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: _effectiveTextColor,
                ),
              ),
              const SizedBox(height: 24),
              
              // Размер шрифта
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Размер текста',
                    style: TextStyle(color: _effectiveTextColor),
                  ),
                  Row(
                    children: [
                      IconButton(
                        onPressed: _fontSize > 12 ? () => _adjustFontSize(-1) : null,
                        icon: const Icon(Icons.remove),
                        color: _effectiveTextColor,
                      ),
                      Text(
                        '${_fontSize.toInt()}px',
                        style: TextStyle(
                          color: _effectiveTextColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      IconButton(
                        onPressed: _fontSize < 24 ? () => _adjustFontSize(1) : null,
                        icon: const Icon(Icons.add),
                        color: _effectiveTextColor,
                      ),
                    ],
                  ),
                ],
              ),
              
              // Интерлиньяж
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Межстрочный интервал',
                    style: TextStyle(color: _effectiveTextColor),
                  ),
                  Row(
                    children: [
                      IconButton(
                        onPressed: _lineHeight > 1.2 ? () => _adjustLineHeight(-0.1) : null,
                        icon: const Icon(Icons.compress),
                        color: _effectiveTextColor,
                      ),
                      Text(
                        '${_lineHeight.toStringAsFixed(1)}x',
                        style: TextStyle(
                          color: _effectiveTextColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      IconButton(
                        onPressed: _lineHeight < 2.0 ? () => _adjustLineHeight(0.1) : null,
                        icon: const Icon(Icons.expand),
                        color: _effectiveTextColor,
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextContent() {
    if (_paragraphs.isEmpty) {
      return Center(
        child: Text(
          'Нет текста для отображения',
          style: TextStyle(color: _effectiveTextColor),
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      physics: const ClampingScrollPhysics(),
      itemCount: _paragraphs.length,
      itemBuilder: (context, index) => _buildParagraph(index),
    );
  }

  Widget _buildParagraph(int index) {
    final paragraph = _paragraphs[index];
    final key = _paragraphKeys[index];
    if (TextFileService.isHeader(paragraph.content)) {
      return const SizedBox.shrink();
    }
    if (paragraph.isQuote) {
      return Container(
        key: key,
        margin: const EdgeInsets.symmetric(vertical: 12.0),
        padding: const EdgeInsets.all(16.0),
        decoration: BoxDecoration(
          color: _currentTheme.quoteHighlightColor.withOpacity(0.15),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _currentTheme.quoteHighlightColor,
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: _currentTheme.quoteHighlightColor.withOpacity(0.2),
              blurRadius: 12,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.format_quote,
                  color: _currentTheme.quoteHighlightColor,
                  size: 24,
                ),
                const SizedBox(width: 8),
                Text(
                  'Цитата дня',
                  style: TextStyle(
                    color: _currentTheme.quoteHighlightColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SelectableText(
              paragraph.content,
              style: TextStyle(
                fontSize: _fontSize + 2,
                height: _lineHeight,
                color: _effectiveTextColor,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }
    if (paragraph.isContext) {
      return Container(
        key: key,
        margin: const EdgeInsets.symmetric(vertical: 6.0),
        padding: const EdgeInsets.all(12.0),
        decoration: BoxDecoration(
          color: _currentTheme.contextHighlightColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _currentTheme.contextHighlightColor.withOpacity(0.3),
            width: 1,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              margin: const EdgeInsets.only(top: 8, right: 12),
              width: 3,
              height: 20,
              decoration: BoxDecoration(
                color: _currentTheme.quoteHighlightColor.withOpacity(0.6),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Expanded(
              child: SelectableText(
                paragraph.content,
                style: TextStyle(
                  fontSize: _fontSize,
                  height: _lineHeight,
                  color: _effectiveTextColor.withOpacity(0.9),
                ),
              ),
            ),
          ],
        ),
      );
    }
    return Container(
      key: key,
      margin: const EdgeInsets.only(bottom: 8.0),
      child: SelectableText(
        paragraph.content,
        style: TextStyle(
          fontSize: _fontSize,
          height: _lineHeight,
          color: _effectiveTextColor,
        ),
      ),
    );
  }

  void _findQuoteManually() async {
    if (_targetParagraphIndex == null) return;
    setState(() => _findingQuote = true);
    for (int i = _targetParagraphIndex!; i < _paragraphs.length; i++) {
      final key = _paragraphKeys[i];
      if (key != null && key.currentContext != null) {
        final box = key.currentContext!.findRenderObject() as RenderBox?;
        if (box != null && box.hasSize) {
          final offset = _paragraphOffsets[i] ?? 0.0;
          await _scrollController.animateTo(
            offset,
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeInOut,
          );
          await Future.delayed(const Duration(milliseconds: 200));
          // Проверяем, видна ли цитата
          if (i == _targetParagraphIndex) break;
        }
      }
    }
    setState(() {
      _autoScrollCompleted = true;
      _findingQuote = false;
    });
    _showScrollHint();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _fadeController.dispose();
    _settingsController.dispose();
    super.dispose();
  }
}

// Класс для представления параграфа
class TextParagraph {
  final int position;
  final String content;
  final int displayIndex;
  bool isQuote;
  bool isContext;

  TextParagraph({
    required this.position,
    required this.content,
    required this.displayIndex,
    this.isQuote = false,
    this.isContext = false,
  });
}