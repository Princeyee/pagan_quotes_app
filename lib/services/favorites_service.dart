// lib/services/favorites_service.dart
import 'package:shared_preferences/shared_preferences.dart';
import '../models/quote.dart';

class FavoritesService {
  static FavoritesService? _instance;
  late SharedPreferences _prefs;
  
  FavoritesService._();
  
  static Future<FavoritesService> init() async {
    if (_instance == null) {
      _instance = FavoritesService._();
      await _instance!._initialize();
    }
    return _instance!;
  }
  
  Future<void> _initialize() async {
    _prefs = await SharedPreferences.getInstance();
  }
  
  /// Загружает все цитаты (в новой архитектуре возвращаем пустой список)
  Future<List<Quote>> loadAllQuotes() async {
    // В новой архитектуре цитаты генерируются динамически из текстов
    return [];
  }
  
  /// Проверяет, является ли цитата избранной
  bool isFavorite(String quoteId) {
    final favs = _prefs.getStringList('favorites') ?? [];
    return favs.contains(quoteId);
  }
  
  /// Переключает статус избранного для цитаты
  Future<void> toggleFavorite(String quoteId) async {
    final favs = _prefs.getStringList('favorites') ?? [];
    if (favs.contains(quoteId)) {
      favs.remove(quoteId);
    } else {
      favs.add(quoteId);
    }
    await _prefs.setStringList('favorites', favs);
  }
  
  /// Получает список избранных цитат
  Future<List<Quote>> getFavoriteQuotes() async {
    final favIds = _prefs.getStringList('favorites') ?? [];
    final quotes = <Quote>[];
    
    for (final id in favIds) {
      final quoteData = _prefs.getString('quote_$id');
      if (quoteData != null) {
        try {
          final parts = quoteData.split('|||');
          if (parts.length >= 6) {
            quotes.add(Quote(
              id: id,
              text: parts[0],
              author: parts[1],
              source: parts[2],
              category: parts[3],
              position: int.tryParse(parts[4]) ?? 0,
              theme: parts[3],
              context: parts.length > 5 ? parts[5] : '',
            ));
          }
        } catch (e) {
          print('Error parsing favorite quote $id: $e');
        }
      }
    }
    
    return quotes;
  }
  
  /// Сохраняет цитату в избранное с полными данными
  Future<void> saveFavoriteQuote(Quote quote) async {
    // Добавляем в список избранных
    final favs = _prefs.getStringList('favorites') ?? [];
    if (!favs.contains(quote.id)) {
      favs.add(quote.id);
      await _prefs.setStringList('favorites', favs);
    }
    
    // Сохраняем данные цитаты
    final quoteData = '${quote.text}|||${quote.author}|||${quote.source}|||${quote.category}|||${quote.position}|||${quote.context}';
    await _prefs.setString('quote_${quote.id}', quoteData);
  }
}