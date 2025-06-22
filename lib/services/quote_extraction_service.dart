// lib/services/quote_extraction_service.dart - ИСПРАВЛЕННАЯ ВЕРСИЯ

import 'dart:math';
import 'dart:convert';
import 'package:flutter/services.dart';
import '../models/quote.dart';
import '../models/quote_context.dart';
import '../models/book_source.dart';
import '../models/daily_quote.dart';
import 'text_file_service.dart';
import 'theme_service.dart'; // ДОБАВЛЯЕМ ИМПОРТ

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

  // Кэш для кураторских цитат - СДЕЛАЕМ ПУБЛИЧНЫМ
  Map<String, List<CuratedQuote>>? _curatedQuotesCache;

  /// Загружает кураторские цитаты из assets/curated/ - ПУБЛИЧНЫЙ МЕТОД
  Future<Map<String, List<CuratedQuote>>> loadCuratedQuotes() async {
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
          // ИСПРАВЛЕНО: Группируем цитаты по их реальным категориям
          for (final quote in quotes) {
            curatedQuotes.putIfAbsent(quote.category, () => []).add(quote);
          }
          
          // Выводим статистику по категориям
          for (final category in curatedQuotes.keys) {
            print('✅ ${curatedQuotes[category]!.length} цитат для: $category');
          }
        }
      } catch (e) {
        print('⚠️ Файл $filePath не найден или поврежден: $e');
        // Просто пропускаем - не критично
      }
    }

    _curatedQuotesCache = curatedQuotes;
    return curatedQuotes;
  }

  /// НОВЫЙ МЕТОД: Получить отфильтрованные цитаты по темам и авторам
  Future<List<Quote>> getFilteredQuotes() async {
    final curated = await loadCuratedQuotes();
    final enabledThemes = await ThemeService.getEnabledThemes();
    final selectedAuthors = await ThemeService.getSelectedAuthors();
    
    print('🎯 Фильтруем цитаты: темы=$enabledThemes, авторы=$selectedAuthors');
    
    final filteredQuotes = <Quote>[];
    
    for (final themeId in enabledThemes) {
      if (curated.containsKey(themeId)) {
        for (final curatedQuote in curated[themeId]!) {
          // Для северной темы фильтруем по source (название книги), для остальных - по author
          final filterKey = curatedQuote.category == 'nordic' ? curatedQuote.source : curatedQuote.author;
          
          // Фильтруем по авторам если они выбраны
          if (selectedAuthors.isEmpty || selectedAuthors.contains(filterKey)) {
            filteredQuotes.add(curatedQuote.toQuote());
          }
        }
      }
    }
    
    print('✅ Найдено ${filteredQuotes.length} отфильтрованных цитат');
    return filteredQuotes;
  }

  /// ОБНОВЛЕННАЯ генерация ежедневной цитаты - учитывает выбранные темы И авторов
  Future<DailyQuote?> generateDailyQuote({DateTime? date}) async {
    date ??= DateTime.now();

    try {
      print('🎭 Генерируем цитату на ${date.toString().split(' ')[0]}');

      // ПОЛУЧАЕМ ОТФИЛЬТРОВАННЫЕ ЦИТАТЫ
      final filteredQuotes = await getFilteredQuotes();

      if (filteredQuotes.isEmpty) {
        print('❌ Нет цитат после фильтрации! Проверьте настройки тем и авторов');
        
        // Fallback - берем любые доступные цитаты
        final curated = await loadCuratedQuotes();
        if (curated.isNotEmpty) {
          final allQuotes = <Quote>[];
          for (final categoryQuotes in curated.values) {
            allQuotes.addAll(categoryQuotes.map((q) => q.toQuote()));
          }
          
          if (allQuotes.isNotEmpty) {
            final daysSinceEpoch = date.difference(DateTime(1970)).inDays;
            final dayRandom = Random(daysSinceEpoch);
            final selectedQuote = allQuotes[dayRandom.nextInt(allQuotes.length)];
            
            print('🔄 Fallback: выбрана случайная цитата');
            return DailyQuote(quote: selectedQuote, date: date);
          }
        }
        
        return null;
      }

      // Группируем по категориям для равномерного распределения
      final quotesByCategory = <String, List<Quote>>{};
      for (final quote in filteredQuotes) {
        quotesByCategory.putIfAbsent(quote.category, () => []).add(quote);
      }

      final categories = quotesByCategory.keys.toList();
      print('📂 Доступные категории после фильтрации: $categories');

      // Выбираем категорию по дню (чередование)
      final daysSinceEpoch = date.difference(DateTime(1970)).inDays;
      final categoryIndex = daysSinceEpoch % categories.length;
      final selectedCategory = categories[categoryIndex];

      print('🎯 День $daysSinceEpoch -> Категория: $selectedCategory');

      // Получаем цитаты для выбранной категории
      final categoryQuotes = quotesByCategory[selectedCategory]!;

      // Выбираем цитату с воспроизводимостью внутри дня
      final dayRandom = Random(daysSinceEpoch + selectedCategory.hashCode);
      final selectedQuote = categoryQuotes[dayRandom.nextInt(categoryQuotes.length)];

      print('📜 Выбрана: ${selectedQuote.author} - "${selectedQuote.text.substring(0, min(50, selectedQuote.text.length))}..."');

      return DailyQuote(
        quote: selectedQuote,
        date: date,
      );

    } catch (e, stackTrace) {
      print('❌ Ошибка генерации цитаты: $e');
      print('Stack trace: $stackTrace');
      return null;
    }
  }

  /// ИСПРАВЛЕННЫЙ метод получения контекста для цитаты
  Future<QuoteContext?> getQuoteContext(Quote quote) async {
    try {
      print('🔍 Ищем контекст для цитаты: ${quote.id}');

      // Находим источник с помощью нового гибкого метода
      final matchingSource = _textService.findBookSource(quote.author, quote.source);

      if (matchingSource == null) {
        print('❌ Источник не найден для: ${quote.author} - ${quote.source}');
        print('📚 Доступные источники:');
        final sources = await _textService.loadBookSources();
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
        contextSize: 1, // Уменьшаем с 5 до 1 параграфа до и после
      );

      print('🔍 DEBUG: Получено ${contextParagraphs.length} параграфов контекста');
      print('🔍 DEBUG: Позиция цитаты: ${quote.position}');
      print('🔍 DEBUG: Текст цитаты: ${quote.text.substring(0, min(50, quote.text.length))}...');
      
      for (int i = 0; i < contextParagraphs.length; i++) {
        final para = contextParagraphs[i];
        final content = para['content'] as String;
        final position = para['position'] as int;
        print('🔍 DEBUG: Параграф $i (позиция $position): ${content.substring(0, min(100, content.length))}...');
      }

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
              contextSize: 1, // Уменьшаем с 5 до 1 параграфа до и после
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

  // Остальные методы остаются без изменений
  Future<Quote?> extractRandomQuote(BookSource source, {int? minLength, int? maxLength}) async {
    return null;
  }

  Future<List<Quote>> searchQuotes(String query, {int limit = 20}) async {
    final curated = await loadCuratedQuotes();
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
    final curated = await loadCuratedQuotes();
    final stats = <String, int>{};

    for (final entry in curated.entries) {
      stats[entry.key] = entry.value.length;
    }

    return stats;
  }
}