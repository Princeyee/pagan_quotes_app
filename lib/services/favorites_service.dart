// lib/services/favorites_service.dart
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/quote.dart';

class FavoritesService {
  static FavoritesService? _instance;
  late SharedPreferences _prefs;
  final List<Quote> _allQuotes = [];
  
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
    await _loadAllQuotes();
  }
  
  Future<void> _loadAllQuotes() async {
    try {
      // Загружаем старый файл quotes.json для обратной совместимости
      final jsonString = await rootBundle.loadString('assets/quotes.json');
      final Map<String, dynamic> jsonData = json.decode(jsonString);
      
      _allQuotes.clear();
      
      // Преобразуем старый формат в новый
      jsonData.forEach((theme, quotes) {
        if (quotes is List) {
          for (var quoteData in quotes) {
            _allQuotes.add(Quote(
              id: '${theme}_${DateTime.now().millisecondsSinceEpoch}_${quotes.indexOf(quoteData)}',
              text: quoteData['text'] ?? '',
              author: quoteData['author'] ?? '',
              source: quoteData['source'] ?? '',
              category: theme,
              position: quotes.indexOf(quoteData),
              theme: theme, // Добавляем поле theme
              context: quoteData['context'] ?? '', // Добавляем контекст
            ));
          }
        }
      });
    } catch (e) {
      print('Error loading quotes: $e');
    }
  }
  
  List<Quote> get allQuotes => List.unmodifiable(_allQuotes);
  
  Future<List<Quote>> loadAllQuotes() async {
    if (_allQuotes.isEmpty) {
      await _loadAllQuotes();
    }
    return _allQuotes;
  }
  
  bool isFavorite(String quoteId) {
    final favs = _prefs.getStringList('favorites') ?? [];
    return favs.contains(quoteId);
  }
  
  Future<void> toggleFavorite(String quoteId) async {
    final favs = _prefs.getStringList('favorites') ?? [];
    if (favs.contains(quoteId)) {
      favs.remove(quoteId);
    } else {
      favs.add(quoteId);
    }
    await _prefs.setStringList('favorites', favs);
  }
  
  Future<List<Quote>> getFavoriteQuotes() async {
    final favIds = _prefs.getStringList('favorites') ?? [];
    return _allQuotes.where((q) => favIds.contains(q.id)).toList();
  }
}