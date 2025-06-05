
// tools/poets.dart - ФОРМАТЕР ДЛЯ ПОЭТИЧЕСКИХ ТЕКСТОВ
import 'dart:io';
import 'dart:convert';

class PoetsFormatter {
  static Future<void> processBook(String sourcePath, String category, String author, String bookName) async {
    print('📚 Обрабатываем поэтический текст: $bookName');
    print('📁 Исходник: $sourcePath');
    
    try {
      // Читаем исходный файл
      final sourceFile = File(sourcePath);
      if (!await sourceFile.exists()) {
        throw Exception('Исходный файл не найден: $sourcePath');
      }
      
      print('📖 Чтение файла...');
      final sourceContent = await sourceFile.readAsString(encoding: utf8);
      print('📊 Прочитано символов: ${sourceContent.length}');
      
      // Создаем папку назначения
      final targetDir = '../assets/full_texts/$category/$author';
      await Directory(targetDir).create(recursive: true);
      
      // Пути для файлов
      final rawPath = '$targetDir/${bookName}_raw.txt';
      final cleanedPath = '$targetDir/${bookName}_cleaned.txt';
      
      // Извлекаем поэтические позиции
      print('🔍 Извлечение поэтических позиций...');
      final poeticPositions = _extractPoeticPositions(sourceContent);
      print('📍 Найдено ${poeticPositions.length} поэтических позиций');
      
      // Обрабатываем для RAW версии
      print('🔄 Создание RAW версии...');
      final rawText = await _processForRaw(poeticPositions);
      print('💾 Сохранение RAW файла...');
      await File(rawPath).writeAsString(rawText, encoding: utf8);
      print('✅ RAW файл создан: $rawPath');
      
      // Создаем CLEANED версию
      print('🔄 Создание CLEANED версии...');
      final cleanedText = await _processForCleaned(poeticPositions);
      print('💾 Сохранение CLEANED файла...');
      await File(cleanedPath).writeAsString(cleanedText, encoding: utf8);
      print('✅ CLEANED файл создан: $cleanedPath');
      
      print('🎉 Готово! Создано 2 синхронизированных файла для $bookName');
      
    } catch (e, stackTrace) {
      print('❌ Ошибка: $e');
      print('📜 Stack trace: $stackTrace');
      rethrow;
    }
  }
  
  // Извлечение поэтических позиций (строфы/четверостишия + заголовки)
  static List<Map<String, dynamic>> _extractPoeticPositions(String text) {
    final positions = <Map<String, dynamic>>[];
    var currentPosition = 1;
    
    // Сначала нормализуем текст
    text = _normalizeCharacters(text);
    
    // Разбиваем на блоки по двойным переносам
    final rawBlocks = text.split(RegExp(r'\n\s*\n'));
    
    for (final block in rawBlocks) {
      final trimmed = block.trim();
      if (trimmed.isEmpty) continue;
      
      // Пропускаем служебную информацию
      if (_isServiceInfo(trimmed)) continue;
      
      // Проверяем - это заголовок или стихотворный блок
      if (_isHeader(trimmed)) {
        // Заголовок - отдельная позиция
        positions.add({
          'position': currentPosition,
          'content': trimmed,
          'type': 'header'
        });
        currentPosition++;
      } else {
        // Стихотворный блок - разбиваем на строфы
        final stanzas = _splitIntoStanzas(trimmed);
        for (final stanza in stanzas) {
          if (stanza.trim().isNotEmpty) {
            positions.add({
              'position': currentPosition,
              'content': stanza.trim(),
              'type': 'stanza'
            });
            currentPosition++;
          }
        }
      }
    }
    
    print('📊 Найдено заголовков: ${positions.where((p) => p['type'] == 'header').length}');
    print('📊 Найдено строф: ${positions.where((p) => p['type'] == 'stanza').length}');
    
    return positions;
  }
  
  // Проверка на заголовок
  static bool _isHeader(String text) {
    final lines = text.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty).toList();
    
    // Если меньше 3 строк и нет цифр в начале строк - вероятно заголовок
    if (lines.length <= 2) return true;
    
    // Если содержит ключевые слова заголовков
    final headerPatterns = [


RegExp(r'^(Песнь|Песня|Глава|Книга|Часть)\s+', caseSensitive: false),
      RegExp(r'^[IVXLCDM]+\.?\s*$'), // Римские цифры
      RegExp(r'^\d+\.?\s*$'), // Обычные цифры
    ];
    
    for (final pattern in headerPatterns) {
      if (pattern.hasMatch(text)) return true;
    }
    
