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
    // При contextSize: 1 мы получаем 3 параграфа (1 до + 1 цитата + 1 после)
    // Центральный параграф (индекс 1) должен содержать цитату
    final centerIndex = contextParagraphs.length ~/ 2;
    
    if (centerIndex < contextParagraphs.length) {
      return contextParagraphs[centerIndex];
    }
    
    // Fallback: возвращаем первый параграф
    return contextParagraphs.isNotEmpty ? contextParagraphs.first : '';
  }

  /// Получает абзацы до цитаты (контекст "до")
  List<String> get beforeContext {
    // При contextSize: 1 мы получаем 3 параграфа (1 до + 1 цитата + 1 после)
    // Центральный параграф (индекс 1) должен содержать цитату
    final centerIndex = contextParagraphs.length ~/ 2;
    
    // Возвращаем все параграфы до центрального (не включая его)
    return contextParagraphs.sublist(0, centerIndex);
  }

  /// Получает абзацы после цитаты (контекст "после")  
  List<String> get afterContext {
    // При contextSize: 1 мы получаем 3 параграфа (1 до + 1 цитата + 1 после)
    // Центральный параграф (индекс 1) должен содержать цитату
    final centerIndex = contextParagraphs.length ~/ 2;
    
    // Возвращаем все параграфы после центрального (не включая его)
    return contextParagraphs.sublist(centerIndex + 1);
  }
}
