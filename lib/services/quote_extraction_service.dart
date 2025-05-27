// lib/services/quote_extraction_service.dart
import 'dart:math';
import '../models/quote.dart';
import '../models/quote_context.dart';
import '../models/book_source.dart';
import '../models/daily_quote.dart';
import 'text_file_service.dart';

class QuoteExtractionService {
  static final QuoteExtractionService _instance = QuoteExtractionService._internal();
  factory QuoteExtractionService() => _instance;
  QuoteExtractionService._internal();

  final TextFileService _textService = TextFileService();
  final Random _random = Random();

  /// Извлекает случайную цитату из указанного источника
  Future<Quote?> extractRandomQuote(BookSource source, {int? minLength, int? maxLength}) async {
    try {
      final cleanedText = await _textService.loadTextFile(source.cleanedFilePath);
      final paragraphs = _textService.extractParagraphsWithPositions(cleanedText);
      
      if (paragraphs.isEmpty) return null;
      
      // Фильтруем по длине, если указано
      var filteredParagraphs = paragraphs;
      if (minLength != null || maxLength != null) {
        filteredParagraphs = paragraphs.where((p) {
          final length = (p['content'] as String).length;
          if (minLength != null && length < minLength) return false;
          if (maxLength != null && length > maxLength) return false;
          return true;
        }).toList();
      }
      
      if (filteredParagraphs.isEmpty) return null;
      
      // Выбираем случайный абзац
      final randomParagraph = filteredParagraphs[_random.nextInt(filteredParagraphs.length)];
      
      // Извлекаем цитату из абзаца
      return _extractQuoteFromParagraph(randomParagraph, source);
      
    } catch (e) {
      print('Error extracting quote from ${source.title}: $e');
      return null;
    }
  }

  /// Извлекает цитату из конкретного абзаца
  Quote _extractQuoteFromParagraph(Map<String, dynamic> paragraph, BookSource source) {
    final content = paragraph['content'] as String;
    final position = paragraph['position'] as int;
    
    // Пытаемся найти законченные предложения
    final sentences = _extractSentences(content);
    String quoteText;
    
    if (sentences.isNotEmpty) {
      // Выбираем одно или несколько предложений
      if (sentences.length == 1) {
        quoteText = sentences.first;
      } else {
        // Выбираем 1-3 предложения
        final count = min(3, _random.nextInt(sentences.length) + 1);
        final startIndex = _random.nextInt(sentences.length - count + 1);
        quoteText = sentences.sublist(startIndex, startIndex + count).join(' ');
      }
    } else {
      // Если не удалось разбить на предложения, берем первые N слов
      final words = content.split(' ');
      final wordCount = min(30, max(10, words.length));
      quoteText = words.take(wordCount).join(' ');
      
      if (words.length > wordCount) {
        quoteText += '...';
      }
    }
    
    return Quote(
      id: '${source.id}_${position}_${DateTime.now().millisecondsSinceEpoch}',
      text: quoteText.trim(),
      author: source.author,
      source: source.title,
      category: source.category,
      position: position,
      translation: source.translator,
      dateAdded: DateTime.now(),
      theme: source.category, // ← ИСПРАВЛЕНО: добавлен обязательный параметр
    );
  }

  /// Разбивает текст на предложения
  List<String> _extractSentences(String text) {
    // Простая регулярка для разбивки на предложения
    final sentences = text
        .split(RegExp(r'[.!?]+\s+'))
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty && s.length > 10)
        .toList();
    
    return sentences;
  }

  /// Получает контекст для цитаты
  Future<QuoteContext?> getQuoteContext(Quote quote) async {
    try {
      // Находим источник цитаты
      final sources = await _textService.loadBookSources();
      final source = sources.firstWhere(
        (s) => s.author == quote.author && s.title == quote.source,
        orElse: () => throw Exception('Source not found'),
      );
      
      // Загружаем очищенный текст
      final cleanedText = await _textService.loadTextFile(source.cleanedFilePath);
      
      // Получаем контекст вокруг позиции цитаты
      final contextParagraphs = _textService.getContextAroundPosition(
        cleanedText, 
        quote.position,
        contextSize: 5,
      );
      
      if (contextParagraphs.isEmpty) return null;
      
      // Формируем контекстный текст
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
      print('Error getting context for quote ${quote.id}: $e');
      return null;
    }
  }

  /// Генерирует ежедневную цитату
  Future<DailyQuote?> generateDailyQuote({DateTime? date}) async {
    date ??= DateTime.now();
    
    try {
      final sources = await _textService.loadBookSources();
      if (sources.isEmpty) return null;
      
      // Используем дату как seed для воспроизводимости
      final daysSinceEpoch = date.difference(DateTime(1970)).inDays;
      final dayRandom = Random(daysSinceEpoch);
      
      // Выбираем случайный источник
      final randomSource = sources[dayRandom.nextInt(sources.length)];
      
      // Извлекаем цитату
      final quote = await extractRandomQuote(
        randomSource,
        minLength: 50,
        maxLength: 300,
      );
      
      if (quote == null) return null;
      
      return DailyQuote(
        quote: quote,
        date: date,
      );
      
    } catch (e) {
      print('Error generating daily quote: $e');
      return null;
    }
  }

  /// Поиск цитат по тексту
  Future<List<Quote>> searchQuotes(String query, {int limit = 20}) async {
    if (query.trim().isEmpty) return [];
    
    try {
      final sources = await _textService.loadBookSources();
      final results = <Quote>[];
      
      for (final source in sources) {
        final cleanedText = await _textService.loadTextFile(source.cleanedFilePath);
        final paragraphs = _textService.extractParagraphsWithPositions(cleanedText);
        
        for (final paragraph in paragraphs) {
          final content = paragraph['content'] as String;
          
          // Простой поиск по подстроке (можно улучшить)
          if (content.toLowerCase().contains(query.toLowerCase())) {
            final quote = _extractQuoteFromParagraph(paragraph, source);
            results.add(quote);
            
            if (results.length >= limit) break;
          }
        }
        
        if (results.length >= limit) break;
      }
      
      return results;
    } catch (e) {
      print('Error searching quotes: $e');
      return [];
    }
  }
}