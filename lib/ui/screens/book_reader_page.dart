// lib/ui/screens/book_reader_page.dart - ИСПРАВЛЕННАЯ ВЕРСИЯ
import 'package:flutter/material.dart';

import '../../models/book_source.dart';
import '../../models/reading_theme.dart';
import '../../services/text_file_service.dart';
import '../../utils/custom_cache.dart';

class BookReaderPage extends StatefulWidget {
  final BookSource book;
  
  const BookReaderPage({
    super.key,
    required this.book,
  });

  @override
  State<BookReaderPage> createState() => _BookReaderPageState();
}

class _BookReaderPageState extends State<BookReaderPage> 
    with TickerProviderStateMixin {
  final TextFileService _textService = TextFileService();
  final ScrollController _scrollController = ScrollController();
  final CustomCachePrefs _cache = CustomCache.prefs;
  
  late AnimationController _fadeController;
  late AnimationController _themeController;
  late AnimationController _settingsController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _themeAnimation;
  
  String? _fullText;
  List<Map<String, dynamic>> _paragraphs = [];
  bool _isLoading = true;
  String? _error;
  
  double _fontSize = 17.0;
  double _lineHeight = 1.5;
  ReadingTheme _currentTheme = ReadingTheme.dark;
  bool _showSettings = false;
  
  Color? _customTextColor;
  Color? _customBackgroundColor;
  bool _useCustomColors = false;
  
  double _savedScrollPosition = 0.0;

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
    _loadBook();
    _scrollController.addListener(_saveScrollPosition);
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

  Future<void> _loadSettings() async {
    final fontSize = _cache.getSetting<double>('book_font_size') ?? 17.0;
    final lineHeight = _cache.getSetting<double>('book_line_height') ?? 1.5;
    final themeType = ReadingTheme.fromString(
      _cache.getSetting<String>('reading_theme') ?? 'dark'
    );
    
    final useCustom = _cache.getSetting<bool>('use_custom_colors_book') ?? false;
    final textColorValue = _cache.getSetting<int>('custom_text_color_book');
    final bgColorValue = _cache.getSetting<int>('custom_background_color_book');
    
    final savedPosition = _cache.getSetting<double>('book_position_${widget.book.id}') ?? 0.0;
    
    setState(() {
      _fontSize = fontSize;
      _lineHeight = lineHeight;
      _currentTheme = ReadingTheme.fromType(themeType);
      _useCustomColors = useCustom;
      _customTextColor = textColorValue != null ? Color(textColorValue) : null;
      _customBackgroundColor = bgColorValue != null ? Color(bgColorValue) : null;
      _savedScrollPosition = savedPosition;
    });
  }

  Future<void> _saveSettings() async {
    await _cache.setSetting('book_font_size', _fontSize);
    await _cache.setSetting('book_line_height', _lineHeight);
    await _cache.setSetting('reading_theme', _currentTheme.typeString);
    await _cache.setSetting('use_custom_colors_book', _useCustomColors);
    
    if (_customTextColor != null) {
      await _cache.setSetting('custom_text_color_book', _customTextColor!.value);
    }
    if (_customBackgroundColor != null) {
      await _cache.setSetting('custom_background_color_book', _customBackgroundColor!.value);
    }
  }

  void _saveScrollPosition() {
    if (_scrollController.hasClients && _scrollController.position.maxScrollExtent > 0) {
      final progress = _scrollController.offset / _scrollController.position.maxScrollExtent;
      _cache.setSetting('book_position_${widget.book.id}', _scrollController.offset);
      _cache.setSetting('reading_progress_${widget.book.id}', progress);
    }
  }

  Future<void> _loadBook() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final text = await _textService.loadTextFile(widget.book.cleanedFilePath);
      _fullText = text;
      
      _paragraphs = _textService.extractParagraphsWithPositions(text);
      
      setState(() {
        _isLoading = false;
      });
      
      _fadeController.forward();
      
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_savedScrollPosition > 0 && _scrollController.hasClients) {
          _scrollController.jumpTo(_savedScrollPosition);
        }
      });
      
    } catch (e) {
      setState(() {
        _error = 'Ошибка загрузки книги: $e';
        _isLoading = false;
      });
    }
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

  @override
  void dispose() {
    _saveScrollPosition();
    _fadeController.dispose();
    _themeController.dispose();
    _settingsController.dispose();
    _scrollController.dispose();
    super.dispose();
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
                      : _buildBookContent(),
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
            'Загружаем книгу...',
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
                  child: Text('Назад', style: TextStyle(color: _effectiveTextColor.withAlpha((0.7 * 255).round()))),
                ),
                const SizedBox(width: 16),
                ElevatedButton(
                  onPressed: _loadBook,
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

  Widget _buildBookContent() {
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
        boxShadow: [BoxShadow(color: Colors.black.withAlpha((0.1 * 255).round()), blurRadius: 8, offset: const Offset(0, 2))],
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
                  widget.book.title,
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: _currentTheme.textColor),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  widget.book.author,
                  style: TextStyle(fontSize: 14, color: _currentTheme.textColor.withAlpha((0.7 * 255).round())),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (_scrollController.hasClients) _buildProgressIndicator(),
          const SizedBox(width: 12),
          IconButton(
            onPressed: () {
              setState(() => _showSettings = !_showSettings);
              if (_showSettings) {
                _settingsController.forward();
              } else {
                _settingsController.reverse();
              }
            },
            icon: Icon(_showSettings ? Icons.close : Icons.settings, color: _currentTheme.textColor),
            tooltip: 'Настройки чтения',
          ),
        ],
      ),
    );
  }

  Widget _buildProgressIndicator() {
    if (!_scrollController.hasClients) return const SizedBox.shrink();
    
    final progress = _scrollController.position.maxScrollExtent > 0
        ? _scrollController.offset / _scrollController.position.maxScrollExtent
        : 0.0;
    
    return Container(
      width: 48,
      height: 48,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CircularProgressIndicator(
            value: progress,
            backgroundColor: _currentTheme.borderColor.withAlpha((0.3 * 255).round()),
            valueColor: AlwaysStoppedAnimation<Color>(_currentTheme.quoteHighlightColor),
            strokeWidth: 3,
          ),
          Text(
            '${(progress * 100).toInt()}%',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: _currentTheme.textColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReadingSettings() {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.7, // Максимум 70% экрана
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
          boxShadow: [BoxShadow(color: Colors.black.withAlpha((0.05 * 255).round()), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: _currentTheme.highlightColor.withAlpha((0.2 * 255).round()),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.tune, size: 20, color: _currentTheme.textColor.withAlpha((0.8 * 255).round())),
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
                        color: _currentTheme.highlightColor.withAlpha((0.3 * 255).round()),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: _currentTheme.borderColor.withAlpha((0.3 * 255).round())),
                      ),
                      child: Text(
                        '${_fontSize.toInt()}px',
                        style: TextStyle(fontWeight: FontWeight.w600, color: _currentTheme.textColor, fontSize: 16),
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
                        color: _currentTheme.highlightColor.withAlpha((0.3 * 255).round()),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: _currentTheme.borderColor.withAlpha((0.3 * 255).round())),
                      ),
                      child: Text(
                        '${_lineHeight.toStringAsFixed(1)}x',
                        style: TextStyle(fontWeight: FontWeight.w600, color: _currentTheme.textColor, fontSize: 16),
                      ),
                    ),
                    const SizedBox(width: 16),
                    _buildModernButton(Icons.expand, () => _adjustLineHeight(0.1), _lineHeight < 2.0),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _buildModernSettingCard(
                'Тема оформления',
                Icons.palette_outlined,
                Wrap(
                  spacing: 12,
                  children: ReadingTheme.allThemes.map((theme) {
                    final isSelected = theme.type == _currentTheme.type && !_useCustomColors;
                    return GestureDetector(
                      onTap: () async {
                        await _themeController.forward();
                        setState(() {
                          _currentTheme = theme;
                          _useCustomColors = false;
                        });
                        await _saveSettings();
                        await _themeController.reverse();
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
                                : theme.borderColor.withAlpha((0.3 * 255).round()),
                            width: isSelected ? 3 : 1,
                          ),
                          boxShadow: isSelected ? [
                            BoxShadow(
                              color: theme.quoteHighlightColor.withAlpha((0.3 * 255).round()),
                              blurRadius: 12,
                              spreadRadius: 2,
                            ),
                          ] : [
                            BoxShadow(
                              color: Colors.black.withAlpha((0.1 * 255).round()),
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
                                  color: _currentTheme.textColor.withAlpha((0.6 * 255).round()),
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
                                  color: _currentTheme.textColor.withAlpha((0.6 * 255).round()),
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
        ),
      ),
    );
  }

  Widget _buildModernSettingCard(String title, IconData icon, Widget content) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _currentTheme.highlightColor.withAlpha((0.1 * 255).round()),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _currentTheme.borderColor.withAlpha((0.2 * 255).round())),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: _currentTheme.textColor.withAlpha((0.7 * 255).round())),
              const SizedBox(width: 8),
              Text(title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: _currentTheme.textColor.withAlpha((0.8 * 255).round()))),
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
              ? _currentTheme.highlightColor.withAlpha((0.8 * 255).round())
              : _currentTheme.highlightColor.withAlpha((0.3 * 255).round()),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _currentTheme.borderColor.withAlpha((0.3 * 255).round())),
          boxShadow: enabled ? [BoxShadow(color: Colors.black.withAlpha((0.1 * 255).round()), blurRadius: 4, offset: const Offset(0, 2))] : null,
        ),
        child: Icon(icon, size: 18, color: enabled ? _currentTheme.textColor : _currentTheme.textColor.withAlpha((0.4 * 255).round())),
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
        final isSelected = currentColor == color;
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
                    : Colors.grey.withAlpha((0.3 * 255).round()),
                width: isSelected ? 3 : 1,
              ),
              boxShadow: [BoxShadow(color: Colors.black.withAlpha((0.1 * 255).round()), blurRadius: 4, offset: const Offset(0, 2))],
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
        itemCount: _paragraphs.length,
        itemBuilder: (context, index) => _buildParagraph(index),
      ),
    );
  }

  Widget _buildParagraph(int index) {
    final paragraph = _paragraphs[index];
    final text = paragraph['content'] as String;
    final position = paragraph['position'] as int;
    if (text.isEmpty || TextFileService.isHeader(text)) return const SizedBox.shrink();
    
    return Container(
      key: ValueKey('paragraph_$position'),
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
        textAlign: TextAlign.justify,
      ),
    );
  }
}