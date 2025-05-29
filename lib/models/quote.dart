// lib/models/quote.dart
class Quote {
  final String id;
  final String text;
  final String author;
  final String source; // название книги/произведения
  final String category; // greece, nordic, philosophy
  final int position; // позиция в тексте [pos:N]
  final String? translation;
  final DateTime? dateAdded;
  final bool isFavorite;
  final String theme; // Добавляем theme для совместимости
  final String context; // Добавляем context для совместимости

  const Quote({
    required this.id,
    required this.text,
    required this.author,
    required this.source,
    required this.category,
    required this.position,
    this.translation,
    this.dateAdded,
    this.isFavorite = false,
    required this.theme,
    this.context = '',
  });

  // Добавляем геттер theme который возвращает category
  String get themeId => category;

  factory Quote.fromJson(Map<String, dynamic> json) {
    return Quote(
      id: json['id'] as String,
      text: json['text'] as String,
      author: json['author'] as String,
      source: json['source'] as String,
      category: json['category'] as String,
      position: json['position'] as int,
      translation: json['translation'] as String?,
      dateAdded: json['dateAdded'] != null 
          ? DateTime.parse(json['dateAdded'] as String)
          : null,
      isFavorite: json['isFavorite'] as bool? ?? false,
      theme: json['theme'] as String? ?? json['category'] as String,
      context: json['context'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'text': text,
      'author': author,
      'source': source,
      'category': category,
      'position': position,
      'translation': translation,
      'dateAdded': dateAdded?.toIso8601String(),
      'isFavorite': isFavorite,
      'theme': theme,
      'context': context,
    };
  }

  Quote copyWith({
    String? id,
    String? text,
    String? author,
    String? source,
    String? category,
    int? position,
    String? translation,
    DateTime? dateAdded,
    bool? isFavorite,
    String? theme,
    String? context,
  }) {
    return Quote(
      id: id ?? this.id,
      text: text ?? this.text,
      author: author ?? this.author,
      source: source ?? this.source,
      category: category ?? this.category,
      position: position ?? this.position,
      translation: translation ?? this.translation,
      dateAdded: dateAdded ?? this.dateAdded,
      isFavorite: isFavorite ?? this.isFavorite,
      theme: theme ?? this.theme,
      context: context ?? this.context,
    );
  }

  @override
  String toString() {
    return 'Quote(id: $id, text: ${text.substring(0, text.length > 50 ? 50 : text.length)}..., author: $author)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Quote && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}