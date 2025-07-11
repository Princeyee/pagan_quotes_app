// lib/ui/screens/calendar_page.dart - ИСПРАВЛЕННАЯ ВЕРСИЯ
/*import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:convert';
import 'dart:ui' as ui;
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
  String? _backgroundImageUrl; // ИСПРАВЛЕНО: добавлено объявление переменной

  // Данные для ближайшего праздника (без живого таймера)
  PaganHoliday? _nextHoliday;
  int? _daysUntilHoliday;
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
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    _backgroundController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    );

    _backgroundAnimation = CurvedAnimation(
      parent: _backgroundController,
      curve: Curves.easeOut,
    );
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

      final daysUntil = targetDate.difference(now).inDays;

      setState(() {
        _nextHoliday = nextHoliday;
        _daysUntilHoliday = daysUntil;
        _nextHolidayDate = targetDate;
      });
    }
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    try {
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

      // Быстрые анимации
      _fadeController.forward();
      _backgroundController.forward();

    } catch (e) {
      print('Error loading calendar data: $e');
      setState(() => _isLoading = false);
    }
  }



  Future<void> _loadBackgroundImage() async {
    try {
      final today = DateTime.now();
      final dateString = '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

      String? cachedImageUrl = _cache.getSetting<String>('daily_image_$dateString'); // ИСПРАВЛЕНО: cage -> _cache
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
        backgroundColor: Colors.black.withAlpha((0.3 * 255).round()),
        elevation: 0,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withAlpha((0.7 * 255).round()),
                Colors.black.withAlpha((0.3 * 255).round()),
                Colors.transparent,
              ],
            ),
          ),
        ),
        title: Text(
          'Календарь',
          style: GoogleFonts.merriweather(
            color: Colors.white,
            fontWeight: FontWeight.w300,
          ),
        ),
        actions: [
          // Фильтр по традициям
          Container(
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              color: Colors.black.withAlpha((0.3 * 255).round()),
              borderRadius: BorderRadius.circular(20),
            ),
            child: PopupMenuButton<String>(
              icon: Icon(
                Icons.filter_list, 
                color: _selectedTradition != null ? Colors.orange : Colors.white.withAlpha((0.9 * 255).round())
              ),
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
          
          // НОВЫЙ ФИЛЬТР ПО ДОСТОВЕРНОСТИ
          Container(
            margin: const EdgeInsets.only(right: 16),
            decoration: BoxDecoration(
              color: Colors.black.withAlpha((0.3 * 255).round()),
              borderRadius: BorderRadius.circular(20),
            ),
            child: PopupMenuButton<HistoricalAuthenticity?>(
              icon: Icon(
                Icons.verified_user, 
                color: _selectedAuthenticity != null ? Colors.green : Colors.white.withAlpha((0.9 * 255).round())
              ),
              color: Colors.grey[900],
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              onSelected: (value) {
                setState(() {
                  _selectedAuthenticity = value;
                  _prepareEvents();
                });
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: null,
                  child: Text('Все уровни', style: TextStyle(color: Colors.white)),
                ),
                ...HistoricalAuthenticity.values.map(
                  (auth) => PopupMenuItem(
                    value: auth,
                    child: Row(
                      children: [
                        Icon(
                          _getAuthenticityIcon(auth),
                          size: 16,
                          color: _getAuthenticityColor(auth),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _getAuthenticityDisplayName(auth),
                          style: const TextStyle(color: Colors.white),
                        ),
                      ],
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
                _buildBackgroundWithBlur(),

                // Основной контент - ДОБАВЛЯЕМ СКРОЛЛ
                _buildScrollableContent(),
              ],
            ),
    );
  }

  // УПРОЩЕННЫЕ МЕТОДЫ ДЛЯ РАБОТЫ С ДОСТОВЕРНОСТЬЮ
  IconData _getAuthenticityIcon(HistoricalAuthenticity authenticity) {
    // ВСЕ ИКОНКИ ОДИНАКОВЫЕ
    return Icons.info_outline;
  }

  Color _getAuthenticityColor(HistoricalAuthenticity authenticity) {
    // ВСЕ ЦВЕТА СЕРЫЕ
    return Colors.grey;
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
        return 'Новые';
    }
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
                  colors: [Colors.grey[900]!, Colors.black],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
            errorWidget: (_, __, ___) => Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.grey[900]!, Colors.black],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          )
        : Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.grey[900]!, Colors.black],
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

            // Более темный блюр для колеса
            BackdropFilter(
              filter: ui.ImageFilter.blur(sigmaX: 20.0, sigmaY: 20.0),
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.grey[900]!, Colors.black],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ),
              errorWidget: (_, __, ___) => Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.grey[900]!, Colors.black],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ),
            )
          : Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.grey[900]!, Colors.black],
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
              BackdropFilter(
                filter: ui.ImageFilter.blur(sigmaX: 20.0, sigmaY: 20.0),
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.black.withAlpha((0.8 * 255).round()),
                        Colors.black.withAlpha((0.9 * 255).round()),
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

          // ===== ИНТЕРАКТИВНОЕ ЯЗЫЧЕСКОЕ КОЛЕСО =====
          InteractivePaganWheel(
            onMonthChanged: (month, holidays) {
              setState(() {
                _focusedDay = DateTime(_focusedDay.year, month);
                _showCalendar = true; // Показываем календарь после первого взаимодействия
                _prepareEvents();
              });
            },
          ),

          // Календарь появляется только после взаимодействия с колесом
          if (_showCalendar) ...[
            const SizedBox(height: 20),

            // Анимированное появление календаря
            TweenAnimationBuilder<double>(
              duration: const Duration(milliseconds: 800),
              tween: Tween(begin: 0.0, end: 1.0),
              curve: Curves.easeOutBack,
              builder: (context, value, child) {
                return Transform.scale(
                  scale: 0.8 + (0.2 * value),
                  child: Opacity(
                    opacity: value,
                    child: _buildEnhancedCalendar(),
                  ),
                );
              },
            ),

            // Ближайший праздник
            _buildSimpleHolidayCountdown(),

            // Информация о выбранном дне
            if (_selectedDay != null) _buildSelectedDayInfo(),
          ],

          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, IconData icon, Color color, VoidCallback onRemove) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withAlpha((0.15 * 255).round()),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withAlpha((0.3 * 255).round())),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: 6),
          GestureDetector(
            onTap: onRemove,
            child: Icon(
              Icons.close,
              size: 14,
              color: color.withAlpha((0.7 * 255).round()),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEnhancedCalendar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha((0.08 * 255).round()),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withAlpha((0.15 * 255).round()),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha((0.3 * 255).round()),
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
                  // Отключаем проблемные анимации
                  pageJumpingEnabled: false,
                  pageAnimationEnabled: false,
                  pageAnimationDuration: Duration.zero,
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
                      color: Colors.white.withAlpha((0.9 * 255).round()),
                      fontWeight: FontWeight.w400,
                    ),
                    weekendTextStyle: GoogleFonts.merriweather(
                      color: Colors.white.withAlpha((0.7 * 255).round()),
                      fontWeight: FontWeight.w300,
                    ),
                    outsideDaysVisible: false,

                    // Выбранный день
                    selectedDecoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.white.withAlpha((0.8 * 255).round()),
                          Colors.white.withAlpha((0.6 * 255).round()),
                        ],
                      ),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.white.withAlpha((0.3 * 255).round()),
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
                      color: Colors.white.withAlpha((0.2 * 255).round()),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white.withAlpha((0.5 * 255).round()),
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
                  selectedTextStyle: GoogleFonts.merriweather(
                    color: Colors.black,
                    fontWeight: FontWeight.bold,
                  ),
                  
                  todayDecoration: BoxDecoration(
                    color: Colors.white.withAlpha((0.2 * 255).round()),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white.withAlpha((0.5 * 255).round()),
                      width: 2,
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
                                    color: markerColor.withAlpha((0.5 * 255).round()),
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
                                  color: markerColor.withAlpha((0.5 * 255).round()),
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
    );
  }

  Widget _buildCalendarHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
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
            color: Colors.white.withAlpha((0.1 * 255).round()),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Colors.white.withAlpha((0.2 * 255).round()),
              width: 1,
            ),
          ),
          child: Icon(
            icon,
            color: Colors.white.withAlpha((0.8 * 255).round()),
            size: 20,
          ),
        ),
      ),
    );
  }

  Widget _buildSimpleHolidayCountdown() {
    if (_nextHoliday == null || _daysUntilHoliday == null || _nextHolidayDate == null) {
      return const SizedBox.shrink();
    }

    final traditionColor = Color(int.parse(_nextHoliday!.traditionColor.replaceFirst('#', '0xFF')));

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _showHolidayDetails(_nextHoliday!),
          borderRadius: BorderRadius.circular(16),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  traditionColor.withAlpha((0.2 * 255).round()),
                  traditionColor.withAlpha((0.1 * 255).round()),
                ],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: traditionColor.withAlpha((0.3 * 255).round()),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: traditionColor.withAlpha((0.2 * 255).round()),
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
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: traditionColor.withAlpha((0.2 * 255).round()),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.celebration,
                          color: traditionColor,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Ближайший праздник',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.white.withAlpha((0.7 * 255).round()),
                                fontWeight: FontWeight.w300,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    _nextHoliday!.name,
                                    style: GoogleFonts.merriweather(
                                      fontSize: 18,
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                // УБИРАЕМ ЯРКИЙ ИНДИКАТОР ДОСТОВЕРНОСТИ
                                Container(
                                  width: 4,
                                  height: 4,
                                  decoration: BoxDecoration(
                                    color: Colors.grey.withAlpha((0.5 * 255).round()),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${_daysUntilHoliday} ${_getDaysWord(_daysUntilHoliday!)} • ${_formatDate(_nextHolidayDate!)}',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.white.withAlpha((0.8 * 255).round()),
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        Icons.arrow_forward_ios,
                        color: traditionColor,
                        size: 16,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
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

  String _formatDate(DateTime date) {
    return '${date.day} ${_getMonthNameGenitive(date.month)}';
  }

  String _getMonthNameGenitive(int month) {
    const months = [
      'января', 'февраля', 'марта', 'апреля', 'мая', 'июня',
      'июля', 'августа', 'сентября', 'октября', 'ноября', 'декабря'
    ];
    return months[month - 1];
  }

  Widget _buildSelectedDayInfo() {
    final events = _getEventsForDay(_selectedDay!);
    if (events.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha((0.08 * 255).round()),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withAlpha((0.15 * 255).round()),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha((0.2 * 255).round()),
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
                      color: Colors.white.withAlpha((0.8 * 255).round()),
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
                  traditionColor.withAlpha((0.15 * 255).round()),
                  traditionColor.withAlpha((0.08 * 255).round()),
                ],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: traditionColor.withAlpha((0.3 * 255).round()),
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
                        color: traditionColor.withAlpha((0.5 * 255).round()),
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
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              holiday.name,
                              style: GoogleFonts.merriweather(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            width: 4,
                            height: 4,
                            decoration: BoxDecoration(
                              color: Colors.grey.withAlpha((0.5 * 255).round()),
                              shape: BoxShape.circle,
                            ),
                          ),
                        ],
                      ),
                      if (holiday.nameOriginal != holiday.name)
                        Text(
                          holiday.nameOriginal,
                          style: TextStyle(
                            fontSize: 12,
                            fontStyle: FontStyle.italic,
                            color: Colors.white.withAlpha((0.7 * 255).round()),
                          ),
                        ),
                      const SizedBox(height: 4),
                      Text(
                        '${_getTraditionDisplayName(holiday.tradition)} • ${holiday.description}',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.white.withAlpha((0.8 * 255).round()),
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
                  Colors.white.withAlpha((0.08 * 255).round()),
                  Colors.white.withAlpha((0.04 * 255).round()),
                ],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.white.withAlpha((0.2 * 255).round()),
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
                        color: Colors.white.withAlpha((0.3 * 255).round()),
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
                          color: Colors.white.withAlpha((0.8 * 255).round()),
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '— ${dailyQuote.quote.author}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white.withAlpha((0.6 * 255).round()),
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.format_quote,
                  color: Colors.white.withAlpha((0.7 * 255).round()),
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
        return 'Славянская традииция';
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
    _fadeController.dispose();
    _backgroundController.dispose();
    _scrollController.dispose();
    super.dispose();
  }
}*/