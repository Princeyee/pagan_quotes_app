// lib/ui/widgets/interactive_pagan_wheel.dart - ОБНОВЛЕННАЯ ВЕРСИЯ С ФИЛЬТРАМИ ДОСТОВЕРНОСТИ
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'dart:async';
import 'package:just_audio/just_audio.dart';
import '../../models/pagan_holiday.dart';
import '../widgets/holiday_info_modal.dart';
import '../../services/sound_manager.dart';

class InteractivePaganWheel extends StatefulWidget {
  final Function(int month, List<PaganHoliday> holidays)? onMonthChanged;
  final String? selectedTradition; // Фильтр по традициям
  final HistoricalAuthenticity? selectedAuthenticity; // НОВЫЙ ФИЛЬТР ПО ДОСТОВЕРНОСТИ
  
  const InteractivePaganWheel({
    super.key,
    this.onMonthChanged,
    this.selectedTradition,
    this.selectedAuthenticity, // НОВЫЙ ПАРАМЕТР
  });

  @override
  State<InteractivePaganWheel> createState() => _InteractivePaganWheelState();
}

class _InteractivePaganWheelState extends State<InteractivePaganWheel>
    with TickerProviderStateMixin {
  
  late AnimationController _rotationController;
  late AnimationController _glowController;
  late AnimationController _contentRevealController;
  late AnimationController _shimmerController;
  late AnimationController _loadingController;
  
  late Animation<double> _rotationAnimation;
  late Animation<double> _glowAnimation;
  late Animation<double> _contentRevealAnimation;
  late Animation<double> _shimmerAnimation;
  late Animation<double> _loadingAnimation;

  double _currentRotation = 0.0;
  int _selectedMonth = DateTime.now().month;
  bool _hasInteracted = false;
  bool _isLoading = true;
  List<PaganHoliday> _currentMonthHolidays = [];
  Timer? _soundTimer;
  AudioPlayer? _wheelSoundPlayer;
  
  final SoundManager _soundManager = SoundManager();

  final List<MonthData> _months = [
    MonthData('Январь', SeasonType.winter, const Color(0xFF4A6FA5)),   
    MonthData('Февраль', SeasonType.winter, const Color(0xFF5B7DB1)), 
    MonthData('Март', SeasonType.spring, const Color(0xFF6B8B5B)),     
    MonthData('Апрель', SeasonType.spring, const Color(0xFF7A9866)),   
    MonthData('Май', SeasonType.spring, const Color(0xFF8AA570)),      
    MonthData('Июнь', SeasonType.summer, const Color(0xFF9A8840)),     
    MonthData('Июль', SeasonType.summer, const Color(0xFFA8754A)),     
    MonthData('Август', SeasonType.summer, const Color(0xFFB8603A)),   
    MonthData('Сентябрь', SeasonType.autumn, const Color(0xFFA5603A)), 
    MonthData('Октябрь', SeasonType.autumn, const Color(0xFF95503A)),  
    MonthData('Ноябрь', SeasonType.autumn, const Color(0xFF7A4A4A)),   
    MonthData('Декабрь', SeasonType.winter, const Color(0xFF5A5A7A)),  
  ];

  @override
  void initState() {
    super.initState();
    
    _initializeAnimations();
    
    final currentMonth = DateTime.now().month;
    _selectedMonth = currentMonth;
    _loadHolidaysForMonth(currentMonth);
    
    _loadingController.forward();
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeWheel();
    });
  }

  // ОБНОВЛЯЕМ ПРИ ИЗМЕНЕНИИ ЛЮБОГО ИЗ ФИЛЬТРОВ
  @override
  void didUpdateWidget(InteractivePaganWheel oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    // Если изменился любой из фильтров, обновляем праздники
    if (oldWidget.selectedTradition != widget.selectedTradition ||
        oldWidget.selectedAuthenticity != widget.selectedAuthenticity) {
      _loadHolidaysForMonth(_selectedMonth);
    }
  }

  void _initializeAnimations() {
    _rotationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    
    _glowController = AnimationController(
      duration: const Duration(seconds: 6),
      vsync: this,
    )..repeat(reverse: true);
    
    _contentRevealController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    _shimmerController = AnimationController(
      duration: const Duration(seconds: 4),
      vsync: this,
    )..repeat();

    _loadingController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _rotationAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _rotationController,
      curve: Curves.easeInOutCubic,
    ));

    _glowAnimation = Tween<double>(
      begin: 0.3,
      end: 0.8,
    ).animate(CurvedAnimation(
      parent: _glowController,
      curve: Curves.easeInOut,
    ));

    _shimmerAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _shimmerController,
      curve: Curves.linear,
    ));

    _contentRevealAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _contentRevealController,
      curve: Curves.easeOutBack,
    ));

    _loadingAnimation = Tween<double>(
      begin: 0.0,
      end: 2 * math.pi,
    ).animate(CurvedAnimation(
      parent: _loadingController,
      curve: Curves.linear,
    ));
  }

  Future<void> _initializeWheel() async {
    await Future.delayed(const Duration(milliseconds: 300));
    
    _rotateToCurrentMonth();
    
    await Future.delayed(const Duration(milliseconds: 600));
    
    setState(() {
      _isLoading = false;
    });
  }

  // ОБНОВЛЯЕМ МЕТОД ЗАГРУЗКИ ПРАЗДНИКОВ С УЧЕТОМ ОБОИХ ФИЛЬТРОВ
  void _loadHolidaysForMonth(int month) {
    try {
      List<PaganHoliday> allHolidays = PaganHolidayService.getHolidaysForMonth(month);
      
      // ПРИМЕНЯЕМ ФИЛЬТР ПО ТРАДИЦИЯМ
      if (widget.selectedTradition != null) {
        allHolidays = allHolidays
            .where((holiday) => holiday.tradition == widget.selectedTradition)
            .toList();
      }
      
      // ПРИМЕНЯЕМ ФИЛЬТР ПО ДОСТОВЕРНОСТИ
      if (widget.selectedAuthenticity != null) {
        allHolidays = allHolidays
            .where((holiday) => holiday.authenticity == widget.selectedAuthenticity)
            .toList();
      }
      
      _currentMonthHolidays = allHolidays;
      
      // Уведомляем родительский виджет об изменениях
      widget.onMonthChanged?.call(month, _currentMonthHolidays);
      
    } catch (e) {
      _currentMonthHolidays = [];
      widget.onMonthChanged?.call(month, []);
    }
  }

  void _handleTap(TapDownDetails details) {
    if (_isLoading) return;
    
    final screenWidth = MediaQuery.of(context).size.width;
    final tapX = details.globalPosition.dx;
    
    if (tapX < screenWidth / 2) {
      _goToPreviousMonth();
    } else {
      _goToNextMonth();
    }
  }

  void _goToPreviousMonth() {
    int newMonth = _selectedMonth - 1;
    if (newMonth < 1) newMonth = 12;
    _rotateToMonth(newMonth);
  }

  void _goToNextMonth() {
    int newMonth = _selectedMonth + 1;
    if (newMonth > 12) newMonth = 1;
    _rotateToMonth(newMonth);
  }

  Future<void> _playFireSound() async {
    if (!_soundManager.isMuted) {
      try {
        _soundTimer?.cancel();
        await _wheelSoundPlayer?.stop();
        await _wheelSoundPlayer?.dispose();
        
        _wheelSoundPlayer = AudioPlayer();
        await _wheelSoundPlayer!.setAsset('assets/sounds/fire.mp3');
        
        _wheelSoundPlayer!.play();
        
        _soundTimer = Timer(const Duration(milliseconds: 700), () async {
          await _wheelSoundPlayer?.stop();
          await _wheelSoundPlayer?.dispose();
          _wheelSoundPlayer = null;
        });
        
      } catch (e) {
        print('Fire sound not available: $e');
      }
    }
  }

  void _rotateToMonth(int month) {
    final monthIndex = month - 1;
    final monthCenterAngle = monthIndex * (2 * math.pi / 12) + (math.pi / 12);
    final targetRotation = -monthCenterAngle + math.pi;
    
    _playFireSound();
    
    setState(() {
      _selectedMonth = month;
      _loadHolidaysForMonth(month); // ПЕРЕЗАГРУЖАЕМ С УЧЕТОМ ОБОИХ ФИЛЬТРОВ
      
      if (!_hasInteracted) {
        _hasInteracted = true;
        _contentRevealController.forward();
      }
    });
    
    _rotationController.reset();
    _rotationAnimation = Tween<double>(
      begin: _currentRotation,
      end: targetRotation,
    ).animate(CurvedAnimation(
      parent: _rotationController,
      curve: Curves.easeInOutCubic,
    ));
    
    _rotationController.forward().then((_) {
      setState(() {
        _currentRotation = targetRotation;
      });
    });
  }

  void _rotateToCurrentMonth() {
    final currentMonth = DateTime.now().month;
    
    final monthIndex = currentMonth - 1; 
    final monthCenterAngle = monthIndex * (2 * math.pi / 12) + (math.pi / 12);
    final targetRotation = -monthCenterAngle + math.pi;
    
    setState(() {
      _currentRotation = targetRotation;
      _selectedMonth = currentMonth;
      _loadHolidaysForMonth(currentMonth);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Колесо с эффектами
        GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTapDown: _handleTap,
          child: Container(
            height: 380,
            width: double.infinity,
            child: ClipRect(
                  child: Stack(
                    children: [
                      Positioned(
                        bottom: -80,
                        left: -50,
                        right: -50,
                        child: Stack(
                          children: [
                            AnimatedOpacity(
                              duration: const Duration(milliseconds: 600),
                              opacity: _isLoading ? 0.3 : 1.0,
                              child: AnimatedBuilder(
                                animation: Listenable.merge([_rotationAnimation, _glowAnimation]),
                                builder: (context, child) {
                                  final currentRotation = _rotationController.isAnimating 
                                      ? _rotationAnimation.value 
                                      : _currentRotation;
                                  
                                  return Transform.rotate(
                                    angle: currentRotation,
                                    child: Stack(
                                      alignment: Alignment.center,
                                      children: [
                                        CustomPaint(
                                          size: const Size(650, 650),
                                          painter: EnhancedWheelPainter(
                                            months: _months,
                                            selectedMonth: _selectedMonth - 1,
                                            glowIntensity: _glowAnimation.value,
                                            shimmerProgress: _shimmerAnimation.value,
                                          ),
                                        ),
                                        _buildCenterElement(),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            ),
                            if (!_isLoading)
                              _buildDecorativeElements(),
                          ],
                        ),
                      ),
                      _buildTopGradient(),
                      if (!_isLoading)
                        _buildMonthIndicator(),
                    ],
                  ),
                ),
          ),
        ),
        // Список праздников месяца убран
      ],
    );
  }

  List<Widget> _buildGlowLayers() {
    return [
      AnimatedBuilder(
        animation: _glowAnimation,
        builder: (context, child) {
          return Container(
            width: 680,
            height: 680,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: _months[_selectedMonth - 1].color.withAlpha((0.05 * _glowAnimation.value * 255).round()),
                  blurRadius: 120,
                  spreadRadius: 60,
                ),
              ],
            ),
          );
        },
      ),
      
      AnimatedBuilder(
        animation: _glowAnimation,
        builder: (context, child) {
          return Container(
            width: 660,
            height: 660,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  Colors.transparent,
                  _months[_selectedMonth - 1].color.withAlpha((0.03 * _glowAnimation.value * 255).round()),
                  Colors.transparent,
                ],
                stops: const [0.0, 0.7, 1.0],
              ),
            ),
          );
        },
      ),
    ];
  }

  Widget _buildCenterElement() {
    return Center(
      child: Container(
        width: 120,
        height: 120,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [
              Colors.black.withAlpha((0.95 * 255).round()),
              Colors.black.withAlpha((0.8 * 255).round()),
              Colors.black.withAlpha((0.6 * 255).round()),
            ],
            stops: const [0.0, 0.7, 1.0],
          ),
          border: Border.all(
            color: Colors.white.withAlpha((0.15 * 255).round()),
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha((0.6 * 255).round()),
              blurRadius: 25,
              spreadRadius: 8,
            ),
            BoxShadow(
              color: _months[_selectedMonth - 1].color.withAlpha((0.3 * 255).round()),
              blurRadius: 40,
              spreadRadius: 0,
            ),
          ],
        ),
        child: ClipOval(
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 8.0, sigmaY: 8.0),
            child: Container(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  colors: [
                    Colors.white.withAlpha((0.08 * 255).round()),
                    Colors.transparent,
                  ],
                ),
              ),
              child: Center(
                child: Container(
                  width: 90,
                  height: 90,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.transparent,
                  ),
                  child: ClipOval(
                    child: Image.asset(
                      'assets/icon/old1.png',
                      width: 90,
                      height: 90,
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) {
                        print('Ошибка загрузки old1.png: $error');
                        return Container(
                          width: 90,
                          height: 90,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: RadialGradient(
                              colors: [
                                _months[_selectedMonth - 1].color.withAlpha((0.7 * 255).round()),
                                _months[_selectedMonth - 1].color.withAlpha((0.3 * 255).round()),
                              ],
                            ),
                          ),
                          child: Icon(
                            Icons.auto_awesome,
                            color: Colors.white.withAlpha((0.9 * 255).round()),
                            size: 45,
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDecorativeElements() {
    return AnimatedBuilder(
      animation: _shimmerAnimation,
      builder: (context, child) {
        return CustomPaint(
          size: const Size(700, 700),
          painter: DecorativeElementsPainter(
            progress: _shimmerAnimation.value,
            color: _months[_selectedMonth - 1].color,
          ),
        );
      },
    );
  }

  Widget _buildTopGradient() {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      height: 180,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.black.withAlpha((0.8 * 255).round()),
              Colors.black.withAlpha((0.6 * 255).round()),
              Colors.black.withAlpha((0.3 * 255).round()),
              Colors.black.withAlpha((0.1 * 255).round()),
              Colors.transparent,
            ],
            stops: const [0.0, 0.3, 0.6, 0.8, 1.0],
          ),
        ),
      ),
    );
  }

  Widget _buildMonthIndicator() {
    // Убираем белую палочку - возвращаем пустой виджет
    return const SizedBox.shrink();
  }

  @override
  void dispose() {
    _rotationController.dispose();
    _glowController.dispose();
    _contentRevealController.dispose();
    _shimmerController.dispose();
    _loadingController.dispose();
    _soundTimer?.cancel();
    _wheelSoundPlayer?.stop();
    _wheelSoundPlayer?.dispose();
    super.dispose();
  }
}

