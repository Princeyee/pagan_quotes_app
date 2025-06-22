// lib/utils/custom_cache.dart
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import '../models/quote.dart';
import '../models/daily_quote.dart';
import '../models/quote_context.dart';
import '../models/book_source.dart';

class CustomCache extends CacheManager {
  static const key = 'customCacheKey';
  static CustomCache? _instance;

  factory CustomCache() {
    _instance ??= CustomCache._();
    return _instance!;
  }

  CustomCache._() : super(Config(
    key,
    stalePeriod: const Duration(days: 7),
    maxNrOfCacheObjects: 200,
  ));

  static CustomCache get instance => _instance ?? CustomCache();

  // SharedPreferences часть
  static final CustomCachePrefs prefs = CustomCachePrefs();
}

class CustomCachePrefs {
  static final CustomCachePrefs _instance = CustomCachePrefs._internal();
  factory CustomCachePrefs() => _instance;
  CustomCachePrefs._internal();

  SharedPreferences? _prefs;
  
  // Ключи для кэша
  static const String _dailyQuoteKey = 'daily_quote_';
  static const String _favoriteQuotesKey = 'favorite_quotes';
  static const String _quoteContextKey = 'quote_context_';
  static const String _viewedQuotesKey = 'viewed_quotes';
  static const String _bookSourcesKey = 'book_sources';
  static const String _settingsKey = 'app_settings';

  /// Инициализация SharedPreferences
  Future<void> init() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  SharedPreferences get prefs {
    if (_prefs == null) {
      throw Exception('CustomCachePrefs not initialized. Call init() first.');
    }
    return _prefs!;
  }

  // ============ ЕЖЕДНЕВНЫЕ ЦИТАТЫ ============

  /// Кэширует ежедневную цитату
  Future<void> cacheDailyQuote(DailyQuote dailyQuote) async {
    final key = _dailyQuoteKey + _dateToString(dailyQuote.date);
    final json = jsonEncode(dailyQuote.toJson());
    await prefs.setString(key, json);
  }

  /// Получает ежедневную цитату из кэша
  DailyQuote? getCachedDailyQuote(DateTime date) {
    final key = _dailyQuoteKey + _dateToString(date);
    final json = prefs.getString(key);
    
    if (json != null) {
      try {
        final data = jsonDecode(json) as Map<String, dynamic>;
        return DailyQuote.fromJson(data);
      } catch (e) {
        print('Error parsing cached daily quote: $e');
        return null;
      }
    }
    
    return null;
  }

  /// Получает сегодняшнюю цитату
  DailyQuote? getTodayQuote() {
    return getCachedDailyQuote(DateTime.now());
  }

  /// Отмечает ежедневную цитату как просмотренную
  Future<void> markDailyQuoteAsViewed(DateTime date, {bool contextViewed = false}) async {
    final cached = getCachedDailyQuote(date);
    if (cached != null) {
      final updated = cached.copyWith(
        isViewed: true,
        isContextViewed: contextViewed || cached.isContextViewed,
      );
      await cacheDailyQuote(updated);
    }
  }

  // ============ ИЗБРАННЫЕ ЦИТАТЫ ============

  /// Добавляет цитату в избранное
  Future<void> addToFavorites(Quote quote) async {
    final favorites = getFavoriteQuotes();
    if (!favorites.any((q) => q.id == quote.id)) {
      favorites.add(quote.copyWith(isFavorite: true));
      await _saveFavoriteQuotes(favorites);
    }
  }

  /// Убирает цитату из избранного
  Future<void> removeFromFavorites(String quoteId) async {
    final favorites = getFavoriteQuotes();
    favorites.removeWhere((q) => q.id == quoteId);
    await _saveFavoriteQuotes(favorites);
  }

  /// Получает список избранных цитат
  List<Quote> getFavoriteQuotes() {
    final json = prefs.getString(_favoriteQuotesKey);
    if (json != null) {
      try {
        final List<dynamic> data = jsonDecode(json);
        return data.map((item) => Quote.fromJson(item as Map<String, dynamic>)).toList();
      } catch (e) {
        print('Error parsing favorite quotes: $e');
        return [];
      }
    }
    return [];
  }

