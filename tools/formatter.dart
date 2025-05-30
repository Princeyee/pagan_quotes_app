
// tools/formatter.dart - ИСПРАВЛЕННАЯ ВЕРСИЯ
import 'dart:io';
import 'dart:convert';

class BookFormatter {
  static Future<void> processBook(String sourcePath, String category, String author, String bookName) async {
    print('📚 Обрабатываем книгу: $bookName');
    print('📁 Исходник: $sourcePath');
    
    try {
      // Читаем исходный файл
      final sourceFile = File(sourcePath);
      if (!await sourceFile.exists()) {
        throw Exception('Исходный файл не найден: $sourcePath');
      }
      
      final sourceContent = await sourceFile.readAsString(encoding: utf8);
      print('📖 Прочитано символов: ${sourceContent.length}');
      
      // Создаем папку назначения
      final targetDir = 'assets/full_texts/$category/$author';
      await Directory(targetDir).create(recursive: true);
      
      // Пути для файлов
      final rawPath = '$targetDir/${bookName}_raw.txt';
      final cleanedPath = '$targetDir/${bookName}_cleaned.txt';
      
      // Обрабатываем для RAW версии (агрессивная очистка)
      final rawText = _processForRaw(sourceContent);
      await File(rawPath).writeAsString(rawText, encoding: utf8);
      print('✅ RAW файл: $rawPath');
      
      // Создаем CLEANED версию (деликатная обработка, но с теми же позициями)
      final cleanedText = _processForCleaned(sourceContent, rawText);
      await File(cleanedPath).writeAsString(cleanedText, encoding: utf8);
      print('✅ CLEANED файл: $cleanedPath');
      
      print('🎉 Готово! Создано 2 синхронизированных файла для $bookName');
      
    } catch (e) {
      print('❌ Ошибка: $e');
      rethrow;
    }
  }
  
  // Агрессивная обработка для RAW версии (для поиска)
  static String _processForRaw(String text) {
    print('🔍 Создаем RAW версию (для поиска)...');
    
    // 1. Убираем ВСЕ квадратные скобки
    text = _removeAllBrackets(text);
    
    // 2. Нормализуем символы
    text = _normalizeCharacters(text);
    
    // 3. Агрессивная очистка
    text = _aggressiveClean(text);
    
    // 4. Нормализуем переносы
    text = text.replaceAll(RegExp(r'\r\n|\r'), '\n');
    text = text.replaceAll(RegExp(r'\n{4,}'), '\n\n\n');
    
    // 5. Склеиваем строки
    text = _joinLines(text);
    
    // 6. Создаем абзацы
    text = _makeParagraphs(text);
    
    // 7. Добавляем маркеры
    text = _addMarkers(text);
    
    return text;
  }
  
  // Деликатная обработка для CLEANED версии (для чтения)
  static String _processForCleaned(String originalText, String rawText) {
    print('📖 Создаем CLEANED версию (для чтения)...');
    
    // Извлекаем позиции из RAW версии
    final rawParagraphs = _extractRawParagraphs(rawText);
    print('📊 Найдено RAW абзацев: ${rawParagraphs.length}');
    
    String cleanedText = originalText;
    
    // 1. Убираем квадратные скобки (как в RAW)
    cleanedText = _removeAllBrackets(cleanedText);
    
    // 2. Нормализуем символы
    cleanedText = _normalizeCharacters(cleanedText);
    
    // 3. Деликатная очистка
    cleanedText = _gentleClean(cleanedText);
    
    // 4. Нормализуем переносы
    cleanedText = cleanedText.replaceAll(RegExp(r'\r\n|\r'), '\n');
    
    // 5. Деликатное склеивание
    cleanedText = _gentleJoinLines(cleanedText);
    
    // 6. Синхронизируем с RAW позициями
    cleanedText = _synchronizeWithRaw(cleanedText, rawParagraphs);
    
    return cleanedText;
  }
  
  // Убираем ВСЕ квадратные скобки
  static String _removeAllBrackets(String text) {
    text = text.replaceAll(RegExp(r'\[[^\]]*\]'), '');
    text = text.replaceAll('[', '').replaceAll(']', '');
    text = text.replaceAll('［', '').replaceAll('］', '');
    return text;
  }
  
  // Нормализуем символы
  static String _normalizeCharacters(String text) {
    text = text.replaceAll(RegExp(r'[""„"]'), '"');
    text = text.replaceAll(RegExp(r'[''`]'), "'");
    text = text.replaceAll(RegExp(r'[—–−]'), '-');
    text = text.replaceAll('…', '...');
    return text;
  }
  
  // Агрессивная очистка для поиска
  static String _aggressiveClean(String text) {
    // Номера страниц
    text = text.


replaceAll(RegExp(r'\n\s*\d+\s*\n'), '\n\n');
    text = text.replaceAll(RegExp(r'\n\s*-\s*\d+\s*-\s*\n'), '\n\n');
    
    // Служебные символы
    text = text.replaceAll(RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]'), '');
    
    // Множественные пробелы
    text = text.replaceAll(RegExp(r'[ \t]+'), ' ');
    
    // Линии разделителей
    text = text.replaceAll(RegExp(r'\n\s*[-=_*]{3,}\s*\n'), '\n\n');
    
    // Служебная информация
    text = text.replaceAll(RegExp(r'\n\s*(ISBN|Copyright|©|\(c\)).*\n', caseSensitive: false), '\n');
    
    return text;
  }
  
