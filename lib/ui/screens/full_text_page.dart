// lib/ui/screens/full_text_page.dart
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/quote_context.dart';
import '../../models/book_source.dart';
import '../../models/reading_theme.dart';
import '../../services/text_file_service.dart';

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

        _fadeController.forward();
        
        Future.delayed(const Duration(milliseconds: 100), () {
          if (mounted) {
            _findQuotePositionFast();
            _scheduleAutoScroll();
          }
        });
        
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

      _fadeController.forward();
      
      Future.delayed(const Duration(milliseconds: 200), () {
        if (mounted) {
          _findQuotePositionFast();
          _scheduleAutoScroll();
        }
      });
      
    } catch (e) {
      setState(() {
        _error = 'Ошибка загрузки полного текста: $e';
        _isLoading = false;
      });
    }
  }

  void _findQuotePositionFast() {
    if (_fullText == null) return;
    
    // ИСПОЛЬЗУЕМ ГОТОВЫЕ ДАННЫЕ из QuoteContext вместо поиска!
    final startPos = widget.context.startPosition;
    final endPos = widget.context.endPosition;
    
    print('🎯 Используем готовые позиции из QuoteContext:');
    print('   startPosition: $startPos');
    print('   endPosition: $endPos');
    print('   contextParagraphs: ${widget.context.contextParagraphs.length}');
    
    // Разбиваем текст по параграфам для подсчета общего количества
    final parts = _fullText!.split(RegExp(r'\[pos:\d+\]'));
    final paragraphs = parts.where((p) => p.trim().isNotEmpty).toList();
    
    // Вычисляем позицию для скролла на основе startPosition
    // startPosition - это номер позиции в файле, нужно найти соответствующий параграф
    
    double progress = 0.0;
    
    if (startPos > 0 && startPos <= paragraphs.length) {
      // Скроллим к началу контекстного блока
      progress = (startPos - 1) / paragraphs.length; // -1 потому что позиции с 1, а индексы с 0
      print('✅ Вычислена позиция скролла: ${(progress * 100).toStringAsFixed(1)}% (параграф ${startPos - 1})');
    } else {
      // Fallback: ищем по тексту как раньше
      print('⚠️ startPosition вне диапазона, ищем по тексту...');
      _findQuoteByTextSearch();
      return;
    }
    
    _initialScrollPosition = progress;
    print('📍 ИТОГ: Используем позицию $startPos-$endPos, скролл: ${(progress * 100).toStringAsFixed(1)}%');
  }
  
  // Fallback метод поиска по тексту (если позиции не работают)
  void _findQuoteByTextSearch() {
    final quoteText = widget.context.quote.text;
    final parts = _fullText!.split(RegExp(r'\[pos:\d+\]'));
    final paragraphs = parts.where((p) => p.trim().isNotEmpty).toList();
    
    final normalizedQuote = _normalizeText(quoteText);
    
    for (int i = 0; i < paragraphs.length; i++) {
      final normalizedParagraph = _normalizeText(paragraphs[i].trim());
      
      if (normalizedParagraph.contains(normalizedQuote)) {
        final progress = i / paragraphs.length;
        _initialScrollPosition = progress;
        print('✅ Fallback: найдено в параграфе $i, позиция: ${(progress * 100).toStringAsFixed(1)}%');
        return;
      }
    }
    
    print('❌ Fallback: цитата не найдена');
    _initialScrollPosition = 0.0;
  }
  
  // НОВЫЙ метод для вычисления схожести текстов
  double _calculateSimilarity(String text1, String text2) {
    final words1 = text1.split(' ').where((w) => w.length > 3).toSet();
    final words2 = text2.split(' ').where((w) => w.length > 3).toSet();
    
    final intersection = words1.intersection(words2).length;
    final union = words1.union(words2).length;
    
    return union > 0 ? intersection / union : 0.0;
  }

  void _scheduleAutoScroll() {
    // СРАЗУ показываем анимацию поиска
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) {
        _showSearchAnimation();
      }
    });
    
    // ПАРАЛЛЕЛЬНО делаем скролл в фоне
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted && !_autoScrolled) {
        _scrollToQuoteSmooth();
      }
    });
  }

  void _scrollToQuoteSmooth() {
    if (_initialScrollPosition > 0 && _scrollController.hasClients) {
      final maxScroll = _scrollController.position.maxScrollExtent;
      
      if (maxScroll > 0) {
        final screenHeight = MediaQuery.of(context).size.height;
        final targetScroll = (maxScroll * _initialScrollPosition) - (screenHeight * 0.3);
        final clampedScroll = targetScroll.clamp(0.0, maxScroll);
        
        print('📍 Скроллим к позиции: ${clampedScroll.toStringAsFixed(0)} из ${maxScroll.toStringAsFixed(0)}');
        
        // ПЛАВНЫЙ скролл БЕЗ показа анимации
        _scrollController.animateTo(
          clampedScroll,
          duration: const Duration(milliseconds: 1200), // Увеличил время чтобы анимация успела
          curve: Curves.easeInOutCubic,
        );
        
        _autoScrolled = true;
      }
    }
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

    // Закрываем анимацию через 2 секунды (достаточно времени для скролла)
    Future.delayed(const Duration(milliseconds: 2000), () {
      if (mounted) Navigator.of(context).pop();
    });
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
          // Убираем отдельную кнопку смены темы - оставляем только в настройках
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
            Wrap(
              spacing: 12,
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

  Widget _buildColorPicker(Color currentColor, Function(Color) onColorChanged, [Color? selectedColor]) {
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
        final isSelected = selectedColor != null && color.value == selectedColor.value;
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
        itemCount: _getItemCount(),
        itemBuilder: (context, index) => _buildLazyItem(index),
      ),
    );
  }

  int _getItemCount() {
    if (_fullText == null) return 0;
    return _fullText!.split(RegExp(r'\[pos:\d+\]')).where((p) => p.trim().isNotEmpty).length;
  }

  Widget _buildLazyItem(int index) {
    final paragraphs = _fullText!.split(RegExp(r'\[pos:\d+\]')).where((p) => p.trim().isNotEmpty).toList();
    
    if (index >= paragraphs.length) return const SizedBox.shrink();
    
    final text = paragraphs[index].trim();
    if (text.isEmpty) return const SizedBox.shrink();
    
    final isQuote = _simpleQuoteCheck(text);
    
    // НОВОЕ: Если это цитата, строим КОНТЕКСТНЫЙ БЛОК
    if (isQuote) {
      return _buildContextBlock(paragraphs, index);
    }
    
    // НОВОЕ: Если это контекст рядом с цитатой, не показываем отдельно
    if (_isPartOfContextBlock(paragraphs, index)) {
      return const SizedBox.shrink();
    }
    
    // Обычный параграф
    return Container(
      margin: const EdgeInsets.only(bottom: 16.0),
      child: RichText(
        text: TextSpan(
          style: TextStyle(
            fontSize: _fontSize,
            height: _lineHeight,
            color: _effectiveTextColor,
            fontWeight: FontWeight.normal,
          ),
          children: [TextSpan(text: text)],
        ),
      ),
    );
  }

  // НОВЫЙ метод: Строим контекстный блок ИЗ ГОТОВЫХ ДАННЫХ QuoteContext
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
              'Контекст цитаты',
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
    
    // ИСПОЛЬЗУЕМ ГОТОВЫЕ ДАННЫЕ из QuoteContext
    
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
    
    // САМА ЦИТАТА (используем quoteParagraph)
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
            children: _highlightQuoteInParagraph(widget.context.quoteParagraph),
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

  // Цвет фона контекстного блока
  Color _getContextBlockBackgroundColor() {
    if (_currentTheme.type == ReadingThemeType.dark) {
      return Colors.orange.withOpacity(0.08); // Оранжевый оттенок для тёмной темы
    } else {
      return _currentTheme.highlightColor.withOpacity(0.1);
    }
  }

  // Цвета для выделения цитаты
  Color _getQuoteHighlightBackgroundColor() {
    if (_currentTheme.type == ReadingThemeType.dark) {
      return Colors.orange.withOpacity(0.12); // Оранжевый фон для цитаты в тёмной теме
    } else {
      return _currentTheme.quoteHighlightColor.withOpacity(0.08);
    }
  }

  Color _getQuoteHighlightBorderColor() {
    if (_currentTheme.type == ReadingThemeType.dark) {
      return Colors.orange.withOpacity(0.4); // Оранжевая рамка для цитаты в тёмной теме
    } else {
      return _currentTheme.quoteHighlightColor.withOpacity(0.2);
    }
  }

  Color _getQuoteHighlightTextColor() {
    if (_currentTheme.type == ReadingThemeType.dark) {
      return Colors.orange; // Оранжевый текст цитаты в тёмной теме
    } else {
      return _currentTheme.quoteHighlightColor;
    }
  }

  // Метод для выделения цитаты в параграфе (как на ContextPage)
  List<TextSpan> _highlightQuoteInParagraph(String paragraphText) {
    final quoteText = widget.context.quote.text;
    
    // Ищем позицию цитаты в параграфе
    final quoteLower = quoteText.toLowerCase().replaceAll(RegExp(r'[^\w\s]'), '');
    final paragraphLower = paragraphText.toLowerCase().replaceAll(RegExp(r'[^\w\s]'), '');
    
    int quoteIndex = paragraphLower.indexOf(quoteLower);
    
    if (quoteIndex == -1) {
      // Если точное совпадение не найдено, ищем по первым словам
      final quoteWords = quoteLower.split(' ').take(5).join(' ');
      quoteIndex = paragraphLower.indexOf(quoteWords);
    }
    
    if (quoteIndex != -1) {
      // Выделяем цитату в контексте
      final beforeQuote = paragraphText.substring(0, quoteIndex);
      final afterQuoteStart = quoteIndex + quoteText.length;
      final afterQuote = afterQuoteStart < paragraphText.length 
          ? paragraphText.substring(afterQuoteStart)
          : '';
      
      return [
        if (beforeQuote.isNotEmpty) TextSpan(text: beforeQuote),
        TextSpan(
          text: quoteText,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: _getQuoteHighlightTextColor(),
          ),
        ),
        if (afterQuote.isNotEmpty) TextSpan(text: afterQuote),
      ];
    }
    
    // Если не нашли цитату, возвращаем весь текст
    return [TextSpan(text: paragraphText)];
  }

  // НОВЫЙ метод: Проверяем является ли параграф частью уже показанного контекстного блока
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
    final normalizedText = _normalizeText(text);
    final normalizedQuote = _normalizeText(widget.context.quote.text);
    
    if (normalizedQuote.length < 10) return false;
    
    final quoteStart = normalizedQuote.substring(0, min(30, normalizedQuote.length));
    return normalizedText.contains(quoteStart);
  }

  List<TextSpan> _highlightQuoteInText(String text) {
    final quoteText = widget.context.quote.text;
    final normalizedText = _normalizeText(text);
    final normalizedQuote = _normalizeText(quoteText);
    
    print('🎨 Выделяем цитату в тексте: "${quoteText.substring(0, min(50, quoteText.length))}..."');
    
    // Ищем ТОЧНОЕ совпадение полной цитаты
    final quoteIndex = normalizedText.indexOf(normalizedQuote);
    
    if (quoteIndex != -1) {
      print('✅ Найдено точное совпадение для выделения на позиции $quoteIndex');
      
      // Находим точные границы в оригинальном тексте
      int realStartIndex = 0;
      int realEndIndex = text.length;
      
      // Пытаемся найти точное начало цитаты в оригинальном тексте
      final words = text.split(' ');
      final quoteWords = quoteText.split(' ');
      
      // Ищем последовательность слов из цитаты в тексте
      for (int i = 0; i <= words.length - quoteWords.length; i++) {
        bool matches = true;
        for (int j = 0; j < quoteWords.length; j++) {
          if (_normalizeText(words[i + j]) != _normalizeText(quoteWords[j])) {
            matches = false;
            break;
          }
        }
        
        if (matches) {
          // Нашли точное совпадение
          realStartIndex = words.take(i).join(' ').length + (i > 0 ? 1 : 0);
          final quotePart = words.skip(i).take(quoteWords.length).join(' ');
          realEndIndex = realStartIndex + quotePart.length;
          
          print('✅ Точные границы: $realStartIndex - $realEndIndex');
          print('✅ Выделяемый текст: "${quotePart}"');
          
          final beforeQuote = realStartIndex > 0 ? text.substring(0, realStartIndex) : '';
          final afterQuote = realEndIndex < text.length ? text.substring(realEndIndex) : '';
          
          return [
            if (beforeQuote.isNotEmpty) TextSpan(text: beforeQuote),
            TextSpan(
              text: quotePart,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                backgroundColor: _currentTheme.quoteHighlightColor.withOpacity(0.3),
                color: _currentTheme.quoteHighlightColor,
              ),
            ),
            if (afterQuote.isNotEmpty) TextSpan(text: afterQuote),
          ];
        }
      }
      
      print('⚠️ Не удалось найти точные границы, используем приблизительное выделение');
    }
    
    // Если точное совпадение не найдено, выделяем весь параграф как потенциальную цитату
    print('❌ Точное совпадение не найдено, выделяем весь параграф');
    return [
      TextSpan(
        text: text,
        style: TextStyle(
          fontWeight: FontWeight.w600,
          backgroundColor: _currentTheme.highlightColor.withOpacity(0.2),
        ),
      ),
    ];
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