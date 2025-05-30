
// lib/ui/screens/full_text_page.dart
// lib/ui/screens/full_text_page.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/quote_context.dart';
import '../../models/book_source.dart';
import '../../models/reading_theme.dart';
import '../../services/text_file_service.dart';
import '../../utils/custom_cache.dart';

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
  final CustomCachePrefs _cache = CustomCache.prefs;

  late AnimationController _fadeController;
  late AnimationController _themeTransitionController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _themeTransitionAnimation;

  String? _fullText;
  BookSource? _bookSource;
  bool _isLoading = true;
  String? _error;
  bool _autoScrolled = false;
  double _fontSize = 16.0;
  double _lineHeight = 1.6;
  bool _showSettings = false;
  ReadingTheme _currentTheme = ReadingTheme.dark;

  @override
  void initState() {
    super.initState();
    _loadSavedTheme();
    _initializeAnimations();
    _loadFullText();
  }

  Future<void> _loadSavedTheme() async {
    final savedTheme = _cache.getSetting<String>('reading_theme') ?? 'dark';
    setState(() {
      _currentTheme = ReadingTheme.fromType(ReadingTheme.fromString(savedTheme));
    });
  }

  void _initializeAnimations() {
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _themeTransitionController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    ));

    _themeTransitionAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _themeTransitionController,
      curve: Curves.easeInOut,
    ));
  }

  Future<void> _changeTheme(ReadingTheme newTheme) async {
    if (newTheme.type == _currentTheme.type) return;
    
    // Запускаем анимацию перехода
    await _themeTransitionController.forward();
    
    setState(() {
      _currentTheme = newTheme;
    });
    
    // Сохраняем выбор темы
    await _cache.setSetting('reading_theme', newTheme.typeString);
    
    // Завершаем анимацию
    await _themeTransitionController.reverse();
  }

  Future<void> _loadFullText() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final sources = await _textService.loadBookSources();
      final source = sources.firstWhere(
        (s) => s.author == widget.context.quote.author && 
               s.title == widget.context.quote.source,
        orElse: () => throw Exception('Book source not found'),
      );

      final fullText = await _textService.loadTextFile(source.cleanedFilePath);

      setState(() {
        _bookSource = source;
        _fullText = fullText;
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
    Future.delayed(const Duration(milliseconds: 800), () {
      if (mounted && !_autoScrolled) {
        _scrollToQuote();
      }
    });
  }

  void _scrollToQuote() async {
    if (_fullText == null || _autoScrolled) return;

    try {
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
                color: _currentTheme.backgroundColor.withOpacity(0.95),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _currentTheme.borderColor),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Поиск по тексту',
                    style: TextStyle(
                      color: _currentTheme.textColor,
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
                      color: _currentTheme.highlightColor,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: _currentTheme.borderColor),
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

      await Future.delayed(const Duration(milliseconds: 2500));

      final normalizedQuote = _normalizeText(widget.context.quote.text);
      final normalizedFullText = _normalizeText(_fullText!);
      
      final quoteIndex = normalizedFullText.indexOf(normalizedQuote);
      
      if (quoteIndex != -1) {
        final progress = quoteIndex / normalizedFullText.length;
        final maxScroll = _scrollController.position.maxScrollExtent;
        final targetScroll = (maxScroll * progress) - 200;
        
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
    return AnimatedBuilder(
      animation: _themeTransitionAnimation,
      builder: (context, child) {
        return Scaffold(
          backgroundColor: _currentTheme.backgroundColor,
          body: SafeArea(
            child: AnimatedOpacity(
              opacity: 1.0 - _themeTransitionAnimation.value * 0.3,
              duration: const Duration(milliseconds: 400),
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
          CircularProgressIndicator(color: _currentTheme.textColor),
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
            Icon(
              Icons.error_outline,
              size: 64,
              color: _currentTheme.quoteHighlightColor,
            ),
            const SizedBox(height: 16),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: _currentTheme.textColor),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TextButton(
                  onPressed: _goBack,
                  child: Text('Назад', style: TextStyle(color: _currentTheme.textColor)),
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
        boxShadow: [
          BoxShadow(
            color: _currentTheme.borderColor.withOpacity(0.5),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: _goBack,
            icon: Icon(Icons.arrow_back, color: _currentTheme.textColor),
            tooltip: 'Назад',
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _bookSource?.title ?? 'Полный текст',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: _currentTheme.textColor,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  _bookSource?.author ?? '',
                  style: TextStyle(
                    fontSize: 14,
                    color: _currentTheme.textColor.withOpacity(0.7),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          // Селектор тем
          _buildThemeSelector(),
          const SizedBox(width: 8),
          IconButton(
            onPressed: () {
              setState(() {
                _showSettings = !_showSettings;
              });
            },
            icon: Icon(
              _showSettings ? Icons.close : Icons.settings,
              color: _currentTheme.textColor,
            ),
            tooltip: 'Настройки чтения',
          ),
        ],
      ),
    );
  }

  Widget _buildThemeSelector() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: ReadingTheme.allThemes.map((theme) {
        final isSelected = theme.type == _currentTheme.type;
        return GestureDetector(
          onTap: () => _changeTheme(theme),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.symmetric(horizontal: 2),
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: theme.backgroundColor,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: isSelected 
                    ? _currentTheme.quoteHighlightColor
                    : theme.borderColor,
                width: isSelected ? 2 : 1,
              ),
              boxShadow: isSelected ? [
                BoxShadow(
                  color: _currentTheme.quoteHighlightColor.withOpacity(0.3),
                  blurRadius: 4,
                  spreadRadius: 1,
                )
              ] : null,
            ),
            child: Center(
              child: Text(
                theme.letter,
                style: TextStyle(
                  color: theme.textColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildReadingSettings() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: _currentTheme.cardColor,
        border: Border(
          top: BorderSide(color: _currentTheme.borderColor, width: 1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Настройки чтения',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: _currentTheme.textColor,
            ),
          ),
          const SizedBox(height: 16),
          
          Row(
            children: [
              Text(
                'Размер шрифта: ',
                style: TextStyle(color: _currentTheme.textColor),
              ),
              IconButton(
                onPressed: () => _adjustFontSize(-1),
                icon: Icon(Icons.remove_circle_outline, color: _currentTheme.textColor),
              ),
              Text(
                '${_fontSize.toInt()}',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: _currentTheme.textColor,
                ),
              ),
              IconButton(
                onPressed: () => _adjustFontSize(1),
                icon: Icon(Icons.add_circle_outline, color: _currentTheme.textColor),
              ),
            ],
          ),
          
          Row(
            children: [
              Text(
                'Интервал: ',
                style: TextStyle(color: _currentTheme.textColor),
              ),
              IconButton(
                onPressed: () => _adjustLineHeight(-0.1),
                icon: Icon(Icons.compress, color: _currentTheme.textColor),
              ),
              Text(
                _lineHeight.toStringAsFixed(1),
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: _currentTheme.textColor,
                ),
              ),
              IconButton(
                onPressed: () => _adjustLineHeight(0.1),
                icon: Icon(Icons.expand, color: _currentTheme.textColor),
              ),
            ],
          ),
          
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
                icon: Icon(Icons.vertical_align_top, color: _currentTheme.textColor),
                label: Text(
                  'К началу',
                  style: TextStyle(color: _currentTheme.textColor),
                ),
              ),
              const SizedBox(width: 16),
              TextButton.icon(
                onPressed: _scrollToQuote,
                icon: Icon(Icons.my_location, color: _currentTheme.textColor),
                label: Text(
                  'К цитате',
                  style: TextStyle(color: _currentTheme.textColor),
                ),
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
          final containsQuote = _paragraphContainsQuote(paragraphText);
          final isContextParagraph = widget.context.contextParagraphs.any((contextPar) => 
            _normalizeText(contextPar).contains(_normalizeText(paragraphText)) ||
            _normalizeText(paragraphText).contains(_normalizeText(contextPar))
          );
          
          BoxDecoration? decoration;
          EdgeInsets padding = EdgeInsets.zero;
          
          if (containsQuote) {
            decoration = BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: _currentTheme.quoteHighlightColor.withOpacity(0.1),
              border: Border.all(
                color: _currentTheme.quoteHighlightColor,
                width: 2,
              ),
            );
            padding = const EdgeInsets.all(16.0);
          } else if (isContextParagraph) {
            decoration = BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              color: _currentTheme.contextHighlightColor,
              border: Border.all(
                color: _currentTheme.borderColor,
                width: 1,
              ),
            );
            padding = const EdgeInsets.all(12.0);
          }
          
          return AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            margin: const EdgeInsets.only(bottom: 16.0),
            padding: padding,
            decoration: decoration,
            child: AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 300),
              style: TextStyle(
                fontSize: _fontSize,
                height: _lineHeight,
                color: _currentTheme.textColor,
                fontWeight: containsQuote ? FontWeight.w600 : FontWeight.w400,
              ),
              child: containsQuote
                  ? RichText(
                      text: TextSpan(
                        style: TextStyle(
                          fontSize: _fontSize,
                          height: _lineHeight,
                          color: _currentTheme.textColor,
                          fontWeight: FontWeight.w400,
                        ),
                        children: _highlightQuoteInParagraph(paragraphText),
                      ),
                    )
                  : Text(paragraphText),
            ),
          );
        }).toList(),
      ),
    );
  }

  bool _paragraphContainsQuote(String paragraphText) {
    final normalizedParagraph = _normalizeText(paragraphText);
    final normalizedQuote = _normalizeText(widget.context.quote.text);
    
    if (normalizedParagraph.contains(normalizedQuote)) {
      return true;
    }
    
    final quoteWords = normalizedQuote.split(' ');
    if (quoteWords.length > 5) {
      final firstWords = quoteWords.take(5).join(' ');
      return normalizedParagraph.contains(firstWords);
    }
    
    return false;
  }
  
  String _normalizeText(String text) {
    return text.toLowerCase()
        .replaceAll(RegExp(r'[^\w\s]'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  List<TextSpan> _highlightQuoteInParagraph(String text) {
    final quoteText = widget.context.quote.text;
    int index = text.indexOf(quoteText);
    
    if (index == -1) {
      final firstWords = quoteText.split(' ').take(3).join(' ');
      index = text.indexOf(firstWords);
      
      if (index != -1) {
        return [
          if (index > 0) TextSpan(text: text.substring(0, index)),
          TextSpan(
            text: text.substring(index, index + firstWords.length),
            style: TextStyle(
              backgroundColor: _currentTheme.quoteHighlightColor.withOpacity(0.3),
              fontWeight: FontWeight.w900,
              fontSize: _fontSize + 2,
              color: _currentTheme.textColor,
              decoration: TextDecoration.underline,
              decorationColor: _currentTheme.quoteHighlightColor,
              decorationThickness: 2,
            ),
          ),
          if (index + firstWords.length < text.length)
            TextSpan(text: text.substring(index + firstWords.length)),
        ];
      }
      
      return [TextSpan(text: text)];
    }

    return [
      if (index > 0) TextSpan(text: text.substring(0, index)),
      TextSpan(
        text: text.substring(index, index + quoteText.length),
        style: TextStyle(
          backgroundColor: _currentTheme.quoteHighlightColor.withOpacity(0.3),
          fontWeight: FontWeight.w900,
          fontSize: _fontSize + 2,
          color: _currentTheme.textColor,
          decoration: TextDecoration.underline,
          decorationColor: _currentTheme.quoteHighlightColor,
          decorationThickness: 2,
        ),
      ),
      if (index + quoteText.length < text.length)
        TextSpan(text: text.substring(index + quoteText.length)),
    ];
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _themeTransitionController.dispose();
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
            height: 2,
            decoration: BoxDecoration(
              color: widget.theme.borderColor,
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
                      color: widget.theme.quoteHighlightColor,
                      borderRadius: BorderRadius.circular(1),
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
                  fontWeight: FontWeight.w400,
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
                    height: 1,
                    width: double.infinity,
                    color: widget.theme.borderColor,
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
                            widget.theme.quoteHighlightColor.withOpacity(0.8),
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