  /// Проверяет, является ли цитата избранной
  bool isFavorite(String quoteId) {
    final favorites = getFavoriteQuotes();
    return favorites.any((q) => q.id == quoteId);
  }

  /// Сохраняет список избранных цитат
  Future<void> _saveFavoriteQuotes(List<Quote> quotes) async {
    final json = jsonEncode(quotes.map((q) => q.toJson()).toList());
    await prefs.setString(_favoriteQuotesKey, json);
  }

  // ============ КОНТЕКСТ ЦИТАТ ============

  /// Кэширует контекст цитаты
  Future<void> cacheQuoteContext(QuoteContext context) async {
    final key = _quoteContextKey + context.quote.id;
    final json = jsonEncode(context.toJson());
    await prefs.setString(key, json);
  }

  /// Получает контекст цитаты из кэша
  QuoteContext? getCachedQuoteContext(String quoteId) {
    final key = _quoteContextKey + quoteId;
    final json = prefs.getString(key);
    
    if (json != null) {
      try {
        final data = jsonDecode(json) as Map<String, dynamic>;
        return QuoteContext.fromJson(data);
      } catch (e) {
        print('Error parsing cached quote context: $e');
        return null;
      }
    }
    
    return null;
  }

  // ============ ПРОСМОТРЕННЫЕ ЦИТАТЫ ============

  /// Отмечает цитату как просмотренную
  Future<void> markQuoteAsViewed(String quoteId) async {
    final viewed = getViewedQuotes();
    if (!viewed.contains(quoteId)) {
      viewed.add(quoteId);
      await _saveViewedQuotes(viewed);
    }
  }

  /// Получает список ID просмотренных цитат
  List<String> getViewedQuotes() {
    final json = prefs.getString(_viewedQuotesKey);
    if (json != null) {
      try {
        final List<dynamic> data = jsonDecode(json);
        return data.cast<String>();
      } catch (e) {
        print('Error parsing viewed quotes: $e');
        return [];
      }
    }
    return [];
  }

  /// Проверяет, была ли цитата просмотрена
  bool isQuoteViewed(String quoteId) {
    final viewed = getViewedQuotes();
    return viewed.contains(quoteId);
  }

  /// Сохраняет список просмотренных цитат
  Future<void> _saveViewedQuotes(List<String> quoteIds) async {
    final json = jsonEncode(quoteIds);
    await prefs.setString(_viewedQuotesKey, json);
  }

  // ============ ИСТОЧНИКИ КНИГ ============

  /// Кэширует список источников книг
  Future<void> cacheBookSources(List<BookSource> sources) async {
    final json = jsonEncode(sources.map((s) => s.toJson()).toList());
    await prefs.setString(_bookSourcesKey, json);
  }

  /// Получает список источников книг из кэша
  List<BookSource>? getCachedBookSources() {
    final json = prefs.getString(_bookSourcesKey);
    if (json != null) {
      try {
        final List<dynamic> data = jsonDecode(json);
        return data.map((item) => BookSource.fromJson(item as Map<String, dynamic>)).toList();
      } catch (e) {
        print('Error parsing cached book sources: $e');
        return null;
      }
    }
    return null;
  }

  // ============ НАСТРОЙКИ ПРИЛОЖЕНИЯ ============

  /// Сохраняет настройки приложения
  Future<void> saveSettings(Map<String, dynamic> settings) async {
    final json = jsonEncode(settings);
    await prefs.setString(_settingsKey, json);
  }

  /// Получает настройки приложения
  Map<String, dynamic> getSettings() {
    final json = prefs.getString(_settingsKey);
    if (json != null) {
      try {
        return jsonDecode(json) as Map<String, dynamic>;
      } catch (e) {
        print('Error parsing app settings: $e');
        return {};
      }
    }
    return {};
  }

  /// Получает конкретную настройку
  T? getSetting<T>(String key, [T? defaultValue]) {
    final settings = getSettings();
    return settings[key] as T? ?? defaultValue;
  }

