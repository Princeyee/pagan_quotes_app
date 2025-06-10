// lib/ui/widgets/pagan_month_wheel.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:math' as math;

class PaganMonthWheel extends StatefulWidget {
  final int selectedMonth;
  final Function(int) onMonthChanged;
  final bool showLabels;
  
  const PaganMonthWheel({
    super.key,
    required this.selectedMonth,
    required this.onMonthChanged,
    this.showLabels = true,
  });

  @override
  State<PaganMonthWheel> createState() => _PaganMonthWheelState();
}

class _PaganMonthWheelState extends State<PaganMonthWheel>
    with TickerProviderStateMixin {
  
  late AnimationController _rotationController;
  late AnimationController _glowController;
  late AnimationController _runeController;
  
  late Animation<double> _rotationAnimation;
  late Animation<double> _glowAnimation;
  late Animation<double> _runeAnimation;

  // Данные о месяцах с сезонными цветами
  final List<MonthData> _months = [
    MonthData('Январь', 'Йоль', SeasonType.winter, const Color(0xFF87CEEB)),
    MonthData('Февраль', 'Имболк', SeasonType.winter, const Color(0xFF87CEEB)),
    MonthData('Март', 'Остара', SeasonType.spring, const Color(0xFF98FB98)),
    MonthData('Апрель', 'Цветень', SeasonType.spring, const Color(0xFF90EE90)),
    MonthData('Май', 'Белтайн', SeasonType.spring, const Color(0xFF7CFC00)),
    MonthData('Июнь', 'Лита', SeasonType.summer, const Color(0xFFFFD700)),
    MonthData('Июль', 'Купала', SeasonType.summer, const Color(0xFFFFA500)),
    MonthData('Август', 'Ламмас', SeasonType.summer, const Color(0xFFFF8C00)),
    MonthData('Сентябрь', 'Мабон', SeasonType.autumn, const Color(0xFFDC143C)),
    MonthData('Октябрь', 'Самайн', SeasonType.autumn, const Color(0xFFB22222)),
    MonthData('Ноябрь', 'Велеслав', SeasonType.autumn, const Color(0xFF8B0000)),
    MonthData('Декабрь', 'Коляда', SeasonType.winter, const Color(0xFF4682B4)),
  ];

  @override
  void initState() {
    super.initState();
    
    _rotationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    
    _glowController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    )..repeat(reverse: true);
    
    _runeController = AnimationController(
      duration: const Duration(seconds: 4),
      vsync: this,
    )..repeat();

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

    _runeAnimation = Tween<double>(
      begin: 0.0,
      end: 2 * math.pi,
    ).animate(CurvedAnimation(
      parent: _runeController,
      curve: Curves.linear,
    ));
  }

  void _onMonthTap(int monthIndex) {
    if (monthIndex != widget.selectedMonth - 1) {
      _rotationController.forward().then((_) {
        widget.onMonthChanged(monthIndex + 1);
        _rotationController.reverse();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 250, // Показываем только нижнюю половину
      child: ClipRect(
        child: Align(
          alignment: Alignment.topCenter,
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
                      width: 320,
                      height: 320,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.white.withOpacity(0.1 * _glowAnimation.value),
                            blurRadius: 60,
                            spreadRadius: 20,
                          ),
                        ],
                      ),
                    );
                  },
                ),
                
                // Основное колесо
                AnimatedBuilder(
                  animation: _rotationAnimation,
                  builder: (context, child) {
                    return Transform.rotate(
                      angle: _rotationAnimation.value * 0.1,
                      child: CustomPaint(
                        size: const Size(320, 320),
                        painter: MonthWheelPainter(
                          months: _months,
                          selectedMonth: widget.selectedMonth - 1,
                          showLabels: widget.showLabels,
                        ),
                      ),
                    );
                  },
                ),
                
                // Центральный круг с руной
                _buildCenterRune(),
                
                // Информация о выбранном месяце
                if (widget.showLabels)
                  Positioned(
                    bottom: 20,
                    child: _buildMonthInfo(),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCenterRune() {
    return AnimatedBuilder(
      animation: Listenable.merge([_glowAnimation, _runeAnimation]),
      builder: (context, child) {
        return Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.black.withOpacity(0.8),
            border: Border.all(
              color: Colors.white.withOpacity(0.6 * _glowAnimation.value),
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.white.withOpacity(0.3 * _glowAnimation.value),
                blurRadius: 20,
                spreadRadius: 5,
              ),
            ],
          ),
          child: Transform.rotate(
            angle: _runeAnimation.value * 0.2, // Медленное вращение руны
            child: CustomPaint(
              size: const Size(80, 80),
              painter: VasetsRunePainter(
                color: Colors.white.withOpacity(0.9),
                glowIntensity: _glowAnimation.value,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildMonthInfo() {
    final currentMonth = _months[widget.selectedMonth - 1];
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.7),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: currentMonth.color.withOpacity(0.5),
          width: 1,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            currentMonth.name,
            style: GoogleFonts.merriweather(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            currentMonth.paganName,
            style: GoogleFonts.merriweather(
              fontSize: 14,
              fontStyle: FontStyle.italic,
              color: currentMonth.color,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: currentMonth.color.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              _getSeasonName(currentMonth.season),
              style: TextStyle(
                fontSize: 12,
                color: currentMonth.color,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
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

  @override
  void dispose() {
    _rotationController.dispose();
    _glowController.dispose();
    _runeController.dispose();
    super.dispose();
  }
}

// Painter для колеса месяцев
class MonthWheelPainter extends CustomPainter {
  final List<MonthData> months;
  final int selectedMonth;
  final bool showLabels;

  MonthWheelPainter({
    required this.months,
    required this.selectedMonth,
    required this.showLabels,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 20;
    final sectorAngle = 2 * math.pi / 12;

    for (int i = 0; i < 12; i++) {
      final month = months[i];
      final isSelected = i == selectedMonth;
      final startAngle = i * sectorAngle - math.pi / 2;
      final endAngle = startAngle + sectorAngle;

      // Рисуем сектор
      final paint = Paint()
        ..color = isSelected 
            ? month.color.withOpacity(0.8)
            : month.color.withOpacity(0.3)
        ..style = PaintingStyle.fill;

      final path = Path();
      path.moveTo(center.dx, center.dy);
      path.arcTo(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sectorAngle,
        false,
      );
      path.close();

      canvas.drawPath(path, paint);

      // Рисуем границы сектора
      final borderPaint = Paint()
        ..color = Colors.white.withOpacity(0.3)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1;

      canvas.drawPath(path, borderPaint);

      // Рисуем текст месяца (если включены лейблы)
      if (showLabels) {
        final textAngle = startAngle + sectorAngle / 2;
        final textRadius = radius * 0.75;
        final textX = center.dx + math.cos(textAngle) * textRadius;
        final textY = center.dy + math.sin(textAngle) * textRadius;

        final textPainter = TextPainter(
          text: TextSpan(
            text: month.name.substring(0, 3),
            style: TextStyle(
              color: isSelected ? Colors.white : Colors.white70,
              fontSize: isSelected ? 14 : 12,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          textAlign: TextAlign.center,
          textDirection: TextDirection.ltr,
        );

        textPainter.layout();
        
        // Поворачиваем текст для читаемости
        canvas.save();
        canvas.translate(textX, textY);
        if (textAngle > math.pi / 2 && textAngle < 3 * math.pi / 2) {
          canvas.rotate(textAngle + math.pi);
        } else {
          canvas.rotate(textAngle);
        }
        textPainter.paint(canvas, Offset(-textPainter.width / 2, -textPainter.height / 2));
        canvas.restore();
      }
    }

    // Рисуем внешнее кольцо
    final outerRingPaint = Paint()
      ..color = Colors.white.withOpacity(0.2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;

    canvas.drawCircle(center, radius, outerRingPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

// Painter для руны Васец
class VasetsRunePainter extends CustomPainter {
  final Color color;
  final double glowIntensity;

  VasetsRunePainter({
    required this.color,
    required this.glowIntensity,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    // Добавляем свечение
    final glowPaint = Paint()
      ..color = color.withOpacity(0.3 * glowIntensity)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);

    // Руна Васец (упрощенная версия)
    final path = Path();
    
    // Основная вертикальная линия
    path.moveTo(center.dx, center.dy - 20);
    path.lineTo(center.dx, center.dy + 20);
    
    // Верхняя диагональ
    path.moveTo(center.dx, center.dy - 10);
    path.lineTo(center.dx + 15, center.dy - 20);
    path.lineTo(center.dx + 15, center.dy);
    
    // Нижняя диагональ  
    path.moveTo(center.dx, center.dy + 10);
    path.lineTo(center.dx + 15, center.dy);
    path.lineTo(center.dx + 15, center.dy + 20);

    // Рисуем свечение, затем основную руну
    canvas.drawPath(path, glowPaint);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

// Модель данных месяца
class MonthData {
  final String name;
  final String paganName;
  final SeasonType season;
  final Color color;

  MonthData(this.name, this.paganName, this.season, this.color);
}

enum SeasonType { winter, spring, summer, autumn }

// =========== ИНТЕГРАЦИЯ С CALENDAR PAGE ===========

// В твоем calendar_page.dart добавь это в imports:
// import '../widgets/pagan_month_wheel.dart';

// Затем в _buildScrollableContent() добавь колесо ПЕРЕД календарем:

/*
Widget _buildScrollableContent() {
  return FadeTransition(
    opacity: _fadeAnimation,
    child: SingleChildScrollView(
      controller: _scrollController,
      physics: const BouncingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      ),
      child: Column(
        children: [
          // Отступ для AppBar
          const SizedBox(height: 100),
          
          // ===== ЯЗЫЧЕСКОЕ КОЛЕСО МЕСЯЦЕВ =====
          _buildWheelOfTime(),
          
          // Календарь
          _buildEnhancedCalendar(),
          
          // Ближайший праздник
          _buildSimpleHolidayCountdown(),
          
          // Информация о выбранном дне
          if (_selectedDay != null) _buildSelectedDayInfo(),
          
          const SizedBox(height: 20),
        ],
      ),
    ),
  );
}

// Добавь этот метод в _CalendarPageState:

Widget _buildWheelOfTime() {
  return Container(
    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    decoration: BoxDecoration(
      color: Colors.white.withOpacity(0.08),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(
        color: Colors.white.withOpacity(0.15),
        width: 1,
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.3),
          blurRadius: 20,
          spreadRadius: 0,
          offset: const Offset(0, 8),
        ),
      ],
    ),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(
                    Icons.album,
                    color: Colors.white.withOpacity(0.8),
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Колесо времени',
                    style: GoogleFonts.merriweather(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
            PaganMonthWheel(
              selectedMonth: _focusedDay.month,
              onMonthChanged: (month) {
                setState(() {
                  _focusedDay = DateTime(_focusedDay.year, month);
                  _prepareEvents();
                });
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    ),
  );
}
*/