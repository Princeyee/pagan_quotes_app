import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:convert';
import 'dart:ui' as ui;

import '../../models/daily_quote.dart';
import '../../models/pagan_holiday.dart';
import '../../services/image_picker_service.dart';
import '../../services/calendar_quote_service.dart';
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
  final CalendarQuoteService _calendarQuoteService = CalendarQuoteService();
  final ScrollController _scrollController = ScrollController();

  late AnimationController _fadeController;
  late AnimationController _backgroundController;
  late Animation<double> _fadeAnimation;

  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

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

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _loadData();
    _selectedDay = DateTime.now();
  }

  void _initializeAnimations() {
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
      value: 1.0, // Начинаем с полностью видимого AppBar
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
  }

  void _findNextHoliday() {
    final now = DateTime.now();
    final filteredHolidays = _getFilteredHolidays();
    
    PaganHoliday? closest;
    int minDays = 366;
    
    for (final holiday in filteredHolidays) {
      final thisYear = DateTime(now.year, holiday.date.month, holiday.date.day);
      final nextYear = DateTime(now.year + 1, holiday.date.month, holiday.date.day);
      
      int daysUntilThisYear = thisYear.difference(now).inDays;
      int daysUntilNextYear = nextYear.difference(now).inDays;
      
      if (daysUntilThisYear >= 0 && daysUntilThisYear < minDays) {
        minDays = daysUntilThisYear;
        closest = holiday;
      } else if (daysUntilNextYear < minDays) {
        minDays = daysUntilNextYear;
        closest = holiday;
      }
    }
    
    setState(() {
      _nextHoliday = closest;
      _daysUntilHoliday = minDays;
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
  void _onDaySelected(DateTime selectedDay, DateTime focusedDay) async {
    if (!isSameDay(_selectedDay, selectedDay)) {
      setState(() {
        _selectedDay = selectedDay;
        _focusedDay = focusedDay;
      });
      
      // Генерируем цитату для выбранной даты, если её нет
      final dateKey = DateTime(selectedDay.year, selectedDay.month, selectedDay.day);
      if (!_cachedQuotes.containsKey(dateKey)) {
        final quote = await _calendarQuoteService.generateQuoteForDate(dateKey);
        if (quote != null) {
          setState(() {
            _cachedQuotes[dateKey] = quote;
            _prepareEvents();
          });
        }
      }
    }
  }
  

  
  // Удаляем метод _buildFullCalendarModal, так как он больше не нужен
  
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
  
  // Метод для получения цвета традиции
  Color _getTraditionColor(String tradition) {
    // Ищем первый праздник с этой традицией
    final holiday = _holidays.firstWhere(
      (h) => h.tradition.toLowerCase() == tradition.toLowerCase(),
      orElse: () => _holidays.first, // Если не найдено, берем первый праздник
    );
    
    // Возвращаем цвет традиции
    return Color(int.parse(holiday.traditionColor.replaceFirst('#', '0xFF')));
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



  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight),
        child: AnimatedBuilder(
          animation: _fadeController,
          builder: (context, child) {
            return Transform.translate(
              offset: Offset(0, -kToolbarHeight * (1 - _fadeController.value)),
              child: child,
            );
          },
          child: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            flexibleSpace: ClipRect(
              child: BackdropFilter(
                filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withAlpha((0.8 * 255).round()),
                        Colors.black.withAlpha((0.5 * 255).round()),
                        Colors.black.withAlpha((0.2 * 255).round()),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
              onPressed: () => Navigator.of(context).pop(),
            ),
            title: Text(
              'Календарь',
              style: GoogleFonts.merriweather(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ),
      body: _buildBackgroundWithBlur(),
      floatingActionButton: Container(
        margin: const EdgeInsets.only(bottom: 16),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(30),
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withAlpha((0.1 * 255).round()),
                borderRadius: BorderRadius.circular(30),
                border: Border.all(
                  color: Colors.white.withAlpha((0.2 * 255).round()),
                  width: 0.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha((0.3 * 255).round()),
                    blurRadius: 10,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(30),
                  onTap: () {
                    showModalBottomSheet(
                      context: context,
                      backgroundColor: Colors.transparent,
                      builder: (context) => _buildFilterSheet(),
                    );
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.filter_list,
                          color: Colors.white.withAlpha((0.9 * 255).round()),
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Фильтры',
                          style: TextStyle(
                            color: Colors.white.withAlpha((0.9 * 255).round()),
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(width: 4),
                        if (_selectedTradition != null || _selectedAuthenticity != null)
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.amber,
                            ),
                          ),
                      ],
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
                      color: Colors.black.withAlpha((0.6 * 255).round()),
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
            : NotificationListener<ScrollNotification>(
                onNotification: (notification) {
                  return false;
                },
                child: SingleChildScrollView(
                  controller: _scrollController,
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: Column(
                    children: [
                      // Колесо в верхней части экрана
                      _buildPaganWheel(),
                      // Отступ после колеса
                      const SizedBox(height: 80),
                      // Контент
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Column(
                          children: [
                            // Виджет цитаты дня
                            _buildDailyQuoteCard(),
                            const SizedBox(height: 20),
                            if (_nextHoliday != null) _buildNextHolidayCard(),
                            if (_showCalendar) ...[
                              const SizedBox(height: 20),
                              _buildCalendar(),
                              const SizedBox(height: 20),
                              _buildSelectedDayEvents(),
                              const SizedBox(height: 20),
                              _buildMonthHolidaysSection(),
                            ],
                            // Дополнительный отступ внизу для удобства прокрутки
                            const SizedBox(height: 100),
                          ],
                        ),
                      ),
                    ],
                  ),
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
    
    // Используем цвет традиции вместо цвета достоверности
    final traditionColor = Color(int.parse(_nextHoliday!.traditionColor.replaceFirst('#', '0xFF')));
    
    return GestureDetector(
      onTap: () {
        if (_nextHoliday != null) {
          showHolidayInfoModal(context, _nextHoliday!);
        }
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              traditionColor.withAlpha((0.2 * 255).round()),
              traditionColor.withAlpha((0.1 * 255).round()),
            ],
          ),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(
            color: traditionColor.withAlpha((0.3 * 255).round()),
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
                  color: traditionColor,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'Следующий праздник',
                  style: TextStyle(
                    color: Colors.white.withAlpha((0.8 * 255).round()),
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const Spacer(),
                Icon(
                  _getAuthenticityIcon(_nextHoliday!.authenticity),
                  color: traditionColor,
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
            Row(
              children: [
                Text(
                  _daysUntilHoliday == 0
                      ? 'Сегодня!'
                      : _daysUntilHoliday == 1
                          ? 'Завтра'
                          : 'Через $_daysUntilHoliday ${_getDaysWord(_daysUntilHoliday)}',
                  style: TextStyle(
                    color: traditionColor,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                Icon(
                  Icons.arrow_forward_ios,
                  color: Colors.white.withAlpha((0.5 * 255).round()),
                  size: 14,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
  
  // Новый виджет для цитаты дня
  Widget _buildDailyQuoteCard() {
    // Получаем цитату дня для текущей даты
    final today = DateTime.now();
    final dateKey = DateTime(today.year, today.month, today.day);
    final events = _getEventsForDay(dateKey);
    
    // Ищем цитату среди событий
    DailyQuote? dailyQuote;
    for (final event in events) {
      if (event is DailyQuote) {
        dailyQuote = event;
        break;
      }
    }
    
    if (dailyQuote == null) return const SizedBox.shrink();
    
    return GestureDetector(
      onTap: () => _showQuoteDetails(dailyQuote!),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Colors.white.withAlpha((0.08 * 255).round()),
              Colors.white.withAlpha((0.04 * 255).round()),
            ],
          ),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(
            color: Colors.white.withAlpha((0.2 * 255).round()),
            width: 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.format_quote,
                  color: Colors.white.withAlpha((0.7 * 255).round()),
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'Цитата дня',
                  style: TextStyle(
                    color: Colors.white.withAlpha((0.8 * 255).round()),
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const Spacer(),
                Icon(
                  Icons.more_horiz,
                  color: Colors.white.withAlpha((0.5 * 255).round()),
                  size: 16,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              // Показываем только часть цитаты
              '\"${_truncateQuote(dailyQuote.quote.text)}\"',
              style: GoogleFonts.merriweather(
                fontSize: 15,
                fontStyle: FontStyle.italic,
                color: Colors.white.withAlpha((0.9 * 255).round()),
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Text(
                  '— ${dailyQuote.quote.author}',
                  style: TextStyle(
                    color: Colors.white.withAlpha((0.7 * 255).round()),
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const Spacer(),
                Icon(
                  Icons.arrow_forward_ios,
                  color: Colors.white.withAlpha((0.5 * 255).round()),
                  size: 14,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
  
  // Вспомогательный метод для сокращения цитаты
  String _truncateQuote(String text) {
    if (text.length <= 100) return text;
    return '${text.substring(0, 100)}...';
  }

  Widget _buildPaganWheel() {
    return Container(
      width: double.infinity,
      child: Column(
        children: [
          // Дополнительный отступ сверху, чтобы поднять колесо выше
          const SizedBox(height: 40),
          // Полукруг колеса
          Container(
            height: 580,
            width: double.infinity,
            child: Stack(
              children: [
                ClipRect(
                  child: Align(
                    alignment: Alignment.topCenter,
                    heightFactor: 0.9,
                    child: InteractivePaganWheel(
                      selectedTradition: _selectedTradition,
                      selectedAuthenticity: _selectedAuthenticity,
                      onMonthChanged: (month, holidays) {
                        setState(() {
                          _focusedDay = DateTime(_focusedDay.year, month);
                          _prepareEvents();
                          _showCalendar = true;
                        });
                      },
                    ),
                  ),
                ),
                // Кнопка показать календарь
                if (!_showCalendar)
                  Positioned(
                    right: 16,
                    top: 16,
                    child: TextButton(
                      onPressed: () {
                        setState(() {
                          _showCalendar = true;
                        });
                      },
                      child: Text(
                        'Показать календарь',
                        style: TextStyle(
                          color: Colors.white.withAlpha((0.8 * 255).round()),
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCalendar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withAlpha((0.3 * 255).round()),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withAlpha((0.1 * 255).round()),
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: TableCalendar<dynamic>(
              firstDay: DateTime.utc(2020, 1, 1),
              lastDay: DateTime.utc(2030, 12, 31),
              focusedDay: _focusedDay,
              calendarFormat: CalendarFormat.month, // Всегда показываем весь месяц
              eventLoader: _getEventsForDay,
              startingDayOfWeek: StartingDayOfWeek.monday,
              
              calendarStyle: CalendarStyle(
                outsideDaysVisible: false,
                weekendTextStyle: TextStyle(color: Colors.red.withAlpha((0.8 * 255).round())),
                holidayTextStyle: TextStyle(color: Colors.red.withAlpha((0.8 * 255).round())),
                defaultTextStyle: const TextStyle(color: Colors.white),
                todayTextStyle: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
                selectedTextStyle: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
                todayDecoration: BoxDecoration(
                  color: Colors.white.withAlpha((0.8 * 255).round()),
                  shape: BoxShape.circle,
                ),
                selectedDecoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                markerDecoration: BoxDecoration(
                  color: Colors.amber.withAlpha((0.8 * 255).round()),
                  shape: BoxShape.circle,
                ),
                markersMaxCount: 3,
                canMarkersOverflow: true,
                cellMargin: const EdgeInsets.all(4), // Добавляем отступы между ячейками
                cellPadding: EdgeInsets.zero, // Убираем внутренние отступы ячеек
              ),
              
              headerStyle: HeaderStyle(
                formatButtonVisible: false, // Убираем кнопку переключения формата
                titleCentered: true,
                leftChevronIcon: const Icon(Icons.chevron_left, color: Colors.white),
                rightChevronIcon: const Icon(Icons.chevron_right, color: Colors.white),
                titleTextStyle: GoogleFonts.merriweather(
                  color: Colors.white,
                  fontSize: 18.0,
                  fontWeight: FontWeight.w600,
                ),
                headerPadding: const EdgeInsets.symmetric(vertical: 8.0), // Уменьшаем отступы заголовка
              ),
              
              daysOfWeekStyle: DaysOfWeekStyle(
                weekdayStyle: TextStyle(
                  color: Colors.white.withAlpha((0.7 * 255).round()),
                  fontWeight: FontWeight.w500,
                ),
                weekendStyle: TextStyle(
                  color: Colors.red.withAlpha((0.7 * 255).round()),
                  fontWeight: FontWeight.w500,
                ),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: Colors.white.withAlpha((0.1 * 255).round()),
                      width: 1,
                    ),
                  ),
                ),
              ),
              
              selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
              onDaySelected: _onDaySelected,
              onPageChanged: _onPageChanged,
              
              calendarBuilders: CalendarBuilders(
                markerBuilder: (context, day, events) {
                  if (events.isEmpty) return null;
                  
                  // Показываем маркеры ТОЛЬКО для праздников, НЕ для цитат
                  final holidays = events.whereType<PaganHoliday>().toList();
                  if (holidays.isEmpty) return null;
                  
                  return Positioned(
                    bottom: 1,
                    left: 0,
                    right: 0,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: holidays.take(3).map((holiday) {
                        // Получаем цвет традиции
                        final traditionColor = Color(
                          int.parse(holiday.traditionColor.replaceFirst('#', '0xFF'))
                        );
                        
                        return Container(
                          margin: const EdgeInsets.symmetric(horizontal: 1),
                          width: 6.0,
                          height: 6.0,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: traditionColor,
                            boxShadow: [
                              BoxShadow(
                                color: traditionColor.withAlpha((0.6 * 255).round()),
                                blurRadius: 4,
                                spreadRadius: 0.5,
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
      ),
    );
  }


  Widget _buildSelectedDayEvents() {
    final events = _getEventsForDay(_selectedDay ?? DateTime.now());
    
    // Разделяем события на праздники и цитаты
    final holidays = events.whereType<PaganHoliday>().toList();
    final quotes = events.whereType<DailyQuote>().toList();
    
    // Если нет ни праздников, ни цитат
    if (holidays.isEmpty && quotes.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.black.withAlpha((0.3 * 255).round()),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(
            color: Colors.white.withAlpha((0.1 * 255).round()),
            width: 1,
          ),
        ),
        child: Column(
          children: [
            Icon(
              Icons.event_busy,
              color: Colors.white.withAlpha((0.5 * 255).round()),
              size: 48,
            ),
            const SizedBox(height: 12),
            Text(
              'Нет событий',
              style: GoogleFonts.merriweather(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.white.withAlpha((0.7 * 255).round()),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _selectedDay != null
                  ? 'На ${_formatDate(_selectedDay!)} нет событий'
                  : 'Выберите дату для просмотра событий',
              style: TextStyle(
                color: Colors.white.withAlpha((0.5 * 255).round()),
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        // Цитата дня для выбранной даты
        if (quotes.isNotEmpty) ...[
          _buildQuoteCard(quotes.first),
          const SizedBox(height: 16),
        ],
        
        // Праздники
        if (holidays.isNotEmpty)
          Container(
            decoration: BoxDecoration(
              color: Colors.black.withAlpha((0.3 * 255).round()),
              borderRadius: BorderRadius.circular(15),
              border: Border.all(
                color: Colors.white.withAlpha((0.1 * 255).round()),
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
                        color: Colors.white.withAlpha((0.8 * 255).round()),
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
                ...holidays.map((holiday) => _buildHolidayCard(holiday)).toList(),
              ],
            ),
          ),
      ],
    );
  }
  
  Widget _buildQuoteCard(DailyQuote dailyQuote) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.white.withAlpha((0.08 * 255).round()),
            Colors.white.withAlpha((0.04 * 255).round()),
          ],
        ),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: Colors.white.withAlpha((0.2 * 255).round()),
          width: 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _showQuoteDetails(dailyQuote),
          borderRadius: BorderRadius.circular(15),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.format_quote,
                    color: Colors.white.withAlpha((0.7 * 255).round()),
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Цитата дня',
                    style: TextStyle(
                      color: Colors.white.withAlpha((0.8 * 255).round()),
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const Spacer(),
                  Icon(
                    Icons.arrow_forward_ios,
                    color: Colors.white.withAlpha((0.5 * 255).round()),
                    size: 14,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                '"${dailyQuote.quote.text}"',
                style: GoogleFonts.merriweather(
                  fontSize: 15,
                  fontStyle: FontStyle.italic,
                  color: Colors.white.withAlpha((0.9 * 255).round()),
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              Text(
                '— ${dailyQuote.quote.author}',
                style: TextStyle(
                  color: Colors.white.withAlpha((0.7 * 255).round()),
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  // Новый метод для отображения всех праздников месяца
  Widget _buildMonthHolidaysSection() {
    // Получаем все праздники для текущего месяца (используем _focusedDay вместо _selectedDay)
    final currentMonth = _focusedDay.month;
    final currentYear = _focusedDay.year;
    
    // Фильтруем праздники по выбранным фильтрам
    final monthHolidays = _getFilteredHolidays().where((holiday) {
      final holidayDate = DateTime(currentYear, holiday.date.month, holiday.date.day);
      return holidayDate.month == currentMonth;
    }).toList();
    
    // Сортируем по дате
    monthHolidays.sort((a, b) => a.date.day.compareTo(b.date.day));
    
    if (monthHolidays.isEmpty) {
      return const SizedBox.shrink();
    }
    
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha((0.03 * 255).round()),
        border: Border(
          top: BorderSide(
            color: Colors.white.withAlpha((0.1 * 255).round()),
            width: 0.5,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 12, left: 16, right: 16),
            child: Row(
              children: [
                Icon(
                  Icons.calendar_month,
                  color: Colors.white.withAlpha((0.7 * 255).round()),
                  size: 18,
                ),
                const SizedBox(width: 8),
                Text(
                  'Все праздники месяца',
                  style: GoogleFonts.merriweather(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.white.withAlpha((0.9 * 255).round()),
                  ),
                ),
              ],
            ),
          ),
          ...monthHolidays.map((holiday) {
            final traditionColor = Color(int.parse(holiday.traditionColor.replaceFirst('#', '0xFF')));
            return Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => _showHolidayDetails(holiday),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: Colors.white.withAlpha((0.05 * 255).round()),
                        width: 0.5,
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: traditionColor.withAlpha((0.1 * 255).round()),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: traditionColor.withAlpha((0.3 * 255).round()),
                            width: 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: traditionColor.withAlpha((0.2 * 255).round()),
                              blurRadius: 4,
                              spreadRadius: 0,
                            ),
                          ],
                        ),
                        child: Text(
                          '${holiday.date.day}',
                          style: TextStyle(
                            color: traditionColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              holiday.name,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _getTraditionDisplayName(holiday.tradition),
                              style: TextStyle(
                                color: Colors.white.withAlpha((0.6 * 255).round()),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        Icons.arrow_forward_ios,
                        color: Colors.white.withAlpha((0.3 * 255).round()),
                        size: 14,
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildHolidayCard(PaganHoliday holiday) {
    // Используем цвет традиции вместо цвета достоверности
    final traditionColor = Color(int.parse(holiday.traditionColor.replaceFirst('#', '0xFF')));
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            traditionColor.withAlpha((0.15 * 255).round()),
            traditionColor.withAlpha((0.05 * 255).round()),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: traditionColor.withAlpha((0.3 * 255).round()),
          width: 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
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
                      color: traditionColor.withAlpha((0.2 * 255).round()),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _getAuthenticityDisplayName(holiday.authenticity),
                      style: TextStyle(
                        color: traditionColor,
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
                  color: Colors.white.withAlpha((0.8 * 255).round()),
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _getTraditionDisplayName(holiday.tradition),
                style: TextStyle(
                  color: traditionColor.withAlpha((0.7 * 255).round()),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }



  // Дополнительный метод для получения иконки достоверности (как в calendar_page_2)
  
  Widget _buildFilterSheet() {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: StatefulBuilder(
          builder: (context, setState) {
            return Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withAlpha((0.9 * 255).round()),
                    Colors.black.withAlpha((0.95 * 255).round()),
                  ],
                ),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                border: Border.all(
                  color: Colors.white.withAlpha((0.1 * 255).round()),
                  width: 0.5,
                ),
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Индикатор свайпа
                    Container(
                      margin: const EdgeInsets.only(top: 12, bottom: 16),
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.white.withAlpha((0.3 * 255).round()),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    
                    // Заголовок
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Row(
                        children: [
                          Text(
                            'Фильтры',
                            style: GoogleFonts.merriweather(
                              fontSize: 22,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                          const Spacer(),
                          if (_selectedTradition != null || _selectedAuthenticity != null)
                            TextButton(
                              onPressed: () {
                                _clearFilters();
                                Navigator.pop(context);
                              },
                              child: Text(
                                'Сбросить',
                                style: TextStyle(
                                  color: Colors.amber.withAlpha((0.8 * 255).round()),
                                  fontSize: 14,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 24),
                    
                    // Секция традиций
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Традиция',
                            style: TextStyle(
                              color: Colors.white.withAlpha((0.7 * 255).round()),
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Wrap(
                            spacing: 8,
                            runSpacing: 12,
                            children: [
                              _buildTraditionChip(null, 'Все'),
                              ...PaganHolidayService.getAllTraditions().map((tradition) {
                                final displayName = _getTraditionDisplayName(tradition).split(' ')[0];
                                // Получаем цвет традиции из первого праздника этой традиции
                                final traditionColor = _getTraditionColor(tradition);
                                return GestureDetector(
                                  onTap: () {
                                    _onTraditionChanged(tradition);
                                    Navigator.pop(context);
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: _selectedTradition == tradition 
                                          ? traditionColor.withAlpha((0.2 * 255).round())
                                          : Colors.white.withAlpha((0.05 * 255).round()),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                        color: _selectedTradition == tradition 
                                            ? traditionColor.withAlpha((0.5 * 255).round())
                                            : Colors.white.withAlpha((0.1 * 255).round()),
                                        width: 1,
                                      ),
                                    ),
                                    child: Text(
                                      displayName,
                                      style: TextStyle(
                                        color: _selectedTradition == tradition 
                                            ? traditionColor
                                            : Colors.white,
                                        fontSize: 14,
                                        fontWeight: _selectedTradition == tradition ? FontWeight.w600 : FontWeight.normal,
                                      ),
                                    ),
                                  ),
                                );
                              }),
                            ],
                          ),
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 32),
                    
                    // Секция достоверности
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Достоверность',
                            style: TextStyle(
                              color: Colors.white.withAlpha((0.7 * 255).round()),
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Wrap(
                            spacing: 8,
                            runSpacing: 12,
                            children: [
                              _buildAuthenticityChip(null, 'Любая'),
                              ...HistoricalAuthenticity.values.map((authenticity) =>
                                _buildAuthenticityChip(authenticity, _getAuthenticityDisplayName(authenticity)),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            );
          }
        ),
      ),
    );
  }
  
  Widget _buildTraditionChip(String? tradition, String label) {
    final isSelected = _selectedTradition == tradition;
    
    return GestureDetector(
      onTap: () {
        _onTraditionChanged(tradition);
        Navigator.pop(context);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.amber.withAlpha((0.2 * 255).round()) : Colors.white.withAlpha((0.05 * 255).round()),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? Colors.amber.withAlpha((0.5 * 255).round()) : Colors.white.withAlpha((0.1 * 255).round()),
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.amber : Colors.white,
            fontSize: 14,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }
  
  Widget _buildAuthenticityChip(HistoricalAuthenticity? authenticity, String label) {
    final isSelected = _selectedAuthenticity == authenticity;
    final color = authenticity != null ? _getAuthenticityColor(authenticity) : Colors.white;
    
    return GestureDetector(
      onTap: () {
        _onAuthenticityChanged(authenticity);
        Navigator.pop(context);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? color.withAlpha((0.2 * 255).round()) : Colors.white.withAlpha((0.05 * 255).round()),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? color.withAlpha((0.5 * 255).round()) : Colors.white.withAlpha((0.1 * 255).round()),
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? color : Colors.white,
            fontSize: 14,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          ),
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
    showCalendarQuoteModal(context, dailyQuote);
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _backgroundController.dispose();
    _scrollController.dispose();
    super.dispose();
  }
}