
// tools/formatter2.dart - ФОРМАТЕР ДЛЯ КОРОТКИХ ЦИТАТ
import 'dart:io';
import 'dart:convert';
import 'dart:math';

class BookFormatter2 {
  static const int TARGET_LENGTH = 200; // Целевая длина цитаты (символов)
  static const int MIN_LENGTH = 80;     // Минимальная длина
  static const int MAX_LENGTH = 400;    // Максимальная длина
  
  static Future<void> processBook(String sourcePath, String category, String author, String bookName) async {
    print('📚 Обрабатываем книгу для цитат: $bookName');
    print('📁 Исходник: $sourcePath');
    print('🎯 Размер цитат: $MIN_LENGTH-$MAX_LENGTH символов (цель: $TARGET_LENGTH)');
    
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
      
      // Предварительная очистка текста
      print('🧹 Предварительная очистка...');
      final cleanedText = _preClean(sourceContent);
      
      // Разбиваем на короткие цитаты
      print('✂️  Разбиение на цитаты...');
      final quotes = _splitIntoQuotes(cleanedText);
      print('📜 Создано цитат: ${quotes.length}');
      
      // Создаем финальные версии
      print('🔄 Создание RAW версии...');
      final rawText = _createVersionedText(quotes, aggressive: true);
      await File(rawPath).writeAsString(rawText, encoding: utf8);
      print('✅ RAW файл создан: $rawPath');
      
      print('🔄 Создание CLEANED версии...');
      final cleanedFinalText = _createVersionedText(quotes, aggressive: false);
      await File(cleanedPath).writeAsString(cleanedFinalText, encoding: utf8);
      print('✅ CLEANED файл создан: $cleanedPath');
      
      // Статистика
      _printStatistics(quotes);
      
      print('🎉 Готово! Создано 2 файла с ${quotes.length} цитатами для $bookName');
      
    } catch (e, stackTrace) {
      print('❌ Ошибка: $e');
      print('📜 Stack trace: $stackTrace');
      rethrow;
    }
  }
  
  // Предварительная очистка текста
  static String _preClean(String text) {
    return text
        // Нормализуем кавычки и символы
        .replaceAll(RegExp(r'[""„"]'), '"')
        .replaceAll(RegExp(r'[''`]'), "'")
        .replaceAll(RegExp(r'[—–−]'), '-')
        .replaceAll('…', '...')
        // Убираем служебную информацию
        .replaceAll(RegExp(r'\n\s*\d+\s*\n'), '\n\n')
        .replaceAll(RegExp(r'\n\s*[-=_*]{3,}\s*\n'), '\n\n')
        .replaceAll(RegExp(r'\n\s*(ISBN|Copyright|©|\(c\)).*\n', caseSensitive: false), '\n')
        // Убираем контрольные символы
        .replaceAll(RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]'), '')
        // Нормализуем пробелы
        .replaceAll(RegExp(r'[ \t]+'), ' ')
        .replaceAll(RegExp(r'\n\s*\n\s*\n+'), '\n\n');
  }
  
  // Разбиение текста на короткие цитаты
  static List<String> _splitIntoQuotes(String text) {
    final quotes = <String>[];
    
    // Сначала разбиваем на параграфы
    final paragraphs = text.split(RegExp(r'\n\s*\n'))
        .map((p) => p.trim())
        .where((p) => p.isNotEmpty && !_isServiceInfo(p))
        .toList();
    
    for (final paragraph in paragraphs) {
      // Если параграф уже подходящего размера - используем целиком
      if (paragraph.length >= MIN_LENGTH && paragraph.length <= MAX_LENGTH) {
        quotes.add(paragraph);
        continue;
      }
      
      // Если параграф слишком короткий - пропускаем или объединяем
      if (paragraph.length < MIN_LENGTH) {
        // Попробуем объединить с предыдущей цитатой
        if (quotes.isNotEmpty) {
          final lastQuote = quotes.last;
          final combined = '$lastQuote $paragraph';
          if (combined.length <= MAX_LENGTH) {
            quotes[quotes.length - 1] = combined;
            continue;
          }
        }
        // Если не получилось объединить и цитата совсем короткая - пропускаем
        if (paragraph.length < 50) continue;
        quotes.add(paragraph);
        continue;
      }
      
      // Если параграф слишком длинный - разбиваем
      if (paragraph.length > MAX_LENGTH) {
        final splitQuotes = _splitLongParagraph(paragraph);
        quotes.addAll(splitQuotes);
        continue;
      }
      
      quotes.add(paragraph);
    }
    
    return quotes;
  }
  
  // Разбиение длинного параграфа на цитаты
  static List<String> _splitLongParagraph(String paragraph) {
    final quotes = <String>[];
    final sentences = _splitIntoSentences(paragraph);
    
    var currentQuote = '';
    
    for (final sentence in sentences) {
      final testQuote = currentQuote.isEmpty 
          ? sentence 
          : '$currentQuote $sentence';
      
      // Если добавление предложения не превышает максимум - добавляем
      if (testQuote.length <= MAX_LENGTH) {
        currentQuote = testQuote;
      } else {
        // Если текущая цитата достаточно длинная - сохраняем
        if (currentQuote.length >= MIN_LENGTH) {
          quotes.add(currentQuote.trim());
          currentQuote = sentence;
        } else {
          // Если текущая цитата слишком короткая - объединяем принудительно
          currentQuote = testQuote;
        }
      }
      
      // Если цитата достигла целевого размера - сохраняем
      if (currentQuote.length >= TARGET_LENGTH) {
        quotes.add(currentQuote.trim());
        currentQuote = '';
      }
    }
    
    // Добавляем последнюю цитату, если она есть
    if (currentQuote.trim().isNotEmpty) {
      if (currentQuote.length >= MIN_LENGTH || quotes.isEmpty) {
        quotes.add(currentQuote.trim());
      } else {
        // Объединяем с последней цитатой, если она слишком короткая
        if (quotes.isNotEmpty) {
          quotes[quotes.length - 1] = '${quotes.last} $currentQuote'.trim();
        } else {
          quotes.add(currentQuote.trim());
        }
      }
    }
    
    return quotes;
  }
  
  // Разбиение на предложения с учетом точек
  static List<String> _splitIntoSentences(String text) {
    // Разбиваем по точкам, но учитываем сокращения
    final sentences = <String>[];
    final parts = text.split('.');
    
    var currentSentence = '';
    
    for (int i = 0; i < parts.length; i++) {
      final part = parts[i].trim();
      
      if (i == parts.length - 1) {
        // Последняя часть
        currentSentence += part;
        break;
      }
      
      currentSentence += '$part.';
      
      // Проверяем, не сокращение ли это
      if (_isSentenceEnd(part, i < parts.length - 1 ? parts[i + 1] : '')) {
        sentences.add(currentSentence.trim());
        currentSentence = '';
      }
    }
    
    if (currentSentence.trim().isNotEmpty) {
      sentences.add(currentSentence.trim());
    }
    
    return sentences.where((s) => s.isNotEmpty).toList();
  }
  
  // Проверка на конец предложения
  static bool _isSentenceEnd(String beforeDot, String afterDot) {
    // Если после точки идет заглавная буква или пробел с заглавной - это конец предложения
    if (afterDot.isEmpty) return true;
    
    final firstChar = afterDot.trim().isNotEmpty ? afterDot.trim()[0] : '';
    if (firstChar.toUpperCase() == firstChar && RegExp(r'[A-ZА-Я]').hasMatch(firstChar)) {
      return true;
    }
    
    // Проверяем на сокращения
    final words = beforeDot.split(' ');
    if (words.isNotEmpty) {
      final lastWord = words.last.toLowerCase();
      // Распространенные сокращения
      if (['т', 'п', 'г', 'в', 'н', 'э', 'см', 'др', 'пр', 'тп', 'им', 'ул'].contains(lastWord)) {
        return false;
      }
    }
    
    return true;
  }
  
  // Проверка на служебную информацию
  static bool _isServiceInfo(String text) {
    return RegExp(r'^(ISBN|Copyright|©|\(c\)|ГЛАВА\s+\w+|Chapter\s+\w+)', caseSensitive: false).hasMatch(text) ||
           RegExp(r'^[-=_*]{3,}$').hasMatch(text) ||
           RegExp(r'^\d+$').hasMatch(text) ||
           text.length < 10;
  }
  
  // Создание финального текста с позициями
  static String _createVersionedText(List<String> quotes, {required bool aggressive}) {
    final result = <String>[];
    
    for (int i = 0; i < quotes.length; i++) {
      final position = i + 1;
      final content = aggressive ? _aggressiveClean(quotes[i]) : quotes[i];
      result.add('[pos:$position] $content');
    }
    
    return result.join('\n\n');
  }
  
  // Агрессивная очистка для RAW версии (как в оригинальном форматере)
  static String _aggressiveClean(String text) {
    return text
        .replaceAll(RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]'), '')
        .replaceAll(RegExp(r'[ \t]+'), ' ')
        .trim();
  }
  
  // Статистика по длине цитат
  static void _printStatistics(List<String> quotes) {
    if (quotes.isEmpty) return;
    
    final lengths = quotes.map((q) => q.length).toList();
    lengths.sort();
    
    final minLen = lengths.first;
    final maxLen = lengths.last;
    final avgLen = lengths.reduce((a, b) => a + b) / lengths.length;
    final medianLen = lengths[lengths.length ~/ 2];
    
    print('\n📊 СТАТИСТИКА ЦИТАТ:');
    print('   Всего цитат: ${quotes.length}');
    print('   Минимальная длина: $minLen символов');
    print('   Максимальная длина: $maxLen символов');
    print('   Средняя длина: ${avgLen.round()} символов');
    print('   Медианная длина: $medianLen символов');
    
    // Распределение по размерам
    var small = lengths.where((l) => l < BookFormatter2.MIN_LENGTH).length;
    var medium = lengths.where((l) => l >= BookFormatter2.MIN_LENGTH && l <= BookFormatter2.TARGET_LENGTH).length;
    var large = lengths.where((l) => l > BookFormatter2.TARGET_LENGTH && l <= BookFormatter2.MAX_LENGTH).length;
    var xlarge = lengths.where((l) => l > BookFormatter2.MAX_LENGTH).length;
    
    print('   📏 Распределение:');
    print('      Короткие (<${BookFormatter2.MIN_LENGTH}): $small');
    print('      Средние (${BookFormatter2.MIN_LENGTH}-${BookFormatter2.TARGET_LENGTH}): $medium');
    print('      Длинные (${BookFormatter2.TARGET_LENGTH}-${BookFormatter2.MAX_LENGTH}): $large');
    print('      Очень длинные (>${BookFormatter2.MAX_LENGTH}): $xlarge');
  }
}

void main(List<String> args) async {
  if (args.length < 4) {
    print('''
📱 Quote-Sized Book Formatter для Sacral App

Использование:
  dart formatter2.dart <source_file> <category> <author> <book_name>

Особенности:
- Создает короткие цитаты размером для экрана (${BookFormatter2.MIN_LENGTH}-${BookFormatter2.MAX_LENGTH} символов)
- Заканчивает фрагменты на точку
- Сохраняет структуру [pos:N] для синхронизации

Пример:
  dart formatter2.dart source_files/metaphysics_source.txt greece aristotle metaphysics

Результат:
- RAW файл с короткими цитатами + позиции [pos:N] (для поиска)
- CLEANED файл с теми же цитатами (для чтения)
  ''');
  exit(1);
  }
  
  try {
    await BookFormatter2.processBook(args[0], args[1], args[2], args[3]);
    print('\n🎉 Успешно обработано!');
  } catch (e) {
    print('\n❌ Ошибка: $e');
    exit(1);
  }
}