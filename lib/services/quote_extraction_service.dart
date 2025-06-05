
// lib/services/quote_extraction_service.dart - ПРОСТАЯ ВЕРСИЯ
import 'dart:math';
import 'dart:convert';
import 'package:flutter/services.dart';
import '../models/quote.dart';
import '../models/quote_context.dart';
import '../models/book_source.dart';
import '../models/daily_quote.dart';
import 'text_file_service.dart';

class CuratedQuote {
  final String id;
  final String text;
  final String author;
  final String source;
  final String category;
  final int position;
  final bool approved;

  const CuratedQuote({
    required this.id,
    required this.text,
    required this.author,
    required this.source,
    required this.category,
    required this.position,
    required this.approved,
  });

  factory CuratedQuote.fromJson(Map<String, dynamic> json) {
    return CuratedQuote(
      id: json['id'] as String,
      text: json['text'] as String,
      author: json['author'] as String,
      source: json['source'] as String,
      category: json['category'] as String,
      position: json['position'] as int,
      approved: json['approved'] as bool,
    );
  }

  Quote toQuote() {
    return Quote(
      id: id,
      text: text,
      author: author,
      source: source,
      category: category,
      position: position,
      dateAdded: DateTime.now(),
      theme: category,
      isFavorite: false,
    );
  }
}

class QuoteExtractionService {
  static final QuoteExtractionService _instance = QuoteExtractionService._internal();
  factory QuoteExtractionService() => _instance;
  QuoteExtractionService._internal();

  final TextFileService _textService = TextFileService();
  
  // Кэш для кураторских цитат
  Map<String, List<CuratedQuote>>? _curatedQuotesCache;

  /// Загружает кураторские цитаты из assets/curated/
  Future<Map<String, List<CuratedQuote>>> _loadCuratedQuotes() async {
    if (_curatedQuotesCache != null) {
      return _curatedQuotesCache!;
    }

    final curatedQuotes = <String, List<CuratedQuote>>{};
    
    // Список файлов с кураторскими цитатами
    final curatedFiles = [
      'assets/curated/aristotle_approved.json',
      'assets/curated/evola_approved.json',
      // Добавляй сюда новые файлы
    ];

    for (final filePath in curatedFiles) {
      try {
        print('📚 Загружаем: $filePath');
        final jsonString = await rootBundle.loadString(filePath);
        final List<dynamic> jsonData = json.decode(jsonString);
        
        final quotes = jsonData
            .map((json) => CuratedQuote.fromJson(json as Map<String, dynamic>))
            .where((quote) => quote.approved) // Только одобренные
            .toList();
        
        if (quotes.isNotEmpty) {
          final category = quotes.first.category;
          curatedQuotes[category] = quotes;
          print('✅ ${quotes.length} цитат для: $category');
        }
      } catch (e) {
        print('⚠️ Файл $filePath не найден или поврежден: $e');
        // Просто пропускаем - не критично
      }
    }

    _curatedQuotesCache = curatedQuotes;
    return curatedQuotes;
  }

  /// Генерация ежедневной цитаты - теперь ТОЛЬКО из отобранных
  Future<DailyQuote?> generateDailyQuote({DateTime? date}) async {
    date ??= DateTime.now();
    
    try {
      print('🎭 Генерируем цитату на ${date.toString().split(' ')[0]}');
      
      // Загружаем отобранные цитаты
      final curated = await _loadCuratedQuotes();
      
      if (curated.isEmpty) {
        print('❌ Нет отобранных цитат! Запустите quote_curator.dart');
        return null;
      }

      final categories = curated.keys.toList();
      print('📂 Доступные категории: $categories');
      
      // Выбираем категорию по дню (чередование)
      final daysSinceEpoch = date.difference(DateTime(1970)).inDays;
      final categoryIndex = daysSinceEpoch % categories.length;
      final selectedCategory = categories[categoryIndex];
      
      print('🎯 День $daysSinceEpoch -> Категория: $selectedCategory');
      
      // Получаем цитаты для выбранной категории
      final categoryQuotes = curated[selectedCategory]!;
      
      // Выбираем цитату с воспроизводимостью внутри дня
      final dayRandom = Random(daysSinceEpoch + selectedCategory.hashCode);
      final selectedQuote = categoryQuotes[dayRandom.nextInt(categoryQuotes.length)];
      
      print('📜 Выбрана: ${selectedQuote.author} - "${selectedQuote.text.substring(0, min(50, selectedQuote.text.length))}..."');
      
      return DailyQuote(
        quote: selectedQuote.toQuote(),
        date: date,
      );
      
    } catch (e) {
      print('❌ Ошибка генерации цитаты: $e');
      return null;
    }
  }

  /// Получает контекст для цитаты
  Future<QuoteContext?> getQuoteContext(Quote quote) async {
    try {
      final sources = await _textService.loadBookSources();
      BookSource? matchingSource;
      
      // Находим источник
      for (final source in sources) {
        if (source.author == quote.author && source.title == quote.source) {
          matchingSource = source;
          break;
        }
      }
      
      if (matchingSource == null) {
        // Fallback поиск по категории и автору
        for (final source in sources) {
          if (source.author == quote.author && source.category == quote.category) {
            matchingSource = source;
            break;
          }
        }
      }
      
      if (matchingSource == null) {
        print('❌ Источник не найден для: ${quote.id}');
        return null;
      }
      
      // Загружаем текст и получаем контекст
      final cleanedText = await _textService.loadTextFile(matchingSource.cleanedFilePath);
      final contextParagraphs = _textService.getContextAroundPosition(
        cleanedText, 
        quote.position,
        contextSize: 1,
      );
      
      if (contextParagraphs.isEmpty) {
        print('❌ Контекст не найден для: ${quote.id}');
        return null;
      }
      
      final contextText = contextParagraphs
          .map((p) => p['content'] as String)
          .join('\n\n');
      
      final startPosition = contextParagraphs.first['position'] as int;
      final endPosition = contextParagraphs.last['position'] as int;
      
      return QuoteContext(
        quote: quote,
        contextText: contextText,
        startPosition: startPosition,
        endPosition: endPosition,
        contextParagraphs: contextParagraphs
            .map((p) => p['content'] as String)
            .toList(),
      );
      
    } catch (e) {
      print('❌ Ошибка получения контекста: $e');
      return null;
    }
  }

  // Остальные методы можно убрать или оставить пустыми для совместимости
  Future<Quote?> extractRandomQuote(BookSource source, {int? minLength, int? maxLength}) async {
    // Больше не используется - все цитаты теперь только отобранные
    return null;
  }

  Future<List<Quote>> searchQuotes(String query, {int limit = 20}) async {
    // Можно убрать или оставить для совместимости
    return [];
  }

  Future<Map<String, int>> getExtractionStats() async {
    // Можно убрать или оставить для совместимости
    return {};
  }
}