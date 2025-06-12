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
import '../widgets/interactive_pagan_wheel.dart';

class CalendarPage extends StatefulWidget {
  const CalendarPage({super.key});

  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> with TickerProviderStateMixin {
  final CustomCachePrefs _cache = CustomCache.prefs;
  final QuoteExtractionService _quoteService = QuoteExtractionService();
  final ScrollController _scrollController = ScrollController();

  late AnimationController _fadeController;
  late AnimationController _backgroundController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _backgroundAnimation;

  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  CalendarFormat _calendarFormat = CalendarFormat.month;

  Map<DateTime, List<dynamic>> _events = {};
  Map<DateTime, DailyQuote> _cachedQuotes = {};
  List<PaganHoliday> _holidays = [];

  bool _isLoading = true;
  bool _showCalendar = false;
  String? _selectedTradition;
  HistoricalAuthenticity? _selectedAuthenticity;
  String? _backgroundImageUrl;

  // Данные для ближайшего праздника
  PaganHoliday? _nextHoliday;
  int _daysUntilHoliday = 0;
  DateTime? _nextHolidayDate;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _loadData();
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

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    try {
      await _loadBackgroundImage();

      // Загружаем праздники
      _holidays = PaganHolidayService.getAllHolidays();

      // Обновляем ближайший праздник
      _findNextHoliday();

      // Загружаем кэшированные цитаты
      await _loadCachedQuotes();

      // Подготавливаем события
      _prepareEvents();

      setState(() => _isLoading = false);

      // Запускаем анимации
      _fadeController.forward();

    } catch (e) {
      debugPrint('Error loading calendar data: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadBackgroundImage() async {
    try {
      final today = DateTime.now();
      final dateString = '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

      String? cachedImageUrl = _cache.getSetting<String>('daily_image_$dateString');
      cachedImageUrl ??= ImagePickerService.getRandomImage('philosophy');

      setState(() {
        _backgroundImageUrl = cachedImageUrl;
      });
    } catch (e) {
      debugPrint('Error loading background image: $e');
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
        debugPrint('Error parsing cached quote: $e');
      }
    }
  }

  void _prepareEvents() {
    _events.clear();
    final currentYear = _focusedDay.year;

    // Добавляем праздники
    final filteredHolidays = _getFilteredHolidays();
    for (final holiday in filteredHolidays) {
      final holidayDate = DateTime(currentYear, holiday.date.month, holiday.date.day);
      final dateKey = DateTime(holidayDate.year, holidayDate.month, holidayDate.day);
      _events.putIfAbsent(dateKey, () => []).add(holiday);
    }

    // Добавляем цитаты
    for (final entry in _cachedQuotes.entries) {
      final dateKey = DateTime(entry.key.year, entry.key.month, entry.key.day);
      _events.putIfAbsent(dateKey, () => []).add(entry.value);
    }
  }

  List<PaganHoliday> _getFilteredHolidays() {
    return _holidays.where((holiday) {
      bool matchesTradition = _selectedTradition == null || 
          holiday.tradition.toLowerCase() == _selectedTradition!.toLowerCase();
      
      bool matchesAuthenticity = _selectedAuthenticity == null || 
          holiday.authenticity == _selectedAuthenticity;
      
      return matchesTradition && matchesAuthenticity;
    }).toList();
  }

  List<dynamic> _getEventsForDay(DateTime day) {
    final dateKey = DateTime(day.year, day.month, day.day);
    return _events[dateKey] ?? [];
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
    _prepareEvents();
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
    switch (tradition.toLowerCase()) {
      case 'nordic':
      case 'scandinavian':
        return 'Скандинавская';
      case 'slavic':
        return 'Славянская';
      case 'celtic':
        return 'Кельтская';
      case 'germanic':
        return 'Германская';
      case 'roman':
        return 'Римская';
      case 'greek':
        return 'Греческая';
      case 'baltic':
        return 'Балтийская';
      case 'finnish':
      case 'finno-ugric':
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

  // Дополнительный метод для получения иконки достоверности (как в calendar_page_2)
  IconData _getAuthenticityIcon(HistoricalAuthenticity authenticity) {
    switch (authenticity) {
      case HistoricalAuthenticity.authentic:
        return Icons.verified;
      case HistoricalAuthenticity.likely:
        return Icons.check_circle_outline;
      case HistoricalAuthenticity.reconstructed:
        return Icons.build_circle;
      case HistoricalAuthenticity.modern:
        return Icons.new_releases;
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

  String _getMonthName(int month) {
    const months = [
      'Январь', 'Февраль', 'Март', 'Апрель', 'Май', 'Июнь',
      'Июль', 'Август', 'Сентябрь', 'Октябрь', 'Ноябрь', 'Декабрь'
    ];
    return months[month - 1];
  }

  String _getMonthNameGenitive(int month) {
    const months = [
      'января', 'февраля', 'марта', 'апреля', 'мая', 'июня',
      'июля', 'августа', 'сентября', 'октября', 'ноября', 'декабря'
    ];
    return months[month - 1];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Календарь праздников',
          style: GoogleFonts.merriweather(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.filter_list, color: Colors.white),
            color: const Color(0xFF1A1A2E),
            itemBuilder: (context) => [
              PopupMenuItem<String>(
                value: 'tradition',
                child: Row(
                  children: [
                    const Icon(Icons.public, color: Colors.white, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Традиция',
                      style: TextStyle(color: Colors.white),
                    ),
                  ],
                ),
              ),
              PopupMenuItem<String>(
                value: 'authenticity',
                child: Row(
                  children: [
                    const Icon(Icons.verified, color: Colors.white, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Достоверность',
                      style: TextStyle(color: Colors.white),
                    ),
                  ],
                ),
              ),
              if (_selectedTradition != null || _selectedAuthenticity != null)
                PopupMenuItem<String>(
                  value: 'clear',
                  child: Row(
                    children: [
                      const Icon(Icons.clear, color: Colors.white, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'Очистить фильтры',
                        style: TextStyle(color: Colors.white),
                      ),
                    ],
                  ),
                ),
            ],
            onSelected: (value) {
              switch (value) {
                case 'tradition':
                  _showTraditionFilter();
                  break;
                case 'authenticity':
                  _showAuthenticityFilter();
                  break;
                case 'clear':
                  _clearFilters();
                  break;
              }
            },
          ),
        ],
      ),
      body: _buildBackgroundWithBlur(),
    );
  }

  Widget _buildBackgroundWithBlur() {
    return Container(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: Alignment.center,
          radius: 1.5,
          colors: [
            const Color(0xFF1A1A2E),
            const Color(0xFF0F0F23),
          ],
        ),
      ),
      child: _backgroundImageUrl != null
          ? Stack(
              children: [
                // Фоновое изображение
                Positioned.fill(
                  child: CachedNetworkImage(
                    imageUrl: _backgroundImageUrl!,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Container(
                      color: const Color(0xFF1A1A2E),
                    ),
                    errorWidget: (context, url, error) => Container(
                      color: const Color(0xFF1A1A2E),
                    ),
                  ),
                ),
                // Блюр и затемнение
                Positioned.fill(
                  child: BackdropFilter(
                    filter: ui.ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                    child: Container(
                      color: Colors.black.withOpacity(0.6),
                    ),
                  ),
                ),
                // Контент
                _buildScrollableContent(),
              ],
            )
          : _buildScrollableContent(),
    );
  }

  Widget _buildScrollableContent() {
    return SafeArea(
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: _isLoading
            ? _buildLoadingIndicator()
            : SingleChildScrollView(
                controller: _scrollController,
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    if (_nextHoliday != null) _buildNextHolidayCard(),
                    const SizedBox(height: 20),
                    _buildPaganWheel(),
                    if (_showCalendar) ...[
                      const SizedBox(height: 20),
                      _buildCalendar(),
                      const SizedBox(height: 20),
                      _buildSelectedDayEvents(),
                    ],
                  ],
                ),
              ),
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

  Widget _buildNextHolidayCard() {
    if (_nextHoliday == null) return const SizedBox.shrink();
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            _getAuthenticityColor(_nextHoliday!.authenticity).withOpacity(0.2),
            _getAuthenticityColor(_nextHoliday!.authenticity).withOpacity(0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: _getAuthenticityColor(_nextHoliday!.authenticity).withOpacity(0.3),
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
              const Spacer(),
              Icon(
                _getAuthenticityIcon(_nextHoliday!.authenticity),
                color: _getAuthenticityColor(_nextHoliday!.authenticity),
                size: 16,
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
                const Spacer(),
                if (!_showCalendar)
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _showCalendar = true;
                      });
                    },
                    child: Text(
                      'Показать календарь',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.8),
                        fontSize: 12,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Container(
            height: 300,
            margin: const EdgeInsets.all(16),
            child: InteractivePaganWheel(
              onMonthChanged: (month, holidays) {
                setState(() {
                  _focusedDay = DateTime(_focusedDay.year, month);
                  _prepareEvents();
                  _showCalendar = true;
                });
              },
            ),
          ),
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
            child: TableCalendar<dynamic>(
              firstDay: DateTime.utc(2020, 1, 1),
              lastDay: DateTime.utc(2030, 12, 31),
              focusedDay: _focusedDay,
              calendarFormat: _calendarFormat,
              eventLoader: _getEventsForDay,
              startingDayOfWeek: StartingDayOfWeek.monday,
              
              calendarStyle: CalendarStyle(
                outsideDaysVisible: false,
                weekendTextStyle: TextStyle(color: Colors.red.withOpacity(0.8)),
                holidayTextStyle: TextStyle(color: Colors.red.withOpacity(0.8)),
                defaultTextStyle: const TextStyle(color: Colors.white),
                todayTextStyle: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
                selectedTextStyle: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
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
              
              headerStyle: HeaderStyle(
                formatButtonVisible: true,
                titleCentered: true,
                formatButtonShowsNext: false,
                formatButtonDecoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12.0),
                ),
                formatButtonTextStyle: const TextStyle(color: Colors.white, fontSize: 12.0),
                leftChevronIcon: const Icon(Icons.chevron_left, color: Colors.white),
                rightChevronIcon: const Icon(Icons.chevron_right, color: Colors.white),
                titleTextStyle: GoogleFonts.merriweather(
                  color: Colors.white,
                  fontSize: 18.0,
                  fontWeight: FontWeight.w600,
                ),
              ),
              
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
              
              selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
              onDaySelected: _onDaySelected,
              onFormatChanged: _onFormatChanged,
              onPageChanged: _onPageChanged,
              
              calendarBuilders: CalendarBuilders(
                markerBuilder: (context, day, events) {
                  if (events.isNotEmpty) {
                    return Positioned(
                      right: 1,
                      bottom: 1,
                      child: Container(
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
                      ),
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

  Widget _buildQuoteCard(DailyQuote dailyQuote) {
    return Container(
      margin: const EdgeInsets.only(left: 16, right: 16, bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.white.withOpacity(0.08),
            Colors.white.withOpacity(0.04),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: InkWell(
        onTap: () => _showQuoteDetails(dailyQuote),
        borderRadius: BorderRadius.circular(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Цитата дня',
              style: GoogleFonts.merriweather(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '"${dailyQuote.quote.text}"',
              style: TextStyle(
                color: Colors.white.withOpacity(0.8),
                fontSize: 14,
                fontStyle: FontStyle.italic,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '— ${dailyQuote.quote.author}',
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

  // Дополнительный метод для получения иконки достоверности (как в calendar_page_2)
  
  void _showTraditionFilter() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFF1A1A2E),
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              child: Text(
                'Выберите традицию',
                style: GoogleFonts.merriweather(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
            ListTile(
              title: const Text('Все традиции', style: TextStyle(color: Colors.white)),
              leading: Radio<String?>(
                value: null,
                groupValue: _selectedTradition,
                onChanged: (value) {
                  _onTraditionChanged(value);
                  Navigator.pop(context);
                },
                activeColor: Colors.white,
              ),
            ),
            ...PaganHolidayService.getAllTraditions().map((tradition) =>
              ListTile(
                title: Text(
                  _getTraditionDisplayName(tradition),
                  style: const TextStyle(color: Colors.white),
                ),
                leading: Radio<String>(
                  value: tradition,
                  groupValue: _selectedTradition,
                  onChanged: (value) {
                    _onTraditionChanged(value);
                    Navigator.pop(context);
                  },
                  activeColor: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  void _showAuthenticityFilter() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFF1A1A2E),
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              child: Text(
                'Выберите достоверность',
                style: GoogleFonts.merriweather(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
            ListTile(
              title: const Text('Любая достоверность', style: TextStyle(color: Colors.white)),
              leading: Radio<HistoricalAuthenticity?>(
                value: null,
                groupValue: _selectedAuthenticity,
                onChanged: (value) {
                  _onAuthenticityChanged(value);
                  Navigator.pop(context);
                },
                activeColor: Colors.white,
              ),
            ),
            ...HistoricalAuthenticity.values.map((authenticity) =>
              ListTile(
                title: Row(
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
                    Text(
                      _getAuthenticityDisplayName(authenticity),
                      style: const TextStyle(color: Colors.white),
                    ),
                  ],
                ),
                leading: Radio<HistoricalAuthenticity>(
                  value: authenticity,
                  groupValue: _selectedAuthenticity,
                  onChanged: (value) {
                    _onAuthenticityChanged(value);
                    Navigator.pop(context);
                  },
                  activeColor: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
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

  void _showQuoteDetails(DailyQuote dailyQuote) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => CalendarQuoteModal(dailyQuote: dailyQuote),
    );
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _backgroundController.dispose();
    _scrollController.dispose();
    super.dispose();
  }
}