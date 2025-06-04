
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

// Экспорт для использования в ContextPage
export 'full_text_page_2.dart';

// --- Элегантная анимация поиска ---
class ElegantSearchAnimation extends StatefulWidget {
  final String authorName;
  final String bookTitle;
  final ReadingTheme theme;
  final VoidCallback? onCancel;

  const ElegantSearchAnimation({
    super.key,
    required this.authorName,
    required this.bookTitle,
    required this.theme,
    this.onCancel,
  });

  @override
  State<ElegantSearchAnimation> createState() => _ElegantSearchAnimationState();
}

class _ElegantSearchAnimationState extends State<ElegantSearchAnimation>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _waveController;
  late AnimationController _textController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _waveAnimation;
  late Animation<double> _textFadeAnimation;

  @override
  void initState() {
    super.initState();
    
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    
    _waveController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );
    
    _textController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _pulseAnimation = Tween<double>(
      begin: 0.8,
      end: 1.2,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));

    _waveAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _waveController,
      curve: Curves.easeInOut,
    ));

    _textFadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _textController,
      curve: Curves.easeOut,
    ));

    // Запускаем анимации
    _pulseController.repeat(reverse: true);
    _waveController.repeat();
    _textController.forward();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _waveController.dispose();
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            widget.theme.backgroundColor.withOpacity(0.95),
            widget.theme.backgroundColor.withOpacity(0.98),
          ],
        ),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Основная анимация поиска
            SizedBox(
              width: 200,
              height: 200,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Внешние волны
                  ...List.generate(3, (index) => _buildWave(index)),
                  
                  // Центральная иконка с пульсацией
                  AnimatedBuilder(
                    animation: _pulseAnimation,
                    builder: (context, child) {
                      return Transform.scale(
                        scale: _pulseAnimation.value,
                        child: Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            color: widget.theme.quoteHighlightColor,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: widget.theme.quoteHighlightColor.withOpacity(0.3),
                                blurRadius: 20,
                                spreadRadius: 5,
                              ),
                            ],
                          ),
                          child: Icon(
                            Icons.auto_stories,
                            color: Colors.white,
                            size: 40,
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 40),
            
            // Текстовая информация с анимацией появления
            FadeTransition(
              opacity: _textFadeAnimation,
              child: Column(
                children: [
                  // Заголовок
                  Text(
                    'Поиск цитаты',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w600,
                      color: widget.theme.textColor,
                      letterSpacing: 0.5,
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Информация о книге
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
                    margin: const EdgeInsets.symmetric(horizontal: 40),
                    decoration: BoxDecoration(
                      color: widget.theme.cardColor.withOpacity(0.8),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: widget.theme.borderColor.withOpacity(0.3),
                        width: 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Text(
                          widget.bookTitle,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w500,
                            color: widget.theme.textColor,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          widget.authorName,
                          style: TextStyle(
                            fontSize: 16,
                            color: widget.theme.textColor.withOpacity(0.7),
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Анимированный текст состояния
                  _buildAnimatedStatus(),
                  
                  const SizedBox(height: 32),
                  
                  // Кнопка отмены (опционально)
                  if (widget.onCancel != null)
                    TextButton.icon(
                      onPressed: widget.onCancel,
                      icon: Icon(
                        Icons.close,
                        color: widget.theme.textColor.withOpacity(0.6),
                        size: 20,
                      ),
                      label: Text(
                        'Отменить',
                        style: TextStyle(
                          color: widget.theme.textColor.withOpacity(0.6),
                          fontSize: 16,
                        ),
                      ),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWave(int index) {
    final delay = index * 0.3;
    return AnimatedBuilder(
      animation: _waveAnimation,
      builder: (context, child) {
        final progress = (_waveAnimation.value + delay) % 1.0;
        final opacity = (1 - progress).clamp(0.0, 0.4);
        final scale = 0.3 + (progress * 1.2);
        
        return Transform.scale(
          scale: scale,
          child: Container(
            width: 200,
            height: 200,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: widget.theme.quoteHighlightColor.withOpacity(opacity),
                width: 2,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildAnimatedStatus() {
    return AnimatedBuilder(
      animation: _textController,
      builder: (context, child) {
        final dots = '.' * ((_textController.value * 3).floor() + 1);
        return Text(
          'Ищем нужный фрагмент$dots',
          style: TextStyle(
            fontSize: 16,
            color: widget.theme.textColor.withOpacity(0.8),
            fontWeight: FontWeight.w300,
          ),
        );
      },
    );
  }
}

// --- Анимация с прогрессом ---
class SearchProgressOverlay extends StatefulWidget {
  final String authorName;
  final String bookTitle;
  final ReadingTheme theme;
  final double progress; // от 0.0 до 1.0
  final String statusText;
  final VoidCallback? onCancel;

  const SearchProgressOverlay({
    super.key,
    required this.authorName,
    required this.bookTitle,
    required this.theme,
    required this.progress,
    required this.statusText,
    this.onCancel,
  });

  @override
  State<SearchProgressOverlay> createState() => _SearchProgressOverlayState();
}

class _SearchProgressOverlayState extends State<SearchProgressOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _shimmerController;
  late Animation<double> _shimmerAnimation;

  @override
  void initState() {
    super.initState();
    _shimmerController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _shimmerAnimation = Tween<double>(
      begin: -1.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _shimmerController,
      curve: Curves.easeInOut,
    ));
    _shimmerController.repeat();
  }

  @override
  void dispose() {
    _shimmerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            widget.theme.backgroundColor.withOpacity(0.95),
            widget.theme.backgroundColor.withOpacity(0.98),
          ],
        ),
      ),
      child: Center(
        child: Container(
          margin: const EdgeInsets.all(40),
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: widget.theme.cardColor,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Иконка книги
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: widget.theme.quoteHighlightColor.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.menu_book,
                  size: 40,
                  color: widget.theme.quoteHighlightColor,
                ),
              ),
              
              const SizedBox(height: 24),
              
              // Заголовок
              Text(
                'Анализ текста',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                  color: widget.theme.textColor,
                ),
              ),
              
              const SizedBox(height: 8),
              
              // Информация о книге
              Text(
                widget.bookTitle,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: widget.theme.textColor,
                ),
              ),
              
              Text(
                widget.authorName,
                style: TextStyle(
                  fontSize: 14,
                  color: widget.theme.textColor.withOpacity(0.7),
                  fontStyle: FontStyle.italic,
                ),
              ),
              
              const SizedBox(height: 32),
              
              // Прогресс бар с шиммером
              Container(
                width: double.infinity,
                height: 8,
                decoration: BoxDecoration(
                  color: widget.theme.highlightColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Stack(
                  children: [
                    // Основной прогресс
                    FractionallySizedBox(
                      widthFactor: widget.progress,
                      child: Container(
                        decoration: BoxDecoration(
                          color: widget.theme.quoteHighlightColor,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                    // Шиммер эффект
                    if (widget.progress < 1.0)
                      AnimatedBuilder(
                        animation: _shimmerAnimation,
                        builder: (context, child) {
                          return Transform.translate(
                            offset: Offset(_shimmerAnimation.value * 200, 0),
                            child: Container(
                              width: 100,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    Colors.transparent,
                                    widget.theme.quoteHighlightColor.withOpacity(0.5),
                                    Colors.transparent,
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                          );
                        },
                      ),
                  ],
                ),
              ),
              
              const SizedBox(height: 16),
              
              // Процент и статус
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${(widget.progress * 100).toInt()}%',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: widget.theme.quoteHighlightColor,
                    ),
                  ),
                  Text(
                    widget.statusText,
                    style: TextStyle(
                      fontSize: 14,
                      color: widget.theme.textColor.withOpacity(0.7),
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 24),
              
              // Кнопка отмены
              if (widget.onCancel != null)
                SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    onPressed: widget.onCancel,
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                        side: BorderSide(
                          color: widget.theme.borderColor.withOpacity(0.3),
                        ),
                      ),
                    ),
                    child: Text(
                      'Отменить поиск',
                      style: TextStyle(
                        color: widget.theme.textColor.withOpacity(0.7),
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
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
  double _searchProgress = 0.0;
  String _searchStatus = 'Подготовка к поиску...';

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
      _searchProgress = 0.0;
      _searchStatus = 'Поиск позиции цитаты...';
    });

    // Симулируем прогресс поиска
    for (int i = 0; i <= 100; i += 10) {
      await Future.delayed(const Duration(milliseconds: 50));
      if (mounted) {
        setState(() {
          _searchProgress = i / 100.0;
          if (i < 30) {
            _searchStatus = 'Анализ структуры текста...';
          } else if (i < 60) {
            _searchStatus = 'Поиск позиции цитаты...';
          } else if (i < 90) {
            _searchStatus = 'Подготовка к прокрутке...';
          } else {
            _searchStatus = 'Переход к цитате...';
          }
        });
      }
    }

    // Выполняем скролл
    await Future.delayed(const Duration(milliseconds: 200));
    if (mounted) {
      await _itemScrollController.scrollTo(
        index: _targetParagraphIndex!,
        duration: const Duration(milliseconds: 1200),
        curve: Curves.easeOutCubic,
        alignment: 0.3,
      );
    }

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
    buffer.writeln('offsets построено: ${_paragraphOffsets.length}');
    buffer.writeln('offset для target: ${_targetParagraphIndex != null ? _paragraphOffsets[_targetParagraphIndex!] : "нет"}');
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
              SearchProgressOverlay(
                authorName: _bookSource?.author ?? widget.context.quote.author,
                bookTitle: _bookSource?.title ?? widget.context.quote.source,
                theme: _currentTheme,
                progress: _searchProgress,
                statusText: _searchStatus,
                onCancel: () {
                  setState(() {
                    _isSearchingQuote = false;
                    _findingQuote = false;
                  });
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
      _searchProgress = 0.0;
      _searchStatus = 'Ручной поиск цитаты...';
      _findingQuote = true;
    });

    // Симулируем прогресс ручного поиска
    for (int i = 0; i <= 100; i += 20) {
      await Future.delayed(const Duration(milliseconds: 100));
      if (mounted) {
        setState(() {
          _searchProgress = i / 100.0;
          if (i < 40) {
            _searchStatus = 'Поиск в тексте...';
          } else if (i < 80) {
            _searchStatus = 'Вычисление позиции...';
          } else {
            _searchStatus = 'Переход к цитате...';
          }
        });
      }
    }

    // Выполняем скролл к цитате
    await _itemScrollController.scrollTo(
      index: _targetParagraphIndex!,
      duration: const Duration(milliseconds: 800),
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