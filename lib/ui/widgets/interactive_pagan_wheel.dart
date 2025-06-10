// lib/ui/widgets/interactive_pagan_wheel.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:math' as math;
import '../../models/pagan_holiday.dart';
import '../widgets/holiday_info_modal.dart';

class InteractivePaganWheel extends StatefulWidget {
  final Function(int month, List<PaganHoliday> holidays)? onMonthChanged;
  
  const InteractivePaganWheel({
    super.key,
    this.onMonthChanged,
  });

  @override
  State<InteractivePaganWheel> createState() => _InteractivePaganWheelState();
}

class _InteractivePaganWheelState extends State<InteractivePaganWheel>
    with TickerProviderStateMixin {
  
  late AnimationController _rotationController;
  late AnimationController _glowController;
  late AnimationController _contentRevealController;
  
  late Animation<double> _rotationAnimation;
  late Animation<double> _glowAnimation;
  late Animation<double> _contentRevealAnimation;

  double _currentRotation = 0.0;
  int _selectedMonth = DateTime.now().month;
  bool _hasInteracted = false;
  List<PaganHoliday> _currentMonthHolidays = [];

  final List<MonthData> _months = [
    MonthData('Январь', SeasonType.winter, const Color(0xFF5A7A9A)),   
    MonthData('Февраль', SeasonType.winter, const Color(0xFF6B8FA8)), 
    MonthData('Март', SeasonType.spring, const Color(0xFF7A9B6B)),     
    MonthData('Апрель', SeasonType.spring, const Color(0xFF8AA876)),   
    MonthData('Май', SeasonType.spring, const Color(0xFF9AB580)),      
    MonthData('Июнь', SeasonType.summer, const Color(0xFFA8A050)),     
    MonthData('Июль', SeasonType.summer, const Color(0xFFB8855A)),     
    MonthData('Август', SeasonType.summer, const Color(0xFFC8704A)),   
    MonthData('Сентябрь', SeasonType.autumn, const Color(0xFFB5704A)), 
    MonthData('Октябрь', SeasonType.autumn, const Color(0xFFA5604A)),  
    MonthData('Ноябрь', SeasonType.autumn, const Color(0xFF8A5A5A)),   
    MonthData('Декабрь', SeasonType.winter, const Color(0xFF6A6A8A)),  
  ];

  @override
  void initState() {
    super.initState();
    
    _rotationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    
    _glowController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    )..repeat(reverse: true);
    
    _contentRevealController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _rotationAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _rotationController,
      curve: Curves.easeOutCubic,
    ));

    _glowAnimation = Tween<double>(
      begin: 0.4,
      end: 0.9,
    ).animate(CurvedAnimation(
      parent: _glowController,
      curve: Curves.easeInOut,
    ));

    _contentRevealAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _contentRevealController,
      curve: Curves.easeOutBack,
    ));

    _loadHolidaysForMonth(_selectedMonth);
    
    // Поворачиваем колесо к текущему месяцу при загрузке
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _rotateToCurrentMonth();
    });
  }

  void _rotateToCurrentMonth() {
    // Устанавливаем поворот так, чтобы текущий месяц был внизу под стрелкой
    final targetRotation = ((DateTime.now().month - 1) / 12) * 2 * math.pi;
    setState(() {
      _currentRotation = targetRotation;
    });
  }

  void _loadHolidaysForMonth(int month) {
    try {
      _currentMonthHolidays = PaganHolidayService.getHolidaysForMonth(month);
    } catch (e) {
      _currentMonthHolidays = [];
    }
  }

  void _handleTap(TapDownDetails details) {
    print('Tap detected at: ${details.localPosition}');
    
    final localPosition = details.localPosition;
    final centerX = 350.0; // Центр большого колеса (700px / 2)
    final centerY = 350.0 + 80; // Центр + смещение вниз
    
    final dx = localPosition.dx - centerX;
    final dy = localPosition.dy - centerY;
    final distance = math.sqrt(dx * dx + dy * dy);
    
    print('Distance from center: $distance');
    
    // Зона клика для большого колеса (избегаем центральную иконку)
    if (distance > 50 && distance < 300) {
      // НОВАЯ логика - стрелка теперь СНИЗУ
      double angle = math.atan2(dy, dx);
      
      if (angle < 0) angle += 2 * math.pi;
      
      // Поворачиваем так, чтобы январь был СНИЗУ под стрелкой
      // Снизу = -π/2, поэтому корректируем формулу
      angle = (angle - math.pi / 2) % (2 * math.pi);
      if (angle < 0) angle += 2 * math.pi;
      
      int monthIndex = (angle / (2 * math.pi / 12)).floor();
      int targetMonth = monthIndex + 1;
      if (targetMonth > 12) targetMonth = 1;
      
      print('Angle: $angle, Month index: $monthIndex, Target month: $targetMonth');
      
      _rotateToMonth(targetMonth);
    } else {
      print('Tap outside wheel area');
    }
  }

  void _rotateToMonth(int month) {
    print('Rotating to month: $month'); // Для отладки
    
    setState(() {
      _selectedMonth = month;
      _loadHolidaysForMonth(_selectedMonth);
      
      if (!_hasInteracted) {
        _hasInteracted = true;
        _contentRevealController.forward();
      }
      
      widget.onMonthChanged?.call(_selectedMonth, _currentMonthHolidays);
    });
    
    // Упрощенная логика поворота
    final targetRotation = ((month - 1) / 12) * 2 * math.pi;
    
    _rotationController.reset();
    _rotationAnimation = Tween<double>(
      begin: _currentRotation,
      end: targetRotation,
    ).animate(CurvedAnimation(
      parent: _rotationController,
      curve: Curves.easeOutCubic,
    ));
    
    _rotationController.forward().then((_) {
      setState(() {
        _currentRotation = targetRotation;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Колесо с правильной обрезкой - только половина, но намного больше размером
        Container(
          height: 350, // Еще больше увеличиваем высоту
          width: double.infinity,
          child: ClipRect(
            child: Stack(
              children: [
                // Само колесо, намного больше
                Positioned(
                  bottom: -80, // Опускаем еще ниже
                  left: -50, // Убираем отступы чтобы колесо было на всю ширину
                  right: -50,
                  child: GestureDetector(
                    onTapDown: _handleTap,
                    child: Container(
                      width: 700, // Намного увеличиваем размер колеса
                      height: 700,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          // Свечение
                          AnimatedBuilder(
                            animation: _glowAnimation,
                            builder: (context, child) {
                              return Container(
                                width: 650,
                                height: 650,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: _months[_selectedMonth - 1].color.withOpacity(0.1 * _glowAnimation.value),
                                      blurRadius: 100,
                                      spreadRadius: 40,
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                          
                          // Само колесо
                          AnimatedBuilder(
                            animation: Listenable.merge([_rotationAnimation, _glowAnimation]),
                            builder: (context, child) {
                              final currentRotation = _rotationController.isAnimating 
                                  ? _rotationAnimation.value 
                                  : _currentRotation;
                              
                              return Transform.rotate(
                                angle: currentRotation,
                                child: CustomPaint(
                                  size: const Size(650, 650), // Намного увеличиваем размер
                                  painter: WheelPainter(
                                    months: _months,
                                    selectedMonth: _selectedMonth - 1,
                                    glowIntensity: _glowAnimation.value,
                                  ),
                                ),
                              );
                            },
                          ),
                          
                          // Центральная иконка (оставляем прежний размер)
                          Container(
                            width: 90,
                            height: 90,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.black.withOpacity(0.85),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.7 * _glowAnimation.value),
                                width: 2,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.white.withOpacity(0.2 * _glowAnimation.value),
                                  blurRadius: 25,
                                  spreadRadius: 5,
                                ),
                              ],
                            ),
                            child: ClipOval(
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                child: ClipOval(
                                  child: Image.asset(
                                    'assets/images/rune_icon.png',
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) {
                                      return Container(
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          gradient: RadialGradient(
                                            colors: [
                                              Colors.white.withOpacity(0.8),
                                              Colors.white.withOpacity(0.3),
                                            ],
                                          ),
                                        ),
                                        child: Icon(
                                          Icons.auto_awesome,
                                          color: Colors.black.withOpacity(0.7),
                                          size: 40,
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ),
                            ),
                          ),
                          
                          // Указатель СНИЗУ - хорошо видно
                          Positioned(
                            bottom: 40,
                            child: Container(
                              width: 4,
                              height: 35,
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.95),
                                borderRadius: BorderRadius.circular(2),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.7),
                                    blurRadius: 10,
                                    offset: const Offset(0, 2),
                                  ),
                                  BoxShadow(
                                    color: Colors.white.withOpacity(0.3),
                                    blurRadius: 4,
                                    spreadRadius: 1,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                
                // Градиент тумана
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  height: 150, // Больше зона тумана для большого колеса
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black,
                          Colors.black.withOpacity(0.9),
                          Colors.black.withOpacity(0.6),
                          Colors.black.withOpacity(0.2),
                          Colors.transparent,
                        ],
                        stops: const [0.0, 0.3, 0.6, 0.85, 1.0],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        
        // Информация о месяце
        _buildMonthInfo(),
        
        // Список праздников - показываем всегда, не только после взаимодействия
        if (_hasInteracted) ...[
          SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.5),
              end: Offset.zero,
            ).animate(_contentRevealAnimation),
            child: FadeTransition(
              opacity: _contentRevealAnimation,
              child: Column(
                children: [
                  const SizedBox(height: 20),
                  _buildHolidaysList(),
                ],
              ),
            ),
          ),
        ] else ...[
          // Показываем контент сразу, без анимации
          Column(
            children: [
              const SizedBox(height: 20),
              _buildHolidaysList(),
            ],
          ),
        ],
      ],
    );
  }



  Widget _buildMonthInfo() {
    final currentMonth = _months[_selectedMonth - 1];
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            currentMonth.color.withOpacity(0.15),
            currentMonth.color.withOpacity(0.08),
          ],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: currentMonth.color.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Text(
            currentMonth.name,
            style: GoogleFonts.merriweather(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color: currentMonth.color.withOpacity(0.2),
              borderRadius: BorderRadius.circular(15),
            ),
            child: Text(
              _getSeasonName(currentMonth.season),
              style: TextStyle(
                fontSize: 14,
                color: currentMonth.color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHolidaysList() {
    if (_currentMonthHolidays.isEmpty) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 20),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Colors.white.withOpacity(0.1),
          ),
        ),
        child: Text(
          'В этом месяце нет особых языческих праздников',
          style: TextStyle(
            color: Colors.white.withOpacity(0.6),
            fontSize: 14,
            fontStyle: FontStyle.italic,
          ),
          textAlign: TextAlign.center,
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withOpacity(0.15),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Icon(
                  Icons.celebration,
                  color: Colors.white.withOpacity(0.8),
                  size: 20,
                ),
                const SizedBox(width: 12),
                Text(
                  'Праздники месяца',
                  style: GoogleFonts.merriweather(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          
          ..._currentMonthHolidays.map((holiday) => _buildHolidayCard(holiday)),
          
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _buildHolidayCard(PaganHoliday holiday) {
    final traditionColor = Color(int.parse(holiday.traditionColor.replaceFirst('#', '0xFF')));
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            showHolidayInfoModal(context, holiday);
          },
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  traditionColor.withOpacity(0.15),
                  traditionColor.withOpacity(0.08),
                ],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: traditionColor.withOpacity(0.3),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: traditionColor,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: traditionColor.withOpacity(0.5),
                        blurRadius: 4,
                        spreadRadius: 1,
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
                        holiday.name,
                        style: GoogleFonts.merriweather(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                      if (holiday.nameOriginal != holiday.name) ...[
                        const SizedBox(height: 2),
                        Text(
                          holiday.nameOriginal,
                          style: TextStyle(
                            fontSize: 12,
                            fontStyle: FontStyle.italic,
                            color: traditionColor.withOpacity(0.8),
                          ),
                        ),
                      ],
                      const SizedBox(height: 4),
                      Text(
                        '${holiday.date.day} ${_getMonthName(holiday.date.month)} • ${holiday.description}',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.white.withOpacity(0.8),
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios,
                  color: traditionColor.withOpacity(0.6),
                  size: 16,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _getSeasonName(SeasonType season) {
    switch (season) {
      case SeasonType.winter:
        return 'Зима';
      case SeasonType.spring:
        return 'Весна';
      case SeasonType.summer:
        return 'Лето';
      case SeasonType.autumn:
        return 'Осень';
    }
  }

  String _getMonthName(int month) {
    const months = [
      'января', 'февраля', 'марта', 'апреля', 'мая', 'июня',
      'июля', 'августа', 'сентября', 'октября', 'ноября', 'декабря'
    ];
    return months[month - 1];
  }

  @override
  void dispose() {
    _rotationController.dispose();
    _glowController.dispose();
    _contentRevealController.dispose();
    super.dispose();
  }
}

class WheelPainter extends CustomPainter {
  final List<MonthData> months;
  final int selectedMonth;
  final double glowIntensity;

  WheelPainter({
    required this.months,
    required this.selectedMonth,
    required this.glowIntensity,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 10;
    final sectorAngle = 2 * math.pi / 12;

    for (int i = 0; i < 12; i++) {
      final month = months[i];
      final startAngle = i * sectorAngle - math.pi / 2;
      final endAngle = startAngle + sectorAngle;
      final midAngle = startAngle + sectorAngle / 2;

      final gradient = RadialGradient(
        colors: [
          Colors.black,
          Colors.black.withOpacity(0.8),
          month.color.withOpacity(0.4),
          month.color.withOpacity(0.7),
        ],
        stops: const [0.0, 0.3, 0.7, 1.0],
      );

      final rect = Rect.fromCircle(center: center, radius: radius);
      final paint = Paint()
        ..shader = gradient.createShader(rect)
        ..style = PaintingStyle.fill;

      final path = Path();
      path.moveTo(center.dx, center.dy);
      path.arcTo(rect, startAngle, sectorAngle, false);
      path.close();

      canvas.drawPath(path, paint);

      final borderPaint = Paint()
        ..color = Colors.white.withOpacity(0.15)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1;

      final borderPath = Path();
      borderPath.moveTo(center.dx, center.dy);
      borderPath.lineTo(
        center.dx + math.cos(startAngle) * radius,
        center.dy + math.sin(startAngle) * radius,
      );
      canvas.drawPath(borderPath, borderPaint);

      final textRadius = radius * 0.75;
      final textX = center.dx + math.cos(midAngle) * textRadius;
      final textY = center.dy + math.sin(midAngle) * textRadius;

      final textPainter = TextPainter(
        text: TextSpan(
          text: month.name,
          style: TextStyle(
            color: Colors.white.withOpacity(0.9),
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      
      textPainter.layout();
      
      canvas.save();
      canvas.translate(textX, textY);
      
      double textRotation = midAngle + math.pi / 2;
      if (textRotation > math.pi / 2 && textRotation < 3 * math.pi / 2) {
        textRotation += math.pi;
      }
      
      canvas.rotate(textRotation);
      textPainter.paint(canvas, Offset(-textPainter.width / 2, -textPainter.height / 2));
      canvas.restore();
    }

    final outerRingPaint = Paint()
      ..color = Colors.white.withOpacity(0.2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawCircle(center, radius, outerRingPaint);

    _drawSeasonLabels(canvas, center, radius + 15);
  }

  void _drawSeasonLabels(Canvas canvas, Offset center, double radius) {
    final seasonData = [
      {'name': 'ЗИМА', 'startMonth': 11, 'endMonth': 1},
      {'name': 'ВЕСНА', 'startMonth': 2, 'endMonth': 4}, 
      {'name': 'ЛЕТО', 'startMonth': 5, 'endMonth': 7},
      {'name': 'ОСЕНЬ', 'startMonth': 8, 'endMonth': 10},
    ];

    for (final season in seasonData) {
      final seasonName = season['name'] as String;
      final startMonth = season['startMonth'] as int;
      final endMonth = season['endMonth'] as int;
      
      double middleAngle;
      if (startMonth > endMonth) {
        middleAngle = ((startMonth - 1) * (2 * math.pi / 12) + (endMonth - 1 + 12) * (2 * math.pi / 12)) / 2;
      } else {
        middleAngle = ((startMonth - 1) + (endMonth - 1)) * (2 * math.pi / 12) / 2;
      }
      
      middleAngle -= math.pi / 2;

      _drawCurvedText(canvas, seasonName, center, radius, middleAngle);
    }
  }

  void _drawCurvedText(Canvas canvas, String text, Offset center, double radius, double startAngle) {
    final textLength = text.length;
    final angleStep = 0.15;
    final totalAngle = angleStep * (textLength - 1);
    final startAngleAdjusted = startAngle - totalAngle / 2;

    for (int i = 0; i < textLength; i++) {
      final char = text[i];
      final angle = startAngleAdjusted + (i * angleStep);
      
      final x = center.dx + math.cos(angle) * radius;
      final y = center.dy + math.sin(angle) * radius;

      final textPainter = TextPainter(
        text: TextSpan(
          text: char,
          style: TextStyle(
            color: Colors.white.withOpacity(0.85),
            fontSize: 14,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.0,
            shadows: [
              Shadow(
                color: Colors.black.withOpacity(0.8),
                blurRadius: 3,
                offset: const Offset(1, 1),
              ),
            ],
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      
      textPainter.layout();
      
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(angle + math.pi / 2);
      textPainter.paint(canvas, Offset(-textPainter.width / 2, -textPainter.height / 2));
      canvas.restore();
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