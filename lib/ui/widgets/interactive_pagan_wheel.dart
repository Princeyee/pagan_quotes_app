// lib/ui/widgets/interactive_pagan_wheel.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:math' as math;
import '../../models/pagan_holiday.dart';

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

  // Данные о месяцах с плавными сезонными цветами
  final List<MonthData> _months = [
    MonthData('Январь', 'Йоль', SeasonType.winter, const Color(0xFF4A90E2), const Color(0xFF87CEEB)),
    MonthData('Февраль', 'Имболк', SeasonType.winter, const Color(0xFF87CEEB), const Color(0xFF98FB98)),
    MonthData('Март', 'Остара', SeasonType.spring, const Color(0xFF98FB98), const Color(0xFF90EE90)),
    MonthData('Апрель', 'Цветень', SeasonType.spring, const Color(0xFF90EE90), const Color(0xFF7CFC00)),
    MonthData('Май', 'Белтайн', SeasonType.spring, const Color(0xFF7CFC00), const Color(0xFFFFD700)),
    MonthData('Июнь', 'Лита', SeasonType.summer, const Color(0xFFFFD700), const Color(0xFFFFA500)),
    MonthData('Июль', 'Купала', SeasonType.summer, const Color(0xFFFFA500), const Color(0xFFFF8C00)),
    MonthData('Август', 'Ламмас', SeasonType.summer, const Color(0xFFFF8C00), const Color(0xFFDC143C)),
    MonthData('Сентябрь', 'Мабон', SeasonType.autumn, const Color(0xFFDC143C), const Color(0xFFB22222)),
    MonthData('Октябрь', 'Самайн', SeasonType.autumn, const Color(0xFFB22222), const Color(0xFF8B0000)),
    MonthData('Ноябрь', 'Велеслав', SeasonType.autumn, const Color(0xFF8B0000), const Color(0xFF4682B4)),
    MonthData('Декабрь', 'Коляда', SeasonType.winter, const Color(0xFF4682B4), const Color(0xFF4A90E2)),
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
    _currentMonthHolidays = PaganHolidayService.getHolidaysForMonth(month);
  }

  void _onPanUpdate(DragUpdateDetails details) {
    setState(() {
      // Вычисляем изменение угла на основе горизонтального движения
      final deltaX = details.delta.dx;
      _currentRotation += deltaX * 0.01; // Чувствительность
      
      // Вычисляем текущий месяц на основе поворота
      final normalizedRotation = _currentRotation % (2 * math.pi);
      final monthFloat = (normalizedRotation / (2 * math.pi)) * 12;
      int newMonth = (monthFloat.round() % 12) + 1;
      
      if (newMonth != _selectedMonth) {
        _selectedMonth = newMonth;
        _loadHolidaysForMonth(_selectedMonth);
        
        if (!_hasInteracted) {
          _hasInteracted = true;
          _contentRevealController.forward();
        }
        
        widget.onMonthChanged?.call(_selectedMonth, _currentMonthHolidays);
      }
    });
  }

  void _onPanEnd(DragEndDetails details) {
    // Привязываем к ближайшему месяцу
    final velocity = details.velocity.pixelsPerSecond.dx;
    final targetMonth = _selectedMonth;
    final targetRotation = ((targetMonth - 1) / 12) * 2 * math.pi;
    
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

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Основное колесо
        Container(
          height: 280, // Показываем ~60% круга
          width: double.infinity,
          child: ClipRect(
            child: Align(
              alignment: Alignment.topCenter,
              child: GestureDetector(
                onPanUpdate: _onPanUpdate,
                onPanEnd: _onPanEnd,
                child: Container(
                  width: 450,
                  height: 450,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Фоновое свечение
                      AnimatedBuilder(
                        animation: _glowAnimation,
                        builder: (context, child) {
                          return Container(
                            width: 380,
                            height: 380,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: _months[_selectedMonth - 1].color.withOpacity(0.15 * _glowAnimation.value),
                                  blurRadius: 80,
                                  spreadRadius: 30,
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
                              size: const Size(360, 360),
                              painter: GradientWheelPainter(
                                months: _months,
                                selectedMonth: _selectedMonth - 1,
                                glowIntensity: _glowAnimation.value,
                              ),
                            ),
                          );
                        },
                      ),
                      
                      // Центральная иконка (без вращения)
                      _buildCenterIcon(),
                      
                      // Указатель наверху
                      Positioned(
                        top: 30,
                        child: Container(
                          width: 4,
                          height: 20,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.8),
                            borderRadius: BorderRadius.circular(2),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.3),
                                blurRadius: 4,
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
                  'assets/images/rune_icon.png', // Твоя иконка
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    // Fallback если иконка не найдена
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
            currentMonth.nextColor.withOpacity(0.10),
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
          const SizedBox(height: 8),
          Text(
            currentMonth.paganName,
            style: GoogleFonts.merriweather(
              fontSize: 16,
              fontStyle: FontStyle.italic,
              color: currentMonth.color,
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
            // Здесь будет открытие модалки с деталями праздника
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
    // Здесь подключишь свою существующую модалку
    // showHolidayInfoModal(context, holiday);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: Text(
          holiday.name,
          style: const TextStyle(color: Colors.white),
        ),
        content: Text(
          holiday.description,
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Закрыть'),
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

// Painter для колеса с градиентными переходами
class GradientWheelPainter extends CustomPainter {
  final List<MonthData> months;
  final int selectedMonth;
  final double glowIntensity;

  GradientWheelPainter({
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
      final isSelected = i == selectedMonth;
      final startAngle = i * sectorAngle - math.pi / 2;
      final endAngle = startAngle + sectorAngle;

      // Создаем градиент от текущего цвета к следующему
      final gradient = SweepGradient(
        startAngle: startAngle,
        endAngle: endAngle,
        colors: [
          month.color.withOpacity(isSelected ? 0.9 : 0.6),
          month.nextColor.withOpacity(isSelected ? 0.9 : 0.6),
        ],
      );

      // Рисуем сектор с градиентом
      final rect = Rect.fromCircle(center: center, radius: radius);
      final paint = Paint()
        ..shader = gradient.createShader(rect)
        ..style = PaintingStyle.fill;

      final path = Path();
      path.moveTo(center.dx, center.dy);
      path.arcTo(rect, startAngle, sectorAngle, false);
      path.close();

      canvas.drawPath(path, paint);

      // Добавляем свечение для выбранного сектора
      if (isSelected) {
        final glowPaint = Paint()
          ..color = month.color.withOpacity(0.3 * glowIntensity)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 8
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);
        
        canvas.drawPath(path, glowPaint);
      }

      // Рисуем тонкие границы
      final borderPaint = Paint()
        ..color = Colors.white.withOpacity(0.1)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.5;

      final borderPath = Path();
      borderPath.moveTo(center.dx, center.dy);
      borderPath.lineTo(
        center.dx + math.cos(startAngle) * radius,
        center.dy + math.sin(startAngle) * radius,
      );

      canvas.drawPath(borderPath, borderPaint);
    }

    // Внешнее кольцо
    final outerRingPaint = Paint()
      ..color = Colors.white.withOpacity(0.2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    canvas.drawCircle(center, radius, outerRingPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

// Модель данных месяца с градиентом
class MonthData {
  final String name;
  final String paganName;
  final SeasonType season;
  final Color color;
  final Color nextColor; // Для плавного перехода

  MonthData(this.name, this.paganName, this.season, this.color, this.nextColor);
}

enum SeasonType { winter, spring, summer, autumn }