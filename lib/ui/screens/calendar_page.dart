import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:ui' as ui;
import 'dart:math' as math;
import '../../models/pagan_holiday.dart';
import '../widgets/interactive_pagan_wheel.dart';
import '../widgets/holiday_info_modal.dart';

class CalendarPage extends StatefulWidget {
  const CalendarPage({super.key});

  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage>
    with TickerProviderStateMixin {
  
  // Контроллеры анимации
  late AnimationController _fadeController;
  late AnimationController _backgroundController;
  late ScrollController _scrollController;
  
  // Анимации
  late Animation<double> _fadeAnimation;
  late Animation<double> _backgroundAnimation;
  
  // Календарь состояние
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  CalendarFormat _calendarFormat = CalendarFormat.month;
  
  // Фильтры
  String? _selectedTradition;
  HistoricalAuthenticity? _selectedAuthenticity;
  
  // Данные праздников
  List<PaganHoliday> _allHolidays = [];
  Map<DateTime, List<PaganHoliday>> _events = {};
  
  // Следующий праздник
  PaganHoliday? _nextHoliday;
  int _daysUntilHoliday = 0;
  DateTime? _nextHolidayDate;
  
  // UI состояние
  bool _isLoading = true;
  bool _showFilters = false;
  
  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _loadHolidays();
    _selectedDay = DateTime.now();
  }
  
