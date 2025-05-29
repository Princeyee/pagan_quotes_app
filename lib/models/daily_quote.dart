// lib/models/daily_quote.dart
import 'quote.dart';
import 'quote_context.dart';

class DailyQuote {
  final Quote quote;
  final DateTime date;
  final QuoteContext? context; // может быть загружен позже
  final bool isViewed;
  final bool isContextViewed;

  const DailyQuote({
    required this.quote,
    required this.date,
    this.context,
    this.isViewed = false,
    this.isContextViewed = false,
  });

  factory DailyQuote.fromJson(Map<String, dynamic> json) {
    return DailyQuote(
      quote: Quote.fromJson(json['quote'] as Map<String, dynamic>),
      date: DateTime.parse(json['date'] as String),
      context: json['context'] != null
          ? QuoteContext.fromJson(json['context'] as Map<String, dynamic>)
          : null,
      isViewed: json['isViewed'] as bool? ?? false,
      isContextViewed: json['isContextViewed'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'quote': quote.toJson(),
      'date': date.toIso8601String(),
      'context': context?.toJson(),
      'isViewed': isViewed,
      'isContextViewed': isContextViewed,
    };
  }

  DailyQuote copyWith({
    Quote? quote,
    DateTime? date,
    QuoteContext? context,
    bool? isViewed,
    bool? isContextViewed,
  }) {
    return DailyQuote(
      quote: quote ?? this.quote,
      date: date ?? this.date,
      context: context ?? this.context,
      isViewed: isViewed ?? this.isViewed,
      isContextViewed: isContextViewed ?? this.isContextViewed,
    );
  }

  /// Проверяет, является ли эта цитата сегодняшней
  bool get isToday {
    final now = DateTime.now();
    return date.year == now.year &&
           date.month == now.month &&
           date.day == now.day;
  }

  /// Получает красивое отображение даты
  String get formattedDate {
    final months = [
      'января', 'февраля', 'марта', 'апреля', 'мая', 'июня',
      'июля', 'августа', 'сентября', 'октября', 'ноября', 'декабря'
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }
}