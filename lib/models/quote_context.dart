// lib/models/quote_context.dart
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
  String get quoteParentalph {
    return contextParagraphs.firstWhere(
      (paragraph) => paragraph.toLowerCase().contains(quote.text.toLowerCase()),
      orElse: () => contextParagraphs.first,
    );
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