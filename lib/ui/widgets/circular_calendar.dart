// lib/ui/widgets/circular_calendar.dart - ПОЛНЫЙ РЕДИЗАЙН
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:math' as math;
import 'dart:async';
import 'package:flutter/services.dart';
import '../../models/pagan_holiday.dart';
import '../../models/daily_quote.dart';

class CircularCalendar extends StatefulWidget {
  final DateTime selectedDate;
  final Map<DateTime, List<dynamic>> events;
  final Function(DateTime) onDateSelected;
  final Function(String?)? onTraditionFilter; // Новый коллбэк для фильтра

  const CircularCalendar({
    super.key,
    required this.selectedDate,
    required this.events,
    required this.onDateSelected,
    this.onTraditionFilter,
  });

  @override
  State<CircularCalendar> createState() => _CircularCalendarState();
}

class _CircularCalendarState extends State<CircularCalendar>
    with TickerProviderStateMixin {
  late AnimationController _rotationController;
  late AnimationController _pulseController;
  late AnimationController _selectedController;
  late AnimationController _holidayRevealController;
  
  late Animation<double> _rotationAnimation;
  late Animation<double> _pulseAnimation;
  late Animation<double> _selectedAnimation;
  late Animation<double> _holidayRevealAnimation;
  
  double _currentRotation = 0.0;
  DateTime? _hoveredDate;
  String? _selectedTradition; // Фильтр традиций
  bool _showHolidays = false;
  List<PaganHoliday> _currentMonthHolidays = [];
  
  // Для задержки показа праздников
  Timer? _holidayDisplayTimer;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _setInitialRotation();
  }

  void _initializeAnimations() {
    _rotationController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    
    _pulseController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    )..repeat(reverse: true);
    
    _selectedController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    _holidayRevealController = AnimationController(
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

    _pulseAnimation = Tween<double>(
      begin: 0.9,
      end: 1.1,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));

    _selectedAnimation = Tween<double>(
      begin: 1.0,
      end: 1.2,
    ).animate(CurvedAnimation(
      parent: _selectedController,
      curve: Curves.elasticOut,
    ));

    _holidayRevealAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _holidayRevealController,
      curve: Curves.easeOutBack,
    ));
  }

  void _setInitialRotation() {
    final monthAngle = (widget.selectedDate.month - 1) * (2 * math.pi / 12);
    _currentRotation = -monthAngle + (math.pi / 2);
    _loadHolidaysForMonth(widget.selectedDate.month);
  }

  void _rotateToMonth(int month, {bool fromGesture = false}) {
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
    
    setState(() {
      _showHolidays = false;
    });
    _holidayRevealController.reset();
    
    _rotationController.forward().then((_) {
      setState(() {
        _currentRotation = targetAngle;
      });
      
      // Задержка перед показом праздников
      _holidayDisplayTimer?.cancel();
      _holidayDisplayTimer = Timer(Duration(milliseconds: fromGesture ? 1500 : 800), () {
        if (mounted) {
          _loadHolidaysForMonth(month);
          setState(() {
            _showHolidays = true;
          });
          _holidayRevealController.forward();
        }
      });
    });
    
    HapticFeedback.lightImpact();
  }

  void _loadHolidaysForMonth(int month) {
    final allHolidays = PaganHolidayService.getAllHolidays();
    _currentMonthHolidays = allHolidays.where((holiday) {
      if (holiday.date.month != month) return false;
      if (_selectedTradition != null && holiday.tradition != _selectedTradition) return false;
      return true;
    }).toList();
  }

  void _onDateTapped(DateTime date) {
    widget.onDateSelected(date);
    _selectedController.forward().then((_) {
      _selectedController.reverse();
    });
    HapticFeedback.mediumImpact();
  }

  void _onTraditionFilterChanged(String? tradition) {
    setState(() {
      _selectedTradition = tradition;
    });
    _loadHolidaysForMonth(widget.selectedDate.month);
    if (widget.onTraditionFilter != null) {
      widget.onTraditionFilter!(tradition);
    }
  }

  void _handlePanUpdate(DragUpdateDetails details) {
    // Жестовое управление вращением
    final center = Offset(175, 175); // Центр 350x350 контейнера
    final position = details.localPosition - center;
    final angle = math.atan2(position.dy, position.dx);
    
    // Определяем ближайший месяц
    final normalizedAngle = (angle + math.pi * 2) % (math.pi * 2);
    final monthAngle = normalizedAngle / (math.pi * 2) * 12;
    final targetMonth = ((12 - monthAngle.round()) % 12) + 1;
    
    if (targetMonth != widget.selectedDate.month) {
      final newDate = DateTime(widget.selectedDate.year, targetMonth, 15);
      widget.onDateSelected(newDate);
      _rotateToMonth(targetMonth, fromGesture: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Фильтр традиций
        _buildTraditionFilter(),
        const SizedBox(height: 20),
        
        // Основное колесо
        GestureDetector(
          onPanUpdate: _handlePanUpdate,
          child: Container(
            width: 350,
            height: 350,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Сезонный фон (вращается)
                AnimatedBuilder(
                  animation: _rotationAnimation,
                  builder: (context, child) {
                    final rotation = _rotationAnimation.isAnimating 
                        ? _rotationAnimation.value 
                        : _currentRotation;
                    
                    return Transform.rotate(
                      angle: rotation,
                      child: _buildSeasonalBackground(),
                    );
                  },
                ),
                
                // Основное кольцо с месяцами (вращается)
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
                
                // Центральная руна (статична)
                _buildCenterIcon(),
                
                // Указатель месяца (статичен)
                _buildMonthPointer(),
              ],
            ),
          ),
        ),
        
        const SizedBox(height: 20),
        
        // Список праздников для текущего месяца
        if (_showHolidays)
          _buildHolidaysList(),
      ],
    );
  }

  Widget _buildTraditionFilter() {
    final traditions = ['nordic', 'slavic', 'celtic', 'germanic', 'roman', 'greek'];
    
    return Container(
      height: 50,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Row(
          children: [
            // Кнопка "Все"
            _buildFilterChip(null, 'Все'),
            const SizedBox(width: 12),
            
            // Кнопки традиций
            ...traditions.map((tradition) => Padding(
              padding: const EdgeInsets.only(right: 12),
              child: _buildFilterChip(tradition, _getTraditionDisplayName(tradition)),
            )).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(String? tradition, String label) {
    final isSelected = _selectedTradition == tradition;
    final color = tradition != null 
        ? _getTraditionColor(tradition)
        : Colors.white;
    
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _onTraditionFilterChanged(tradition),
        borderRadius: BorderRadius.circular(20),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: isSelected 
                ? color.withOpacity(0.15)
                : Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected 
                  ? color.withOpacity(0.5)
                  : Colors.white.withOpacity(0.2),
              width: isSelected ? 2 : 1,
            ),
            boxShadow: isSelected ? [
              BoxShadow(
                color: color.withOpacity(0.3),
                blurRadius: 8,
                spreadRadius: 2,
              ),
            ] : null,
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
              color: isSelected ? color : Colors.white.withOpacity(0.8),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSeasonalBackground() {
    return Container(
      width: 350,
      height: 350,
      child: CustomPaint(
        painter: ElegantSeasonalPainter(),
      ),
    );
  }

  Widget _buildMainWheel() {
    return Container(
      width: 300,
      height: 300,
      child: Stack(
        children: [
          // Основное темное кольцо
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.black.withOpacity(0.6),
              border: Border.all(
                color: Colors.white.withOpacity(0.1),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.8),
                  blurRadius: 30,
                  spreadRadius: 5,
                ),
              ],
            ),
          ),
          
          // Месяцы
          ...List.generate(12, (index) => _buildMonthSegment(index)),
          
          // Праздники (только если показываем)
          if (_showHolidays)
            ..._currentMonthHolidays.map((holiday) => 
              _buildHolidayMarker(holiday)
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
            offset: const Offset(0, 25),
            child: GestureDetector(
              onTap: () {
                final newDate = DateTime(widget.selectedDate.year, month, 15);
                _onDateTapped(newDate);
                _rotateToMonth(month);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: isSelected 
                      ? Colors.white.withOpacity(0.9)
                      : Colors.black.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(
                    color: isSelected 
                        ? Colors.amber.withOpacity(0.8)
                        : Colors.white.withOpacity(0.2),
                    width: isSelected ? 2 : 1,
                  ),
                  boxShadow: isSelected ? [
                    BoxShadow(
                      color: Colors.amber.withOpacity(0.4),
                      blurRadius: 12,
                      spreadRadius: 3,
                    ),
                  ] : [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 6,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: Transform.rotate(
                  angle: -angle,
                  child: Text(
                    _getMonthName(month),
                    style: GoogleFonts.merriweather(
                      fontSize: 11,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                      color: isSelected ? Colors.black87 : Colors.white.withOpacity(0.9),
                      letterSpacing: 0.5,
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

  Widget _buildHolidayMarker(PaganHoliday holiday) {
    final dayProgress = holiday.date.day / 31.0;
    final angle = dayProgress * (2 * math.pi / 12) - (math.pi / 24);
    
    final traditionColor = _getTraditionColor(holiday.tradition);
    final isToday = _isHolidayToday(holiday);

    return Positioned.fill(
      child: Transform.rotate(
        angle: angle,
        child: Align(
          alignment: Alignment.topCenter,
          child: Transform.translate(
            offset: const Offset(0, 55),
            child: FadeTransition(
              opacity: _holidayRevealAnimation,
              child: ScaleTransition(
                scale: _holidayRevealAnimation,
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
                      final scale = isToday ? _pulseAnimation.value : 1.0;
                      
                      return Transform.scale(
                        scale: scale,
                        child: Container(
                          width: 20,
                          height: 20,
                          decoration: BoxDecoration(
                            gradient: RadialGradient(
                              colors: [
                                traditionColor,
                                traditionColor.withOpacity(0.7),
                              ],
                            ),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.white,
                              width: 2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: traditionColor.withOpacity(0.6),
                                blurRadius: isToday ? 12 : 6,
                                spreadRadius: isToday ? 3 : 1,
                              ),
                            ],
                          ),
                          child: Center(
                            child: Icon(
                              _getHolidayIcon(holiday.type),
                              size: 10,
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
        ),
      ),
    );
  }

  Widget _buildCenterIcon() {
    return Container(
      width: 70,
      height: 70,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.black.withOpacity(0.8),
        border: Border.all(
          color: Colors.white.withOpacity(0.3),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.6),
            blurRadius: 20,
            spreadRadius: 5,
          ),
        ],
      ),
      child: ClipOval(
        child: Image.asset(
          'assets/images/rune_icon.png',
          width: 50,
          height: 50,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    Colors.amber.withOpacity(0.3),
                    Colors.orange.withOpacity(0.2),
                  ],
                ),
              ),
              child: Icon(
                Icons.wb_sunny,
                size: 35,
                color: Colors.white.withOpacity(0.8),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildMonthPointer() {
    return Positioned(
      top: 15,
      child: Container(
        width: 4,
        height: 20,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Colors.amber,
              Colors.white,
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
          borderRadius: BorderRadius.circular(2),
          boxShadow: [
            BoxShadow(
              color: Colors.amber.withOpacity(0.5),
              blurRadius: 8,
              spreadRadius: 2,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHolidaysList() {
    if (_currentMonthHolidays.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        child: Text(
          'Нет праздников в этом месяце',
          style: TextStyle(
            color: Colors.white.withOpacity(0.5),
            fontSize: 14,
            fontStyle: FontStyle.italic,
          ),
        ),
      );
    }

    return FadeTransition(
      opacity: _holidayRevealAnimation,
      child: Container(
        constraints: const BoxConstraints(maxHeight: 200),
        margin: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.6),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Colors.white.withOpacity(0.1),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 20,
              spreadRadius: 5,
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Заголовок
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: Colors.white.withOpacity(0.1),
                  ),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.celebration,
                    color: Colors.white.withOpacity(0.7),
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Праздники ${_getMonthName(widget.selectedDate.month)}',
                    style: GoogleFonts.merriweather(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
            
            // Список праздников
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: _currentMonthHolidays.length,
                itemBuilder: (context, index) {
                  final holiday = _currentMonthHolidays[index];
                  final traditionColor = _getTraditionColor(holiday.tradition);
                  
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: traditionColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: traditionColor.withOpacity(0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        // Дата
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: traditionColor.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Center(
                            child: Text(
                              '${holiday.date.day}',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: traditionColor,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        
                        // Информация
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                holiday.name,
                                style: GoogleFonts.merriweather(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                holiday.description,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.white.withOpacity(0.7),
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        
                        // Иконка типа
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: traditionColor.withOpacity(0.2),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            _getHolidayIcon(holiday.type),
                            size: 16,
                            color: traditionColor,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Вспомогательные методы
  Color _getTraditionColor(String tradition) {
    switch (tradition.toLowerCase()) {
      case 'nordic':
      case 'scandinavian':
        return const Color(0xFF4A90E2);
      case 'slavic':
        return const Color(0xFFE24A4A);
      case 'celtic':
        return const Color(0xFF4AE24A);
      case 'germanic':
        return const Color(0xFFE2A94A);
      case 'roman':
        return const Color(0xFFA94AE2);
      case 'greek':
        return const Color(0xFF4AE2E2);
      default:
        return Colors.white;
    }
  }

  String _getTraditionDisplayName(String tradition) {
    switch (tradition.toLowerCase()) {
      case 'nordic':
        return 'Север';
      case 'slavic':
        return 'Славяне';
      case 'celtic':
        return 'Кельты';
      case 'germanic':
        return 'Германцы';
      case 'roman':
        return 'Рим';
      case 'greek':
        return 'Греки';
      default:
        return tradition;
    }
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
      case PaganHolidayType.water:
        return Icons.waves;
      case PaganHolidayType.nature:
        return Icons.eco;
      case PaganHolidayType.ancestor:
        return Icons.family_restroom;
      case PaganHolidayType.deity:
        return Icons.auto_awesome;
      case PaganHolidayType.protection:
        return Icons.shield;
      case PaganHolidayType.fertility:
        return Icons.spa;
      default:
        return Icons.star;
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
    _pulseController.dispose();
    _selectedController.dispose();
    _holidayRevealController.dispose();
    _holidayDisplayTimer?.cancel();
    super.dispose();
  }
}

// Painter для элегантного сезонного фона
class ElegantSeasonalPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    
    // Элегантные сезонные цвета (приглушенные)
    final seasonGradients = [
      // Зима (дек-фев)
      [const Color(0xFF1A1A2E).withOpacity(0.4), const Color(0xFF16213E).withOpacity(0.3)],
      // Весна (мар-май)  
      [const Color(0xFF0F3460).withOpacity(0.3), const Color(0xFF16537E).withOpacity(0.2)],
      // Лето (июн-авг)
      [const Color(0xFF533483).withOpacity(0.3), const Color(0xFF7209B7).withOpacity(0.2)],
      // Осень (сен-ноя)
      [const Color(0xFF2D1B2E).withOpacity(0.3), const Color(0xFF422041).withOpacity(0.2)],
    ];
    
    // Рисуем сезонные сектора
    for (int i = 0; i < 4; i++) {
      final startAngle = i * (math.pi / 2) - (math.pi / 4);
      final sweepAngle = math.pi / 2;
      
      final gradient = RadialGradient(
        colors: seasonGradients[i],
        center: Alignment.center,
        radius: 1.0,
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
    
    // Тонкие разделители между сезонами
    final dividerPaint = Paint()
      ..color = Colors.white.withOpacity(0.06)
      ..strokeWidth = 1.5;
    
    for (int i = 0; i < 4; i++) {
      final angle = i * (math.pi / 2);
      final startPoint = Offset(
        center.dx + (radius * 0.4) * math.cos(angle),
        center.dy + (radius * 0.4) * math.sin(angle),
      );
      final endPoint = Offset(
        center.dx + radius * math.cos(angle),
        center.dy + radius * math.sin(angle),
      );
      
      canvas.drawLine(startPoint, endPoint, dividerPaint);
    }
    
    // Внутренний круг для более плавного перехода
    final innerPaint = Paint()
      ..color = Colors.black.withOpacity(0.2)
      ..style = PaintingStyle.fill;
    
    canvas.drawCircle(center, radius * 0.35, innerPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}