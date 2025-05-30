// lib/ui/screens/full_text_page.dart
import 'package:flutter/material.dart';
import '../../models/quote_context.dart';
import '../../models/book_source.dart';
import '../../services/text_file_service.dart';

class FullTextPage extends StatefulWidget {
  final QuoteContext context;

  const FullTextPage({
    super.key,
    required this.context,
  });

  @override
  State<FullTextPage> createState() => _FullTextPageState();
}

class _FullTextPageState extends State<FullTextPage> 
    with TickerProviderStateMixin {
  final TextFileService _textService = TextFileService();
  final ScrollController _scrollController = ScrollController();

  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  String? _fullText;
  BookSource? _bookSource;
  bool _isLoading = true;
  String? _error;
  String? _debugInfo; // Добавляем отладочную информацию
  bool _autoScrolled = false;
  double _fontSize = 16.0;
  double _lineHeight = 1.6;
  bool _showSettings = false;
  bool _showDebugInfo = false; // Добавляем флаг для отладки

  // Определяем цвета в зависимости от темы
  Color get _highlightColor {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark ? Colors.white : const Color(0xFF64B5F6); // Белый в темной, синий в светлой
  }
  
  Color get _accentColor {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark ? Colors.white : const Color(0xFF90CAF9);
  }
  
  Color get _contextColor {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark ? Colors.white : const Color(0xFF1E3A8A);
  }

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _loadFullText();
  }

  void _initializeAnimations() {
    _fadeController = AnimationController(
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
  }

  Future<void> _loadFullText() async {
    setState(() {
      _isLoading = true;
      _error = null;
      _debugInfo = "Начинаем загрузку...";
    });

    try {
      setState(() => _debugInfo = "Загружаем источники книг...");
      // Находим источник книги
      final sources = await _textService.loadBookSources();
      
      setState(() => _debugInfo = "Найдено источников: ${sources.length}. Ищем: ${widget.context.quote.author} - ${widget.context.quote.source}");
      final source = sources.firstWhere(
        (s) => s.author == widget.context.quote.author && 
               s.title == widget.context.quote.source,
        orElse: () => throw Exception('Book source not found'),
      );
      
      setState(() => _debugInfo = "Источник найден: ${source.title}. Загружаем файл: ${source.cleanedFilePath}");

      // Загружаем cleaned версию для отображения (без маркеров)
      final cleanedText = await _textService.loadTextFile(source.cleanedFilePath);
      
      setState(() => _debugInfo = "Текст загружен, длина: ${cleanedText.length} символов");

      setState(() {
        _bookSource = source;
        _fullText = cleanedText; // Используем cleaned версию
        _isLoading = false;
        _debugInfo = null; // Убираем отладку после успешной загрузки
      });

      _fadeController.forward();
      _scheduleAutoScroll();
      
    } catch (e) {
      setState(() {
        _error = 'Ошибка загрузки полного текста: $e';
        _debugInfo = 'ОШИБКА: $e';
        _isLoading = false;
      });
    }
  }

  void _scheduleAutoScroll() {
    // Автопрокрутка к цитате через небольшую задержку
    Future.delayed(const Duration(milliseconds: 800), () {
      if (mounted && !_autoScrolled) {
        _scrollToQuote();
      }
    });
  }

  void _scrollToQuote() async {
    if (_fullText == null || _autoScrolled) return;

    try {
      // Показываем диалог поиска
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => Material(
          color: Colors.transparent,
          child: Center(
            child: Container(
              margin: const EdgeInsets.all(40),
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.95),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withOpacity(0.08)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Поиск по тексту',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.9),
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      decoration: TextDecoration.none,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Container(
                    height: 80,
                    width: 240,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.03),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.white.withOpacity(0.1)),
                    ),
                    child: _SearchProgressWidget(context: widget.context),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      // Ждем завершения анимации
      await Future.delayed(const Duration(milliseconds: 2500));

      // Ищем позицию цитаты
      final normalizedQuote = _normalizeText(widget.context.quote.text);
      final normalizedFullText = _normalizeText(_fullText!);
      
      final quoteIndex = normalizedFullText.indexOf(normalizedQuote);
      
      if (quoteIndex != -1) {
        // Вычисляем примерную позицию скролла
        final progress = quoteIndex / normalizedFullText.length;
        final maxScroll = _scrollController.position.maxScrollExtent;
        final targetScroll = (maxScroll * progress) - 200; // Отступ от верха
        
        await _scrollController.animateTo(
          targetScroll.clamp(0.0, maxScroll),
          duration: const Duration(milliseconds: 1200),
          curve: Curves.easeInOutCubic,
        );
      }

      if (mounted) Navigator.of(context).pop();
      _autoScrolled = true;

    } catch (e) {
      print('Scroll error: $e');
      if (mounted) Navigator.of(context).pop();
    }
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
                : _buildFullTextContent(),
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
          const Text(
            'Загружаем полный текст...',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w300,
            ),
          ),
          if (_debugInfo != null) ...[
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.symmetric(horizontal: 20),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _debugInfo!,
                style: const TextStyle(
                  fontSize: 12,
                  fontFamily: 'monospace',
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
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
                  onPressed: _loadFullText,
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
        // Header
        _buildHeader(),
        
        // Настройки чтения (если открыты)
        if (_showSettings) _buildReadingSettings(),
        
        // Отладочная информация (только если включена)
        if (_showDebugInfo) _buildDebugInfo(),
        
        // Полный текст
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
        color: Theme.of(context).cardColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                onPressed: _goBack,
                icon: const Icon(Icons.arrow_back),
                tooltip: 'Назад',
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _bookSource?.title ?? 'Полный текст',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      _bookSource?.author ?? '',
                      style: TextStyle(
                        fontSize: 14,
                        color: Theme.of(context).textTheme.bodySmall?.color,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              // Кнопка отладки
              IconButton(
                onPressed: () {
                  setState(() {
                    _showDebugInfo = !_showDebugInfo;
                  });
                },
                icon: Icon(_showDebugInfo ? Icons.bug_report : Icons.bug_report_outlined),
                tooltip: 'Отладка',
              ),
              IconButton(
                onPressed: () {
                  setState(() {
                    _showSettings = !_showSettings;
                  });
                },
                icon: Icon(_showSettings ? Icons.close : Icons.settings),
                tooltip: 'Настройки чтения',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDebugInfo() {
    if (_fullText == null) return const SizedBox.shrink();
    
    final quoteToFind = widget.context.quote.text;
    final normalizedQuote = _normalizeText(quoteToFind);
    final normalizedFullText = _normalizeText(_fullText!);
    final foundIndex = normalizedFullText.indexOf(normalizedQuote);
    
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Colors.blue.withOpacity(0.1),
        border: Border(
          top: BorderSide(
            color: Theme.of(context).dividerColor,
            width: 1,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.bug_report, size: 16),
              const SizedBox(width: 8),
              const Text(
                'Отладочная информация',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          Text(
            'ФАЙЛ: ${_bookSource?.cleanedFilePath ?? "неизвестно"}',
            style: const TextStyle(fontSize: 12),
          ),
          const SizedBox(height: 8),
          Text(
            'ПЕРВЫЕ 200 СИМВОЛОВ ФАЙЛА:\n"${_fullText!.substring(0, (_fullText!.length > 200 ? 200 : _fullText!.length))}"',
            style: const TextStyle(fontSize: 10, fontFamily: 'monospace'),
          ),
          const SizedBox(height: 8),
          
          Text(
            'ИЩЕМ ЦИТАТУ:\n"${quoteToFind.length > 100 ? quoteToFind.substring(0, 100) + "..." : quoteToFind}"',
            style: const TextStyle(fontSize: 11, fontFamily: 'monospace'),
          ),
          const SizedBox(height: 8),
          Text(
            'НОРМАЛИЗОВАННАЯ ЦИТАТА:\n"${normalizedQuote.length > 100 ? normalizedQuote.substring(0, 100) + "..." : normalizedQuote}"',
            style: const TextStyle(fontSize: 11, fontFamily: 'monospace'),
          ),
          const SizedBox(height: 8),
          Text(
            'РЕЗУЛЬТАТ ПОИСКА: ${foundIndex != -1 ? "НАЙДЕНО на позиции $foundIndex" : "НЕ НАЙДЕНО"}',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: foundIndex != -1 ? Colors.green : Colors.red,
            ),
          ),
          if (foundIndex != -1) ...[
            const SizedBox(height: 8),
            Text(
              'КОНТЕКСТ НАЙДЕННОГО:\n"${_fullText!.substring(
                (foundIndex - 50).clamp(0, _fullText!.length),
                (foundIndex + quoteToFind.length + 50).clamp(0, _fullText!.length)
              )}"',
              style: const TextStyle(fontSize: 10, fontFamily: 'monospace'),
            ),
          ],
          const SizedBox(height: 8),
          Text(
            'КОНТЕКСТНЫЕ АБЗАЦЫ: ${widget.context.contextParagraphs.length}',
            style: const TextStyle(fontSize: 12),
          ),
          if (widget.context.contextParagraphs.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              'ПЕРВЫЙ КОНТЕКСТ:\n"${widget.context.contextParagraphs.first.length > 80 ? widget.context.contextParagraphs.first.substring(0, 80) + "..." : widget.context.contextParagraphs.first}"',
              style: const TextStyle(fontSize: 10, fontFamily: 'monospace'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildReadingSettings() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        border: Border(
          top: BorderSide(
            color: Theme.of(context).dividerColor,
            width: 1,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Настройки чтения',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          
          // Размер шрифта
          Row(
            children: [
              const Text('Размер шрифта: '),
              IconButton(
                onPressed: () => _adjustFontSize(-1),
                icon: const Icon(Icons.remove_circle_outline),
              ),
              Text(
                '${_fontSize.toInt()}',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              IconButton(
                onPressed: () => _adjustFontSize(1),
                icon: const Icon(Icons.add_circle_outline),
              ),
            ],
          ),
          
          // Междустрочный интервал
          Row(
            children: [
              const Text('Интервал: '),
              IconButton(
                onPressed: () => _adjustLineHeight(-0.1),
                icon: const Icon(Icons.compress),
              ),
              Text(
                _lineHeight.toStringAsFixed(1),
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              IconButton(
                onPressed: () => _adjustLineHeight(0.1),
                icon: const Icon(Icons.expand),
              ),
            ],
          ),
          
          // Кнопки действий
          Row(
            children: [
              TextButton.icon(
                onPressed: () {
                  _scrollController.animateTo(
                    0,
                    duration: const Duration(milliseconds: 800),
                    curve: Curves.easeInOut,
                  );
                },
                icon: const Icon(Icons.vertical_align_top),
                label: const Text('К началу'),
              ),
              const SizedBox(width: 16),
              TextButton.icon(
                onPressed: () {
                  _autoScrolled = false; // Сбрасываем флаг
                  _scrollToQuote();
                },
                icon: const Icon(Icons.my_location),
                label: const Text('К цитате'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTextContent() {
    if (_fullText == null) return const SizedBox.shrink();

    return GestureDetector(
      onVerticalDragEnd: (details) {
        // Свайп вниз для возврата
        if (details.primaryVelocity != null && details.primaryVelocity! > 500) {
          _goBack();
        }
      },
      child: SingleChildScrollView(
        controller: _scrollController,
        padding: const EdgeInsets.all(24.0),
        physics: const BouncingScrollPhysics(),
        child: _buildFormattedText(),
      ),
    );
  }

  Widget _buildFormattedText() {
    if (_fullText == null) return const SizedBox.shrink();
    
    try {
      final paragraphs = _textService.extractParagraphsWithPositions(_fullText!);
      
      if (paragraphs.isEmpty) {
        // Fallback - простое разделение на абзацы
        final simpleParagraphs = _fullText!.split('\n\n').where((p) => p.trim().isNotEmpty).toList();
        
        return RepaintBoundary(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Показываем предупреждение только в режиме отладки
              if (_showDebugInfo)
                Container(
                  padding: const EdgeInsets.all(16),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'ОТЛАДКА: extractParagraphsWithPositions вернул пустой массив. Используем простое разделение. Найдено абзацев: ${simpleParagraphs.length}',
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              ...simpleParagraphs.map((paragraphText) {
                return Container(
                  margin: const EdgeInsets.only(bottom: 16.0),
                  child: Text(
                    paragraphText.trim(),
                    style: TextStyle(
                      fontSize: _fontSize,
                      height: _lineHeight,
                      color: Theme.of(context).textTheme.bodyLarge?.color,
                    ),
                  ),
                );
              }).toList(),
            ],
          ),
        );
      }
      
      return RepaintBoundary(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: paragraphs.map((paragraph) {
            final paragraphText = paragraph['content'] as String;
            
            // Проверяем, содержит ли абзац нашу цитату
            final containsQuote = _paragraphContainsQuote(paragraphText);
            
            // Проверяем контекст только если нет цитаты И контекст не пустой
            final isContextParagraph = !containsQuote && 
                widget.context.contextParagraphs.isNotEmpty &&
                widget.context.contextParagraphs.any((contextPar) => 
                  contextPar.trim().isNotEmpty &&
                  (_normalizeText(contextPar).contains(_normalizeText(paragraphText)) ||
                   _normalizeText(paragraphText).contains(_normalizeText(contextPar)))
                );
            
            // Определяем стиль оформления
            BoxDecoration? decoration;
            EdgeInsets padding = EdgeInsets.zero;
            
            if (containsQuote) {
              // Это абзац с цитатой - самое яркое выделение
              final isDark = Theme.of(context).brightness == Brightness.dark;
              decoration = BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: _highlightColor.withOpacity(isDark ? 0.08 : 0.15),
                border: Border.all(
                  color: _highlightColor.withOpacity(isDark ? 0.3 : 1.0),
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: _highlightColor.withOpacity(isDark ? 0.1 : 0.2),
                    blurRadius: 8,
                    spreadRadius: 1,
                  ),
                ],
              );
              padding = const EdgeInsets.all(20.0);
            } else if (isContextParagraph) {
              // Это контекстный абзац - легкое выделение
              final isDark = Theme.of(context).brightness == Brightness.dark;
              decoration = BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                color: _contextColor.withOpacity(isDark ? 0.04 : 0.1),
                border: Border.all(
                  color: _contextColor.withOpacity(isDark ? 0.15 : 0.3),
                  width: 1,
                ),
              );
              padding = const EdgeInsets.all(12.0);
            }
            
            return Container(
              margin: const EdgeInsets.only(bottom: 16.0),
              padding: padding,
              decoration: decoration,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Показываем отладку для каждого абзаца только в режиме отладки
                  if (_showDebugInfo && (containsQuote || isContextParagraph))
                    Container(
                      padding: const EdgeInsets.all(8),
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(
                        color: containsQuote ? Colors.green.withOpacity(0.1) : Colors.yellow.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        containsQuote ? '✅ ЦИТАТА НАЙДЕНА' : '📝 КОНТЕКСТНЫЙ АБЗАЦ',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: containsQuote ? Colors.green : Colors.orange,
                        ),
                      ),
                    ),
                  
                  // Сам текст абзаца
                  RichText(
                    text: TextSpan(
                      style: TextStyle(
                        fontSize: _fontSize,
                        height: _lineHeight,
                        color: Theme.of(context).textTheme.bodyLarge?.color,
                        fontWeight: containsQuote ? FontWeight.w600 : FontWeight.w400,
                      ),
                      children: containsQuote
                          ? _highlightQuoteInParagraph(paragraphText)
                          : [TextSpan(text: paragraphText)],
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      );
      
    } catch (e) {
      return Center(
        child: Container(
          padding: const EdgeInsets.all(16),
          margin: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.red.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'ОШИБКА В _buildFormattedText:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                '$e',
                style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
              ),
            ],
          ),
        ),
      );
    }
  }

  // Вспомогательный метод для проверки наличия цитаты
  bool _paragraphContainsQuote(String paragraphText) {
    final normalizedParagraph = _normalizeText(paragraphText);
    final normalizedQuote = _normalizeText(widget.context.quote.text);
    
    // Проверяем минимальную длину
    if (normalizedQuote.length < 10) return false;
    
    // Пробуем найти полную цитату
    if (normalizedParagraph.contains(normalizedQuote)) {
      return true;
    }
    
    // Пробуем найти по первым 5+ словам (если цитата длинная)
    final quoteWords = normalizedQuote.split(' ');
    if (quoteWords.length >= 5) {
      final firstWords = quoteWords.take(5).join(' ');
      if (firstWords.length > 15 && normalizedParagraph.contains(firstWords)) {
        return true;
      }
    }
    
    return false;
  }
  
  // Нормализация текста для сравнения (менее агрессивная)
  String _normalizeText(String text) {
    return text.toLowerCase()
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
  }

  List<TextSpan> _highlightQuoteInParagraph(String text) {
    final quoteText = widget.context.quote.text;
    
    // Сначала пробуем точное совпадение
    int index = text.indexOf(quoteText);
    
    if (index != -1) {
      return _createHighlightedSpans(text, index, quoteText.length);
    }
    
    // Пробуем нормализованный поиск
    final normalizedText = _normalizeText(text);
    final normalizedQuote = _normalizeText(quoteText);
    
    final normalizedIndex = normalizedText.indexOf(normalizedQuote);
    if (normalizedIndex != -1) {
      // Пытаемся найти соответствующую позицию в оригинальном тексте
      // Это приблизительная конвертация
      final ratio = normalizedIndex / normalizedText.length;
      final approximateIndex = (ratio * text.length).round();
      
      // Ищем ближайшее слово
      final words = text.split(' ');
      int currentPos = 0;
      for (int i = 0; i < words.length; i++) {
        if (currentPos >= approximateIndex) {
          // Берем несколько слов начиная с этой позиции
          final wordsToHighlight = words.skip(i).take(5).join(' ');
          final wordIndex = text.indexOf(wordsToHighlight, currentPos);
          if (wordIndex != -1) {
            return _createHighlightedSpans(text, wordIndex, wordsToHighlight.length);
          }
          break;
        }
        currentPos += words[i].length + 1; // +1 для пробела
      }
    }
    
    // Если ничего не нашли, возвращаем текст без выделения
    return [TextSpan(text: text)];
  }

  List<TextSpan> _createHighlightedSpans(String text, int startIndex, int length) {
    final spans = <TextSpan>[];
    
    if (startIndex > 0) {
      spans.add(TextSpan(text: text.substring(0, startIndex)));
    }
    
    spans.add(TextSpan(
      text: text.substring(startIndex, startIndex + length),
      style: TextStyle(
        backgroundColor: _accentColor.withOpacity(0.15),
        fontWeight: FontWeight.w900,
        fontSize: _fontSize + 2,
        color: _accentColor.withOpacity(Theme.of(context).brightness == Brightness.dark ? 0.9 : 1.0),
        decoration: TextDecoration.underline,
        decorationColor: _accentColor.withOpacity(0.6),
        decorationThickness: 2,
      ),
    ));
    
    if (startIndex + length < text.length) {
      spans.add(TextSpan(text: text.substring(startIndex + length)));
    }
    
    return spans;
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _scrollController.dispose();
    super.dispose();
  }
}

class _SearchProgressWidget extends StatefulWidget {
  final QuoteContext context;

  const _SearchProgressWidget({required this.context});

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
    
    // Генерируем шаги от общего к частному
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
          // Прогресс-бар
          Container(
            height: 2,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(1),
            ),
            child: AnimatedBuilder(
              animation: _progressAnimation,
              builder: (context, child) {
                return FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: _progressAnimation.value,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.8),
                      borderRadius: BorderRadius.circular(1),
                    ),
                  ),
                );
              },
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Текущий статус
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: Container(
              key: ValueKey(_currentStep),
              child: Text(
                _currentStep < _searchSteps.length ? _searchSteps[_currentStep] : 'Операция завершена',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.8),
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                  decoration: TextDecoration.none,
                ),
              ),
            ),
          ),
          
          const SizedBox(height: 12),
          
          // Сканирующая линия
          AnimatedBuilder(
            animation: _scanAnimation,
            builder: (context, child) {
              return Stack(
                children: [
                  Container(
                    height: 1,
                    width: double.infinity,
                    color: Colors.white.withOpacity(0.05),
                  ),
                  Positioned(
                    left: _scanAnimation.value * 200,
                    child: Container(
                      height: 1,
                      width: 40,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.transparent,
                            Colors.white.withOpacity(0.6),
                            Colors.transparent,
                          ],
                        ),
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