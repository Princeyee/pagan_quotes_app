
// lib/ui/screens/full_text_page_2.dart
import 'package:flutter/material.dart';
import '../../models/quote_context.dart';
import '../../models/book_source.dart';
import '../../models/reading_theme.dart';
import '../../services/text_file_service.dart';
import '../../services/logger_service.dart';
import '../../utils/custom_cache.dart';
import 'package:flutter/services.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:ui' as ui;

// Экспорт для использования в ContextPage
export 'full_text_page_2.dart';

// --- Новая элегантная анимация поиска в стиле Apple ---
class AppleStyleSearchOverlay extends StatefulWidget {
  final String authorName;
  final String bookTitle;
  final ReadingTheme theme;
  final VoidCallback? onComplete;
  final bool showBackgroundScroll;
  final Widget? backgroundContent;

  const AppleStyleSearchOverlay({
    super.key,
    required this.authorName,
    required this.bookTitle,
    required this.theme,
    this.onComplete,
    this.showBackgroundScroll = true,
    this.backgroundContent,
  });

  @override
  State<AppleStyleSearchOverlay> createState() => _AppleStyleSearchOverlayState();
}

class _AppleStyleSearchOverlayState extends State<AppleStyleSearchOverlay>
    with TickerProviderStateMixin {
  late AnimationController _blurController;
  late AnimationController _contentController;
  late AnimationController _pulseController;
  late AnimationController _textSequenceController;
  
  late Animation<double> _blurAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;
  late Animation<double> _pulseAnimation;
  
  bool _showContent = false;
  String _themeText = '';

  @override
  void initState() {
    super.initState();
    
    _blurController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    
    _contentController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    
    _textSequenceController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );

    _blurAnimation = Tween<double>(
      begin: 0.0,
      end: 15.0,
    ).animate(CurvedAnimation(
      parent: _blurController,
      curve: Curves.easeInOut,
    ));

    _scaleAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _contentController,
      curve: Curves.easeOutBack,
    ));

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _contentController,
      curve: Curves.easeIn,
    ));

    _pulseAnimation = Tween<double>(
      begin: 1.0,
      end: 1.1,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));

    _determineTheme();
    _startAnimation();
  }

  void _determineTheme() {
    final bookLower = widget.bookTitle.toLowerCase();
    final authorLower = widget.authorName.toLowerCase();
    
    if (authorLower.contains('aristotle') || authorLower.contains('аристотель')) {
      _themeText = 'Античная мудрость';
    } else if (authorLower.contains('evola') || authorLower.contains('эвола')) {
      _themeText = 'Традиционализм';
    } else if (bookLower.contains('nordic') || bookLower.contains('север')) {
      _themeText = 'Северная традиция';
    } else if (bookLower.contains('philosophy') || bookLower.contains('философия')) {
      _themeText = 'Философия';
    } else {
      _themeText = 'Вечная мудрость';
    }
  }

  void _startAnimation() async {
    await Future.delayed(const Duration(milliseconds: 100));
    _blurController.forward();
    
    await Future.delayed(const Duration(milliseconds: 200));
    setState(() => _showContent = true);
    _contentController.forward();
    _pulseController.repeat(reverse: true);
    
    // Минимум 2 секунды показа анимации
    await Future.delayed(const Duration(seconds: 2));
    
    if (widget.onComplete != null) {
      widget.onComplete!();
    }
  }

  @override
  void dispose() {
    _blurController.dispose();
    _contentController.dispose();
    _pulseController.dispose();
    _textSequenceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Stack(
        children: [
          // Фоновый контент с блюром
          if (widget.backgroundContent != null)
            AnimatedBuilder(
              animation: _blurAnimation,
              builder: (context, child) {
                return BackdropFilter(
                  filter: ui.ImageFilter.blur(
                    sigmaX: _blurAnimation.value,
                    sigmaY: _blurAnimation.value,
                  ),
                  child: Container(
                    color: widget.theme.backgroundColor.withOpacity(0.3),
                    child: widget.backgroundContent,
                  ),
                );
              },
            )
          else
            Container(
              color: widget.theme.backgroundColor.withOpacity(0.95),
            ),
          
          // Основной контент анимации
          if (_showContent)
            Center(
              child: AnimatedBuilder(
                animation: Listenable.merge([_fadeAnimation, _scaleAnimation]),
                builder: (context, child) {
                  return FadeTransition(
                    opacity: _fadeAnimation,
                    child: Transform.scale(
                      scale: _scaleAnimation.value,
                      child: _buildSearchContent(),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSearchContent() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Анимированный круг с иконкой
          AnimatedBuilder(
            animation: _pulseAnimation,
            builder: (context, child) {
              return Transform.scale(
                scale: _pulseAnimation.value,
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        widget.theme.quoteHighlightColor.withOpacity(0.1),
                        widget.theme.quoteHighlightColor.withOpacity(0.05),
                        Colors.transparent,
                      ],
                      stops: const [0.5, 0.8, 1.0],
                    ),
                  ),
                  child: Center(
                    child: Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: widget.theme.cardColor,
                        border: Border.all(
                          color: widget.theme.quoteHighlightColor.withOpacity(0.3),
                          width: 2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: widget.theme.quoteHighlightColor.withOpacity(0.2),
                            blurRadius: 20,
                            spreadRadius: 5,
                          ),
                        ],
                      ),
                      child: Center(
                        child: _buildRuneIcon(),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
          
          const SizedBox(height: 40),
          
          // Информация о поиске
          _buildInfoSection(),
          
          const SizedBox(height: 40),
          
          // Индикатор загрузки
          _buildLoadingIndicator(),
        ],
      ),
    );
  }

  Widget _buildRuneIcon() {
    return AnimatedBuilder(
      animation: _contentController,
      builder: (context, child) {
        return Transform.rotate(
          angle: _contentController.value * 0.5,
          child: Text(
            '᛭', // Руна
            style: TextStyle(
              fontSize: 36,
              fontWeight: FontWeight.w300,
              color: widget.theme.quoteHighlightColor,
              fontFamily: 'serif',
            ),
          ),
        );
      },
    );
  }

  Widget _buildInfoSection() {
    return Column(
      children: [
        // Тема
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.0, end: 1.0),
          duration: const Duration(milliseconds: 800),
          builder: (context, value, child) {
            return Opacity(
              opacity: value,
              child: Transform.translate(
                offset: Offset(0, 20 * (1 - value)),
                child: Text(
                  _themeText,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w300,
                    color: widget.theme.textColor.withOpacity(0.6),
                    letterSpacing: 2,
                  ),
                ),
              ),
            );
          },
        ),
        
        const SizedBox(height: 16),
        
        // Название книги
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.0, end: 1.0),
          duration: const Duration(milliseconds: 800),
          curve: Curves.easeOut,
          builder: (context, value, child) {
            return Opacity(
              opacity: value,
              child: Transform.translate(
                offset: Offset(0, 20 * (1 - value)),
                child: Text(
                  widget.bookTitle,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.merriweather(
                    fontSize: 24,
                    fontWeight: FontWeight.w600,
                    color: widget.theme.textColor,
                    height: 1.3,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            );
          },
        ),
        
        const SizedBox(height: 8),
        
        // Автор
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.0, end: 1.0),
          duration: const Duration(milliseconds: 800),
          curve: Curves.easeOut,
          builder: (context, value, child) {
            return Opacity(
              opacity: value,
              child: Transform.translate(
                offset: Offset(0, 20 * (1 - value)),
                child: Text(
                  widget.authorName,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w400,
                    color: widget.theme.textColor.withOpacity(0.8),
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildLoadingIndicator() {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(seconds: 2),
      builder: (context, value, child) {
        return Column(
          children: [
            // Прогресс-бар
            Container(
              width: 200,
              height: 2,
              decoration: BoxDecoration(
                color: widget.theme.borderColor.withOpacity(0.2),
                borderRadius: BorderRadius.circular(1),
              ),
              child: Stack(
                children: [
                  FractionallySizedBox(
                    widthFactor: value,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            widget.theme.quoteHighlightColor.withOpacity(0.8),
                            widget.theme.quoteHighlightColor,
                          ],
                        ),
                        borderRadius: BorderRadius.circular(1),
                        boxShadow: [
                          BoxShadow(
                            color: widget.theme.quoteHighlightColor.withOpacity(0.5),
                            blurRadius: 4,
                            offset: const Offset(0, 0),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Текст статуса
            Text(
              'Поиск в тексте...',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w300,
                color: widget.theme.textColor.withOpacity(0.5),
                letterSpacing: 0.5,
              ),
            ),
          ],
        );
      },
    );
  }
}

// --- Универсальный виджет настроек чтения ---
class ReadingSettingsPanel extends StatefulWidget {
  final double fontSize;
  final double lineHeight;
  final ReadingTheme currentTheme;
  final bool useCustomColors;
  final Color? customTextColor;
  final Color? customBackgroundColor;
  final ValueChanged<double> onFontSizeChanged;
  final ValueChanged<double> onLineHeightChanged;
  final ValueChanged<ReadingTheme> onThemeChanged;
  final ValueChanged<bool> onUseCustomColorsChanged;
  final ValueChanged<Color> onCustomTextColorChanged;
  final ValueChanged<Color> onCustomBackgroundColorChanged;

  const ReadingSettingsPanel({
    super.key,
    required this.fontSize,
    required this.lineHeight,
    required this.currentTheme,
    required this.useCustomColors,
    required this.customTextColor,
    required this.customBackgroundColor,
    required this.onFontSizeChanged,
    required this.onLineHeightChanged,
    required this.onThemeChanged,
    required this.onUseCustomColorsChanged,
    required this.onCustomTextColorChanged,
    required this.onCustomBackgroundColorChanged,
  });

  @override
  State<ReadingSettingsPanel> createState() => _ReadingSettingsPanelState();
}

class _ReadingSettingsPanelState extends State<ReadingSettingsPanel> {
  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.7,
      ),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.all(24.0),
        decoration: BoxDecoration(
          color: widget.currentTheme.cardColor,
          borderRadius: const BorderRadius.only(
            bottomLeft: Radius.circular(16),
            bottomRight: Radius.circular(16),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
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
                      color: widget.currentTheme.highlightColor.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.tune, size: 20, color: widget.currentTheme.textColor.withOpacity(0.8)),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Настройки чтения',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: widget.currentTheme.textColor),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              _buildModernSettingCard(
                'Размер текста',
                Icons.format_size,
                Row(
                  children: [
                    _buildModernButton(Icons.remove, () => widget.onFontSizeChanged(widget.fontSize - 1), widget.fontSize > 12),
                    const SizedBox(width: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: widget.currentTheme.highlightColor.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: widget.currentTheme.borderColor.withOpacity(0.3)),
                      ),
                      child: Text(
                        '${widget.fontSize.toInt()}px',
                        style: TextStyle(fontWeight: FontWeight.w600, color: widget.currentTheme.textColor, fontSize: 16),
                      ),
                    ),
                    const SizedBox(width: 16),
                    _buildModernButton(Icons.add, () => widget.onFontSizeChanged(widget.fontSize + 1), widget.fontSize < 24),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _buildModernSettingCard(
                'Межстрочный интервал',
                Icons.format_line_spacing,
                Row(
                  children: [
                    _buildModernButton(Icons.compress, () => widget.onLineHeightChanged(widget.lineHeight - 0.1), widget.lineHeight > 1.2),
                    const SizedBox(width: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: widget.currentTheme.highlightColor.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: widget.currentTheme.borderColor.withOpacity(0.3)),
                      ),
                      child: Text(
                        '${widget.lineHeight.toStringAsFixed(1)}x',
                        style: TextStyle(fontWeight: FontWeight.w600, color: widget.currentTheme.textColor, fontSize: 16),
                      ),
                    ),
                    const SizedBox(width: 16),
                    _buildModernButton(Icons.expand, () => widget.onLineHeightChanged(widget.lineHeight + 0.1), widget.lineHeight < 2.0),
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
                    final isSelected = theme.type == widget.currentTheme.type && !widget.useCustomColors;
                    return GestureDetector(
                      onTap: () {
                        widget.onThemeChanged(theme);
                        widget.onUseCustomColorsChanged(false);
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
                                  color: widget.currentTheme.textColor.withOpacity(0.6),
                                ),
                              ),
                              const SizedBox(height: 8),
                              _buildColorPicker(
                                widget.customTextColor ?? widget.currentTheme.textColor,
                                (color) {
                                  widget.onCustomTextColorChanged(color);
                                  widget.onUseCustomColorsChanged(true);
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
                                  color: widget.currentTheme.textColor.withOpacity(0.6),
                                ),
                              ),
                              const SizedBox(height: 8),
                              _buildColorPicker(
                                widget.customBackgroundColor ?? widget.currentTheme.backgroundColor,
                                (color) {
                                  widget.onCustomBackgroundColorChanged(color);
                                  widget.onUseCustomColorsChanged(true);
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
        color: widget.currentTheme.highlightColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: widget.currentTheme.borderColor.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: widget.currentTheme.textColor.withOpacity(0.7)),
              const SizedBox(width: 8),
              Text(title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: widget.currentTheme.textColor.withOpacity(0.8))),
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
              ? widget.currentTheme.highlightColor.withOpacity(0.8)
              : widget.currentTheme.highlightColor.withOpacity(0.3),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: widget.currentTheme.borderColor.withOpacity(0.3)),
          boxShadow: enabled ? [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 4, offset: const Offset(0, 2))] : null,
        ),
        child: Icon(icon, size: 18, color: enabled ? widget.currentTheme.textColor : widget.currentTheme.textColor.withOpacity(0.4)),
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
                    ? widget.currentTheme.quoteHighlightColor 
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
}

// --- Основной класс FullTextPage2 ---
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
  bool _findingQuote = false;

  // Для scrollable_positioned_list
  final ItemScrollController _itemScrollController = ItemScrollController();
  final ItemPositionsListener _itemPositionsListener = ItemPositionsListener.create();

  // Новые переменные для элегантной анимации поиска
  bool _isSearchingQuote = false;
  bool _canStartScroll = false;

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
    if (_targetParagraphIndex == null) return;
    
    // Показываем элегантную анимацию поиска
    setState(() {
      _isSearchingQuote = true;
    });

    // Ждем минимум 2 секунды перед началом скролла
    await Future.delayed(const Duration(seconds: 2));
    
    setState(() {
      _canStartScroll = true;
    });

    // Начинаем фоновый скролл
    if (_targetParagraphIndex! > 10) {
      // Сначала быстро прокручиваем до близкой позиции
      await _itemScrollController.scrollTo(
        index: _targetParagraphIndex! - 5,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
    }

    // Затем плавно доскроливаем до цитаты
    await _itemScrollController.scrollTo(
      index: _targetParagraphIndex!,
      duration: const Duration(milliseconds: 1500),
      curve: Curves.easeOutCubic,
      alignment: 0.3,
    );

    // Скрываем анимацию поиска
    if (mounted) {
      setState(() {
        _isSearchingQuote = false;
        _autoScrollCompleted = true;
      });
      _showScrollHint();
    }
  }

  void _showScrollHint() {
    if (!mounted) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Цитата найдена и выделена'),
        duration: const Duration(seconds: 3),
        backgroundColor: _currentTheme.quoteHighlightColor.withOpacity(0.9),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _effectiveBackgroundColor,
      body: SafeArea(
        child: Stack(
          children: [
            // Основной контент
            _isLoading
                ? _buildLoadingState()
                : _error != null
                    ? _buildErrorState()
                    : _buildFullTextContent(),
            
            // Элегантная анимация поиска с фоновым контентом
            if (_isSearchingQuote)
              AppleStyleSearchOverlay(
                authorName: _bookSource?.author ?? widget.context.quote.author,
                bookTitle: _bookSource?.title ?? widget.context.quote.source,
                theme: _currentTheme,
                backgroundContent: _canStartScroll && !_isLoading && _error == null
                    ? _buildTextContent()
                    : null,
                onComplete: () {
                  // Анимация завершена, но мы не закрываем ее сами
                  // Она закроется после завершения скролла
                },
              ),
          ],
        ),
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
        if (!_autoScrollCompleted && !_findingQuote && !_isSearchingQuote)
          Positioned(
            bottom: 24,
            right: 24,
            child: FloatingActionButton.extended(
              onPressed: _findQuoteManually,
              backgroundColor: _currentTheme.quoteHighlightColor,
              foregroundColor: Colors.white,
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
 return ReadingSettingsPanel(
   fontSize: _fontSize,
   lineHeight: _lineHeight,
   currentTheme: _currentTheme,
   useCustomColors: _useCustomColors,
   customTextColor: _customTextColor,
   customBackgroundColor: _customBackgroundColor,
   onFontSizeChanged: (v) {
     setState(() => _fontSize = v.clamp(12.0, 24.0));
     _saveSettings();
   },
   onLineHeightChanged: (v) {
     setState(() => _lineHeight = v.clamp(1.2, 2.0));
     _saveSettings();
   },
   onThemeChanged: (theme) {
     setState(() {
       _currentTheme = theme;
       _useCustomColors = false;
     });
     _saveSettings();
   },
   onUseCustomColorsChanged: (v) {
     setState(() => _useCustomColors = v);
     _saveSettings();
   },
   onCustomTextColorChanged: (color) {
     setState(() => _customTextColor = color);
     _saveSettings();
   },
   onCustomBackgroundColorChanged: (color) {
     setState(() => _customBackgroundColor = color);
     _saveSettings();
   },
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
    return ScrollablePositionedList.builder(
      itemScrollController: _itemScrollController,
      itemPositionsListener: _itemPositionsListener,
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
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
    
    setState(() {
      _isSearchingQuote = true;
      _findingQuote = true;
      _canStartScroll = false;
    });

    // Ждем 2 секунды перед началом скролла
    await Future.delayed(const Duration(seconds: 2));
    
    setState(() {
      _canStartScroll = true;
    });

    // Выполняем скролл к цитате
    await _itemScrollController.scrollTo(
      index: _targetParagraphIndex!,
      duration: const Duration(milliseconds: 1200),
      curve: Curves.easeInOut,
      alignment: 0.3,
    );

    if (mounted) {
      setState(() {
        _isSearchingQuote = false;
        _autoScrollCompleted = true;
        _findingQuote = false;
      });
      _showScrollHint();
    }
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