// Painter для анимации загрузки
class LoadingWheelPainter extends CustomPainter {
  final double progress;

  LoadingWheelPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 15;
    
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    
    for (int i = 0; i < 3; i++) {
      final startAngle = (i * 120) * math.pi / 180;
      final sweepAngle = progress * math.pi * 0.6;
      
      paint.shader = LinearGradient(
        colors: [
          Colors.white.withAlpha((0.1 * 255).round()),
          Colors.white.withAlpha((0.3 * progress * 255).round()),
        ],
      ).createShader(Rect.fromCircle(center: center, radius: radius));
      
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius - i * 20),
        startAngle,
        sweepAngle,
        false,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

// Улучшенный Painter для колеса
class EnhancedWheelPainter extends CustomPainter {
  final List<MonthData> months;
  final int selectedMonth;
  final double glowIntensity;
  final double shimmerProgress;

  EnhancedWheelPainter({
    required this.months,
    required this.selectedMonth,
    required this.glowIntensity,
    required this.shimmerProgress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 15;
    final sectorAngle = 2 * math.pi / 12;

    _drawWheelShadow(canvas, center, radius);

    for (int i = 0; i < 12; i++) {
      final month = months[i];
      final isSelected = i == selectedMonth;
      
      final startAngle = i * sectorAngle - math.pi / 2;
      final midAngle = startAngle + sectorAngle / 2;

      _drawSector(canvas, center, radius, startAngle, sectorAngle, month, isSelected);
      _drawSectorLines(canvas, center, radius, startAngle);
      _drawMonthSymbol(canvas, center, radius * 0.55, midAngle, i + 1, month);
      _drawMonthText(canvas, center, radius * 0.75, midAngle, month.name);
    }

    _drawOuterRing(canvas, center, radius);
    _drawSeasonLabels(canvas, center, radius + 25);
    _drawShimmerEffect(canvas, center, radius);
  }

  void _drawWheelShadow(Canvas canvas, Offset center, double radius) {
    final shadowPaint = Paint()
      ..color = Colors.black.withAlpha((0.3 * 255).round())
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 30);
    
    canvas.drawCircle(center, radius + 5, shadowPaint);
  }

