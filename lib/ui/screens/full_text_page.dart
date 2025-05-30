// lib/ui/screens/full_text_page.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  final GlobalKey _targetKey = GlobalKey();

  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  String? _fullText;
  BookSource? _bookSource;
  bool _isLoading = true;
  String? _error;
  bool _autoScrolled = false;
  double _fontSize = 16.0;
  double _lineHeight = 1.6;
  bool _showSettings = false;

  // Цветовая схема для темной темы
  static const Color _highlightColor = Color(0xFF64B5F6); // Современный синий
  static const Color _accentColor = Color(0xFF90CAF9); // Светлее синий для акцентов
  static const Color _contextColor = Color(0xFF1E3A8A); // Темно-синий для контекста

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
    });

    try {
      // Находим источник книги
      final sources = await _textService.loadBookSources();
      final source = sources.firstWhere(
        (s) => s.author == widget.context.quote.author && 
               s.title == widget.context.quote.source,
        orElse: () => throw Exception('Book source not found'),
      );

      // Загружаем полный текст (используем raw версию для поиска)
      final rawText = await _textService.loadTextFile(source.rawFilePath);

      setState(() {
        _bookSource = source;
        _fullText = rawText;
        _isLoading = false;
      });

      _fadeController.forward();
      _scheduleAutoScroll();
      
    } catch (e) {
      setState(() {
        _error = 'Ошибка загрузки полного текста: $e';
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

      // Ищем позицию цитаты более точно
      final quotePosition = _findQuotePosition();
      
      if (quotePosition != -1) {
        // Подсчитываем количество символов до позиции цитаты
        final textBeforeQuote = _fullText!.substring(0, quotePosition);
        final lines = textBeforeQuote.split('\n').length;
        
        // Приблизительная высота одной строки с учетом размера шрифта и интервала
        final lineHeight = _fontSize * _lineHeight;
        final approximateScrollPosition = (lines * lineHeight) - (MediaQuery.of(context).size.height * 0.4);
        
        // Ограничиваем скролл в допустимых пределах
        final maxScroll = _scrollController.position.maxScrollExtent;
        final targetScroll = approximateScrollPosition.clamp(0.0, maxScroll);
        
        await _scrollController.animateTo(
          targetScroll,
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

  int _findQuotePosition() {
    if (_fullText == null) return -1;
    
    final normalizedQuote = _normalizeText(widget.context.quote.text);
    final normalizedFullText = _normalizeText(_fullText!);
    
    // Пробуем найти полную цитату
    int position = normalizedFullText.indexOf(normalizedQuote);
    
    if (position == -1) {
      // Пробуем найти по первым 5 словам
      final quoteWords = normalizedQuote.split(' ');
      if (quoteWords.length > 3) {
        final firstWords = quoteWords.take(5).join(' ');
        position = normalizedFullText.indexOf(firstWords);
      }
    }
    
    // Конвертируем позицию из нормализованного текста в оригинальный
    if (position != -1) {
      // Это приблизительная конвертация, но для скролла достаточно точная
      final ratio = position / normalizedFullText.length;
      return (ratio * _fullText!.length).round();
    }
    
    return -1;
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
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text(
            'Загружаем полный текст...',
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
                  _autoScrolled = false;
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
    final paragraphs = _textService.extractParagraphsWithPositions(_fullText!);
    
    return RepaintBoundary(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: paragraphs.map((paragraph) {
          final paragraphText = paragraph['content'] as String;
          final paragraphPosition = paragraph['position'] as int;
          
          // Проверяем, содержит ли абзац нашу цитату
          final containsQuote = _paragraphContainsQuote(paragraphText);
          
          // Проверяем контекстные абзацы более точно
          final isContextParagraph = !containsQuote && _isRealContextParagraph(paragraphs, paragraph);
          
          // Определяем стиль оформления только для специальных абзацев
          BoxDecoration? decoration;
          EdgeInsets padding = EdgeInsets.zero;
          
          if (containsQuote) {
            // Это абзац с цитатой - яркое выделение
            decoration = BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: _highlightColor.withOpacity(0.15),
              border: Border.all(
                color: _highlightColor,
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: _highlightColor.withOpacity(0.2),
                  blurRadius: 8,
                  spreadRadius: 1,
                ),
              ],
            );
            padding = const EdgeInsets.all(20.0);
          } else if (isContextParagraph) {
            // Это контекстный абзац - легкое выделение
            decoration = BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              color: _contextColor.withOpacity(0.1),
              border: Border.all(
                color: _contextColor.withOpacity(0.3),
                width: 1,
              ),
            );
            padding = const EdgeInsets.all(12.0);
          }
          
          return Container(
            margin: const EdgeInsets.only(bottom: 16.0),
            padding: padding,
            decoration: decoration,
            child: RichText(
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
          );
        }).toList(),
      ),
    );
  }

  // Более точная проверка контекстных абзацев
  bool _isRealContextParagraph(List<Map<String, dynamic>> allParagraphs, Map<String, dynamic> currentParagraph) {
    final currentIndex = allParagraphs.indexOf(currentParagraph);
    
    // Ищем абзац с цитатой
    int quoteIndex = -1;
    for (int i = 0; i < allParagraphs.length; i++) {
      if (_paragraphContainsQuote(allParagraphs[i]['content'] as String)) {
        quoteIndex = i;
        break;
      }
    }
    
    if (quoteIndex == -1) return false;
    
    // Контекстными считаем только ближайшие 1-2 абзаца до и после цитаты
    final distance = (currentIndex - quoteIndex).abs();
    return distance <= 2 && distance > 0;
  }

  // Вспомогательный метод для проверки наличия цитаты
  bool _paragraphContainsQuote(String paragraphText) {
    final normalizedParagraph = _normalizeText(paragraphText);
    final normalizedQuote = _normalizeText(widget.context.quote.text);
    
    // Пробуем найти полную цитату
    if (normalizedParagraph.contains(normalizedQuote)) {
      return true;
    }
    
    // Пробуем найти по первым словам (если цитата длинная)
    final quoteWords = normalizedQuote.split(' ');
    if (quoteWords.length > 5) {
      final firstWords = quoteWords.take(5).join(' ');
      if (normalizedParagraph.contains(firstWords)) {
        return true;
      }
    }
    
    // Проверяем по последним словам тоже
    if (quoteWords.length > 5) {
      final lastWords = quoteWords.skip(quoteWords.length - 5).join(' ');
      if (normalizedParagraph.contains(lastWords)) {
        return true;
      }
    }
    
    return false;
  }
  
  // Нормализация текста для сравнения
  String _normalizeText(String text) {
    return text.toLowerCase()
        .replaceAll(RegExp(r'[^\w\s]'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  List<TextSpan> _highlightQuoteInParagraph(String text) {
    final quoteText = widget.context.quote.text;
    
    // Пробуем найти точное совпадение
    int index = text.indexOf(quoteText);
    
    if (index == -1) {
      // Пробуем найти без знаков препинания
      final cleanQuote = quoteText.replaceAll(RegExp(r'[^\w\s]'), '');
      final cleanText = text.replaceAll(RegExp(r'[^\w\s]'), '');
      final cleanIndex = cleanText.indexOf(cleanQuote);
      
      if (cleanIndex != -1) {
        // Находим приблизительную позицию в оригинальном тексте
        index = cleanIndex;
      }
    }
    
    if (index == -1) {
      // Последняя попытка - по первым словам
      final firstWords = quoteText.split(' ').take(3).join(' ');
      index = text.indexOf(firstWords);
      
      if (index != -1) {
        return _createHighlightedSpans(text, index, firstWords.length);
      }
      
      return [TextSpan(text: text)];
    }

    return _createHighlightedSpans(text, index, quoteText.length);
  }

  List<TextSpan> _createHighlightedSpans(String text, int startIndex, int length) {
    final spans = <TextSpan>[];
    
    if (startIndex > 0) {
      spans.add(TextSpan(text: text.substring(0, startIndex)));
    }
    
    spans.add(TextSpan(
      text: text.substring(startIndex, startIndex + length),
      style: TextStyle(
        backgroundColor: _accentColor.withOpacity(0.3),
        fontWeight: FontWeight.w900,
        fontSize: _fontSize + 2,
        color: _accentColor,
        decoration: TextDecoration.underline,
        decorationColor: _accentColor,
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