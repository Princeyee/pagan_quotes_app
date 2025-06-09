
// lib/ui/widgets/circular_calendar.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:math' as math;
import 'package:flutter/services.dart';
import '../../models/pagan_holiday.dart';
import '../../models/daily_quote.dart';

class CircularCalendar extends StatefulWidget {
  final DateTime selectedDate;
  final Map<DateTime, List<dynamic>> events;
  final Function(DateTime) onDateSelected;

  const CircularCalendar({
    super.key,
    required this.selectedDate,
    required this.events,
    required this.onDateSelected,
  });

  @override
  State<CircularCalendar> createState() => _CircularCalendarState();
}

class _CircularCalendarState extends State<CircularCalendar>
    with TickerProviderStateMixin {
  late AnimationController _rotationController;
  late AnimationController _pulseController;
  late AnimationController _selectedController;
  
  late Animation<double> _rotationAnimation;
  late Animation<double> _pulseAnimation;
  late Animation<double> _selectedAnimation;
  
  double _currentRotation = 0.0;
  DateTime? _hoveredDate;
  final List<PaganHoliday> _majorHolidays = [];

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _loadMajorHolidays();
    _setInitialRotation();
  }

  void _initializeAnimations() {
    _rotationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    
    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);
    
    _selectedController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _rotationAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _rotationController,
      curve: Curves.easeOutCubic,
    ));

    _pulseAnimation = Tween<double>(
      begin: 0.8,
      end: 1.2,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));

    _selectedAnimation = Tween<double>(
      begin: 1.0,
      end: 1.3,
    ).animate(CurvedAnimation(
      parent: _selectedController,
      curve: Curves.elasticOut,
    ));
  }

  void _loadMajorHolidays() {
    final allHolidays = PaganHolidayService.getAllHolidays();
    
    // Берем основные праздники Колеса Года
    final majorNames = [
      'Йоль', 'Имболк', 'Остара', 'Белтайн', 
      'Купала', 'Ламмас', 'Мабон', 'Самайн'
    ];
    
    for (final name in majorNames) {
      final holiday = allHolidays.firstWhere(
        (h) => h.name.toLowerCase().contains(name.toLowerCase()),
        orElse: () => _createPlaceholderHoliday(name),
      );
      _majorHolidays.add(holiday);
    }
  }

  PaganHoliday _createPlaceholderHoliday(String name) {
    // Fallback для отсутствующих праздников
    final monthMap = {
      'Йоль': 12, 'Имболк': 2, 'Остара': 3, 'Белтайн': 5,
      'Купала': 7, 'Ламмас': 8, 'Мабон': 9, 'Самайн': 10
    };
    
    return PaganHoliday(
      id: name.toLowerCase(),
      name: name,
      nameOriginal: name,
      date: DateTime(2024, monthMap[name] ?? 1, 15),
      tradition: 'mixed',
      description: 'Праздник Колеса Года',
      traditions: [],
      symbols: [],
      type: PaganHolidayType.seasonal,
    );
  }

  void _setInitialRotation() {
    // Поворачиваем колесо так, чтобы текущий месяц был сверху
    final monthAngle = (widget.selectedDate.month - 1) * (2 * math.pi / 12);
    _currentRotation = -monthAngle + (math.pi / 2); // +90° чтобы январь был сверху
  }

  void _rotateToMonth(int month) {
    final targetAngle = -(month - 1) * (2 * math.pi / 12) + (math.pi / 2);
    final startAngle = _currentRotation;
    
    _rotationController.reset();
    _rotationAnimation = Tween<double>(
      begin: startAngle,
      end: targetAngle,
    ).animate(CurvedAnimation(
      parent: _rotationController,
      curve: Curves.easeOutCubic,
    ));
    
    _rotationController.forward().then((_) {
      setState(() {
        _currentRotation = targetAngle;
      });
    });
    
    HapticFeedback.lightImpact();
  }

  void _onDateTapped(DateTime date) {
    widget.onDateSelected(date);
    _selectedController.forward().then((_) {
      _selectedController.reverse();
    });
    HapticFeedback.mediumImpact();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 350,
      height: 350,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Фоновые круги (сезоны)
          _buildSeasonalBackground(),
          
          // Основное колесо с месяцами
          AnimatedBuilder(
            animation: _rotationAnimation,
            builder: (context, child) {
              final rotation = _rotationAnimation.isAnimating 
                  ? _rotationAnimation.value 
                  : _currentRotation;
              
              return Transform.rotate(
                angle: rotation,
                child: _buildMainWheel(),
              );
            },
          ),
          
          // Центральная иконка
          _buildCenterIcon(),
          
          // Указатель текущего месяца
          _buildMonthPointer(),
          
          // Контролы навигации
          _buildNavigationControls(),
        ],
      ),
    );
  }

  Widget _buildSeasonalBackground() {
    return Container(
      width: 350,
      height: 350,
      child: CustomPaint(
        painter: SeasonalBackgroundPainter(),
      ),
    );
  }

  Widget _buildMainWheel() {
    return Container(
      width: 320,
      height: 320,
      child: Stack(
        children: [
          // Основное кольцо
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white.withOpacity(0.3),
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 20,
                  spreadRadius: 5,
                ),
              ],
            ),
          ),
          
          // Месяцы и праздники
          ...List.generate(12, (index) => _buildMonthSegment(index)),
          
          // Праздники Колеса Года
          ..._majorHolidays.asMap().entries.map((entry) => 
            _buildHolidayMarker(entry.key, entry.value)
          ).toList(),
        ],
      ),
    );
  }

  Widget _buildMonthSegment(int monthIndex) {
    final angle = monthIndex * (2 * math.pi / 12);
    final month = monthIndex + 1;
    final isSelected = widget.selectedDate.month == month;
    
    return Positioned.fill(
      child: Transform.rotate(
        angle: angle,
        child: Align(
          alignment: Alignment.topCenter,
          child: Transform.translate(
            offset: const Offset(0, 15),
            child: GestureDetector(
              onTap: () {
                final newDate = DateTime(widget.selectedDate.year, month, 15);
                _onDateTapped(newDate);
                _rotateToMonth(month);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isSelected 
                      ? Colors.white.withOpacity(0.9)
                      : Colors.black.withOpacity(0.6),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected 
                        ? Colors.amber 
                        : Colors.white.withOpacity(0.3),
                    width: isSelected ? 2 : 1,
                  ),
                  boxShadow: isSelected ? [
                    BoxShadow(
                      color: Colors.amber.withOpacity(0.5),
                      blurRadius: 10,
                      spreadRadius: 2,
                    ),
                  ] : null,
                ),
                child: Transform.rotate(
                  angle: -angle, // Поворачиваем текст обратно
                  child: Text(
                    _getMonthName(month),
                    style: GoogleFonts.merriweather(
                      fontSize: 11,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w400,
                      color: isSelected ? Colors.black : Colors.white,
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

  Widget _buildHolidayMarker(int index, PaganHoliday holiday) {
    final monthIndex = holiday.date.month - 1;
    final dayProgress = holiday.date.day / 31.0; // Позиция внутри месяца
    final baseAngle = monthIndex * (2 * math.pi / 12);
    final dayOffset = dayProgress * (2 * math.pi / 12) - (math.pi / 24);
    final angle = baseAngle + dayOffset;
    
    final traditionColor = Color(int.parse(
      holiday.traditionColor.replaceFirst('#', '0xFF')
    ));

    return Positioned.fill(
      child: Transform.rotate(
        angle: angle,
        child: Align(
          alignment: Alignment.topCenter,
          child: Transform.translate(
            offset: const Offset(0, 45),
            child: GestureDetector(
              onTap: () {
                final newDate = DateTime(
                  widget.selectedDate.year, 
                  holiday.date.month, 
                  holiday.date.day
                );
                _onDateTapped(newDate);
              },
              child: AnimatedBuilder(
                animation: _pulseAnimation,
                builder: (context, child) {
                  final isToday = _isHolidayToday(holiday);
                  final scale = isToday ? _pulseAnimation.value : 1.0;
                  
                  return Transform.scale(
                    scale: scale,
                    child: Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: traditionColor,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white,
                          width: 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: traditionColor.withOpacity(0.6),
                            blurRadius: isToday ? 8 : 4,
                            spreadRadius: isToday ? 2 : 1,
                          ),
                        ],
                      ),
                      child: Center(
                        child: Icon(
                          _getHolidayIcon(holiday.type),
                          size: 6,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCenterIcon() {
    return AnimatedBuilder(
      animation: _selectedAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _selectedAnimation.value,
          child: Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  Colors.amber.withOpacity(0.3),
                  Colors.orange.withOpacity(0.2),
                  Colors.transparent,
                ],
              ),
              border: Border.all(
                color: Colors.white.withOpacity(0.4),
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.amber.withOpacity(0.3),
                  blurRadius: 20,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: ClipOval(
              child: Image.asset(
                'assets/images/rune_icon.png',
                width: 60,
                height: 60,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          Colors.amber.withOpacity(0.5),
                          Colors.orange.withOpacity(0.3),
                        ],
                      ),
                    ),
                    child: Icon(
                      Icons.wb_sunny,
                      size: 40,
                      color: Colors.white.withOpacity(0.9),
                    ),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildMonthPointer() {
    return Positioned(
      top: 10,
      child: Container(
        width: 3,
        height: 15,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.5),
              blurRadius: 4,
              spreadRadius: 1,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavigationControls() {
    return Positioned(
      bottom: -10,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildNavButton(
            Icons.chevron_left,
            () {
              final prevMonth = widget.selectedDate.month == 1 ? 12 : widget.selectedDate.month - 1;
              final prevYear = widget.selectedDate.month == 1 ? widget.selectedDate.year - 1 : widget.selectedDate.year;
              _rotateToMonth(prevMonth);
              widget.onDateSelected(DateTime(prevYear, prevMonth, 15));
            },
          ),
          const SizedBox(width: 20),
          _buildNavButton(
            Icons.today,
            () {
              final today = DateTime.now();
              _rotateToMonth(today.month);
              widget.onDateSelected(today);
            },
          ),
          const SizedBox(width: 20),
          _buildNavButton(
            Icons.chevron_right,
            () {
              final nextMonth = widget.selectedDate.month == 12 ? 1 : widget.selectedDate.month + 1;
              final nextYear = widget.selectedDate.month == 12 ? widget.selectedDate.year + 1 : widget.selectedDate.year;
              _rotateToMonth(nextMonth);
              widget.onDateSelected(DateTime(nextYear, nextMonth, 15));
            },
          ),
        ],
      ),
    );
  }

  Widget _buildNavButton(IconData icon, VoidCallback onTap) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.5),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Colors.white.withOpacity(0.3),
              width: 1,
            ),
          ),
          child: Icon(
            icon,
            color: Colors.white.withOpacity(0.9),
            size: 20,
          ),
        ),
      ),
    );
  }

  bool _isHolidayToday(PaganHoliday holiday) {
    final today = DateTime.now();
    return holiday.date.month == today.month && holiday.date.day == today.day;
  }

  IconData _getHolidayIcon(PaganHolidayType type) {
    switch (type) {
      case PaganHolidayType.seasonal:
        return Icons.wb_sunny;
      case PaganHolidayType.fire:
        return Icons.local_fire_department;
      case PaganHolidayType.harvest:
        return Icons.agriculture;
      case PaganHolidayType.lunar:
        return Icons.nights_stay;
      default:
        return Icons.star;
    }
  }

  String _getMonthName(int month) {
    const months = [
      'Янв', 'Фев', 'Мар', 'Апр', 'Май', 'Июн',
      'Июл', 'Авг', 'Сен', 'Окт', 'Ноя', 'Дек'
    ];
    return months[month - 1];
  }

  @override
  void dispose() {
    _rotationController.dispose();
    _pulseController.dispose();
    _selectedController.dispose();
    super.dispose();
  }
}

// Painter для сезонного фона
class SeasonalBackgroundPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    
    // Сезонные цвета
    final seasonColors = [
      [Colors.white.withOpacity(0.1), Colors.blue.withOpacity(0.1)], // Зима
      [Colors.green.withOpacity(0.1), Colors.yellow.withOpacity(0.1)], // Весна  
      [Colors.yellow.withOpacity(0.1), Colors.orange.withOpacity(0.1)], // Лето
      [Colors.orange.withOpacity(0.1), Colors.red.withOpacity(0.1)], // Осень
    ];
    
    // Рисуем сезонные сектора
    for (int i = 0; i < 4; i++) {
      final startAngle = i * (math.pi / 2) - (math.pi / 4);
      final sweepAngle = math.pi / 2;
      
      final gradient = RadialGradient(
        colors: seasonColors[i],
        center: Alignment.center,
        radius: 0.8,
      );
      
      final paint = Paint()
        ..shader = gradient.createShader(Rect.fromCircle(center: center, radius: radius));
      
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle,
        true,
        paint,
      );
    }
    
    // Рисуем разделители сезонов
    final dividerPaint = Paint()
      ..color = Colors.white.withOpacity(0.2)
      ..strokeWidth = 1;
    
    for (int i = 0; i < 4; i++) {
      final angle = i * (math.pi / 2);
      final startPoint = Offset(
        center.dx + (radius * 0.3) * math.cos(angle),
        center.dy + (radius * 0.3) * math.sin(angle),
      );
      final endPoint = Offset(
        center.dx + radius * math.cos(angle),
        center.dy + radius * math.sin(angle),
      );
      
      canvas.drawLine(startPoint, endPoint, dividerPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}