  void _drawSector(Canvas canvas, Offset center, double radius, double startAngle, 
      double sectorAngle, MonthData month, bool isSelected) {
    final rect = Rect.fromCircle(center: center, radius: radius);
    
    final gradient = RadialGradient(
      center: Alignment(
        math.cos(startAngle + sectorAngle / 2) * 0.5,
        math.sin(startAngle + sectorAngle / 2) * 0.5,
      ),
      colors: [
        Colors.black.withAlpha((0.9 * 255).round()),
        Colors.black.withAlpha((0.7 * 255).round()),
        month.color.withAlpha((0.2 * 255).round()),
        month.color.withAlpha(((isSelected ? 0.5 : 0.3) * 255).round()),
      ],
      stops: const [0.0, 0.3, 0.7, 1.0],
    );

    final paint = Paint()
      ..shader = gradient.createShader(rect)
      ..style = PaintingStyle.fill;

    final path = Path();
    path.moveTo(center.dx, center.dy);
    path.arcTo(rect, startAngle, sectorAngle, false);
    path.close();

    canvas.drawPath(path, paint);

    if (isSelected) {
      final highlightPaint = Paint()
        ..shader = RadialGradient(
          center: Alignment(
            math.cos(startAngle + sectorAngle / 2) * 0.5,
            math.sin(startAngle + sectorAngle / 2) * 0.5,
          ),
          colors: [
            Colors.transparent,
            month.color.withAlpha((0.2 * glowIntensity * 255).round()),
          ],
        ).createShader(rect)
        ..style = PaintingStyle.fill;

      canvas.drawPath(path, highlightPaint);
    }
  }

