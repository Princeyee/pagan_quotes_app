
// lib/ui/screens/calendar_page.dart - УЛУЧШЕННАЯ ВЕРСИЯ
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:convert';
import 'dart:ui' as ui;
import 'dart:math' as math;
import '../../models/daily_quote.dart';
import '../../models/pagan_holiday.dart';
import '../../services/quote_extraction_service.dart';
import '../../services/image_picker_service.dart';
import '../../utils/custom_cache.dart';
import '../widgets/calendar_quote_modal.dart';
import '../widgets/holiday_info_modal.dart';

class CalendarPage extends StatefulWidget {
  const CalendarPage({super.key});

  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> with TickerProviderStateMixin {
  final CustomCachePrefs _cache = CustomCache.prefs;
  final QuoteExtractionService _quoteService = QuoteExtractionService();
  
  late AnimationController _fadeController;
  late AnimationController _backgroundController;
  late AnimationController _countdownController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _backgroundAnimation;
  late Animation<double> _countdownAnimation;
  
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  CalendarFormat _calendarFormat = CalendarFormat.month;
  
  Map<DateTime, List<dynamic>> _events = {};
  Map<DateTime, DailyQuote> _cachedQuotes = {};
  List<PaganHoliday> _holidays = [];
  
  bool _isLoading = true;
  String? _selectedTradition;
  String? _backgroundImageUrl;
  
  // Данные для счетчика праздников
  PaganHoliday? _nextHoliday;
  Duration? _timeUntilNextHoliday;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _loadData();
    _selectedDay = DateTime.now();
    _startCountdownTimer();
  }

  void _initializeAnimations() {
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    
    _backgroundController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    
    _countdownController = AnimationController(
      duration: const Duration(seconds: 1),
      vsync: this,
    )..repeat();

    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    );

    _backgroundAnimation = CurvedAnimation(
      parent: _backgroundController,
      curve: Curves.easeInOut,
    );

