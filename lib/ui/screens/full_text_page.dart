// lib/ui/screens/full_text_page.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/quote_context.dart';
import '../../models/book_source.dart';
import '../../services/text_file_service.dart';


class _SearchProgressWidget extends StatefulWidget {
  const _SearchProgressWidget();

  @override
  State<_SearchProgressWidget> createState() => _SearchProgressWidgetState();
}

class _SearchProgressWidgetState extends State<_SearchProgressWidget>
    with TickerProviderStateMixin {
  late AnimationController _scanController;
  late AnimationController _progressController;
  late Animation<double> _scanAnimation;
  late Animation<double> _progressAnimation;

  final List<String> _searchSteps = [
    'Загрузка документа',
    'Анализ структуры',
    'Поиск совпадений',
    'Определение позиции',
    'Готово',
  ];

  int _currentStep = 0;

  @override
  void initState() {
    super.initState();
    
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
            child: Text(
              _currentStep < _searchSteps.length ? _searchSteps[_currentStep] : 'Завершено',
              key: ValueKey(_currentStep),
              style: TextStyle(
                color: Colors.white.withOpacity(0.8),
                fontSize: 12,
                fontWeight: FontWeight.w400,
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
                            Colors.
transparent,
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


class FullTextPage extends StatefulWidget {
  final QuoteContext context; // ← ИСПРАВЛЕНО: правильный тип

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

      // Загружаем полный текст
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
      final paragraphs = _textService.extractParagraphsWithPositions(_fullText!);
      final targetParagraph = paragraphs.firstWhere(
        (p) => p['position'] == widget.context.quote.position,
        orElse: () => {},
      );

      if (targetParagraph.isNotEmpty) {
        // Находим приблизительную позицию в тексте
        final targetText = targetParagraph['content'] as String;
        final fullTextClean = _fullText!.replaceAll(RegExp(r'\[pos:\d+\]\s*'), '');
        final index = fullTextClean.indexOf(targetText);
        
        if (index != -1) {
          // Вычисляем приблизительную позицию скролла
          final totalLength = fullTextClean.length;
          final progress = index / totalLength;
          final maxScroll = _scrollController.position.maxScrollExtent;
          final targetScroll = (maxScroll * progress) - (MediaQuery.of(context).size.height * 0.5);

          // Показываем плавный индикатор поиска
showDialog(
  context: context,
  barrierDismissible: false,
  builder: (context) => Center(
    child: Container(
      margin: const EdgeInsets.all(40),
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.95),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.8),
            blurRadius: 24,
            spreadRadius: 8,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Заголовок
          Text(
            'Поиск по тексту',
            style: TextStyle(
              color: Colors.white.withOpacity(0.9),
              fontSize: 16,
              fontWeight: FontWeight.w500,
              letterSpacing: 0.5,
            ),
          ),
          
          const SizedBox(height: 24),
          
          // Анимированная панель поиска
          Container(
            height: 80,
            width: 240,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.03),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.white.withOpacity(0.1)),
            ),
            child: const _SearchProgressWidget(),
          ),
          
          const SizedBox(height: 20),
          
          // Статус
          Text(
            'Анализ структуры документа...',
            style: TextStyle(
              color: Colors.white.withOpacity(0.6),
              fontSize: 13,
              fontWeight: FontWeight.w300,
            ),
          ),
        ],
      ),
    ),
  ),
);
// Плавная прокрутка
await _scrollController.animateTo(
  targetScroll - (MediaQuery.of(context).size.height * 0.35),
  duration: const Duration(milliseconds: 1800),
  curve: Curves.easeInOutCubic,
);

// Закрываем диалог
if (mounted) Navigator.of(context).pop();

          _autoScrolled = true;
          
          // Показываем подсказку
          if (mounted) {
          
          }
        }
      }
    } catch (e) {
      print('Error during auto-scroll: $e');
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
                onPressed: _scrollToQuote,
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
  
  return RepaintBoundary( // ДОБАВИТЬ
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: paragraphs.map((paragraph) {
        final isQuoteParagraph = paragraph['position'] == widget.context.quote.position;
        
        return Container(
          key: isQuoteParagraph ? _targetKey : null,
          margin: const EdgeInsets.only(bottom: 16.0),
          padding: isQuoteParagraph ? const EdgeInsets.all(16.0) : EdgeInsets.zero,
          decoration: isQuoteParagraph
              ? BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: Colors.white.withOpacity(0.05),
                  border: Border(
                    left: BorderSide(
                      color: Colors.white.withOpacity(0.3),
                      width: 3,
                    ),
                  ),
                )
              : null,
          child: RichText(
            text: TextSpan(
              style: TextStyle(
                fontSize: _fontSize,
                height: _lineHeight,
                color: Theme.of(context).textTheme.bodyLarge?.color,
                fontWeight: isQuoteParagraph ? FontWeight.w500 : FontWeight.w400,
              ),
              children: isQuoteParagraph
                  ? _highlightQuoteInParagraph(paragraph['content'] as String)
                  : [TextSpan(text: paragraph['content'] as String)],
            ),
          ),
        );
      }).toList(),
    ), // ДОБАВИТЬ закрывающую скобку RepaintBoundary
  );
}

  List<TextSpan> _highlightQuoteInParagraph(String text) {
    final quoteText = widget.context.quote.text.toLowerCase();
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
    
    // Сама цитата (сильно выделенная)
    spans.add(TextSpan(
  text: text.substring(index, index + quoteText.length),
  style: TextStyle(
    backgroundColor: Colors.orange.withOpacity(0.4),
    fontWeight: FontWeight.w800,
    fontSize: _fontSize + 3, // Больше размер
    color: Colors.white,
    shadows: [
      Shadow(
        color: Colors.orange.withOpacity(0.8),
        blurRadius: 8,
        offset: const Offset(0, 0),
      ),
    ],
  ),
));
    
    // Текст после цитаты
    if (index + quoteText.length < text.length) {
      spans.add(TextSpan(text: text.substring(index + quoteText.length)));
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