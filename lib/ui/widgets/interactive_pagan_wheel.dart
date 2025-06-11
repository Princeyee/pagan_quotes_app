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
        Container(
          height: 380,
          width: double.infinity,
          child: Stack(
            children: [
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: const Alignment(0, 0.6),
                      radius: 1.5,
                      colors: [
                        Colors.transparent,
                        Colors.black.withOpacity(0.1),
                        Colors.black.withOpacity(0.3),
                        Colors.black.withOpacity(0.5),
                      ],
                      stops: const [0.0, 0.4, 0.7, 1.0],
                    ),
                  ),
                ),
              ),
              
              // Основное колесо
              ClipRect(
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
                              ..._buildGlowLayers(),
                              
                              if (_isLoading)
                                AnimatedBuilder(
                                  animation: _loadingAnimation,
                                  builder: (context, child) {
                                    return Transform.rotate(
                                      angle: _loadingAnimation.value,
                                      child: CustomPaint(
                                        size: const Size(650, 650),
                                        painter: LoadingWheelPainter(
                                          progress: _loadingController.value,
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              
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
                                      child: CustomPaint(
                                        size: const Size(650, 650),
                                        painter: EnhancedWheelPainter(
                                          months: _months,
                                          selectedMonth: _selectedMonth - 1,
                                          glowIntensity: _glowAnimation.value,
                                          shimmerProgress: _shimmerAnimation.value,
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                              
                              AnimatedBuilder(
                                animation: _rotationAnimation,
                                builder: (context, child) {
                                  final currentRotation = _rotationController.isAnimating 
                                      ? _rotationAnimation.value 
                                      : _currentRotation;
                                  
                                  return Transform.rotate(
                                    angle: currentRotation,
                                    child: _buildCenterElement(),
                                  );
                                },
                              ),
                              
                              if (!_isLoading)
                                _buildDecorativeElements(),
                            ],
                          ),
                        ),
                      ),
                    ),
                    
                    _buildTopGradient(),
                    
                    if (!_isLoading)
                      _buildMonthIndicator(),
                  ],
                ),
              ),
            ],
          ),
        ),
        
        // Информация о месяце
        AnimatedOpacity(
          duration: const Duration(milliseconds: 600),
          opacity: _isLoading ? 0.0 : 1.0,
          child: _buildMonthInfo(),
        ),
        
        // Список праздников
        if (_hasInteracted && !_isLoading) ...[
          SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.3),
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
        ] else if (!_isLoading) ...[
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
                  color: _months[_selectedMonth - 1].color.withOpacity(0.05 * _glowAnimation.value),
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
                  _months[_selectedMonth - 1].color.withOpacity(0.03 * _glowAnimation.value),
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
    return Container(
      width: 100,
      height: 100,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            Colors.black.withOpacity(0.9),
            Colors.black.withOpacity(0.7),
          ],
        ),
        border: Border.all(
          color: Colors.white.withOpacity(0.1),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.5),
            blurRadius: 20,
            spreadRadius: 5,
          ),
          BoxShadow(
            color: _months[_selectedMonth - 1].color.withOpacity(0.2),
            blurRadius: 30,
            spreadRadius: 0,
          ),
        ],
      ),
      child: ClipOval(
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 5.0, sigmaY: 5.0),
          child: Container(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                colors: [
                  Colors.white.withOpacity(0.05),
                  Colors.transparent,
                ],
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(2),
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
                            _months[_selectedMonth - 1].color.withOpacity(0.6),
                            _months[_selectedMonth - 1].color.withOpacity(0.2),
                          ],
                        ),
                      ),
                      child: Icon(
                        Icons.auto_awesome,
                        color: Colors.white.withOpacity(0.9),
                        size: 40,
                      ),
                    );
                  },
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
              Colors.black.withOpacity(0.8),
              Colors.black.withOpacity(0.6),
              Colors.black.withOpacity(0.3),
              Colors.black.withOpacity(0.1),
              Colors.transparent,
            ],
            stops: const [0.0, 0.3, 0.6, 0.8, 1.0],
          ),
        ),
      ),
    );
  }

  Widget _buildMonthIndicator() {
    return Positioned(
      bottom: 10,
      left: 0,
      right: 0,
      child: Center(
        child: AnimatedBuilder(
          animation: _glowAnimation,
          builder: (context, child) {
            return Container(
              width: 8,
              height: 35,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.white.withOpacity(0.3),
                    Colors.white.withOpacity(0.9),
                    Colors.white.withOpacity(0.3),
                  ],
                ),
                borderRadius: BorderRadius.circular(4),
                boxShadow: [
                  BoxShadow(
                    color: Colors.white.withOpacity(0.6 * _glowAnimation.value),
                    blurRadius: 15,
                    spreadRadius: 3,
                  ),
                  BoxShadow(
                    color: _months[_selectedMonth - 1].color.withOpacity(0.4),
                    blurRadius: 20,
                    spreadRadius: 0,
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildMonthInfo() {
    final currentMonth = _months[_selectedMonth - 1];
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  currentMonth.color.withOpacity(0.1),
                  currentMonth.color.withOpacity(0.05),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: currentMonth.color.withOpacity(0.2),
                width: 1,
              ),
            ),
            child: Column(
              children: [
                Text(
                  currentMonth.name,
                  style: GoogleFonts.merriweather(
                    fontSize: 26,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    shadows: [
                      Shadow(
                        color: currentMonth.color.withOpacity(0.5),
                        blurRadius: 10,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  decoration: BoxDecoration(
                    color: currentMonth.color.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: currentMonth.color.withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  child: Text(
                    _getSeasonName(currentMonth.season),
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white.withOpacity(0.9),
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHolidaysList() {
    // ОБНОВЛЯЕМ СООБЩЕНИЕ О ПУСТОМ СПИСКЕ С УЧЕТОМ ОБОИХ ФИЛЬТРОВ
    if (_currentMonthHolidays.isEmpty) {
      String emptyMessage;
      
      if (widget.selectedTradition != null && widget.selectedAuthenticity != null) {
        final traditionName = _getTraditionDisplayName(widget.selectedTradition!);
        final authenticityName = _getAuthenticityDisplayName(widget.selectedAuthenticity!);
        emptyMessage = 'В этом месяце нет праздников из $traditionName традиции с достоверностью "$authenticityName"';
      } else if (widget.selectedTradition != null) {
        final traditionName = _getTraditionDisplayName(widget.selectedTradition!);
        emptyMessage = 'В этом месяце нет праздников из $traditionName традиции';
      } else if (widget.selectedAuthenticity != null) {
        final authenticityName = _getAuthenticityDisplayName(widget.selectedAuthenticity!);
        emptyMessage = 'В этом месяце нет праздников с достоверностью "$authenticityName"';
      } else {
        emptyMessage = 'В этом месяце нет особых языческих праздников';
      }
      
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 20),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.03),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Colors.white.withOpacity(0.08),
                ),
              ),
              child: Text(
                emptyMessage,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.5),
                  fontSize: 14,
                  fontStyle: FontStyle.italic,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Colors.white.withOpacity(0.1),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          Icons.celebration,
                          color: Colors.white.withOpacity(0.8),
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Праздники месяца',
                              style: GoogleFonts.merriweather(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                            // ОБНОВЛЯЕМ ИНФОРМАЦИЮ О ФИЛЬТРАХ
                            if (widget.selectedTradition != null || widget.selectedAuthenticity != null) ...[
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  if (widget.selectedTradition != null) ...[
                                    Text(
                                      _getTraditionDisplayName(widget.selectedTradition!),
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.orange.withOpacity(0.8),
                                        fontStyle: FontStyle.italic,
                                      ),
                                    ),
                                    if (widget.selectedAuthenticity != null) ...[
                                      Text(
                                        ' • ',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.white.withOpacity(0.6),
                                        ),
                                      ),
                                    ],
                                  ],
                                  if (widget.selectedAuthenticity != null) ...[
                                    Icon(
                                      _getAuthenticityIcon(widget.selectedAuthenticity!),
                                      size: 12,
                                      color: _getAuthenticityColor(widget.selectedAuthenticity!),
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      _getAuthenticityDisplayName(widget.selectedAuthenticity!),
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: _getAuthenticityColor(widget.selectedAuthenticity!).withOpacity(0.8),
                                        fontStyle: FontStyle.italic,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                
                ..._currentMonthHolidays.map((holiday) => _buildHolidayCard(holiday)),
                
                const SizedBox(height: 12),
              ],
            ),
          ),
        ),
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
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            showHolidayInfoModal(context, holiday);
          },
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  traditionColor.withOpacity(0.1),
                  traditionColor.withOpacity(0.05),
                ],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: traditionColor.withOpacity(0.2),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      colors: [
                        traditionColor,
                        traditionColor.withOpacity(0.4),
                      ],
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: traditionColor.withOpacity(0.6),
                        blurRadius: 8,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ДОБАВЛЯЕМ ИНДИКАТОР ДОСТОВЕРНОСТИ В НАЗВАНИЕ
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              holiday.name,
                              style: GoogleFonts.merriweather(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.white.withOpacity(0.95),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Icon(
                            _getAuthenticityIcon(holiday.authenticity),
                            size: 14,
                            color: _getAuthenticityColor(holiday.authenticity),
                          ),
                        ],
                      ),
                      if (holiday.nameOriginal != holiday.name) ...[
                        const SizedBox(height: 2),
                        Text(
                          holiday.nameOriginal,
                          style: TextStyle(
                            fontSize: 12,
                            fontStyle: FontStyle.italic,
                            color: traditionColor.withOpacity(0.7),
                          ),
                        ),
                      ],
                      const SizedBox(height: 4),
                      Text(
                        '${holiday.date.day} ${_getMonthName(holiday.date.month)} • ${holiday.description}',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.white.withOpacity(0.7),
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios,
                  color: traditionColor.withOpacity(0.5),
                  size: 16,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // НОВЫЕ МЕТОДЫ ДЛЯ РАБОТЫ С ДОСТОВЕРНОСТЬЮ
  IconData _getAuthenticityIcon(HistoricalAuthenticity authenticity) {
    switch (authenticity) {
      case HistoricalAuthenticity.authentic:
        return Icons.verified;
      case HistoricalAuthenticity.likely:
        return Icons.check_circle_outline;
      case HistoricalAuthenticity.reconstructed:
        return Icons.construction;
      case HistoricalAuthenticity.modern:
        return Icons.new_releases;
    }
  }

  Color _getAuthenticityColor(HistoricalAuthenticity authenticity) {
    switch (authenticity) {
      case HistoricalAuthenticity.authentic:
        return Colors.green;
      case HistoricalAuthenticity.likely:
        return Colors.blue;
      case HistoricalAuthenticity.reconstructed:
        return Colors.orange;
      case HistoricalAuthenticity.modern:
        return Colors.red;
    }
  }

  String _getAuthenticityDisplayName(HistoricalAuthenticity authenticity) {
    switch (authenticity) {
      case HistoricalAuthenticity.authentic:
        return 'Подлинные';
      case HistoricalAuthenticity.likely:
        return 'Вероятные';
      case HistoricalAuthenticity.reconstructed:
        return 'Реконструкции';
      case HistoricalAuthenticity.modern:
        return 'Современные';
    }
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

  String _getTraditionDisplayName(String tradition) {
    switch (tradition.toLowerCase()) {
      case 'nordic':
      case 'scandinavian':
        return 'Северная традиция';
      case 'slavic':
        return 'Славянская традиция';
      case 'celtic':
        return 'Кельтская традиция';
      case 'germanic':
        return 'Германская традиция';
      case 'roman':
        return 'Римская традиция';
      case 'greek':
        return 'Греческая традиция';
      case 'baltic':
        return 'Балтийская традиция';
      case 'finnish':
      case 'finno-ugric':
        return 'Финно-угорская традиция';
      default:
        return tradition;
    }
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
          Colors.white.withOpacity(0.1),
          Colors.white.withOpacity(0.3 * progress),
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
      final endAngle = startAngle + sectorAngle;
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
      ..color = Colors.black.withOpacity(0.3)
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
        Colors.black.withOpacity(0.9),
        Colors.black.withOpacity(0.7),
        month.color.withOpacity(0.2),
        month.color.withOpacity(isSelected ? 0.5 : 0.3),
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
            month.color.withOpacity(0.2 * glowIntensity),
          ],
        ).createShader(rect)
        ..style = PaintingStyle.fill;

      canvas.drawPath(path, highlightPaint);
    }
  }

  void _drawSectorLines(Canvas canvas, Offset center, double radius, double angle) {
    final linePaint = Paint()
      ..color = Colors.white.withOpacity(0.1)
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
      ..color = monthData.color.withOpacity(0.3 * glowIntensity)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    
    canvas.drawCircle(Offset(symbolX, symbolY), 15, glowPaint);
    
    final monthSymbol = _getMonthSymbol(month);
    final symbolPainter = TextPainter(
      text: TextSpan(
        text: monthSymbol,
        style: TextStyle(
          color: monthData.color.withOpacity(0.9),
          fontSize: 24,
          fontWeight: FontWeight.w600,
          shadows: [
            Shadow(
              color: monthData.color.withOpacity(0.5),
              blurRadius: 4,
            ),
            Shadow(
              color: Colors.black.withOpacity(0.8),
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
          color: Colors.white.withOpacity(0.8),
          fontSize: 14,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.5,
          shadows: [
            Shadow(
              color: Colors.black.withOpacity(0.9),
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
          Colors.white.withOpacity(0.3),
          Colors.white.withOpacity(0.1),
        ],
      ).createShader(Rect.fromCircle(center: center, radius: radius))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    
    canvas.drawCircle(center, radius, ringPaint);
    
    final innerRingPaint = Paint()
      ..color = Colors.white.withOpacity(0.05)
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
            color: seasonColor.withOpacity(0.8),
            fontSize: 16,
            fontWeight: FontWeight.w700,
            letterSpacing: 2,
            shadows: [
              Shadow(
                color: Colors.black.withOpacity(0.9),
                blurRadius: 4,
                offset: const Offset(1, 1),
              ),
              Shadow(
                color: seasonColor.withOpacity(0.4),
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
          Colors.white.withOpacity(0.05),
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
      ..color = color.withOpacity(0.1)
      ..style = PaintingStyle.fill;

    // Рисуем орбитальные точки
    for (int i = 0; i < 12; i++) {
      final angle = (i * 30 * math.pi / 180) + (progress * 2 * math.pi);
      final radius = 320 + math.sin(progress * 2 * math.pi + i) * 20;
      
      final x = center.dx + math.cos(angle) * radius;
      final y = center.dy + math.sin(angle) * radius;
      
      final opacity = (0.3 + 0.3 * math.sin(progress * 2 * math.pi + i)).clamp(0.0, 1.0);
      paint.color = color.withOpacity(opacity * 0.2);
      
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