// lib/models/book_source.dart
class BookSource {
  final String id;
  final String title;
  final String author;
  final String category; // greece, nordic, philosophy, pagan
  final String language; // en, ru
  final String? translator;
  final String rawFilePath; // путь к raw.txt
  final String cleanedFilePath; // путь к cleaned.txt
  final bool hasAudioVersion; // флаг наличия аудиоверсии

  const BookSource({
    required this.id,
    required this.title,
    required this.author,
    required this.category,
    required this.language,
    this.translator,
    required this.rawFilePath,
    required this.cleanedFilePath,
    this.hasAudioVersion = false,
  });

  factory BookSource.fromJson(Map<String, dynamic> json) {
    return BookSource(
      id: json['id'] as String,
      title: json['title'] as String,
      author: json['author'] as String,
      category: json['category'] as String,
      language: json['language'] as String,
      translator: json['translator'] as String?,
      rawFilePath: json['rawFilePath'] as String,
      cleanedFilePath: json['cleanedFilePath'] as String,
      hasAudioVersion: json['hasAudioVersion'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'author': author,
      'category': category,
      'language': language,
      'translator': translator,
      'rawFilePath': rawFilePath,
      'cleanedFilePath': cleanedFilePath,
      'hasAudioVersion': hasAudioVersion,
    };
  }

  /// Генерирует красивое отображение источника
  String get displayName {
    final base = '$author - $title';
    return translator != null ? '$base (пер. $translator)' : base;
  }

  /// Путь к каталогу книги
  String get directoryPath {
    final parts = rawFilePath.split('/');
    parts.removeLast(); // убираем имя файла
    return parts.join('/');
  }

  /// Получает категорию на русском
  String get categoryDisplay {
    switch (category) {
      case 'greece':
        return 'Греция';
      case 'nordic':
        return 'Север';
      case 'philosophy':
        return 'Философия';
      case 'pagan':
        return 'Язычество & Традиционализм';
      default:
        return category;
    }
  }

  @override
  String toString() {
    return 'BookSource(id: $id, title: $title, author: $author)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is BookSource && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}