  /// Сохраняет конкретную настройку
  Future<void> setSetting(String key, dynamic value) async {
    final settings = getSettings();
    settings[key] = value;
    await saveSettings(settings);
  }

  // ============ ОЧИСТКА КЭША ============

  /// Очищает весь кэш
  Future<void> clearAll() async {
    await prefs.clear();
  }

  /// Очищает кэш ежедневных цитат
  Future<void> clearDailyQuotes() async {
    final keys = prefs.getKeys().where((key) => key.startsWith(_dailyQuoteKey));
    for (final key in keys) {
      await prefs.remove(key);
    }
  }

  /// Очищает кэш контекстов цитат
  Future<void> clearQuoteContexts() async {
    final keys = prefs.getKeys().where((key) => key.startsWith(_quoteContextKey));
    for (final key in keys) {
      await prefs.remove(key);
    }
  }

  /// Очищает кэш контекста для конкретной цитаты
  Future<void> clearQuoteContext(String quoteId) async {
    final key = _quoteContextKey + quoteId;
    await prefs.remove(key);
  }

  /// Очищает все кэши контекстов при обновлении цитаты
  /// Это предотвращает проблемы с несоответствием контекста и цитаты
  Future<void> clearAllQuoteContexts() async {
    await clearQuoteContexts();
  }

  /// Очищает старые ежедневные цитаты (старше указанного количества дней)
  Future<void> clearOldDailyQuotes(int daysToKeep) async {
    final cutoffDate = DateTime.now().subtract(Duration(days: daysToKeep));
    final keys = prefs.getKeys().where((key) => key.startsWith(_dailyQuoteKey));
    
    for (final key in keys) {
      final dateStr = key.replaceFirst(_dailyQuoteKey, '');
      final date = _stringToDate(dateStr);
      if (date != null && date.isBefore(cutoffDate)) {
        await prefs.remove(key);
      }
    }
  }

  // ============ УТИЛИТЫ ============

  /// Конвертирует дату в строку для ключа
  String _dateToString(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  /// Конвертирует строку в дату
  DateTime? _stringToDate(String dateStr) {
    try {
      final parts = dateStr.split('-');
      if (parts.length == 3) {
        return DateTime(
          int.parse(parts[0]),
          int.parse(parts[1]),
          int.parse(parts[2]),
        );
      }
    } catch (e) {
      print('Error parsing date string: $dateStr');
    }
    return null;
  }

  /// Получает размер кэша (приблизительно в байтах)
  int getCacheSize() {
    int totalSize = 0;
    final keys = prefs.getKeys();
    
    for (final key in keys) {
      final value = prefs.get(key);
      if (value is String) {
        totalSize += value.length * 2; // примерно 2 байта на символ UTF-16
      }
    }
    
    return totalSize;
  }

  /// Получает статистику кэша
  Map<String, int> getCacheStats() {
    final keys = prefs.getKeys();
    int dailyQuotes = 0;
    int favoriteQuotes = 0;
    int quoteContexts = 0;
    int viewedQuotes = 0;
    int bookSources = 0;
    int settings = 0;
    int other = 0;

    for (final key in keys) {
      if (key.startsWith(_dailyQuoteKey)) {
        dailyQuotes++;
      } else if (key == _favoriteQuotesKey) {
        favoriteQuotes++;
      } else if (key.startsWith(_quoteContextKey)) {
        quoteContexts++;
      } else if (key == _viewedQuotesKey) {
        viewedQuotes++;
      } else if (key == _bookSourcesKey) {
        bookSources++;
      } else if (key == _settingsKey) {
        settings++;
      } else {
        other++;
      }
    }

    return {
      'dailyQuotes': dailyQuotes,
      'favoriteQuotes': favoriteQuotes,
      'quoteContexts': quoteContexts,
      'viewedQuotes': viewedQuotes,
      'bookSources': bookSources,
      'settings': settings,
      'other': other,
      'total': keys.length,
    };
  }
}