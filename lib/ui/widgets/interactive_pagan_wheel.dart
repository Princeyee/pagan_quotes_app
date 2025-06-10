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
    
    _initializeAnimations();
    
    // ПРАВИЛЬНАЯ инициализация
    final currentMonth = DateTime.now().month;
    _selectedMonth = currentMonth;
    _loadHolidaysForMonth(currentMonth);
    
    // Поворачиваем к текущему месяцу ПОСЛЕ построения виджета
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _rotateToCurrentMonth();
    });
  }

  void _initializeAnimations() {
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
  }

  void _loadHolidaysForMonth(int month) {
    try {
      _currentMonthHolidays = PaganHolidayService.getHolidaysForMonth(month);
    } catch (e) {
      _currentMonthHolidays = [];
    }
  }

  void _handleTap(TapDownDetails details) {
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

  void _rotateToMonth(int month) {
    // ПРОСТАЯ логика: какой месяц внизу, тот и выбран
    final monthIndex = month - 1;
    final monthAngle = monthIndex * (2 * math.pi / 12);
    final targetRotation = -monthAngle;
    
    setState(() {
      _selectedMonth = month;
      _loadHolidaysForMonth(month);
      
      if (!_hasInteracted) {
        _hasInteracted = true;
        _contentRevealController.forward();
      }
      
      widget.onMonthChanged?.call(month, _currentMonthHolidays);
    });
    
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

  void _rotateToCurrentMonth() {
    final currentMonth = DateTime.now().month;
    
    // ПРОСТАЯ логика: поворачиваем так, чтобы текущий месяц был внизу
    final monthIndex = currentMonth - 1; // 0-11
    final monthAngle = monthIndex * (2 * math.pi / 12); // угол месяца
    final targetRotation = -monthAngle; // поворачиваем на -угол, чтобы месяц оказался внизу
    
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
        Container(
          height: 350,
          width: double.infinity,
          child: ClipRect(
            child: Stack(
              children: [
                Positioned(
                  bottom: -80,
                  left: -50,
                  right: -50,
                  child: GestureDetector(
                    onTapDown: _handleTap,
                    child: Container(
                      width: 700,
                      height: 700,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
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
                          
                          AnimatedBuilder(
                            animation: Listenable.merge([_rotationAnimation, _glowAnimation]),
                            builder: (context, child) {
                              final currentRotation = _rotationController.isAnimating 
                                  ? _rotationAnimation.value 
                                  : _currentRotation;
                              
                              return Transform.rotate(
                                angle: currentRotation,
                                child: CustomPaint(
                                  size: const Size(650, 650),
                                  painter: WheelPainter(
                                    months: _months,
                                    selectedMonth: _selectedMonth - 1,
                                    glowIntensity: _glowAnimation.value,
                                  ),
                                ),
                              );
                            },
                          ),
                          
                          Container(
                            width: 90,
                            height: 90,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.black.withOpacity(0.3),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.7),
                                width: 2,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.white.withOpacity(0.2),
                                  blurRadius: 25,
                                  spreadRadius: 5,
                                ),
                              ],
                            ),
                            child: ClipOval(
                              child: Padding(
                                padding: const EdgeInsets.all(4),
                                child: ClipOval(
                                  child: Image.asset(
                                    'assets/icon/old1.png',
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) {
                                      return Container(
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          gradient: RadialGradient(
                                            colors: [
                                              _months[_selectedMonth - 1].color.withOpacity(0.8),
                                              _months[_selectedMonth - 1].color.withOpacity(0.3),
                                            ],
                                          ),
                                        ),
                                        child: Icon(
                                          Icons.auto_awesome,
                                          color: Colors.white,
                                          size: 40,
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  height: 150,
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
                
                Positioned(
                  bottom: 10,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Container(
                      width: 6,
                      height: 30,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.95),
                        borderRadius: BorderRadius.circular(3),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.8),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                          BoxShadow(
                            color: Colors.white.withOpacity(0.4),
                            blurRadius: 4,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        
        _buildMonthInfo(),
        
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

    // ВАЖНО: правильный порядок месяцев
    // Январь (индекс 0) должен быть сверху (-π/2)
    // Февраль (индекс 1) должен быть на 30° по часовой стрелке от января
    // И так далее...
    
    for (int i = 0; i < 12; i++) {
      final month = months[i];
      
      // Начало сектора для месяца i
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

      // Название месяца в ЦЕНТРЕ сектора
      final textRadius = radius * 0.75;
      final textX = center.dx + math.cos(midAngle) * textRadius;
      final textY = center.dy + math.sin(midAngle) * textRadius;

      final textPainter = TextPainter(
        text: TextSpan(
          text: month.name,
          style: TextStyle(
            color: Colors.white.withOpacity(0.9),
            fontSize: 14,
            fontWeight: FontWeight.w600,
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
      canvas.translate(textX, textY);
      
      double textRotation = midAngle + math.pi / 2;
      if (textRotation > math.pi / 2 && textRotation < 3 * math.pi / 2) {
        textRotation += math.pi;
      }
      
      canvas.rotate(textRotation);
      textPainter.paint(canvas, Offset(-textPainter.width / 2, -textPainter.height / 2));
      canvas.restore();

      // ДОБАВЛЯЕМ языческие символы для каждого месяца
      final symbolRadius = radius * 0.55; // Ближе к центру
      final symbolX = center.dx + math.cos(midAngle) * symbolRadius;
      final symbolY = center.dy + math.sin(midAngle) * symbolRadius;
      
      final monthSymbol = _getMonthSymbol(i + 1);
      final symbolPainter = TextPainter(
        text: TextSpan(
          text: monthSymbol,
          style: TextStyle(
            color: month.color.withOpacity(0.8),
            fontSize: 24,
            fontWeight: FontWeight.w400,
            shadows: [
              Shadow(
                color: Colors.black.withOpacity(0.7),
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

    final outerRingPaint = Paint()
      ..color = Colors.white.withOpacity(0.2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawCircle(center, radius, outerRingPaint);

    _drawSeasonLabels(canvas, center, radius + 20);
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

  void _drawCurvedSeasonText(Canvas canvas, String text, Offset center, double radius, List<int> months, Color seasonColor) {
    final firstMonth = months[0];
    final lastMonth = months[2];
    
    final firstIndex = (firstMonth - 1) % 12;
    final lastIndex = (lastMonth - 1) % 12;
    
    var startAngle = firstIndex * (2 * math.pi / 12) - math.pi / 2;
    var endAngle = lastIndex * (2 * math.pi / 12) - math.pi / 2 + (2 * math.pi / 12);
    
    if (firstMonth == 12 && lastMonth == 2) {
      startAngle = 11 * (2 * math.pi / 12) - math.pi / 2;
      endAngle = 2 * (2 * math.pi / 12) - math.pi / 2;
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
            color: seasonColor.withOpacity(0.9),
            fontSize: 18,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.5,
            shadows: [
              Shadow(
                color: Colors.black.withOpacity(0.9),
                blurRadius: 4,
                offset: const Offset(1, 1),
              ),
              Shadow(
                color: seasonColor.withOpacity(0.6),
                blurRadius: 8,
                offset: const Offset(0, 0),
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

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;

  // Настоящие языческие символы для каждого месяца
  String _getMonthSymbol(int month) {
    switch (month) {
      case 1: return 'ᛁ'; // Январь - руна Иса (лед)
      case 2: return 'ᚢ'; // Февраль - руна Уруз (сила)
      case 3: return 'ᚦ'; // Март - руна Турисаз (великан, сила)
      case 4: return 'ᚨ'; // Апрель - руна Ансуз (бог, дыхание)
      case 5: return 'ᚱ'; // Май - руна Райдо (путь, движение)
      case 6: return '☉'; // Июнь - символ солнца
      case 7: return 'ᛋ'; // Июль - руна Совило (солнце)
      case 8: return 'ᛃ'; // Август - руна Йера (урожай, год)
      case 9: return 'ᛈ'; // Сентябрь - руна Перт (тайна, изменение)
      case 10: return 'ᛇ'; // Октябрь - руна Эйваз (защита, смерть)
      case 11: return 'ᛜ'; // Ноябрь - руна Ингуз (плодородие)
      case 12: return '☾'; // Декабрь - символ луны
      default: return '⚬';
    }
  }
}

class MonthData {
  final String name;
  final SeasonType season;
  final Color color;

  MonthData(this.name, this.season, this.color);
}

enum SeasonType { winter, spring, summer, autumn }