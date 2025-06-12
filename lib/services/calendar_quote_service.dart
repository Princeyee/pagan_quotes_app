
// lib/services/calendar_quote_service.dart
import 'dart:math';
import '../models/daily_quote.dart';
import '../models/quote.dart';
import '../utils/custom_cache.dart';
import 'quote_extraction_service.dart';
import 'theme_service.dart';

class CalendarQuoteService {
  static final CalendarQuoteService _instance = CalendarQuoteService._internal();
  factory CalendarQuoteService() => _instance;
  CalendarQuoteService._internal();

  final QuoteExtractionService _quoteService = QuoteExtractionService();
  final CustomCachePrefs _cache = CustomCache.prefs;

  /// Генерирует цитату для любой даты (включая прошлые)
  Future<DailyQuote?> generateQuoteForDate(DateTime date) async {
    try {
      // Сначала проверяем кэш
      final cachedQuote = _cache.getCachedDailyQuote(date);
      if (cachedQuote != null) {
        return cachedQuote;
      }

      // Если это сегодняшняя дата, используем обычный метод
      final today = DateTime.now();
      if (_isSameDate(date, today)) {
        return await _quoteService.generateDailyQuote(date: date);
      }

      // Для прошлых/будущих дат генерируем детерминированно
      final quote = await _generateDeterministicQuote(date);
      if (quote != null) {
        final dailyQuote = DailyQuote(
          quote: quote,
          date: date,
          isViewed: false,
          isContextViewed: false,
        );
        
        // Кэшируем для будущего использования
        await _cache.cacheDailyQuote(dailyQuote);
        return dailyQuote;
      }

      return null;
    } catch (e) {
      print('Error generating quote for date $date: $e');
      return null;
    }
  }

  /// Генерирует детерминированную цитату для указанной даты
  Future<Quote?> _generateDeterministicQuote(DateTime date) async {
    try {
      // Загружаем отобранные цитаты - ИСПОЛЬЗУЕМ ПУБЛИЧНЫЙ МЕТОД
      final curated = await _quoteService.loadCuratedQuotes();
      
      if (curated.isEmpty) {
        print('No curated quotes available');
        return null;
      }

      // ПОЛУЧАЕМ АКТИВНЫЕ ТЕМЫ
      final enabledThemes = await ThemeService.getEnabledThemes();
      print('🎯 Активные темы: $enabledThemes');
      
      // ФИЛЬТРУЕМ КАТЕГОРИИ ПО АКТИВНЫМ ТЕМАМ
      final allCategories = curated.keys.toList();
      final enabledCategories = allCategories.where((category) => 
        enabledThemes.contains(category)
      ).toList();
      
      if (enabledCategories.isEmpty) {
        print('❌ Нет активных категорий, используем все');
        // Fallback - используем все категории если нет активных
        final categories = allCategories;
        final daysSinceEpoch = date.difference(DateTime(1970)).inDays;
        final categoryIndex = daysSinceEpoch % categories.length;
        final selectedCategory = categories[categoryIndex];
        final categoryQuotes = curated[selectedCategory]!;
        final random = Random(daysSinceEpoch + selectedCategory.hashCode);
        final selectedQuote = categoryQuotes[random.nextInt(categoryQuotes.length)];
        return selectedQuote.toQuote();
      }
      
      print('✅ Доступные категории: $enabledCategories');
      
      // Используем дату как сид для воспроизводимости
      final daysSinceEpoch = date.difference(DateTime(1970)).inDays;
      
      // Выбираем категорию детерминированно ИЗ АКТИВНЫХ
      final categoryIndex = daysSinceEpoch % enabledCategories.length;
      final selectedCategory = enabledCategories[categoryIndex];
      
      print('🎲 Выбрана категория: $selectedCategory для даты ${date.day}.${date.month}.${date.year}');
      
      // Получаем цитаты для выбранной категории
      final categoryQuotes = curated[selectedCategory]!;
      
      // Выбираем цитату детерминированно
      final random = Random(daysSinceEpoch + selectedCategory.hashCode);
      final selectedQuote = categoryQuotes[random.nextInt(categoryQuotes.length)];
      
      return selectedQuote.toQuote();
      
    } catch (e) {
      print('Error generating deterministic quote: $e');
      return null;
    }
  }

  /// Генерирует цитаты для диапазона дат (для предзагрузки календаря)
  Future<Map<DateTime, DailyQuote>> generateQuotesForRange(
    DateTime startDate, 
    DateTime endDate
  ) async {
    final quotes = <DateTime, DailyQuote>{};
    
    DateTime currentDate = startDate;
    while (currentDate.isBefore(endDate) || _isSameDate(currentDate, endDate)) {
      final quote = await generateQuoteForDate(currentDate);
      if (quote != null) {
        quotes[currentDate] = quote;
      }
      
      currentDate = currentDate.add(const Duration(days: 1));
    }
    
    return quotes;
  }

  /// Предзагружает цитаты для текущего месяца
  Future<void> preloadCurrentMonth() async {
    final now = DateTime.now();
    final startOfMonth = DateTime(now.year, now.month, 1);
    final endOfMonth = DateTime(now.year, now.month + 1, 0);
    
    await generateQuotesForRange(startOfMonth, endOfMonth);
  }

  /// Очищает старые кэшированные цитаты (старше 3 месяцев)
  Future<void> cleanupOldQuotes() async {
    try {
      await _cache.clearOldDailyQuotes(90); // Оставляем 3 месяца
    } catch (e) {
      print('Error cleaning up old quotes: $e');
    }
  }

  /// Проверяет, совпадают ли две даты (игнорируя время)
  bool _isSameDate(DateTime date1, DateTime date2) {
    return date1.year == date2.year &&
           date1.month == date2.month &&
           date1.day == date2.day;
  }

  /// Получает статистику цитат в календаре
  Future<Map<String, int>> getCalendarStats() async {
    final stats = _cache.getCacheStats();
    
    return {
      'totalCachedQuotes': stats['dailyQuotes'] ?? 0,
      'cacheSize': _cache.getCacheSize(),
      'viewedQuotes': (stats['viewedQuotes'] ?? 0),
    };
  }
}