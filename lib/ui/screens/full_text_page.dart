// lib/ui/screens/full_text_page.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/quote_context.dart';
import '../../models/book_source.dart';
import '../../models/reading_theme.dart';
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
  final GlobalKey _quoteKey = GlobalKey(); // Ключ для поиска позиции цитаты

  late AnimationController _fadeController;
  late AnimationController _themeController;
  late AnimationController _settingsController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _themeAnimation;

  String? _fullText;
  BookSource? _bookSource;
  bool _isLoading = true;
  String? _error;
  String? _debugInfo;
  bool _autoScrolled = false;
  double _fontSize = 16.0;
  double _lineHeight = 1.6;
  bool _showSettings = false;
  ReadingTheme _currentTheme = ReadingTheme.dark;

  // Для оптимизации рендера
  List<Map<String, dynamic>>? _cachedParagraphs;
  List<Map<String, dynamic>>? _cachedContextParagraphs;

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
    setState(() {
      _currentTheme = ReadingTheme.fromType(themeType);
    });
  }

  Future<void> _saveTheme() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('reading_theme', _currentTheme.typeString);
  }

  Future<void> _changeTheme() async {
    _themeController.forward();
    
    await Future.delayed(const Duration(milliseconds: 250));
    
    final currentIndex = ReadingTheme.allThemes.indexOf(_currentTheme);
    final nextIndex = (currentIndex + 1) % ReadingTheme.allThemes.length;
    
    setState(() {
      _currentTheme = ReadingTheme.allThemes[nextIndex];
      // Очищаем кэш при смене темы для перерендера
      _cachedParagraphs = null;
      _cachedContextParagraphs = null;
    });
    
    await _saveTheme();
    
    _themeController.reverse();
  }

  Future<void> _loadFullText() async {
    setState(() {
      _isLoading = true;
      _error = null;
      _debugInfo = "Начинаем загрузку...";
    });

    try {
      setState(() => _debugInfo = "Загружаем источники книг...");
      final sources = await _textService.loadBookSources();
      
      setState(() => _debugInfo = "Найдено источников: ${sources.length}. Ищем: ${widget.context.quote.author} - ${widget.context.quote.source}");
      final source = sources.firstWhere(
        (s) => s.author == widget.context.quote.author && 
               s.title == widget.context.quote.source,
        orElse: () => throw Exception('Book source not found'),
      );
      
      setState(() => _debugInfo = "Источник найден: ${source.title}. Загружаем файл: ${source.cleanedFilePath}");

      final cleanedText = await _textService.loadTextFile(source.cleanedFilePath);
      
      setState(() => _debugInfo = "Текст загружен, длина: ${cleanedText.length} символов");

      setState(() {
        _bookSource = source;
        _fullText = cleanedText;
        _isLoading = false;
        _debugInfo = null;
      });

      // Кэшируем обработанные абзацы
      _cacheParagraphs();

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

  void _cacheParagraphs() {
    if (_fullText == null) return;
    
    final paragraphs = _textService.extractParagraphsWithPositions(_fullText!);
    _cachedParagraphs = paragraphs;
    
    // Кэшируем контекстные абзацы
    final contextParagraphs = <Map<String, dynamic>>[];
    
    for (final paragraph in paragraphs) {
      final paragraphText = paragraph['content'] as String;
      final containsQuote = _paragraphContainsQuote(paragraphText);
      final isContext = !containsQuote && 
          widget.context.contextParagraphs.isNotEmpty &&
          widget.context.contextParagraphs.any((contextPar) => 
            contextPar.trim().isNotEmpty &&
            (_normalizeText(contextPar).contains(_normalizeText(paragraphText)) ||
             _normalizeText(paragraphText).contains(_normalizeText(contextPar)))
          );
      
      if (containsQuote || isContext) {
        contextParagraphs.add({
          ...paragraph,
          'containsQuote': containsQuote,
          'isContext': isContext,
        });
      }
    }
    
    _cachedContextParagraphs = contextParagraphs;
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
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: _currentTheme.borderColor),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 20,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Поиск по тексту',
                    style: TextStyle(
                      color: _currentTheme.textColor,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      decoration: TextDecoration.none,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Container(
                    height: 80,
                    width: 240,
                    decoration: BoxDecoration(
                      color: _currentTheme.highlightColor,
                      borderRadius: BorderRadius.circular(12),
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

      // УЛУЧШЕННЫЙ АВТОСКРОЛЛ: ищем точную позицию цитаты
      await _scrollToQuoteWidget();

      if (mounted) Navigator.of(context).pop();
      _autoScrolled = true;

    } catch (e) {
      print('Scroll error: $e');
      if (mounted) Navigator.of(context).pop();
    }
  }

  Future<void> _scrollToQuoteWidget() async {
    // Ждем, пока виджет будет построен
    await Future.delayed(const Duration(milliseconds: 100));
    
    if (_quoteKey.currentContext != null) {
      // Используем Scrollable.ensureVisible для точного позиционирования
      await Scrollable.ensureVisible(
        _quoteKey.currentContext!,
        alignment: 0.5, // Центрируем на экране
        duration: const Duration(milliseconds: 1200),
        curve: Curves.easeInOutCubic,
      );
    } else {
      // Fallback к старому методу
      final normalizedQuote = _normalizeText(widget.context.quote.text);
      final normalizedFullText = _normalizeText(_fullText!);
      
      final quoteIndex = normalizedFullText.indexOf(normalizedQuote);
      
      if (quoteIndex != -1) {
        final progress = quoteIndex / normalizedFullText.length;
        final maxScroll = _scrollController.position.maxScrollExtent;
        final screenHeight = MediaQuery.of(context).size.height;
        final targetScroll = (maxScroll * progress) - (screenHeight / 2);
        
        await _scrollController.animateTo(
          targetScroll.clamp(0.0, maxScroll),
          duration: const Duration(milliseconds: 1200),
          curve: Curves.easeInOutCubic,
        );
      }
    }
  }

  // ОПТИМИЗИРОВАННЫЕ МЕТОДЫ для плавности
  void _adjustFontSize(double delta) {
    setState(() {
      _fontSize = (_fontSize + delta).clamp(12.0, 24.0);
    });
    // Не перестраиваем весь список, только обновляем стили
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
      animation: _themeAnimation,
      builder: (context, child) {
        return Scaffold(
          backgroundColor: Color.lerp(
            _currentTheme.backgroundColor,
            Colors.white,
            _themeAnimation.value * 0.1,
          ),
          body: SafeArea(
            child: _isLoading 
                ? _buildLoadingState()
                : _error != null 
                    ? _buildErrorState()
                    : _buildFullTextContent(),
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
          CircularProgressIndicator(
            color: _currentTheme.quoteHighlightColor,
          ),
          const SizedBox(height: 16),
          Text(
            'Загружаем полный текст...',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w300,
              color: _currentTheme.textColor,
            ),
          ),
          if (_debugInfo != null) ...[
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.symmetric(horizontal: 20),
              decoration: BoxDecoration(
                color: _currentTheme.highlightColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _currentTheme.borderColor),
              ),
              child: Text(
                _debugInfo!,
                style: TextStyle(
                  fontSize: 12,
                  fontFamily: 'monospace',
                  color: _currentTheme.textColor.withOpacity(0.8),
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
              color: _currentTheme.quoteHighlightColor,
            ),
            const SizedBox(height: 16),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: _currentTheme.textColor,
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TextButton(
                  onPressed: _goBack,
                  child: Text(
                    'Назад',
                    style: TextStyle(color: _currentTheme.textColor.withOpacity(0.7)),
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
        border: Border(
          bottom: BorderSide(
            color: _currentTheme.borderColor,
            width: 1,
          ),
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
            onPressed: _goBack,
            icon: Icon(
              Icons.arrow_back,
              color: _currentTheme.textColor,
            ),
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
          // Кнопка смены темы с анимацией
          AnimatedBuilder(
            animation: _themeAnimation,
            builder: (context, child) {
              return Transform.scale(
                scale: 1.0 - (_themeAnimation.value * 0.1),
                child: IconButton(
                  onPressed: _changeTheme,
                  icon: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: _currentTheme.highlightColor,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: _currentTheme.borderColor),
                      boxShadow: [
                        BoxShadow(
                          color: _currentTheme.quoteHighlightColor.withOpacity(0.2),
                          blurRadius: 4,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                    child: Text(
                      _currentTheme.letter,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: _currentTheme.textColor,
                      ),
                    ),
                  ),
                  tooltip: 'Сменить тему: ${_currentTheme.displayName}',
                ),
              );
            },
          ),
          IconButton(
            onPressed: () {
              setState(() {
                _showSettings = !_showSettings;
              });
              if (_showSettings) {
                _settingsController.forward();
              } else {
                _settingsController.reverse();
              }
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

  Widget _buildReadingSettings() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: _currentTheme.cardColor,
        border: Border(
          bottom: BorderSide(
            color: _currentTheme.borderColor,
            width: 1,
          ),
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
                icon: Icon(
                  Icons.remove_circle_outline,
                  color: _currentTheme.textColor,
                ),
              ),
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 200),
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: _currentTheme.textColor,
                  fontSize: 16,
                ),
                child: Text('${_fontSize.toInt()}'),
              ),
              IconButton(
                onPressed: () => _adjustFontSize(1),
                icon: Icon(
                  Icons.add_circle_outline,
                  color: _currentTheme.textColor,
                ),
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
                icon: Icon(
                  Icons.compress,
                  color: _currentTheme.textColor,
                ),
              ),
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 200),
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: _currentTheme.textColor,
                  fontSize: 16,
                ),
                child: Text(_lineHeight.toStringAsFixed(1)),
              ),
              IconButton(
                onPressed: () => _adjustLineHeight(0.1),
                icon: Icon(
                  Icons.expand,
                  color: _currentTheme.textColor,
                ),
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
                icon: Icon(
                  Icons.vertical_align_top,
                  color: _currentTheme.textColor,
                ),
                label: Text(
                  'К началу',
                  style: TextStyle(color: _currentTheme.textColor),
                ),
              ),
              const SizedBox(width: 16),
              TextButton.icon(
                onPressed: () {
                  _autoScrolled = false;
                  _scrollToQuote();
                },
                icon: Icon(
                  Icons.my_location,
                  color: _currentTheme.textColor,
                ),
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
    if (_cachedParagraphs == null) return const SizedBox.shrink();
    
    if (_cachedParagraphs!.isEmpty) {
      final simpleParagraphs = _fullText!.split('\n\n').where((p) => p.trim().isNotEmpty).toList();
      
      return RepaintBoundary(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: simpleParagraphs.map((paragraphText) {
            return Container(
              margin: const EdgeInsets.only(bottom: 16.0),
              child: AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 200),
                style: TextStyle(
                  fontSize: _fontSize,
                  height: _lineHeight,
                  color: _currentTheme.textColor,
                ),
                child: Text(paragraphText.trim()),
              ),
            );
          }).toList(),
        ),
      );
    }
    
    return RepaintBoundary(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: _buildOptimizedParagraphs(),
      ),
    );
  }

  List<Widget> _buildOptimizedParagraphs() {
    final widgets = <Widget>[];
    bool contextBlockBuilt = false;
    
    for (int i = 0; i < _cachedParagraphs!.length; i++) {
      final paragraph = _cachedParagraphs![i];
      final paragraphText = paragraph['content'] as String;
      final containsQuote = _paragraphContainsQuote(paragraphText);
      final isContext = !containsQuote && 
          widget.context.contextParagraphs.isNotEmpty &&
          widget.context.contextParagraphs.any((contextPar) => 
            contextPar.trim().isNotEmpty &&
            (_normalizeText(contextPar).contains(_normalizeText(paragraphText)) ||
             _normalizeText(paragraphText).contains(_normalizeText(contextPar)))
          );
      
      if ((containsQuote || isContext) && !contextBlockBuilt) {
        widgets.add(_buildUnifiedContextBlock());
        contextBlockBuilt = true;
      } else if (!containsQuote && !isContext) {
        widgets.add(_buildNormalParagraph(paragraphText));
      }
    }
    
    return widgets;
  }

  Widget _buildNormalParagraph(String text) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16.0),
      child: AnimatedDefaultTextStyle(
        duration: const Duration(milliseconds: 200),
        style: TextStyle(
          fontSize: _fontSize,
          height: _lineHeight,
          color: _currentTheme.textColor,
        ),
        child: Text(text),
      ),
    );
  }

  Widget _buildUnifiedContextBlock() {
    if (_cachedContextParagraphs == null || _cachedContextParagraphs!.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 24.0),
      decoration: _getContextBlockDecoration(),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildContextHeader(),
              const SizedBox(height: 20),
              ..._cachedContextParagraphs!.map((paragraph) {
                final paragraphText = paragraph['content'] as String;
                final containsQuote = paragraph['containsQuote'] as bool;
                
                return Padding(
                  padding: const EdgeInsets.only(bottom: 16.0),
                  child: containsQuote 
                      ? _buildQuoteParagraph(paragraphText)
                      : _buildContextParagraph(paragraphText),
                );
              }).toList(),
            ],
          ),
        ),
      ),
    );
  }

  BoxDecoration _getContextBlockDecoration() {
    // Уникальные стили для каждой темы
    switch (_currentTheme.type) {
      case ReadingThemeType.dark:
        return BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color(0xFF2A2A2A).withOpacity(0.8),
              const Color(0xFF1A1A1A).withOpacity(0.6),
            ],
          ),
          border: Border.all(
            color: Colors.orange.withOpacity(0.3),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.orange.withOpacity(0.1),
              blurRadius: 20,
              spreadRadius: 2,
              offset: const Offset(0, 8),
            ),
          ],
        );
        
      case ReadingThemeType.light:
        return BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color(0xFFF8F9FA),
              const Color(0xFFE9ECEF),
            ],
          ),
          border: Border.all(
            color: const Color(0xFF4A90E2).withOpacity(0.4),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF4A90E2).withOpacity(0.1),
              blurRadius: 16,
              spreadRadius: 1,
              offset: const Offset(0, 4),
            ),
          ],
        );
        
      case ReadingThemeType.sepia:
        return BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color(0xFFF5F1E8),
              const Color(0xFFEDE6D3),
            ],
          ),
          border: Border.all(
            color: const Color(0xFFB8860B).withOpacity(0.4),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFB8860B).withOpacity(0.1),
              blurRadius: 16,
              spreadRadius: 1,
              offset: const Offset(0, 4),
            ),
          ],
        );
    }
  }

  Widget _buildContextHeader() {
    IconData icon;
    Color color;
    
    switch (_currentTheme.type) {
      case ReadingThemeType.dark:
        icon = Icons.auto_stories;
        color = Colors.orange;
        break;
      case ReadingThemeType.light:
        icon = Icons.article_outlined;
        color = const Color(0xFF4A90E2);
        break;
      case ReadingThemeType.sepia:
        icon = Icons.menu_book;
        color = const Color(0xFFB8860B);
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: color.withOpacity(0.3),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 16,
            color: color,
          ),
          const SizedBox(width: 8),
          Text(
            'Контекст цитаты',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContextParagraph(String text) {
    return AnimatedDefaultTextStyle(
      duration: const Duration(milliseconds: 200),
      style: TextStyle(
        fontSize: _fontSize,
        height: _lineHeight,
        color: _currentTheme.textColor.withOpacity(0.8),
        fontWeight: FontWeight.w400,
      ),
      child: Text(text),
    );
  }

  Widget _buildQuoteParagraph(String text) {
    return Container(
      key: _quoteKey, // КЛЮЧ ДЛЯ ТОЧНОГО АВТОСКРОЛЛА
      padding: const EdgeInsets.all(20),
      decoration: _getQuoteDecoration(),
      child: AnimatedDefaultTextStyle(
        duration: const Duration(milliseconds: 200),
        style: TextStyle(
          fontSize: _fontSize + 1,
          height: _lineHeight,
          color: _currentTheme.textColor,
          fontWeight: FontWeight.w500,
        ),
        child: RichText(
          text: TextSpan(
            style: TextStyle(
              fontSize: _fontSize + 1,
              height: _lineHeight,
              color: _currentTheme.textColor,
              fontWeight: FontWeight.w500,
            ),
            children: _highlightQuoteInParagraph(text),
          ),
        ),
      ),
    );
  }

  BoxDecoration _getQuoteDecoration() {
    // СОВРЕМЕННОЕ ВЫДЕЛЕНИЕ ЦИТАТЫ для каждой темы
    switch (_currentTheme.type) {
      case ReadingThemeType.dark:
        return BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.orange.withOpacity(0.1),
              Colors.deepOrange.withOpacity(0.05),
            ],
          ),
          border: Border.all(
            color: Colors.orange.withOpacity(0.4),
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.orange.withOpacity(0.2),
              blurRadius: 12,
              spreadRadius: 1,
              offset: const Offset(0, 4),
            ),
            BoxShadow(
              color: Colors.orange.withOpacity(0.1),
              blurRadius: 24,
              spreadRadius: 2,
              offset: const Offset(0, 8),
            ),
          ],
        );
        
      case ReadingThemeType.light:
        return BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color(0xFF4A90E2).withOpacity(0.08),
              const Color(0xFF64B5F6).withOpacity(0.05),
            ],
          ),
          border: Border.all(
            color: const Color(0xFF4A90E2).withOpacity(0.5),
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF4A90E2).withOpacity(0.15),
              blurRadius: 12,
              spreadRadius: 1,
              offset: const Offset(0, 4),
            ),
          ],
        );
        
      case ReadingThemeType.sepia:
        return BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color(0xFFB8860B).withOpacity(0.08),
              const Color(0xFFDAA520).withOpacity(0.05),
            ],
          ),
          border: Border.all(
            color: const Color(0xFFB8860B).withOpacity(0.5),
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFB8860B).withOpacity(0.15),
              blurRadius: 12,
              spreadRadius: 1,
              offset: const Offset(0, 4),
            ),
          ],
        );
    }
  }

  bool _paragraphContainsQuote(String paragraphText) {
    final normalizedParagraph = _normalizeText(paragraphText);
    final normalizedQuote = _normalizeText(widget.context.quote.text);
    
    if (normalizedQuote.length < 10) return false;
    
    if (normalizedParagraph.contains(normalizedQuote)) {
      return true;
    }
    
    final quoteWords = normalizedQuote.split(' ');
    if (quoteWords.length >= 5) {
      final firstWords = quoteWords.take(5).join(' ');
      if (firstWords.length > 15 && normalizedParagraph.contains(firstWords)) {
        return true;
      }
    }
    
    return false;
  }
  
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
    
    int index = text.indexOf(quoteText);
    
    if (index != -1) {
      return _createHighlightedSpans(text, index, quoteText.length);
    }
    
    final normalizedText = _normalizeText(text);
    final normalizedQuote = _normalizeText(quoteText);
    
    final normalizedIndex = normalizedText.indexOf(normalizedQuote);
    if (normalizedIndex != -1) {
      final ratio = normalizedIndex / normalizedText.length;
      final approximateIndex = (ratio * text.length).round();
      
      final words = text.split(' ');
      int currentPos = 0;
      for (int i = 0; i < words.length; i++) {
        if (currentPos >= approximateIndex) {
          final wordsToHighlight = words.skip(i).take(5).join(' ');
          final wordIndex = text.indexOf(wordsToHighlight, currentPos);
          if (wordIndex != -1) {
            return _createHighlightedSpans(text, wordIndex, wordsToHighlight.length);
          }
          break;
        }
        currentPos += words[i].length + 1;
      }
    }
    
    return [TextSpan(text: text)];
  }

  List<TextSpan> _createHighlightedSpans(String text, int startIndex, int length) {
    final spans = <TextSpan>[];
    
    if (startIndex > 0) {
      spans.add(TextSpan(text: text.substring(0, startIndex)));
    }
    
    // УБРАНО ПОДЧЕРКИВАНИЕ И ФОН - только цвет и вес шрифта
    Color highlightColor;
    switch (_currentTheme.type) {
      case ReadingThemeType.dark:
        highlightColor = Colors.orange;
        break;
      case ReadingThemeType.light:
        highlightColor = const Color(0xFF1565C0);
        break;
      case ReadingThemeType.sepia:
        highlightColor = const Color(0xFF8B4513);
        break;
    }
    
    spans.add(TextSpan(
      text: text.substring(startIndex, startIndex + length),
      style: TextStyle(
        fontWeight: FontWeight.w800,
        fontSize: _fontSize + 3,
        color: highlightColor,
        letterSpacing: 0.5,
        // УБРАНО: backgroundColor, decoration
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
                    left: _scanAnimation.value * 200,
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