  void _initializeAnimations() {
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    
    _backgroundController = AnimationController(
      duration: const Duration(seconds: 10),
      vsync: this,
    )..repeat();
    
    _scrollController = ScrollController();
    
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    ));
    
    _backgroundAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _backgroundController,
      curve: Curves.linear,
    ));
    
    _fadeController.forward();
  }
  
  @override
  void dispose() {
    _fadeController.dispose();
    _backgroundController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // Методы для работы с данными
  Future<void> _loadHolidays() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      // Используем существующий сервис
      _allHolidays = PaganHolidayService.getAllHolidays();
      _prepareEvents();
      _findNextHoliday();
    } catch (e) {
      debugPrint('Error loading holidays: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  void _prepareEvents() {
    _events.clear();
    
    final filteredHolidays = _getFilteredHolidays();
    
    for (final holiday in filteredHolidays) {
      final date = DateTime(DateTime.now().year, holiday.date.month, holiday.date.day);
      if (_events[date] != null) {
        _events[date]!.add(holiday);
      } else {
        _events[date] = [holiday];
      }
    }
  }
  
  List<PaganHoliday> _getFilteredHolidays() {
    return _allHolidays.where((holiday) {
      bool matchesTradition = _selectedTradition == null || 
          holiday.tradition == _selectedTradition;
      
      bool matchesAuthenticity = _selectedAuthenticity == null || 
          holiday.authenticity == _selectedAuthenticity;
      
      return matchesTradition && matchesAuthenticity;
    }).toList();
  }
  
  List<PaganHoliday> _getEventsForDay(DateTime day) {
    return _events[DateTime(day.year, day.month, day.day)] ?? [];
  }
  
  void _findNextHoliday() {
    final now = DateTime.now();
    final filteredHolidays = _getFilteredHolidays();
    
    PaganHoliday? closest;
    int minDays = 366;
    DateTime? closestDate;
    
    for (final holiday in filteredHolidays) {
      final thisYear = DateTime(now.year, holiday.date.month, holiday.date.day);
      final nextYear = DateTime(now.year + 1, holiday.date.month, holiday.date.day);
      
      int daysUntilThisYear = thisYear.difference(now).inDays;
      int daysUntilNextYear = nextYear.difference(now).inDays;
      
      if (daysUntilThisYear >= 0 && daysUntilThisYear < minDays) {
        minDays = daysUntilThisYear;
        closest = holiday;
        closestDate = thisYear;
      } else if (daysUntilNextYear < minDays) {
        minDays = daysUntilNextYear;
        closest = holiday;
        closestDate = nextYear;
      }
    }
    
    setState(() {
      _nextHoliday = closest;
      _daysUntilHoliday = minDays;
      _nextHolidayDate = closestDate;
    });
  }

  // Обработчики событий календаря
  void _onDaySelected(DateTime selectedDay, DateTime focusedDay) {
    if (!isSameDay(_selectedDay, selectedDay)) {
      setState(() {
        _selectedDay = selectedDay;
        _focusedDay = focusedDay;
      });
    }
  }
  
  void _onFormatChanged(CalendarFormat format) {
    if (_calendarFormat != format) {
      setState(() {
        _calendarFormat = format;
      });
    }
  }
  
  void _onPageChanged(DateTime focusedDay) {
    setState(() {
      _focusedDay = focusedDay;
    });
  }
  
  // Методы фильтрации
  void _onTraditionChanged(String? tradition) {
    setState(() {
      _selectedTradition = tradition;
    });
    _prepareEvents();
    _findNextHoliday();
  }
  
  void _onAuthenticityChanged(HistoricalAuthenticity? authenticity) {
    setState(() {
      _selectedAuthenticity = authenticity;
    });
    _prepareEvents();
    _findNextHoliday();
  }
  
  void _toggleFilters() {
    setState(() {
      _showFilters = !_showFilters;
    });
  }
  
  void _clearFilters() {
    setState(() {
      _selectedTradition = null;
      _selectedAuthenticity = null;
    });
    _prepareEvents();
    _findNextHoliday();
  }
  
  // Вспомогательные методы для отображения
  String _getTraditionDisplayName(String tradition) {
    switch (tradition) {
      case 'nordic':
        return 'Скандинавская';
      case 'celtic':
        return 'Кельтская';
      case 'germanic':
        return 'Германская';
      case 'slavic':
        return 'Славянская';
      case 'roman':
        return 'Римская';
      case 'greek':
        return 'Греческая';
      case 'baltic':
        return 'Балтийская';
      case 'finnish':
        return 'Финно-угорская';
      default:
        return tradition;
    }
  }
  
  String _getAuthenticityDisplayName(HistoricalAuthenticity authenticity) {
    switch (authenticity) {
      case HistoricalAuthenticity.authentic:
        return 'Древние';
      case HistoricalAuthenticity.likely:
        return 'Вероятные';
      case HistoricalAuthenticity.reconstructed:
        return 'Восстановленные';
      case HistoricalAuthenticity.modern:
        return 'Современные';
    }
  }
  
  Color _getAuthenticityColor(HistoricalAuthenticity authenticity) {
    switch (authenticity) {
      case HistoricalAuthenticity.authentic:
        return Colors.green;
      case HistoricalAuthenticity.likely:
        return Colors.orange;
      case HistoricalAuthenticity.reconstructed:
        return Colors.blue;
      case HistoricalAuthenticity.modern:
        return Colors.purple;
    }
  }

  String _formatDate(DateTime date) {
    const months = [
      'января', 'февраля', 'марта', 'апреля', 'мая', 'июня',
      'июля', 'августа', 'сентября', 'октября', 'ноября', 'декабря'
    ];
    return '${date.day} ${months[date.month - 1]}';
  }

  String _getDaysWord(int days) {
    if (days % 10 == 1 && days % 100 != 11) {
      return 'день';
    } else if ([2, 3, 4].contains(days % 10) && ![12, 13, 14].contains(days % 100)) {
      return 'дня';
    } else {
      return 'дней';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: AnimatedBuilder(
        animation: _backgroundAnimation,
        builder: (context, child) {
          return Container(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment.center,
                radius: 1.5,
                colors: [
                  Color.lerp(
                    const Color(0xFF1A1A2E),
                    const Color(0xFF16213E),
                    math.sin(_backgroundAnimation.value * 2 * math.pi) * 0.5 + 0.5,
                  )!,
                  Color.lerp(
                    const Color(0xFF0F0F23),
                    const Color(0xFF1A1A2E),
                    math.cos(_backgroundAnimation.value * 2 * math.pi) * 0.5 + 0.5,
                  )!,
                ],
              ),
            ),
            child: SafeArea(
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: Column(
                  children: [
                    _buildHeader(),
                    if (_showFilters) _buildFilters(),
                    Expanded(
                      child: _isLoading
                          ? _buildLoadingIndicator()
                          : _buildCalendarContent(),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
  
  Widget _buildLoadingIndicator() {
    return const Center(
      child: CircularProgressIndicator(
        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
      ),
    );
  }
  
  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(
                  Icons.arrow_back_ios,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              Expanded(
                child: Text(
                  'Календарь праздников',
                  style: GoogleFonts.merriweather(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              IconButton(
                onPressed: _toggleFilters,
                icon: Icon(
                  _showFilters ? Icons.filter_list_off : Icons.filter_list,
                  color: Colors.white,
                  size: 24,
                ),
              ),
            ],
          ),
          if (_nextHoliday != null) _buildNextHolidayCard(),
        ],
      ),
    );
  }

  Widget _buildNextHolidayCard() {
    if (_nextHoliday == null) return const SizedBox.shrink();
    
    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            _getAuthenticityColor(_nextHoliday!.authenticity)
                .withOpacity(0.2),
            _getAuthenticityColor(_nextHoliday!.authenticity)
                .withOpacity(0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: _getAuthenticityColor(_nextHoliday!.authenticity)
              .withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.event,
                color: _getAuthenticityColor(_nextHoliday!.authenticity),
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'Следующий праздник',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.8),
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _nextHoliday!.name,
            style: GoogleFonts.merriweather(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _daysUntilHoliday == 0
                ? 'Сегодня!'
                : _daysUntilHoliday == 1
                    ? 'Завтра'
                    : 'Через $_daysUntilHoliday ${_getDaysWord(_daysUntilHoliday)}',
            style: TextStyle(
              color: _getAuthenticityColor(_nextHoliday!.authenticity),
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilters() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: Colors.white.withOpacity(0.1),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Фильтры',
                style: GoogleFonts.merriweather(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              const Spacer(),
              TextButton(
                onPressed: _clearFilters,
                child: Text(
                  'Очистить',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.7),
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          
          // Фильтр по традициям
          Text(
            'Традиция:',
            style: TextStyle(
              color: Colors.white.withOpacity(0.8),
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: _selectedTradition,
            decoration: InputDecoration(
              filled: true,
              fillColor: Colors.white.withOpacity(0.05),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(
                  color: Colors.white.withOpacity(0.2),
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(
                  color: Colors.white.withOpacity(0.2),
                ),
              ),
            ),
            dropdownColor: const Color(0xFF1A1A2E),
            style: const TextStyle(color: Colors.white),
            items: [
              const DropdownMenuItem<String>(
                value: null,
                child: Text('Все традиции'),
              ),
              ...PaganHolidayService.getAllTraditions()
                  .map((tradition) => DropdownMenuItem<String>(
                        value: tradition,
                        child: Text(_getTraditionDisplayName(tradition)),
                      )),
            ],
            onChanged: _onTraditionChanged,
          ),
          
          const SizedBox(height: 16),
          
          // Фильтр по достоверности
          Text(
            'Достоверность:',
            style: TextStyle(
              color: Colors.white.withOpacity(0.8),
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<HistoricalAuthenticity>(
            value: _selectedAuthenticity,
            decoration: InputDecoration(
              filled: true,
              fillColor: Colors.white.withOpacity(0.05),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(
                  color: Colors.white.withOpacity(0.2),
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(
                  color: Colors.white.withOpacity(0.2),
                ),
              ),
            ),
            dropdownColor: const Color(0xFF1A1A2E),
            style: const TextStyle(color: Colors.white),
            items: [
              const DropdownMenuItem<HistoricalAuthenticity>(
                value: null,
                child: Text('Любая достоверность'),
              ),
              ...HistoricalAuthenticity.values.map((authenticity) =>
                  DropdownMenuItem<HistoricalAuthenticity>(
                    value: authenticity,
                    child: Row(
                      children: [
                        Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: _getAuthenticityColor(authenticity),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(_getAuthenticityDisplayName(authenticity)),
                      ],
                    ),
                  )),
            ],
            onChanged: _onAuthenticityChanged,
          ),
        ],
      ),
    );
  }

  Widget _buildCalendarContent() {
    return SingleChildScrollView(
      controller: _scrollController,
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          _buildCalendar(),
          const SizedBox(height: 20),
          _buildSelectedDayEvents(),
          const SizedBox(height: 20),
          _buildPaganWheel(),
        ],
      ),
    );
  }
  
  Widget _buildCalendar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withOpacity(0.1),
          width: 1,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: TableCalendar<PaganHoliday>(
              firstDay: DateTime.utc(2020, 1, 1),
              lastDay: DateTime.utc(2030, 12, 31),
              focusedDay: _focusedDay,
              calendarFormat: _calendarFormat,
              eventLoader: _getEventsForDay,
              startingDayOfWeek: StartingDayOfWeek.monday,
              
              // Стилизация календаря
              calendarStyle: CalendarStyle(
                outsideDaysVisible: false,
                weekendTextStyle: TextStyle(
                  color: Colors.red.withOpacity(0.8),
                ),
                holidayTextStyle: TextStyle(
                  color: Colors.red.withOpacity(0.8),
                ),
                defaultTextStyle: const TextStyle(
                  color: Colors.white,
                ),
                todayTextStyle: const TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.bold,
                ),
                selectedTextStyle: const TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.bold,
                ),
                todayDecoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.8),
                  shape: BoxShape.circle,
                ),
                selectedDecoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                markerDecoration: BoxDecoration(
                  color: Colors.amber.withOpacity(0.8),
                  shape: BoxShape.circle,
                ),
                markersMaxCount: 3,
                canMarkersOverflow: true,
              ),
              
              // Стилизация заголовка
              headerStyle: HeaderStyle(
                formatButtonVisible: true,
                titleCentered: true,
                formatButtonShowsNext: false,
                formatButtonDecoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12.0),
                ),
                formatButtonTextStyle: const TextStyle(
                  color: Colors.white,
                  fontSize: 12.0,
                ),
                leftChevronIcon: const Icon(
                  Icons.chevron_left,
                  color: Colors.white,
                ),
                rightChevronIcon: const Icon(
                  Icons.chevron_right,
                  color: Colors.white,
                ),
                titleTextStyle: GoogleFonts.merriweather(
                  color: Colors.white,
                  fontSize: 18.0,
                  fontWeight: FontWeight.w600,
                ),
              ),
              
              // Стилизация дней недели
              daysOfWeekStyle: DaysOfWeekStyle(
                weekdayStyle: TextStyle(
                  color: Colors.white.withOpacity(0.7),
                  fontWeight: FontWeight.w500,
                ),
                weekendStyle: TextStyle(
                  color: Colors.red.withOpacity(0.7),
                  fontWeight: FontWeight.w500,
                ),
              ),
              
              selectedDayPredicate: (day) {
                return isSameDay(_selectedDay, day);
              },
              
              onDaySelected: _onDaySelected,
              onFormatChanged: _onFormatChanged,
              onPageChanged: _onPageChanged,
              
              // Кастомный билдер для маркеров событий
              calendarBuilders: CalendarBuilders(
                markerBuilder: (context, day, events) {
                  if (events.isNotEmpty) {
                    return Positioned(
                      right: 1,
                      bottom: 1,
                      child: _buildEventMarker(events.cast<PaganHoliday>()),
                    );
                  }
                  return null;
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEventMarker(List<PaganHoliday> events) {
    return Container(
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.amber,
      ),
      width: 16.0,
      height: 16.0,
      child: Center(
        child: Text(
          '${events.length}',
          style: const TextStyle(
            color: Colors.black,
            fontSize: 10.0,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildSelectedDayEvents() {
    final events = _getEventsForDay(_selectedDay ?? DateTime.now());
    
    if (events.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(
            color: Colors.white.withOpacity(0.1),
            width: 1,
          ),
        ),
        child: Column(
          children: [
            Icon(
              Icons.event_busy,
              color: Colors.white.withOpacity(0.5),
              size: 48,
            ),
            const SizedBox(height: 12),
            Text(
              'Нет праздников',
              style: GoogleFonts.merriweather(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.white.withOpacity(0.7),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _selectedDay != null
                  ? 'На ${_formatDate(_selectedDay!)} нет праздников'
                  : 'Выберите дату для просмотра праздников',
              style: TextStyle(
                color: Colors.white.withOpacity(0.5),
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: Colors.white.withOpacity(0.1),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(
                  Icons.event,
                  color: Colors.white.withOpacity(0.8),
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  _selectedDay != null
                      ? 'Праздники ${_formatDate(_selectedDay!)}'
                      : 'Праздники сегодня',
                  style: GoogleFonts.merriweather(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          ...events.map((holiday) => _buildHolidayCard(holiday)),
        ],
      ),
    );
  }

  Widget _buildHolidayCard(PaganHoliday holiday) {
    return Container(
      margin: const EdgeInsets.only(left: 16, right: 16, bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            _getAuthenticityColor(holiday.authenticity).withOpacity(0.15),
            _getAuthenticityColor(holiday.authenticity).withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _getAuthenticityColor(holiday.authenticity).withOpacity(0.3),
          width: 1,
        ),
      ),
      child: InkWell(
        onTap: () => _showHolidayDetails(holiday),
        borderRadius: BorderRadius.circular(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    holiday.name,
                    style: GoogleFonts.merriweather(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _getAuthenticityColor(holiday.authenticity).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _getAuthenticityDisplayName(holiday.authenticity),
                    style: TextStyle(
                      color: _getAuthenticityColor(holiday.authenticity),
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              holiday.description,
              style: TextStyle(
                color: Colors.white.withOpacity(0.8),
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _getTraditionDisplayName(holiday.tradition),
              style: TextStyle(
                color: Colors.white.withOpacity(0.7),
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaganWheel() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: Colors.white.withOpacity(0.1),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(
                  Icons.circle_outlined,
                  color: Colors.white.withOpacity(0.8),
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'Колесо года',
                  style: GoogleFonts.merriweather(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          // Здесь должен быть InteractivePaganWheel, но пока заглушка
          Container(
            height: 200,
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.white.withOpacity(0.1),
                width: 1,
              ),
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.circle_outlined,
                    color: Colors.white.withOpacity(0.5),
                    size: 48,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Интерактивное колесо года',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.7),
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Будет добавлено позже',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.5),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showHolidayDetails(PaganHoliday holiday) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => HolidayInfoModal(holiday: holiday),
    );
  }

  String _getMonthName(int month) {
    const months = [
      'Январь', 'Февраль', 'Март', 'Апрель', 'Май', 'Июнь',
      'Июль', 'Август', 'Сентябрь', 'Октябрь', 'Ноябрь', 'Декабрь'
    ];
    return months[month - 1];
  }
}