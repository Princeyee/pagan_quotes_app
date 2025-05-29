// lib/services/favorites_service.dart
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/quote.dart';

class FavoriteQuoteWithImage {
  final Quote quote;
  final String? imageUrl;
  final DateTime addedAt;

  const FavoriteQuoteWithImage({
    required this.quote,
    this.imageUrl,
    required this.addedAt,
  });

  factory FavoriteQuoteWithImage.fromJson(Map<String, dynamic> json) {
    return FavoriteQuoteWithImage(
      quote: Quote.fromJson(json['quote'] as Map<String, dynamic>),
      imageUrl: json['imageUrl'] as String?,
      addedAt: DateTime.parse(json['addedAt'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'quote': quote.toJson(),
      'imageUrl': imageUrl,
      'addedAt': addedAt.toIso8601String(),
    };
  }
}

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
  
  /// Загружает все цитаты (устаревший метод для совместимости)
  Future<List<Quote>> loadAllQuotes() async {
    final favorites = await getFavoriteQuotesWithImages();
    return favorites.map((f) => f.quote).toList();
  }
  
  /// Проверяет, является ли цитата избранной
  bool isFavorite(String quoteId) {
    final favs = _prefs.getStringList('favorites_v2') ?? [];
    return favs.any((jsonStr) {
      try {
        final data = json.decode(jsonStr) as Map<String, dynamic>;
        final favorite = FavoriteQuoteWithImage.fromJson(data);
        return favorite.quote.id == quoteId;
      } catch (e) {
        return false;
      }
    });
  }
  
  /// Переключает статус избранного для цитаты
  Future<void> toggleFavorite(String quoteId) async {
    final favs = _prefs.getStringList('favorites_v2') ?? [];
    
    // Находим и удаляем цитату, если она есть
    final updatedFavs = favs.where((jsonStr) {
      try {
        final data = json.decode(jsonStr) as Map<String, dynamic>;
        final favorite = FavoriteQuoteWithImage.fromJson(data);
        return favorite.quote.id != quoteId;
      } catch (e) {
        return true; // Оставляем поврежденные записи как есть
      }
    }).toList();
    
    await _prefs.setStringList('favorites_v2', updatedFavs);
  }
  
  /// Добавляет цитату в избранное с изображением
  Future<void> addToFavorites(Quote quote, {String? imageUrl}) async {
    // Проверяем, не добавлена ли уже эта цитата
    if (isFavorite(quote.id)) {
      return;
    }
    
    final favs = _prefs.getStringList('favorites_v2') ?? [];
    
    final favoriteWithImage = FavoriteQuoteWithImage(
      quote: quote.copyWith(isFavorite: true),
      imageUrl: imageUrl,
      addedAt: DateTime.now(),
    );
    
    favs.add(json.encode(favoriteWithImage.toJson()));
    await _prefs.setStringList('favorites_v2', favs);
  }
  
  /// Удаляет цитату из избранного
  Future<void> removeFromFavorites(String quoteId) async {
    final favs = _prefs.getStringList('favorites_v2') ?? [];
    
    final updatedFavs = favs.where((jsonStr) {
      try {
        final data = json.decode(jsonStr) as Map<String, dynamic>;
        final favorite = FavoriteQuoteWithImage.fromJson(data);
        return favorite.quote.id != quoteId;
      } catch (e) {
        return true;
      }
    }).toList();
    
    await _prefs.setStringList('favorites_v2', updatedFavs);
  }
  
  /// Получает список избранных цитат (устаревший метод)
  Future<List<Quote>> getFavoriteQuotes() async {
    final favorites = await getFavoriteQuotesWithImages();
    return favorites.map((f) => f.quote).toList();
  }
  
  /// Получает список избранных цитат с изображениями
  Future<List<FavoriteQuoteWithImage>> getFavoriteQuotesWithImages() async {
    final favs = _prefs.getStringList('favorites_v2') ?? [];
final favorites = <FavoriteQuoteWithImage>[];
    
    for (final jsonStr in favs) {
      try {
        final data = json.decode(jsonStr) as Map<String, dynamic>;
        final favorite = FavoriteQuoteWithImage.fromJson(data);
        favorites.add(favorite);
      } catch (e) {
        print('Error parsing favorite quote: $e');
      }
    }
    
    // Сортируем по дате добавления (новые сначала)
    favorites.sort((a, b) => b.addedAt.compareTo(a.addedAt));
    
    return favorites;
  }
  
  /// Сохраняет цитату в избранное с полными данными (устаревший метод)
  Future<void> saveFavoriteQuote(Quote quote) async {
    await addToFavorites(quote);
  }
  
  /// Миграция старых избранных цитат в новый формат
  Future<void> migrateOldFavorites() async {
    final oldFavs = _prefs.getStringList('favorites') ?? [];
    
    if (oldFavs.isEmpty) return;
    
    final newFavs = <String>[];
    
    for (final quoteId in oldFavs) {
      final quoteData = _prefs.getString('quote_$quoteId');
      if (quoteData != null) {
        try {
          final parts = quoteData.split('|||');
          if (parts.length >= 6) {
            final quote = Quote(
              id: quoteId,
              text: parts[0],
              author: parts[1],
              source: parts[2],
              category: parts[3],
              position: int.tryParse(parts[4]) ?? 0,
              theme: parts[3],
              context: parts.length > 5 ? parts[5] : '',
              isFavorite: true,
              dateAdded: DateTime.now(),
            );
            
            final favoriteWithImage = FavoriteQuoteWithImage(
              quote: quote,
              imageUrl: null, // Старые цитаты без изображений
              addedAt: DateTime.now(),
            );
            
            newFavs.add(json.encode(favoriteWithImage.toJson()));
          }
        } catch (e) {
          print('Error migrating favorite quote $quoteId: $e');
        }
      }
    }
    
    if (newFavs.isNotEmpty) {
      await _prefs.setStringList('favorites_v2', newFavs);
      print('Migrated ${newFavs.length} favorite quotes to new format');
    }
  }
}
