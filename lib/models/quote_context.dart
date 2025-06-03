// lib/models/quote_context.dart
import 'quote.dart';

class QuoteContext {
  final Quote quote;
  final String contextText; // расширенный контекст ~10 строк
  final int startPosition; // начальная позиция контекста
  final int endPosition; // конечная позиция контекста
  final List<String> contextParagraphs; // абзацы контекста

  const QuoteContext({
    required this.quote,
    required this.contextText,
    required this.startPosition,
    required this.endPosition,
    required this.contextParagraphs,
  });

  factory QuoteContext.fromJson(Map<String, dynamic> json) {
    return QuoteContext(
      quote: Quote.fromJson(json['quote'] as Map<String, dynamic>),
      contextText: json['contextText'] as String,
      startPosition: json['startPosition'] as int,
      endPosition: json['endPosition'] as int,
      contextParagraphs: List<String>.from(json['contextParagraphs'] as List),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'quote': quote.toJson(),
      'contextText': contextText,
      'startPosition': startPosition,
      'endPosition': endPosition,
      'contextParagraphs': contextParagraphs,
    };
  }

  /// Получает абзац, содержащий саму цитату
  String get quoteParagraph {
    // Нормализуем текст цитаты для более точного поиска
    final normalizedQuote = _normalizeText(quote.text);
    
    // Сначала пробуем найти точное совпадение
    for (final paragraph in contextParagraphs) {
      if (_normalizeText(paragraph).contains(normalizedQuote)) {
        return paragraph;
      }
    }
    
    // Если точное совпадение не найдено, ищем по словам
    final quoteWords = normalizedQuote.split(' ')
        .where((word) => word.length > 3)  // Игнорируем короткие слова
        .toList();
    
    if (quoteWords.isEmpty) return contextParagraphs.first;
    
    // Ищем параграф с наибольшим количеством совпадающих слов
    var bestMatch = contextParagraphs.first;
    var maxMatchCount = 0;
    
    for (final paragraph in contextParagraphs) {
      final normalizedParagraph = _normalizeText(paragraph);
      final matchCount = quoteWords
          .where((word) => normalizedParagraph.contains(word))
          .length;
      
      if (matchCount > maxMatchCount) {
        maxMatchCount = matchCount;
        bestMatch = paragraph;
      }
    }
    
    return bestMatch;
  }
  
  /// Нормализует текст для сравнения
  String _normalizeText(String text) {
    return text
        .toLowerCase()
        .replaceAll(RegExp(r'[.,!?:;«»\[\]()]'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  /// Получает абзацы до цитаты (контекст "до")
  List<String> get beforeContext {
    final quoteParIndex = contextParagraphs.indexWhere(
      (p) => p.toLowerCase().contains(quote.text.toLowerCase()),
    );
    return quoteParIndex > 0 
        ? contextParagraphs.sublist(0, quoteParIndex)
        : [];
  }

  /// Получает абзацы после цитаты (контекст "после")  
  List<String> get afterContext {
    final quoteParIndex = contextParagraphs.indexWhere(
      (p) => p.toLowerCase().contains(quote.text.toLowerCase()),
    );
    return quoteParIndex >= 0 && quoteParIndex < contextParagraphs.length - 1
        ? contextParagraphs.sublist(quoteParIndex + 1)
        : [];
  }
}
