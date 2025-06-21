 // lib/ui/screens/full_text_page_2.dart
import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../../models/quote_context.dart';
import '../../models/book_source.dart';
import '../../models/reading_theme.dart';
import '../../services/text_file_service.dart';
import '../../services/logger_service.dart';
import '../../utils/custom_cache.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/sound_manager.dart';

// Экспорт для использования в ContextPage
export 'full_text_page_2.dart';

// --- Новая элегантная анимация поиска ---
class AppleStyleSearchOverlay extends StatefulWidget {
  final String authorName;
  final String bookTitle;
  final ReadingTheme theme;
  final VoidCallback? onComplete;

  const AppleStyleSearchOverlay({
    super.key,
    required this.authorName,
    required this.bookTitle,
    required this.theme,
    this.onComplete,
  });

  @override
  State<AppleStyleSearchOverlay> createState() => _AppleStyleSearchOverlayState();
}

class _AppleStyleSearchOverlayState extends State<AppleStyleSearchOverlay>
    with TickerProviderStateMixin {
  late AnimationController _containerController;
  late AnimationController _contentController;
  late AnimationController _particleController;
  late AnimationController _glowController;
  
  late Animation<double> _containerFadeAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;
  late Animation<double> _glowAnimation;
  
  bool _showContent = false;
  String _themeText = '';
  bool _isClosing = false;

  @override
  void initState() {
    super.initState();
    
    _containerController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    
    _contentController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    
    _particleController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    );
    
    _glowController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );

    _containerFadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _containerController,
      curve: Curves.easeInOut,
    ));

    _scaleAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _contentController,
      curve: Curves.easeOutCubic,
    ));

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _contentController,
      curve: Curves.easeIn,
    ));

    _glowAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _glowController,
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
    _containerController.forward();
    
    await Future.delayed(const Duration(milliseconds: 200));
    setState(() => _showContent = true);
    _contentController.forward();
    _particleController.repeat();
    _glowController.repeat(reverse: true);
    
    // Ждем ровно 2 секунды
    await Future.delayed(const Duration(seconds: 2));
    
    // Закрываем всю анимацию
    _closeAnimation();
  }

  void _closeAnimation() async {
    if (_isClosing) return;
    _isClosing = true;
    
    // Плавное исчезновение всего контента одновременно
    await Future.wait([
      _contentController.reverse(),
      _containerController.reverse(),
    ]);
    
    if (widget.onComplete != null && mounted) {
      widget.onComplete!();
    }
  }

  @override
  void dispose() {
    _containerController.dispose();
    _contentController.dispose();
    _particleController.dispose();
    _glowController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: AnimatedBuilder(
        animation: _containerFadeAnimation,
        builder: (context, child) {
          return Container(
            color: widget.theme.backgroundColor.withAlpha(((0.95 * _containerFadeAnimation.value) * 255).round()),
            child: FadeTransition(
              opacity: _containerFadeAnimation,
              child: _showContent ? _buildMainContent() : const SizedBox.shrink(),
            ),
          );
        },
      ),
    );
  }

  Widget _buildMainContent() {
    return Center(
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
    );
  }

  Widget _buildSearchContent() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Иконка с эффектами
          Stack(
            alignment: Alignment.center,
            children: [
              // Свечение позади иконки
              AnimatedBuilder(
                animation: _glowAnimation,
                builder: (context, child) {
                  return Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: widget.theme.quoteHighlightColor.withAlpha(((0.3 * _glowAnimation.value) * 255).round()),
                          blurRadius: 30,
                          spreadRadius: 10,
                        ),
                      ],
                    ),
                  );
                },
              ),
              // Частицы вокруг иконки
              CustomPaint(
                size: const Size(140, 140),
                painter: ParticlePainter(
                  animation: _particleController,
                  color: widget.theme.quoteHighlightColor,
                ),
              ),
              // Сама иконка
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: widget.theme.cardColor,
                  border: Border.all(
                    color: widget.theme.quoteHighlightColor.withAlpha((0.3 * 255).round()),
                    width: 2,
                  ),
                ),
                child: ClipOval(
                  child: Image.asset(
                    'assets/images/rune_icon.png',
                    width: 80,
                    height: 80,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Center(
                        child: Icon(
                          Icons.park,
                          size: 40,
                          color: widget.theme.quoteHighlightColor,
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
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

  Widget _buildInfoSection() {
    return Column(
      children: [
        // Тема
        Text(
          _themeText,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w300,
            color: widget.theme.textColor.withAlpha((0.6 * 255).round()),
            letterSpacing: 2,
          ),
        ),
        
        const SizedBox(height: 16),
        
        // Название книги
        Text(
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
        
        const SizedBox(height: 8),
        
        // Автор
        Text(
          widget.authorName,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w400,
            color: widget.theme.textColor.withAlpha((0.8 * 255).round()),
            fontStyle: FontStyle.italic,
          ),
        ),
      ],
    );
  }

  Widget _buildLoadingIndicator() {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(seconds: 2),
      builder: (context, value, child) {
        return Container(
          width: 200,
          height: 2,
          decoration: BoxDecoration(
            color: widget.theme.borderColor.withAlpha((0.2 * 255).round()),
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
                        widget.theme.quoteHighlightColor.withAlpha((0.8 * 255).round()),
                        widget.theme.quoteHighlightColor,
                      ],
                    ),
                    borderRadius: BorderRadius.circular(1),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// Painter для частиц
class ParticlePainter extends CustomPainter {
  final Animation<double> animation;
  final Color color;

  ParticlePainter({
    required this.animation,
    required this.color,
  }) : super(repaint: animation);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withAlpha((0.3 * 255).round())
      ..style = PaintingStyle.fill;

    final center = Offset(size.width / 2, size.height / 2);
    final progress = animation.value;

    // Рисуем искры
    for (int i = 0; i < 8; i++) {
      final angle = (i * 45 * math.pi / 180) + (progress * 2 * math.pi);
      final distance = 50 + (20 * math.sin(progress * 2 * math.pi));
      
      final x = center.dx + math.cos(angle) * distance;
      final y = center.dy + math.sin(angle) * distance;
      
      final opacity = (0.5 + 0.5 * math.sin(progress * 2 * math.pi + i)).clamp(0.0, 1.0);
      paint.color = color.withAlpha(((opacity * 0.5) * 255).round());
      
      canvas.drawCircle(Offset(x, y), 2, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
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
  final VoidCallback? onScrollToQuote;
  final VoidCallback? onScrollToStart;

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
    this.onScrollToQuote,
    this.onScrollToStart,
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
              color: Colors.black.withAlpha((0.05 * 255).round()),
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
                      color: widget.currentTheme.highlightColor.withAlpha((0.2 * 255).round()),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.tune, size: 20, color: widget.currentTheme.textColor.withAlpha((0.8 * 255).round())),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Настройки чтения',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: widget.currentTheme.textColor),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              
              // Кнопки навигации
              _buildModernSettingCard(
                'Навигация',
                Icons.navigation,
                Row(
                  children: [
                    Expanded(
                      child: _buildNavigationButton(
                        'К началу',
                        Icons.vertical_align_top,
                        widget.onScrollToStart,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildNavigationButton(
                        'К цитате',
                        Icons.format_quote,
                        widget.onScrollToQuote,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              
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
                        color: widget.currentTheme.highlightColor.withAlpha((0.3 * 255).round()),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: widget.currentTheme.borderColor.withAlpha((0.3 * 255).round())),
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
                        color: widget.currentTheme.highlightColor.withAlpha((0.3 * 255).round()),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: widget.currentTheme.borderColor.withAlpha((0.3 * 255).round())),
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
                                  color: widget.currentTheme.textColor.withAlpha((0.6 * 255).round()),
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
                                  color: widget.currentTheme.textColor.withAlpha((0.6 * 255).round()),
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

  Widget _buildNavigationButton(String label, IconData icon, VoidCallback? onTap) {
    return Material(
      color: widget.currentTheme.highlightColor.withAlpha((0.8 * 255).round()),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: widget.currentTheme.borderColor.withAlpha((0.3 * 255).round())),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18, color: widget.currentTheme.textColor),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: widget.currentTheme.textColor,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
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
        color: widget.currentTheme.highlightColor.withAlpha((0.1 * 255).round()),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: widget.currentTheme.borderColor.withAlpha((0.2 * 255).round())),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: widget.currentTheme.textColor.withAlpha((0.7 * 255).round())),
              const SizedBox(width: 8),
              Text(title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: widget.currentTheme.textColor.withAlpha((0.8 * 255).round()))),
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
              ? widget.currentTheme.highlightColor.withAlpha((0.8 * 255).round())
              : widget.currentTheme.highlightColor.withAlpha((0.3 * 255).round()),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: widget.currentTheme.borderColor.withAlpha((0.3 * 255).round())),
          boxShadow: enabled ? [BoxShadow(color: Colors.black.withAlpha((0.1 * 255).round()), blurRadius: 4, offset: const Offset(0, 2))] : null,
        ),
        child: Icon(icon, size: 18, color: enabled ? widget.currentTheme.textColor : widget.currentTheme.textColor.withAlpha((0.4 * 255).round())),
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
                    ? widget.currentTheme.quoteHighlightColor 
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
  final _soundManager = SoundManager();

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
  
  // Музыка
  bool _isMusicEnabled = true;

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
  
  // Прогресс чтения
  double _readingProgress = 0.0;

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
    _setupScrollListener();
    
    // Проверяем, не выключена ли музыка локально
    _checkMusicState();
  }
  
  void _checkMusicState() async {
    // Проверяем локальную настройку для этой страницы
    final localMusicEnabled = await _cache.getSetting<bool>('full_text_music_enabled') ?? true;
    setState(() {
      _isMusicEnabled = localMusicEnabled;
    });
    
    // Если музыка выключена локально, ставим на паузу
    if (!_isMusicEnabled) {
      await _soundManager.pauseAll();
    }
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

  void _setupScrollListener() {
    _itemPositionsListener.itemPositions.addListener(() {
      final positions = _itemPositionsListener.itemPositions.value;
      if (positions.isNotEmpty && _paragraphs.isNotEmpty) {
        final firstVisibleIndex = positions
            .where((position) => position.itemLeadingEdge < 1)
            .map((position) => position.index)
            .reduce((min, index) => index < min ? index : min);
        
        final progress = firstVisibleIndex / _paragraphs.length;
        if (mounted) {
          setState(() {
            _readingProgress = progress.clamp(0.0, 1.0);
          });
        }
      }
    });
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
    
    // Загружаем состояние звука из SoundManager
    setState(() {
      _fontSize = fontSize;
      _lineHeight = lineHeight;
      _currentTheme = ReadingTheme.fromType(themeType);
      _useCustomColors = useCustom;
      _customTextColor = textColorValue != null ? Color(textColorValue) : null;
      _customBackgroundColor = bgColorValue != null ? Color(bgColorValue) : null;
      _isMusicEnabled = !_soundManager.isMuted;
    });
  }

  Future<void> _saveSettings() async {
    await _cache.setSetting('font_size', _fontSize);
    await _cache.setSetting('line_height', _lineHeight);
    await _cache.setSetting('reading_theme', _currentTheme.typeString);
    await _cache.setSetting('use_custom_colors', _useCustomColors);
    
    if (_customTextColor != null) {
      await _cache.setSetting('custom_text_color', _customTextColor!.toARGB32());
    }
    if (_customBackgroundColor != null) {
      await _cache.setSetting('custom_background_color', _customBackgroundColor!.toARGB32());
    }
  }

  Future<void> _loadFullText() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Найти источник книги с помощью нового гибкого метода
      final source = _textService.findBookSource(
        widget.context.quote.author, 
        widget.context.quote.source
      );
      
      if (source == null) {
        throw Exception('Источник книги не найден для: ${widget.context.quote.author} - ${widget.context.quote.source}');
      }

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

    // Ждем 1.5 секунды перед началом скролла
    await Future.delayed(const Duration(milliseconds: 1500));

    // Плавный скролл к цитате без прыжков
    await _itemScrollController.scrollTo(
      index: _targetParagraphIndex!,
      duration: const Duration(milliseconds: 2000),
      curve: Curves.easeInOutCubic,
      alignment: 0.3,
    );

    // Ждем завершения скролла
    await Future.delayed(const Duration(milliseconds: 300));

    // Анимация автоматически закроется через 2 секунды
    if (mounted) {
      setState(() {
        _autoScrollCompleted = true;
      });
    }
  }

  void _scrollToStart() {
    _itemScrollController.scrollTo(
      index: 0,
      duration: const Duration(milliseconds: 800),
      curve: Curves.easeInOut,
    );
    setState(() => _showSettings = false);
  }

  void _scrollToQuoteFromSettings() {
    if (_targetParagraphIndex != null) {
      _itemScrollController.scrollTo(
        index: _targetParagraphIndex!,
        duration: const Duration(milliseconds: 800),
        curve: Curves.easeInOut,
        alignment: 0.3,
      );
    }
    setState(() => _showSettings = false);
  }

  void _toggleMusic() async {
    setState(() {
      _isMusicEnabled = !_isMusicEnabled;
    });
    
    // Сохраняем локальную настройку для этой страницы
    await _cache.setSetting('full_text_music_enabled', _isMusicEnabled);
    
    // Управляем только фоновой музыкой с главного экрана
    if (_isMusicEnabled) {
      // Возобновляем фоновую музыку
      await _soundManager.resumeAll();
    } else {
      // Приостанавливаем фоновую музыку (не останавливаем полностью)
      await _soundManager.pauseAll();
    }
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
            
            // Элегантная анимация поиска
            if (_isSearchingQuote)
              AppleStyleSearchOverlay(
                authorName: _bookSource?.author ?? widget.context.quote.author,
                bookTitle: _bookSource?.title ?? widget.context.quote.source,
                theme: _currentTheme,
                onComplete: () {
                  // Анимация завершена, закрываем overlay
                  if (mounted) {
                    setState(() {
                      _isSearchingQuote = false;
                    });
                  }
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
                    style: TextStyle(color: _effectiveTextColor.withAlpha((0.7 * 255).round())),
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
            color: Colors.black.withAlpha((0.1 * 255).round()),
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
                    color: _effectiveTextColor.withAlpha((0.7 * 255).round()),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          // Кнопка музыки
          IconButton(
            onPressed: _toggleMusic,
            icon: Icon(
              _isMusicEnabled ? Icons.volume_up : Icons.volume_off,
              color: _effectiveTextColor,
            ),
            tooltip: _isMusicEnabled ? 'Выключить музыку' : 'Включить музыку',
          ),
          // Прогресс чтения
          Container(
            width: 40,
            height: 40,
            margin: const EdgeInsets.symmetric(horizontal: 8),
            child: Stack(
              alignment: Alignment.center,
              children: [
                CircularProgressIndicator(
                  value: _readingProgress,
                  backgroundColor: _currentTheme.borderColor.withAlpha((0.2 * 255).round()),
                  valueColor: AlwaysStoppedAnimation<Color>(_currentTheme.quoteHighlightColor),
                  strokeWidth: 3,
                ),
                Text(
                  '${(_readingProgress * 100).toInt()}%',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: _effectiveTextColor,
                  ),
                ),
              ],
            ),
          ),
          // Настройки
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
      onScrollToQuote: _scrollToQuoteFromSettings,
      onScrollToStart: _scrollToStart,
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
          color: _currentTheme.quoteHighlightColor.withAlpha((0.15 * 255).round()),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _currentTheme.quoteHighlightColor,
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: _currentTheme.quoteHighlightColor.withAlpha((0.2 * 255).round()),
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
          color: _currentTheme.contextHighlightColor.withAlpha((0.1 * 255).round()),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _currentTheme.contextHighlightColor.withAlpha((0.3 * 255).round()),
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
                color: _currentTheme.quoteHighlightColor.withAlpha((0.6 * 255).round()),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Expanded(
              child: SelectableText(
                paragraph.content,
                style: TextStyle(
                  fontSize: _fontSize,
                  height: _lineHeight,
                  color: _effectiveTextColor.withAlpha((0.9 * 255).round()),
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
    });

    // Ждем 1.5 секунды перед началом скролла
    await Future.delayed(const Duration(milliseconds: 1500));

    // Выполняем плавный скролл к цитате
    await _itemScrollController.scrollTo(
      index: _targetParagraphIndex!,
      duration: const Duration(milliseconds: 2000),
      curve: Curves.easeInOutCubic,
      alignment: 0.3,
    );

    // Ждем завершения скролла
    await Future.delayed(const Duration(milliseconds: 300));

    if (mounted) {
      setState(() {
        _autoScrollCompleted = true;
        _findingQuote = false;
      });
    }
  }

  @override
  void dispose() {
    // Если музыка была выключена локально, возобновляем при выходе
    if (!_isMusicEnabled && !_soundManager.isMuted) {
      _soundManager.resumeAll();
    }
    
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