    return false;
  }
  
  // Разбивка стихотворного блока на строфы
  static List<String> _splitIntoStanzas(String text) {
    final lines = text.split('\n');
    final stanzas = <String>[];
    var currentStanza = <String>[];
    var emptyLineCount = 0;
    
    for (int i = 0; i < lines.length; i++) {
      final line = lines[i].trim();
      
      if (line.isEmpty) {
        emptyLineCount++;
        // Если накопились строки и встретили пустую строку - завершаем строфу
        if (currentStanza.isNotEmpty && emptyLineCount >= 1) {
          stanzas.add(currentStanza.join('\n'));
          currentStanza.clear();
          emptyLineCount = 0;
        }
      } else {
        // Сбрасываем счетчик пустых строк
        emptyLineCount = 0;
        
        // Проверяем цифры в строке (номера строк)
        final cleanLine = _removeLineNumbers(line);
        if (cleanLine.isNotEmpty) {
          currentStanza.add(cleanLine);
        }
        
        // Если накопилось 4-6 строк - завершаем строфу (четверостишие/шестистишие)
        if (currentStanza.length >= 4) {
          // Проверяем, есть ли следующая строка и не пустая ли она
          if (i + 1 < lines.length) {
            final nextLine = lines[i + 1].trim();
            if (nextLine.isEmpty || currentStanza.length >= 6) {
              stanzas.add(currentStanza.join('\n'));
              currentStanza.clear();
            }
          }
        }
      }
    }
    
    // Добавляем оставшуюся строфу
    if (currentStanza.isNotEmpty) {
      stanzas.add(currentStanza.join('\n'));
    }
    
    return stanzas;
  }
  
  // Удаление номеров строк
  static String _removeLineNumbers(String line) {
    // Удаляем отдельно стоящие цифры
    line = line.replaceAll(RegExp(r'^\s*\d+\s*$'), '');
    // Удаляем цифры в начале строки с пробелами
    line = line.replaceAll(RegExp(r'^\s*\d+\s+'), '');
    // Удаляем цифры в конце строки
    line = line.replaceAll(RegExp(r'\s+\d+\s*$'), '');
    return line.trim();
  }
  
  // Проверка на служебную информацию
  static bool _isServiceInfo(String text) {
    return RegExp(r'^(ISBN|Copyright|©|\(c\))', caseSensitive: false).hasMatch(text) ||
           RegExp(r'^[-=_*]{3,}$').hasMatch(text);
  }
  
  // Обработка для RAW версии
  static Future<String> _processForRaw(List<Map<String, dynamic>> positions) async {
    final result = <String>[];
    
    for (final position in positions) {
      var content = position['content'] as String;
      
      // Агрессивная очистка для поиска
      content = _aggressiveClean(content);
      
      if (content.isNotEmpty) {
        result.add('[pos:${position['position']}] $content');
      }
    }
    
    return result.join('\n\n');
  }
  
  // Обработка для CLEANED версии
  static Future<String> _processForCleaned(List<Map<String, dynamic>> positions) async {
    final result = <String>[];
    
    for (final position in positions) {
      var content = position['content'] as String;
      
      // Деликатная очистка для чтения
      content = _gentleClean(content);
      
      if (content.isNotEmpty) {
        result.add('[pos:${position['position']}] $content');
      }
    }
    
    return result.join('\n\n');
  }
  
  // Нормализация символов
  static String _normalizeCharacters(String text) {
    return text
        .replaceAll(RegExp(r'[""„"]'), '"')
        .replaceAll(RegExp(r'[''`]'), "'")
        .replaceAll(RegExp(r'[—–−]'), '-')
        .replaceAll('…', '...');
  }
  
  // Агрессивная очистка для RAW
  static String _aggressiveClean(String text) {
    return text
        .replaceAll(RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]'), '') // Удаляем управляющие символы
        .replaceAll(RegExp(r'\[[\d\s\-–—.,;:!?]*\]'), '') // Удаляем сноски в квадратных скобках
        .


replaceAll(RegExp(r'[ \t]+'), ' ') // Нормализуем пробелы
        .replaceAll(RegExp(r'\n\s*\n\s*\n+'), '\n\n') // Убираем лишние переносы
        .trim();
  }
  
  // Деликатная очистка для CLEANED
  static String _gentleClean(String text) {
    return text
        .replaceAll(RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]'), '') // Удаляем только управляющие символы
        .replaceAll(RegExp(r'[ \t]+'), ' ') // Нормализуем пробелы
        .replaceAll(RegExp(r'\n\s*\n\s*\n+'), '\n\n') // Убираем лишние переносы
        .trim();
  }
}

void main(List<String> args) async {
  if (args.length < 4) {
    print('''
🎭 Poets Formatter для поэтических текстов

Использование:
  dart poets.dart <source_file> <category> <author> <book_name>

Пример:
  dart poets.dart source_files/odyssey.txt greece homer odyssey
  dart poets.dart source_files/beowulf.txt england anonymous beowulf

Результат:
  - RAW файл с агрессивной очисткой + позиции [pos:N] (для поиска)
  - CLEANED файл с деликатной обработкой + те же позиции (для чтения)
  - Автоматическое разбиение на строфы/четверостишия
    ''');
    exit(1);
  }
  
  try {
    await PoetsFormatter.processBook(args[0], args[1], args[2], args[3]);
    print('\n🎉 Поэтический текст успешно обработан!');
  } catch (e) {
    print('\n❌ Ошибка: $e');
    exit(1);
  }
}
