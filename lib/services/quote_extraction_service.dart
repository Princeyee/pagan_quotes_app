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

  // Паттерны для фильтрации заголовков и нежелательного контента
  final List<RegExp> _headerPatterns = [
    RegExp(r'^(Глава|Chapter|Часть|Part)\s+\d+', caseSensitive: false),
    RegExp(r'^(Книга|Book)\s+\d+', caseSensitive: false),
    RegExp(r'^[IVXLCDM]+\.\s*$'), // Римские цифры
    RegExp(r'^\d+\.\s*$'), // Просто числа с точкой
    RegExp(r'^[A-ZА-Я\s]{5,}$'), // Только заглавные буквы (заголовки)
    RegExp(r'^(СОДЕРЖАНИЕ|ОГЛАВЛЕНИЕ|CONTENT|INDEX)', caseSensitive: false),
    RegExp(r'^(ПРЕДИСЛОВИЕ|ВВЕДЕНИЕ|ЗАКЛЮЧЕНИЕ|PREFACE|INTRODUCTION|CONCLUSION)', caseSensitive: false),
  ];

  final List<String> _unwantedWords = [
    'глава', 'chapter', 'часть', 'part', 'книга', 'book',
    'содержание', 'оглавление', 'предисловие', 'введение',
    'заключение', 'примечание', 'комментарий'
  ];

  /// Извлекает случайную цитату из указанного источника
  Future<Quote?> extractRandomQuote(BookSource source, {int? minLength, int? maxLength}) async {
    try {
      final cleanedText = await _textService.loadTextFile(source.cleanedFilePath);
      final paragraphs = _textService.extractParagraphsWithPositions(cleanedText);
      
      if (paragraphs.isEmpty) return null;
      
      // Фильтруем параграфы по качеству
      var qualityParagraphs = _filterQualityParagraphs(paragraphs);
      
      // Фильтруем по длине, если указано
      if (minLength != null || maxLength != null) {
        qualityParagraphs = qualityParagraphs.where((p) {
          final length = (p['content'] as String).length;
          if (minLength != null && length < minLength) return false;
          if (maxLength != null && length > maxLength) return false;
          return true;
        }).toList();
      }
      
      if (qualityParagraphs.isEmpty) return null;
      
      // Выбираем случайный качественный абзац
      final randomParagraph = qualityParagraphs[_random.nextInt(qualityParagraphs.length)];
      
      // Извлекаем цитату из абзаца
      return _extractQuoteFromParagraph(randomParagraph, source);
      
    } catch (e) {
      print('Error extracting quote from ${source.title}: $e');
      return null;
    }
  }

  /// Фильтрует абзацы по качеству, исключая заголовки и служебную информацию
  List<Map<String, dynamic>> _filterQualityParagraphs(List<Map<String, dynamic>> paragraphs) {
    return paragraphs.where((paragraph) {
      final content = (paragraph['content'] as String).trim();
      
      // Минимальная длина
      if (content.length < 30) return false;
      
      // Максимальная длина для удобства отображения
      if (content.length > 500) return false;
      
      // Проверка на заголовки
      if (_isHeader(content)) return false;
      
      // Проверка на нежелательные слова
      if (_containsUnwantedWords(content)) return false;
      
      // Должно содержать хотя бы одно предложение с пунктуацией
      if (!RegExp(r'[.!?;:]').hasMatch(content)) return false;
      
      // Не должно быть только числами или служебными символами
      if (RegExp(r'^[\d\s\-=_*]+$').hasMatch(content)) return false;
      
      // Должно содержать достаточно букв (не только цифры и символы)
      final letterCount = RegExp(r'[a-zA-Zа-яА-Я]').allMatches(content).length;
      if (letterCount < content.length * 0.7) return false;
      
      return true;
    }).toList();
  }

  /// Проверяет, является ли текст заголовком
  bool _isHeader(String text) {
    // Проверка по паттернам
    for (final pattern in _headerPatterns) {
      if (pattern.hasMatch(text)) return true;
    }
    
    // Проверка на короткие строки в верхнем регистре
    if (text.length < 50 && text.toUpperCase() == text && text.contains(' ')) {
      return true;
    }
    
    // Проверка на строки, состоящие только из заглавной буквы и цифр
    if (RegExp(r'^[A-ZА-Я]\d*\.?\s*$').hasMatch(text)) return true;
    
    return false;
  }

  /// Проверяет, содержит ли текст нежелательные слова
  bool _containsUnwantedWords(String text) {
    final lowerText = text.toLowerCase();
    
    for (final word in _unwantedWords) {
      // Проверяем, что слово стоит в начале или является отдельным словом
      if (lowerText.startsWith(word) || 
          RegExp(r'\b' + word + r'\b').hasMatch(lowerText)) {
        return true;
      }
    }
    
    return false;
  }

  /// Извлекает улучшенную цитату из конкретного абзаца
  Quote _extractQuoteFromParagraph(Map<String, dynamic> paragraph, BookSource source) {
    final content = paragraph['content'] as String;
    final position = paragraph['position'] as int;
    
    String quoteText = _extractBestSentence(content);
    
    return Quote(
      id: '${source.id}_${position}_${DateTime.now().millisecondsSinceEpoch}',
      text: quoteText.trim(),
      author: source.author,
      source: source.title,
      category: source.category,
      position: position,
      translation: source.translator,
      dateAdded: DateTime.now(),
      theme: source.category,
    );
  }

  /// Извлекает лучшее предложение или группу предложений из абзаца
  String _extractBestSentence(String content) {
    final sentences = _extractSentences(content);
    
    if (sentences.isEmpty) {
      // Если не удалось разбить на предложения, обрезаем до разумной длины
      return _truncateToWords(content, 250);
    }
    
    if (sentences.length == 1) {
      return sentences.first;
    }
    
    // Ищем лучшую комбинацию предложений
    String bestQuote = sentences.first;
    
    // Пробуем комбинации из 1-3 предложений
    for (int count = 1; count <= min(3, sentences.length); count++) {
      for (int start = 0; start <= sentences.length - count; start++) {
        final candidateQuote = sentences.sublist(start, start + count).join(' ');
        
        // Предпочитаем цитаты длиной 100-300 символов
        if (candidateQuote.length >= 100 && candidateQuote.length <= 300) {
          bestQuote = candidateQuote;
          break;
        }
        
        // Если текущий кандидат лучше по длине, используем его
        if (_isBetterLength(candidateQuote, bestQuote)) {
          bestQuote = candidateQuote;
        }
      }
    }
    
    return bestQuote;
  }

  /// Проверяет, лучше ли длина нового кандидата
  bool _isBetterLength(String candidate, String current) {
    const idealLength = 200;
    
    final candidateDiff = (candidate.length - idealLength).abs();
    final currentDiff = (current.length - idealLength).abs();
    
    return candidateDiff < currentDiff;
  }

  /// Обрезает текст до указанного количества символов по границам слов
  String _truncateToWords(String text, int maxLength) {
    if (text.length <= maxLength) return text;
    
    final words = text.split(' ');
    final result = <String>[];
    int currentLength = 0;
    
    for (final word in words) {
      if (currentLength + word.length + 1 > maxLength) break;
      result.add(word);
      currentLength += word.length + 1;
    }
    
    return result.join(' ');
  }

  /// Улучшенное разбитие текста на предложения
  List<String> _extractSentences(String text) {
    // Более точная регулярка для разбивки на предложения
    final sentences = text
        .split(RegExp(r'(?<=[.!?])\s+(?=[A-ZА-Я])'))
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty && s.length > 15)
        .toList();
    
    // Фильтруем слишком короткие или подозрительные предложения
    return sentences.where((sentence) {
      // Минимальная длина
      if (sentence.length < 20) return false;
      
      // Должно содержать буквы
      if (!RegExp(r'[a-zA-Zа-яА-Я]').hasMatch(sentence)) return false;
      
      // Не должно быть заголовком
      if (_isHeader(sentence)) return false;
      
      return true;
    }).toList();
  }

  /// Получает улучшенный контекст для цитаты
  Future<QuoteContext?> getQuoteContext(Quote quote) async {
    try {
      // Находим источник цитаты
      final sources = await _textService.loadBookSources();
      BookSource? matchingSource;
      
      // Более гибкий поиск источника
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
      
      if (matchingSource == null) {
        print('No matching source found for quote: ${quote.id}');
        return null;
      }
      
      // Загружаем очищенный текст
      final cleanedText = await _textService.loadTextFile(matchingSource.cleanedFilePath);
      
      // Получаем контекст вокруг позиции цитаты
      final contextParagraphs = _textService.getContextAroundPosition(
        cleanedText, 
        quote.position,
        contextSize: 3, // Уменьшаем размер контекста для лучшей читаемости
      );
      
      if (contextParagraphs.isEmpty) {
        print('No context paragraphs found for quote: ${quote.id}');
        return null;
      }
      
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

  /// Генерирует ежедневную цитату с улучшенной фильтрацией
  Future<DailyQuote?> generateDailyQuote({DateTime? date}) async {
    date ??= DateTime.now();
    
    try {
      final sources = await _textService.loadBookSources();
      if (sources.isEmpty) return null;
      
      // Используем дату как seed для воспроизводимости
      final daysSinceEpoch = date.difference(DateTime(1970)).inDays;
      final dayRandom = Random(daysSinceEpoch);
      
      // Пробуем несколько раз найти качественную цитату
      for (int attempt = 0; attempt < 10; attempt++) {
        // Выбираем случайный источник
        final randomSource = sources[dayRandom.nextInt(sources.length)];
        
        // Извлекаем цитату с ограничениями для UI
        final quote = await extractRandomQuote(
          randomSource,
          minLength: 50,  // Минимум для содержательности
          maxLength: 300, // Максимум для помещения в экран
        );
        
        if (quote != null && _isQualityQuote(quote)) {
          return DailyQuote(
            quote: quote,
            date: date,
          );
        }
      }
      
      // Если не нашли качественную цитату, берем любую подходящую
      final fallbackSource = sources[dayRandom.nextInt(sources.length)];
      final fallbackQuote = await extractRandomQuote(
        fallbackSource,
        minLength: 30,
        maxLength: 400,
      );
      
      if (fallbackQuote != null) {
        return DailyQuote(
          quote: fallbackQuote,
          date: date,
        );
      }
      
      return null;
      
    } catch (e) {
      print('Error generating daily quote: $e');
      return null;
    }
  }

  /// Проверяет качество цитаты для отображения
  bool _isQualityQuote(Quote quote) {
    final text = quote.text;
    
    // Проверяем длину (оптимальная для отображения)
    if (text.length < 50 || text.length > 300) return false;
    
    // Не должно быть заголовком
    if (_isHeader(text)) return false;
    
    // Должно содержать осмысленный контент
    final wordCount = text.split(' ').length;
    if (wordCount < 8) return false; // Минимум 8 слов
    
    // Должно заканчиваться пунктуацией
    if (!RegExp(r'[.!?;:]').hasMatch(text.trim())) return false;
    
    // Не должно содержать слишком много цифр
    final digitCount = RegExp(r'\d').allMatches(text).length;
    if (digitCount > text.length * 0.1) return false;
    
    return true;
  }

  /// Поиск цитат по тексту с улучшенной фильтрацией
  Future<List<Quote>> searchQuotes(String query, {int limit = 20}) async {
    if (query.trim().isEmpty) return [];
    
    try {
      final sources = await _textService.loadBookSources();
      final results = <Quote>[];
      
      for (final source in sources) {
        final cleanedText = await _textService.loadTextFile(source.cleanedFilePath);
        final paragraphs = _textService.extractParagraphsWithPositions(cleanedText);
        
        // Фильтруем качественные параграфы
        final qualityParagraphs = _filterQualityParagraphs(paragraphs);
        
        for (final paragraph in qualityParagraphs) {
          final content = paragraph['content'] as String;
          
          // Улучшенный поиск (регистронезависимый, по словам)
          if (_matchesQuery(content, query)) {
            final quote = _extractQuoteFromParagraph(paragraph, source);
            
            if (_isQualityQuote(quote)) {
              results.add(quote);
              
              if (results.length >= limit) break;
            }
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

  /// Улучшенная проверка соответствия запросу
  bool _matchesQuery(String content, String query) {
    final contentLower = content.toLowerCase();
    final queryLower = query.toLowerCase().trim();
    
    // Разбиваем запрос на слова
    final queryWords = queryLower.split(RegExp(r'\s+'));
    
    // Проверяем, что все слова запроса присутствуют в тексте
    for (final word in queryWords) {
      if (word.length > 2 && !contentLower.contains(word)) {
        return false;
      }
    }
    
    return true;
  }

  /// Получает статистику извлечения цитат
  Future<Map<String, int>> getExtractionStats() async {
    try {
      final sources = await _textService.loadBookSources();
      int totalParagraphs = 0;
      int qualityParagraphs = 0;
      int potentialQuotes = 0;
      
      for (final source in sources) {
        final cleanedText = await _textService.loadTextFile(source.cleanedFilePath);
        final paragraphs = _textService.extractParagraphsWithPositions(cleanedText);
        
        totalParagraphs += paragraphs.length;
        
        final quality = _filterQualityParagraphs(paragraphs);
        qualityParagraphs += quality.length;
        
        for (final paragraph in quality) {
          final quote = _extractQuoteFromParagraph(paragraph, source);
          if (_isQualityQuote(quote)) {
            potentialQuotes++;
          }
        }
      }
      
      return {
        'totalSources': sources.length,
        'totalParagraphs': totalParagraphs,
        'qualityParagraphs': qualityParagraphs,
        'potentialQuotes': potentialQuotes,
      };
    } catch (e) {
      print('Error getting extraction stats: $e');
      return {};
    }
  }
}