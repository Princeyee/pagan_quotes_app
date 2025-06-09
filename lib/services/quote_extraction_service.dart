 
// lib/services/quote_extraction_service.dart - ИСПРАВЛЕННАЯ ВЕРСИЯ
import 'dart:math';
import 'dart:convert';
import 'package:flutter/services.dart';
import '../models/quote.dart';
import '../models/quote_context.dart';
import '../models/book_source.dart';
import '../models/daily_quote.dart';
import 'text_file_service.dart';
import 'theme_service.dart'; // Добавляем импорт!

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
      'assets/curated/my_quotes_approved.json',
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
          // Группируем по категориям
          for (final quote in quotes) {
            curatedQuotes.putIfAbsent(quote.category, () => []).add(quote);
          }
        }
      } catch (e) {
        print('⚠️ Файл $filePath не найден или поврежден: $e');
        // Просто пропускаем - не критично
      }
    }

    // Выводим статистику
    for (final entry in curatedQuotes.entries) {
      print('✅ ${entry.value.length} цитат для категории: ${entry.key}');
    }

    _curatedQuotesCache = curatedQuotes;
    return curatedQuotes;
  }

  /// Генерация ежедневной цитаты - теперь УЧИТЫВАЕТ настройки пользователя
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

      // ВАЖНО: Получаем список включенных пользователем тем
      final enabledThemes = await ThemeService.getEnabledThemes();
      print('✅ Включенные темы: $enabledThemes');
      
      // Фильтруем только те категории, которые включены пользователем
      final availableCategories = curated.keys
          .where((category) => enabledThemes.contains(category))
          .toList();
      
      if (availableCategories.isEmpty) {
        print('❌ Нет доступных категорий! Все темы выключены пользователем');
        print('📂 Доступные категории в кураторских цитатах: ${curated.keys.toList()}');
        print('🔧 Включенные пользователем темы: $enabledThemes');
        
        // Если все темы выключены, включаем хотя бы одну по умолчанию
        if (curated.keys.isNotEmpty) {
          final defaultCategory = curated.keys.first;
          print('⚠️ Используем категорию по умолчанию: $defaultCategory');
          availableCategories.add(defaultCategory);
        } else {
          return null;
        }
      }
      
      print('📂 Доступные категории после фильтрации: $availableCategories');
      
      // Выбираем категорию по дню (чередование только среди включенных)
      final daysSinceEpoch = date.difference(DateTime(1970)).inDays;
      final categoryIndex = daysSinceEpoch % availableCategories.length;
      final selectedCategory = availableCategories[categoryIndex];
      
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

  /// ИСПРАВЛЕННЫЙ метод получения контекста для цитаты
  Future<QuoteContext?> getQuoteContext(Quote quote) async {
    try {
      print('🔍 Ищем контекст для цитаты: ${quote.id}');
      
      // Загружаем источники книг
      final sources = await _textService.loadBookSources();
      BookSource? matchingSource;
      
      // Находим источник по автору и названию
      for (final source in sources) {
        if (source.author == quote.author && source.title == quote.source) {
          matchingSource = source;
          break;
        }
      }
      
      // Fallback поиск по категории и автору
      if (matchingSource == null) {
        for (final source in sources) {
          if (source.author == quote.author && source.category == quote.category) {
            matchingSource = source;
            break;
          }
        }
      }
      
      // Дополнительный fallback - поиск по частичному совпадению
      if (matchingSource == null) {
        print('⚠️ Точное совпадение не найдено, ищем по автору...');
        for (final source in sources) {
          if (source.author.toLowerCase().contains(quote.author.toLowerCase()) || 
              quote.author.toLowerCase().contains(source.author.toLowerCase())) {
            matchingSource = source;
            print('✅ Найдено частичное совпадение: ${source.title}');
            break;
          }
        }
      }
      
      if (matchingSource == null) {
        print('❌ Источник не найден для: ${quote.author} - ${quote.source}');
        print('📚 Доступные источники:');
        for (final s in sources) {
          print('   - ${s.author} : ${s.title} (${s.category})');
        }
        return null;
      }
      
      print('✅ Найден источник: ${matchingSource.title} - ${matchingSource.cleanedFilePath}');
      
      // Загружаем текст и получаем контекст
      final cleanedText = await _textService.loadTextFile(matchingSource.cleanedFilePath);
      print('📖 Загружен текст длиной: ${cleanedText.length} символов');
      
      // Получаем контекст вокруг позиции цитаты
      final contextParagraphs = _textService.getContextAroundPosition(
        cleanedText, 
        quote.position,
        contextSize: 1, // По 1 параграфу до и после
      );
      
      if (contextParagraphs.isEmpty) {
        print('❌ Контекст не найден на позиции: ${quote.position}');
        
        // Попробуем найти цитату по тексту
        print('🔍 Пытаемся найти цитату по тексту...');
        final paragraphs = _textService.extractParagraphsWithPositions(cleanedText);
        
        for (final para in paragraphs) {
          final content = para['content'] as String;
          final position = para['position'] as int;
          
          // Проверяем, содержится ли текст цитаты в этом параграфе
          if (content.toLowerCase().contains(quote.text.toLowerCase().substring(0, min(30, quote.text.length)))) {
            print('✅ Найдена цитата по тексту на позиции: $position');
            
            // Получаем контекст для найденной позиции
            final foundContextParagraphs = _textService.getContextAroundPosition(
              cleanedText, 
              position,
              contextSize: 1,
            );
            
            if (foundContextParagraphs.isNotEmpty) {
              final contextText = foundContextParagraphs
                  .map((p) => p['content'] as String)
                  .join('\n\n');
              
              final startPosition = foundContextParagraphs.first['position'] as int;
              final endPosition = foundContextParagraphs.last['position'] as int;
              
              return QuoteContext(
                quote: quote,
                contextText: contextText,
                startPosition: startPosition,
                endPosition: endPosition,
                contextParagraphs: foundContextParagraphs
                    .map((p) => p['content'] as String)
                    .toList(),
              );
            }
          }
        }
        
        print('❌ Не удалось найти цитату ни по позиции, ни по тексту');
        return null;
      }
      
      final contextText = contextParagraphs
          .map((p) => p['content'] as String)
          .join('\n\n');
      
      final startPosition = contextParagraphs.first['position'] as int;
      final endPosition = contextParagraphs.last['position'] as int;
      
      print('✅ Контекст найден: ${contextParagraphs.length} параграфов');
      
      return QuoteContext(
        quote: quote,
        contextText: contextText,
        startPosition: startPosition,
        endPosition: endPosition,
        contextParagraphs: contextParagraphs
            .map((p) => p['content'] as String)
            .toList(),
      );
      
    } catch (e, stackTrace) {
      print('❌ Ошибка получения контекста: $e');
      print('Stack trace: $stackTrace');
      return null;
    }
  }

  // Остальные методы можно убрать или оставить пустыми для совместимости
  Future<Quote?> extractRandomQuote(BookSource source, {int? minLength, int? maxLength}) async {
    // Больше не используется - все цитаты теперь только отобранные
    return null;
  }

  Future<List<Quote>> searchQuotes(String query, {int limit = 20}) async {
    // Можно реализовать поиск по отобранным цитатам
    final curated = await _loadCuratedQuotes();
    final allQuotes = <Quote>[];
    
    for (final categoryQuotes in curated.values) {
      for (final curatedQuote in categoryQuotes) {
        final quote = curatedQuote.toQuote();
        if (quote.text.toLowerCase().contains(query.toLowerCase()) ||
            quote.author.toLowerCase().contains(query.toLowerCase()) ||
            quote.source.toLowerCase().contains(query.toLowerCase())) {
          allQuotes.add(quote);
        }
      }
    }
    
    return allQuotes.take(limit).toList();
  }

  Future<Map<String, int>> getExtractionStats() async {
    final curated = await _loadCuratedQuotes();
    final stats = <String, int>{};
    
    for (final entry in curated.entries) {
      stats[entry.key] = entry.value.length;
    }
    
    return stats;
  }
}