  // Деликатная очистка для чтения
  static String _gentleClean(String text) {
    // Только самое необходимое
    text = text.replaceAll(RegExp(r'\n\s*\d+\s*\n'), '\n\n'); // Номера страниц
    text = text.replaceAll(RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]'), ''); // Служебные символы
    text = text.replaceAll(RegExp(r'[ \t]+'), ' '); // Множественные пробелы
    text = text.replaceAll(RegExp(r'\n\s*(ISBN|Copyright|©|\(c\)).*\n', caseSensitive: false), '\n'); // Служебная информация
    
    return text;
  }
  
  // Склеивание строк для RAW
  static String _joinLines(String text) {
    final lines = text.split('\n');
    final result = <String>[];
    
    for (int i = 0; i < lines.length; i++) {
      final current = lines[i].trim();
      
      if (current.isEmpty) {
        result.add('');
        continue;
      }
      
      // ИСПРАВЛЕНО: добавил закрывающую скобку в RegExp
      if (i < lines.length - 1 && 
          !RegExp(r'[.!?;:,]$').hasMatch(current) &&
          lines[i + 1].trim().isNotEmpty &&
          !RegExp(r'^[A-ZА-Я]').hasMatch(lines[i + 1].trim()) &&
          current.length > 10) {
        
        final next = lines[i + 1].trim();
        result.add('$current $next');
        i++;
      } else {
        result.add(current);
      }
    }
    
    return result.join('\n');
  }
  
  // Деликатное склеивание для CLEANED
  static String _gentleJoinLines(String text) {
    final lines = text.split('\n');
    final result = <String>[];
    
    for (int i = 0; i < lines.length; i++) {
      final current = lines[i].trim();
      
      if (current.isEmpty) {
        result.add('');
        continue;
      }
      
      // Более деликатное склеивание
      if (i < lines.length - 1 && 
          current.length > 20 &&
          !RegExp(r'[.!?;:]$').hasMatch(current) &&
          lines[i + 1].trim().isNotEmpty &&
          !RegExp(r'^[A-ZА-Я]').hasMatch(lines[i + 1].trim()) &&
          lines[i + 1].trim().length > 10) {
        
        final next = lines[i + 1].trim();
        result.add('$current $next');
        i++;
      } else {
        result.add(current);
      }
    }
    
    return result.join('\n');
  }
  
  // Создание абзацев
  static String _makeParagraphs(String text) {
    final lines = text.split('\n');
    final paragraphs = <String>[];
    final current = <String>[];
    
    for (final line in lines) {
      final trimmed = line.trim();
      
      if (trimmed.isEmpty) {
        if (current.isNotEmpty) {
          paragraphs.add(current.join(' ').trim());
          current.clear();
        }
      } else {
        current.add(trimmed);
      }
    }
    
    if (current.isNotEmpty) {
      paragraphs.add(current.join(' ').trim());
    }
    
    final filtered = paragraphs.where((p) => p.length > 5).toList();
    return filtered.join('\n\n');
  }
  
  // Добавление маркеров
  static String _addMarkers(String text) {
    final paragraphs = text.split('\n\n');
    final result = <String>[];
    
    for (int i = 0; i < paragraphs.length; i++) {
      final paragraph = paragraphs[i].trim();
      if (paragraph.isNotEmpty) {
        result.add('[pos:${i + 1}] $paragraph');
      }
    }
    
    return result.join('\n\n');
  }
  
  // Извлечение абзацев из RAW
  static List<String> _extractRawParagraphs(String rawText) {
    final paragraphs = <String>[];
    final lines = rawText.split('\n\n');
    
    for (final line in lines) {
      final match = RegExp(r'\[pos:\d+\]\s*(.*)').firstMatch(line.trim());


if (match != null) {
        paragraphs.add(match.group(1)!.trim());
      }
    }
    
    return paragraphs;
  }
  
  // Синхронизация CLEANED с RAW позициями
  static String _synchronizeWithRaw(String cleanedText, List<String> rawParagraphs) {
    final lines = cleanedText.split('\n').where((line) => line.trim().isNotEmpty).toList();
    
    if (rawParagraphs.isEmpty || lines.isEmpty) {
      return cleanedText;
    }
    
    final result = <String>[];
    final linesPerParagraph = (lines.length / rawParagraphs.length).ceil();
    
    int lineIndex = 0;
    
    for (int i = 0; i < rawParagraphs.length; i++) {
      final endIndex = (lineIndex + linesPerParagraph).clamp(0, lines.length);
      
      if (lineIndex < lines.length) {
        final paragraphLines = lines.sublist(lineIndex, endIndex);
        final paragraphText = paragraphLines.join(' ').trim();
        
        if (paragraphText.isNotEmpty) {
          result.add('[pos:${i + 1}] $paragraphText');
        }
        
        lineIndex = endIndex;
      }
    }
    
    return result.join('\n\n');
  }
}

void main(List<String> args) async {
  if (args.length < 4) {
    print('''
📚 Book Formatter для Sacral App

Использование:
  dart formatter.dart <source_file> <category> <author> <book_name>

Пример:
  dart formatter.dart source_files/metaphysics_source.txt greece aristotle metaphysics

Результат:
  - RAW файл с агрессивной очисткой + позиции [pos:N] (для поиска)
  - CLEANED файл с деликатной обработкой + те же позиции (для чтения)
    ''');
    exit(1);
  }
  
  try {
    await BookFormatter.processBook(args[0], args[1], args[2], args[3]);
    print('\n🎉 Успешно обработано!');
  } catch (e) {
    print('\n❌ Ошибка: $e');
    exit(1);
  }
}
