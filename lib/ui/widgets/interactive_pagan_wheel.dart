// lib/ui/widgets/interactive_pagan_wheel.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:math' as math;
import '../../models/pagan_holiday.dart';
import '../widgets/holiday_info_modal.dart'; // Добавляем импорт модалки

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

  // Данные о месяцах с приглушенными цветами
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
  }

  void _loadHolidaysForMonth(int month) {
    try {
      _currentMonthHolidays = PaganHolidayService.getHolidaysForMonth(month);
    } catch (e) {
      // Fallback если сервис недоступен
      _currentMonthHolidays = [];
    }
  }

  bool _isPointerVisible() {
    // Указатель видим только если он не в зоне тумана
    // Проверяем текущий поворот и видим ли январь (который должен быть под указателем)
    return true; // Пока всегда показываем для простоты
  }

  void _onTapDown(TapDownDetails details) {
    // Получаем позицию клика относительно самого GestureDetector
    final localPosition = details.localPosition;
    
    // Центр колеса в локальных координатах (колесо 360x360, по центру)
    final centerX = 180.0; // Половина ширины колеса
    final centerY = 180.0; // Половина высоты колеса
    
    // Вектор от центра к точке клика
    final dx = localPosition.dx - centerX;
    final dy = localPosition.dy - centerY;
    
    // Расстояние от центра
    final distance = math.sqrt(dx * dx + dy * dy);
    
    // Проверяем что клик внутри колеса (но не в центральной иконке)
    if (distance > 45 && distance < 160) {
      // Вычисляем угол клика
      double angle = math.atan2(dy, dx);
      
      // Нормализуем угол 
      angle = (angle + 2 * math.pi) % (2 * math.pi);
      
      // Поворачиваем на 90 градусов, чтобы 0 был вверху
      angle = (angle + 3 * math.pi / 2) % (2 * math.pi);
      
      // Вычисляем месяц (12 месяцев в кругу)
      final monthFloat = (angle / (2 * math.pi)) * 12;
      int targetMonth = (monthFloat.round() % 12);
      if (targetMonth == 0) targetMonth = 12; // Декабрь
      
      // Анимируем поворот к выбранному месяцу
      _rotateToMonth(targetMonth);
    }
  }

  void _rotateToMonth(int month) {
    if (month == _selectedMonth) return;
    
    setState(() {
      _selectedMonth = month;
      _loadHolidaysForMonth(_selectedMonth);
      
      if (!_hasInteracted) {
        _hasInteracted = true;
        _contentRevealController.forward();
      }
      
      widget.onMonthChanged?.call(_selectedMonth, _currentMonthHolidays);
    });
    
    // Вычисляем целевой угол поворота
    // Месяц 1 (январь) должен быть вверху (угол 0)
    final targetRotation = -((month - 1) / 12) * 2 * math.pi;
    
    _rotationController.reset();
    final rotationTween = Tween<double>(
      begin: _currentRotation,
      end: targetRotation,
    );
    
    _rotationAnimation = rotationTween.animate(CurvedAnimation(
      parent: _rotationController,
      curve: Curves.easeOutCubic,
    ));
    
    _rotationController.forward().then((_) {
      setState(() {
        _currentRotation = targetRotation;
      });
    });
  }

  void _onSectorTap(int month) {
    _rotateToMonth(month);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Основное колесо с правильной обрезкой и затемнением
        Container(
          height: 220,
          width: double.infinity,
          child: Stack(
            children: [
              // Само колесо - показываем ровно половину
              Container(
                height: 200,
                child: ClipRect(
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: GestureDetector(
                      onPanUpdate: _onPanUpdate,
                      onPanEnd: _onPanEnd,
                      child: Container(
                        width: 400,
                        height: 400,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            // Фоновое свечение
                            AnimatedBuilder(
                              animation: _glowAnimation,
                              builder: (context, child) {
                                return Container(
                                  width: 350,
                                  height: 350,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: _months[_selectedMonth - 1].color.withOpacity(0.1 * _glowAnimation.value),
                                        blurRadius: 60,
                                        spreadRadius: 20,
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                            
                            // Основное колесо с анимацией
                            AnimatedBuilder(
                              animation: Listenable.merge([_rotationAnimation, _glowAnimation]),
                              builder: (context, child) {
                                final currentRotation = _rotationController.isAnimating 
                                    ? _rotationAnimation.value 
                                    : _currentRotation;
                                
                                return Transform.rotate(
                                  angle: currentRotation,
                                  child: CustomPaint(
                                    size: const Size(320, 320),
                                    painter: GradientWheelPainter(
                                      months: _months,
                                      selectedMonth: _selectedMonth - 1,
                                      glowIntensity: _glowAnimation.value,
                                      rotation: currentRotation,
                                    ),
                                  ),
                                );
                              },
                            ),
                            
                            // Центральная иконка (без вращения)
                            _buildCenterIcon(),
                            
                            // Указатель наверху (фиксированный)
                            Positioned(
                              top: 40,
                              child: Container(
                                width: 3,
                                height: 25,
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.9),
                                  borderRadius: BorderRadius.circular(2),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.5),
                                      blurRadius: 6,
                                      offset: const Offset(0, 2),
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
                ),
              ),
              
              // Градиентное затемнение сверху
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                height: 50,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black,
                        Colors.black.withOpacity(0.8),
                        Colors.black.withOpacity(0.3),
                        Colors.transparent,
                      ],
                      stops: const [0.0, 0.4, 0.8, 1.0],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        
        // Информация о месяце (всегда видна)
        _buildMonthInfo(),
        
        // Контент появляется после взаимодействия
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
        ],
      ],
    );
  }

  Widget _buildCenterIcon() {
    return AnimatedBuilder(
      animation: _glowAnimation,
      builder: (context, child) {
        return Container(
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
        );
      },
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
            _showHolidayDetails(holiday);
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

  void _showHolidayDetails(PaganHoliday holiday) {
    // Используем импортированную функцию
    showHolidayInfoModal(context, holiday);
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

// Painter для колеса с сезонными надписями по периметру
class GradientWheelPainter extends CustomPainter {
  final List<MonthData> months;
  final int selectedMonth;
  final double glowIntensity;
  final double rotation;
  final Function(int)? onSectorTap;

  GradientWheelPainter({
    required this.months,
    required this.selectedMonth,
    required this.glowIntensity,
    required this.rotation,
    this.onSectorTap,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 10;
    final sectorAngle = 2 * math.pi / 12;

    // Рисуем секторы (январь вверху, по часовой стрелке)
    for (int i = 0; i < 12; i++) {
      final month = months[i];
      // Январь (i=0) должен быть вверху, остальные по часовой стрелке
      final startAngle = i * sectorAngle - math.pi / 2;
      final endAngle = startAngle + sectorAngle;
      final midAngle = startAngle + sectorAngle / 2;

      // Радиальный градиент от черного центра к цвету месяца
      final gradient = RadialGradient(
        colors: [
          Colors.black,
          Colors.black.withOpacity(0.8),
          month.color.withOpacity(0.4),
          month.color.withOpacity(0.7),
        ],
        stops: const [0.0, 0.3, 0.7, 1.0],
      );

      // Рисуем сектор
      final rect = Rect.fromCircle(center: center, radius: radius);
      final paint = Paint()
        ..shader = gradient.createShader(rect)
        ..style = PaintingStyle.fill;

      final path = Path();
      path.moveTo(center.dx, center.dy);
      path.arcTo(rect, startAngle, sectorAngle, false);
      path.close();

      canvas.drawPath(path, paint);

      // Границы между секторами
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

      // Название месяца на секторе
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

    // Внешнее кольцо
    final outerRingPaint = Paint()
      ..color = Colors.white.withOpacity(0.2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawCircle(center, radius, outerRingPaint);

    // Сезонные надписи по периметру
    _drawSeasonLabelsOnCircle(canvas, center, radius + 15);
  }

  void _drawSeasonLabelsOnCircle(Canvas canvas, Offset center, double radius) {
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

// Модель данных месяца
class MonthData {
  final String name;
  final SeasonType season;
  final Color color;

  MonthData(this.name, this.season, this.color);
}

enum SeasonType { winter, spring, summer, autumn }