  void _drawSectorLines(Canvas canvas, Offset center, double radius, double angle) {
    final linePaint = Paint()
      ..color = Colors.white.withAlpha((0.1 * 255).round())
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5;

    final innerRadius = radius * 0.3;
    final outerPoint = Offset(
      center.dx + math.cos(angle) * radius,
      center.dy + math.sin(angle) * radius,
    );
    final innerPoint = Offset(
      center.dx + math.cos(angle) * innerRadius,
      center.dy + math.sin(angle) * innerRadius,
    );

    canvas.drawLine(innerPoint, outerPoint, linePaint);
  }

  void _drawMonthSymbol(Canvas canvas, Offset center, double radius, double angle, 
      int month, MonthData monthData) {
    final symbolX = center.dx + math.cos(angle) * radius;
    final symbolY = center.dy + math.sin(angle) * radius;
    
    final glowPaint = Paint()
      ..color = monthData.color.withAlpha((0.3 * glowIntensity * 255).round())
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    
    canvas.drawCircle(Offset(symbolX, symbolY), 15, glowPaint);
    
    final monthSymbol = _getMonthSymbol(month);
    final symbolPainter = TextPainter(
      text: TextSpan(
        text: monthSymbol,
        style: TextStyle(
          color: monthData.color.withAlpha((0.9 * 255).round()),
          fontSize: 24,
          fontWeight: FontWeight.w600,
          shadows: [
            Shadow(
              color: monthData.color.withAlpha((0.5 * 255).round()),
              blurRadius: 4,
            ),
            Shadow(
              color: Colors.black.withAlpha((0.8 * 255).round()),
              blurRadius: 2,
              offset: const Offset(1, 1),
            ),
          ],
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    
    symbolPainter.layout();
    canvas.save();
    canvas.translate(symbolX, symbolY);
    symbolPainter.paint(canvas, Offset(-symbolPainter.width / 2, -symbolPainter.height / 2));
    canvas.restore();
  }

  void _drawMonthText(Canvas canvas, Offset center, double radius, double angle, String name) {
    final textX = center.dx + math.cos(angle) * radius;
    final textY = center.dy + math.sin(angle) * radius;

    final textPainter = TextPainter(
      text: TextSpan(
        text: name,
        style: TextStyle(
          color: Colors.white.withAlpha((0.8 * 255).round()),
          fontSize: 14,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.5,
          shadows: [
            Shadow(
              color: Colors.black.withAlpha((0.9 * 255).round()),
              blurRadius: 4,
              offset: const Offset(1, 1),
            ),
          ],
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    
    textPainter.layout();
    
    canvas.save();
    canvas.translate(textX, textY);
    
    double textRotation = angle + math.pi / 2;
    if (textRotation > math.pi / 2 && textRotation < 3 * math.pi / 2) {
      textRotation += math.pi;
    }
    
    canvas.rotate(textRotation);
    textPainter.paint(canvas, Offset(-textPainter.width / 2, -textPainter.height / 2));
    canvas.restore();
  }

  void _drawOuterRing(Canvas canvas, Offset center, double radius) {
    final ringPaint = Paint()
      ..shader = LinearGradient(
        colors: [
          Colors.white.withAlpha((0.3 * 255).round()),
          Colors.white.withAlpha((0.1 * 255).round()),
        ],
      ).createShader(Rect.fromCircle(center: center, radius: radius))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    
    canvas.drawCircle(center, radius, ringPaint);
    
    final innerRingPaint = Paint()
      ..color = Colors.white.withAlpha((0.05 * 255).round())
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    
    canvas.drawCircle(center, radius * 0.3, innerRingPaint);
  }

  void _drawSeasonLabels(Canvas canvas, Offset center, double radius) {
    final seasonData = [
      {'name': 'ЗИМА', 'months': [12, 1, 2], 'color': const Color(0xFF87CEEB)},
      {'name': 'ВЕСНА', 'months': [3, 4, 5], 'color': const Color(0xFF90EE90)},
      {'name': 'ЛЕТО', 'months': [6, 7, 8], 'color': const Color(0xFFFFD700)},
      {'name': 'ОСЕНЬ', 'months': [9, 10, 11], 'color': const Color(0xFFDC143C)},
    ];

    for (final season in seasonData) {
      final seasonName = season['name'] as String;
      final months = season['months'] as List<int>;
      final seasonColor = season['color'] as Color;
      
      _drawCurvedSeasonText(canvas, seasonName, center, radius, months, seasonColor);
    }
  }

  void _drawCurvedSeasonText(Canvas canvas, String text, Offset center, double radius, 
      List<int> months, Color seasonColor) {
    final firstMonth = months[0];
    final lastMonth = months[2];
    
    final firstIndex = (firstMonth - 1) % 12;
    
    var startAngle = firstIndex * (2 * math.pi / 12) - math.pi / 2;
    
    if (firstMonth == 12 && lastMonth == 2) {
      startAngle = 11 * (2 * math.pi / 12) - math.pi / 2;
    }
    
    final totalAngle = math.pi / 2;
    final textLength = text.length;
    final charAngleStep = totalAngle / (textLength + 1);
    
    for (int i = 0; i < textLength; i++) {
      final char = text[i];
      final charAngle = startAngle + (i + 1) * charAngleStep;
      
      final x = center.dx + math.cos(charAngle) * radius;
      final y = center.dy + math.sin(charAngle) * radius;

      final textPainter = TextPainter(
        text: TextSpan(
          text: char,
          style: TextStyle(
            color: seasonColor.withAlpha((0.8 * 255).round()),
            fontSize: 16,
            fontWeight: FontWeight.w700,
            letterSpacing: 2,
            shadows: [
              Shadow(
                color: Colors.black.withAlpha((0.9 * 255).round()),
                blurRadius: 4,
                offset: const Offset(1, 1),
              ),
              Shadow(
                color: seasonColor.withAlpha((0.4 * 255).round()),
                blurRadius: 10,
              ),
            ],
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      
      textPainter.layout();
      
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(charAngle + math.pi / 2);
      textPainter.paint(canvas, Offset(-textPainter.width / 2, -textPainter.height / 2));
      canvas.restore();
    }
  }

  void _drawShimmerEffect(Canvas canvas, Offset center, double radius) {
    final shimmerPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment(-1 + shimmerProgress * 2, -1),
        end: Alignment(-1 + shimmerProgress * 2 + 0.5, 1),
        colors: [
          Colors.transparent,
          Colors.white.withAlpha((0.05 * 255).round()),
          Colors.transparent,
        ],
      ).createShader(Rect.fromCircle(center: center, radius: radius))
      ..style = PaintingStyle.fill
      ..blendMode = BlendMode.overlay;
    
    canvas.drawCircle(center, radius, shimmerPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;

  String _getMonthSymbol(int month) {
    switch (month) {
      case 1: return 'ᛁ'; // Январь - руна Иса
      case 2: return 'ᚢ'; // Февраль - руна Уруз
      case 3: return 'ᚦ'; // Март - руна Турисаз
      case 4: return 'ᚨ'; // Апрель - руна Ансуз
      case 5: return 'ᚱ'; // Май - руна Райдо
      case 6: return '☉'; // Июнь - солнце
      case 7: return 'ᛋ'; // Июль - руна Совило
      case 8: return 'ᛃ'; // Август - руна Йера
      case 9: return 'ᛈ'; // Сентябрь - руна Перт
      case 10: return 'ᛇ'; // Октябрь - руна Эйваз
      case 11: return 'ᛜ'; // Ноябрь - руна Ингуз
      case 12: return '☾'; // Декабрь - луна
      default: return '⚬';
    }
  }
}

// Painter для декоративных элементов
class DecorativeElementsPainter extends CustomPainter {
  final double progress;
  final Color color;

  DecorativeElementsPainter({
    required this.progress,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final paint = Paint()
      ..color = color.withAlpha((0.1 * 255).round())
      ..style = PaintingStyle.fill;

    // Рисуем орбитальные точки
    for (int i = 0; i < 12; i++) {
      final angle = (i * 30 * math.pi / 180) + (progress * 2 * math.pi);
      final radius = 320 + math.sin(progress * 2 * math.pi + i) * 20;
      
      final x = center.dx + math.cos(angle) * radius;
      final y = center.dy + math.sin(angle) * radius;
      
      final opacity = (0.3 + 0.3 * math.sin(progress * 2 * math.pi + i)).clamp(0.0, 1.0);
      paint.color = color.withAlpha((opacity * 0.2 * 255).round());
      
      canvas.drawCircle(Offset(x, y), 2, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class MonthData {
  final String name;
  final SeasonType season;
  final Color color;

  MonthData(this.name, this.season, this.color);
}

enum SeasonType { winter, spring, summer, autumn }