    _countdownAnimation = CurvedAnimation(
      parent: _countdownController,
      curve: Curves.easeInOut,
    );
  }

  void _startCountdownTimer() {
    // Обновляем каждую секунду для живого таймера
    Future.doWhile(() async {
      if (!mounted) return false;
      
      await Future.delayed(const Duration(seconds: 1));
      if (mounted) {
        _updateNextHoliday();
      }
      return mounted;
    });
  }

  void _updateNextHoliday() {
    final nextHoliday = PaganHolidayService.getNextHoliday();
    if (nextHoliday != null) {
      final now = DateTime.now();
      final currentYear = now.year;
      final holidayThisYear = nextHoliday.getDateForYear(currentYear);
      
      DateTime targetDate;
      if (holidayThisYear.isAfter(now)) {
        targetDate = holidayThisYear;
      } else {
        targetDate = nextHoliday.getDateForYear(currentYear + 1);
      }
      
      final timeUntil = targetDate.difference(now);
      
      if (mounted) {
        setState(() {
          _nextHoliday = nextHoliday;
          _timeUntilNextHoliday = timeUntil;
        });
      }
    }
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    
    try {
      // Загружаем фоновое изображение (используем ту же что на главном экране)
      await _loadBackgroundImage();
      
      // Загружаем праздники
      _holidays = PaganHolidayService.getAllHolidays();
      
      // Обновляем ближайший праздник
      _updateNextHoliday();
      
      // Загружаем кэшированные цитаты
      await _loadCachedQuotes();
      
      // Подготавливаем события
      _prepareEvents();
      
      setState(() => _isLoading = false);
      
      // Запускаем анимации
      _fadeController.forward();
      await Future.delayed(const Duration(milliseconds: 300));
      _backgroundController.forward();
      
    } catch (e) {
      print('Error loading calendar data: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadBackgroundImage() async {
    try {
      // Используем сегодняшнее изображение или случайное из философии
      final today = DateTime.now();
      final dateString = '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
      
      String? cachedImageUrl = _cache.getSetting<String>('daily_image_$dateString');
      cachedImageUrl ??= ImagePickerService.getRandomImage('philosophy');
      
      setState(() {
        _backgroundImageUrl = cachedImageUrl;
      });
    } catch (e) {
      print('Error loading background image: $e');
      setState(() {
        _backgroundImageUrl = ImagePickerService.getRandomImage('philosophy');
      });
    }
  }

  Future<void> _loadCachedQuotes() async {
    final prefs = _cache.prefs;
    final keys = prefs.getKeys().where((key) => key.startsWith('daily_quote_'));
    
    for (final key in keys) {
      try {
        final json = prefs.getString(key);
        if (json != null) {
          final data = jsonDecode(json) as Map<String, dynamic>;
          final dailyQuote = DailyQuote.fromJson(data);
          _cachedQuotes[dailyQuote.date] = dailyQuote;
        }
      } catch (e) {
        print('Error parsing cached quote: $e');
      }
    }
  }

  void _prepareEvents() {
    _events.clear();
    final currentYear = _focusedDay.year;
    
    // Добавляем праздники
    for (final holiday in _holidays) {
      if (_selectedTradition == null || holiday.tradition == _selectedTradition) {
        final holidayDate = holiday.getDateForYear(currentYear);
        final dateKey = DateTime(holidayDate.year, holidayDate.month, holidayDate.day);
        
        _events.putIfAbsent(dateKey, () => []).add(holiday);
      }
    }
    
    // Добавляем цитаты
    for (final entry in _cachedQuotes.entries) {
      final dateKey = DateTime(entry.key.year, entry.key.month, entry.key.day);
      _events.putIfAbsent(dateKey, () => []).add(entry.value);
    }
  }

  List<dynamic> _getEventsForDay(DateTime day) {
    final dateKey = DateTime(day.year, day.month, day.day);
    return _events[dateKey] ?? [];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Календарь',
          style: GoogleFonts.merriweather(
            color: Colors.white,
            fontWeight: FontWeight.w300,
          ),
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.3),
              borderRadius: BorderRadius.circular(20),
            ),
            child: PopupMenuButton<String>(
              icon: Icon(Icons.filter_list, color: Colors.white.withOpacity(0.9)),
              color: Colors.grey[900],
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              onSelected: (value) {
                setState(() {
                  _selectedTradition = value == 'all' ? null : value;
                  _prepareEvents();
                });
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'all',
                  child: Text('Все традиции', style: TextStyle(color: Colors.white)),
                ),
                ...PaganHolidayService.getAllTraditions().map(
                  (tradition) => PopupMenuItem(
                    value: tradition,
                    child: Text(
                      _getTraditionDisplayName(tradition),
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.white))
          : Stack(
              fit: StackFit.expand,
              children: [
                // Фоновое изображение с блюром
                _buildBackgroundWithBlur(),
                
                // Основной контент
                _buildMainContent(),
              ],
            ),
    );
  }

  Widget _buildBackgroundWithBlur() {
    return AnimatedBuilder(
      animation: _backgroundAnimation,
      child: _backgroundImageUrl != null
          ? CachedNetworkImage(
              imageUrl: _backgroundImageUrl!,
              cacheManager: CustomCache.instance,
              fit: BoxFit.cover,
              placeholder: (_, __) => Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.grey[900]!,
                      Colors.black,
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ),
              errorWidget: (_, __, ___) => Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.grey[900]!,
                      Colors.black,
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ),
            )
          : Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.grey[900]!,
                    Colors.black,
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
      builder: (context, child) {
        return Opacity(
          opacity: _backgroundAnimation.value,
          child: Stack(
            fit: StackFit.expand,
            children: [
              child ?? const SizedBox(),
              
              // Блюр эффект
              BackdropFilter(
                filter: ui.ImageFilter.blur(
                  sigmaX: 15.0,
                  sigmaY: 15.0,
                ),
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.black.withOpacity(0.7),
                        Colors.black.withOpacity(0.8),
                      ],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMainContent() {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Column(
        children: [
          // Отступ для AppBar
          const SizedBox(height: 100),
          
          // Календарь с улучшенным дизайном
          _buildEnhancedCalendar(),
          
          // Счетчик до ближайшего праздника
          _buildHolidayCountdown(),
          
          // Информация о выбранном дне
          if (_selectedDay != null) _buildSelectedDayInfo(),
        ],
      ),
    );
  }

  Widget _buildEnhancedCalendar() {
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
          child: Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Заголовок календаря
                _buildCalendarHeader(),
                
                const SizedBox(height: 16),
                
                // Сам календарь
                TableCalendar<dynamic>(
                  firstDay: DateTime(2020),
                  lastDay: DateTime(2030),
                  focusedDay: _focusedDay,
                  calendarFormat: _calendarFormat,
                  eventLoader: _getEventsForDay,
                  startingDayOfWeek: StartingDayOfWeek.monday,
                  // ВАЖНО: отключаем gesture-ы чтобы избежать проблем со свайпом
                  pageJumpingEnabled: false,
                  pageAnimationEnabled: false,
                  selectedDayPredicate: (day) {
                    return isSameDay(_selectedDay, day);
                  },
                  onDaySelected: (selectedDay, focusedDay) {
                    setState(() {
                      _selectedDay = selectedDay;
                      _focusedDay = focusedDay;
                    });
                  },
                  onFormatChanged: (format) {
                    setState(() {
                      _calendarFormat = format;
                    });
                  },
                  onPageChanged: (focusedDay) {
                    setState(() {
                      _focusedDay = focusedDay;
                      _prepareEvents();
                    });
                  },
                  calendarStyle: CalendarStyle(
                    // Основные дни
                    defaultTextStyle: GoogleFonts.merriweather(
                      color: Colors.white.withOpacity(0.9),
                      fontWeight: FontWeight.w400,
                    ),
                    weekendTextStyle: GoogleFonts.merriweather(
                      color: Colors.white.withOpacity(0.7),
                      fontWeight: FontWeight.w300,
                    ),
                    outsideDaysVisible: false,
                    
                    // Выбранный день
                    selectedDecoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.white.withOpacity(0.8),
                          Colors.white.withOpacity(0.6),
                        ],
                      ),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.white.withOpacity(0.3),
                          blurRadius: 8,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    selectedTextStyle: GoogleFonts.merriweather(
                      color: Colors.black,
                      fontWeight: FontWeight.bold,
                    ),
                    
                    // Сегодня
                    todayDecoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white.withOpacity(0.5),
                        width: 2,
                      ),
                    ),
                    todayTextStyle: GoogleFonts.merriweather(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                    
                    // События (маркеры)
                    markerDecoration: const BoxDecoration(
                      color: Color(0xFFE2A94A),
                      shape: BoxShape.circle,
                    ),
                    markersMaxCount: 3,
                    markerSize: 7,
                    markerMargin: const EdgeInsets.symmetric(horizontal: 0.5),
                  ),
                  headerStyle: HeaderStyle(
                    formatButtonVisible: false,
                    titleCentered: true,
                    titleTextStyle: GoogleFonts.merriweather(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                    ),
                    leftChevronVisible: false,
                    rightChevronVisible: false,
                  ),
                  daysOfWeekStyle: DaysOfWeekStyle(
                    weekdayStyle: GoogleFonts.merriweather(
                      color: Colors.white.withOpacity(0.7),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                    weekendStyle: GoogleFonts.merriweather(
                      color: Colors.white.withOpacity(0.5),
                      fontSize: 12,
                      fontWeight: FontWeight.w300,
                    ),
                  ),
                  calendarBuilders: CalendarBuilders(
                    markerBuilder: (context, day, events) {
                      if (events.isEmpty) return const SizedBox.shrink();
                      
                      return Positioned(
                        bottom: 1,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: events.take(3).map((event) {
                            Color markerColor;
                            if (event is PaganHoliday) {
                              markerColor = Color(int.parse(event.traditionColor.replaceFirst('#', '0xFF')));
                            } else if (event is DailyQuote) {
                              markerColor = Colors.white;
                            } else {
                              markerColor = Colors.grey;
                            }
                            
                            return Container(
                              width: 6,
                              height: 6,
                              margin: const EdgeInsets.symmetric(horizontal: 0.5),
                              decoration: BoxDecoration(
                                color: markerColor,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: markerColor.withOpacity(0.5),
                                    blurRadius: 3,
                                    spreadRadius: 1,
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCalendarHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Название месяца и года с анимацией
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: Text(
            '${_getMonthName(_focusedDay.month)} ${_focusedDay.year}',
            key: ValueKey('${_focusedDay.month}_${_focusedDay.year}'),
            style: GoogleFonts.merriweather(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ),
        
        // Кнопки навигации
        Row(
          children: [
            _buildNavButton(
              Icons.chevron_left,
              () {
                setState(() {
                  _focusedDay = DateTime(_focusedDay.year, _focusedDay.month - 1);
                  _prepareEvents();
                });
              },
            ),
            const SizedBox(width: 8),
            _buildNavButton(
              Icons.today,
              () {
                setState(() {
                  _focusedDay = DateTime.now();
                  _selectedDay = DateTime.now();
                  _prepareEvents();
                });
              },
            ),
            const SizedBox(width: 8),
            _buildNavButton(
              Icons.chevron_right,
              () {
                setState(() {
                  _focusedDay = DateTime(_focusedDay.year, _focusedDay.month + 1);
                  _prepareEvents();
                });
              },
            ),
          ],
        ),
      ],
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
            color: Colors.white.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Colors.white.withOpacity(0.2),
              width: 1,
            ),
          ),
          child: Icon(
            icon,
            color: Colors.white.withOpacity(0.8),
            size: 20,
          ),
        ),
      ),
    );
  }

  Widget _buildHolidayCountdown() {
    if (_nextHoliday == null || _timeUntilNextHoliday == null) {
      return const SizedBox.shrink();
    }

    final traditionColor = Color(int.parse(_nextHoliday!.traditionColor.replaceFirst('#', '0xFF')));
    
    return AnimatedBuilder(
      animation: _countdownAnimation,
      builder: (context, child) {
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                traditionColor.withOpacity(0.2),
                traditionColor.withOpacity(0.1),
              ],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: traditionColor.withOpacity(0.3),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: traditionColor.withOpacity(0.2),
                blurRadius: 15,
                spreadRadius: 0,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: BackdropFilter(
              filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: traditionColor.withOpacity(0.2),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.celebration,
                            color: traditionColor,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Ближайший праздник',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.white.withOpacity(0.7),
                                  fontWeight: FontWeight.w300,
                                ),
                              ),
                              Text(
                                _nextHoliday!.name,
                                style: GoogleFonts.merriweather(
                                  fontSize: 16,
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 12),
                    
                    // Счетчик времени
                    _buildTimeCountdown(traditionColor),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildTimeCountdown(Color accentColor) {
    final timeUntil = _timeUntilNextHoliday!;
    final days = timeUntil.inDays;
    final hours = timeUntil.inHours % 24;
    final minutes = timeUntil.inMinutes % 60;
    final seconds = timeUntil.inSeconds % 60;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _buildTimeUnit(days, 'дней', accentColor),
        _buildTimeSeparator(),
        _buildTimeUnit(hours, 'часов', accentColor),
        _buildTimeSeparator(),
        _buildTimeUnit(minutes, 'минут', accentColor),
        _buildTimeSeparator(),
        _buildTimeUnit(seconds, 'секунд', accentColor),
      ],
    );
  }

  Widget _buildTimeUnit(int value, String label, Color accentColor) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.3),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: accentColor.withOpacity(0.3),
              width: 1,
            ),
          ),
          child: Text(
            value.toString().padLeft(2, '0'),
            style: GoogleFonts.merriweather(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: Colors.white.withOpacity(0.6),
          ),
        ),
      ],
    );
  }

  Widget _buildTimeSeparator() {
    return Text(
      ':',
      style: GoogleFonts.merriweather(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: Colors.white.withOpacity(0.5),
      ),
    );
  }

  Widget _buildSelectedDayInfo() {
    final events = _getEventsForDay(_selectedDay!);
    if (events.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withOpacity(0.15),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 15,
            spreadRadius: 0,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.event,
                      color: Colors.white.withOpacity(0.8),
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${_selectedDay!.day} ${_getMonthName(_selectedDay!.month)}',
                      style: GoogleFonts.merriweather(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                
                ...events.map((event) {
                  if (event is PaganHoliday) {
                    return _buildHolidayCard(event);
                  } else if (event is DailyQuote) {
                    return _buildQuoteCard(event);
                  }
                  return const SizedBox.shrink();
                }).toList(),
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
      margin: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _showHolidayDetails(holiday),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(12),
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
                const SizedBox(width: 12),
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
                      if (holiday.nameOriginal != holiday.name)
                        Text(
                          holiday.nameOriginal,
                          style: TextStyle(
                            fontSize: 12,
                            fontStyle: FontStyle.italic,
                            color: Colors.white.withOpacity(0.7),
                          ),
                        ),
                      const SizedBox(height: 4),
                      Text(
                        '${_getTraditionDisplayName(holiday.tradition)} • ${holiday.description}',
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
                  Icons.info_outline,
                  color: traditionColor,
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildQuoteCard(DailyQuote dailyQuote) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _showQuoteDetails(dailyQuote),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.white.withOpacity(0.08),
                  Colors.white.withOpacity(0.04),
                ],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.white.withOpacity(0.2),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.white.withOpacity(0.3),
                        blurRadius: 4,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Цитата дня',
                        style: GoogleFonts.merriweather(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '"${dailyQuote.quote.text}"',
                        style: TextStyle(
                          fontSize: 13,
                          fontStyle: FontStyle.italic,
                          color: Colors.white.withOpacity(0.8),
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '— ${dailyQuote.quote.author}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white.withOpacity(0.6),
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.format_quote,
                  color: Colors.white.withOpacity(0.7),
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showHolidayDetails(PaganHoliday holiday) {
    showHolidayInfoModal(context, holiday);
  }

  void _showQuoteDetails(DailyQuote dailyQuote) {
    showCalendarQuoteModal(context, dailyQuote);
  }

  String _getMonthName(int month) {
    const months = [
      'Январь', 'Февраль', 'Март', 'Апрель', 'Май', 'Июнь',
      'Июль', 'Август', 'Сентябрь', 'Октябрь', 'Ноябрь', 'Декабрь'
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
      default:
        return tradition;
    }
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _backgroundController.dispose();
    _countdownController.dispose();
    super.dispose();
  }
}