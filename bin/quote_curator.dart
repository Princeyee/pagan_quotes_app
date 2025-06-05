// bin/quote_curator.dart - УПРОЩЕННАЯ ВЕРСИЯ
import 'dart:io';
import 'dart:convert';
import 'dart:math';

class Quote {
  final String id;
  final String text;
  final String author;
  final String source;
  final String category;
  final int position;
  final bool approved;
  final DateTime reviewedAt;

  Quote({
    required this.id,
    required this.text,
    required this.author,
    required this.source,
    required this.category,
    required this.position,
    required this.approved,
    required this.reviewedAt,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'text': text,
    'author': author,
    'source': source,
    'category': category,
    'position': position,
    'approved': approved,
    'reviewedAt': reviewedAt.toIso8601String(),
  };

  factory Quote.fromJson(Map<String, dynamic> json) => Quote(
    id: json['id'],
    text: json['text'],
    author: json['author'],
    source: json['source'],
    category: json['category'],
    position: json['position'],
    approved: json['approved'],
    reviewedAt: DateTime.parse(json['reviewedAt']),
  );
}

class SimpleCurator {
  final String cleanedTextPath;
  final String outputPath;
  final String category;
  final String author;
  final String source;
  
  List<String> paragraphs = [];
  List<Quote> processedQuotes = [];
  
  SimpleCurator({
    required this.cleanedTextPath,
    required this.outputPath,
    required this.category,
    required this.author,
    required this.source,
  });

  Future<void> run() async {
    print('\n📚 ПРОСТОЙ ОТБОР ЦИТАТ');
    print('=' * 40);
    print('Книга: $source');
    print('Автор: $author');
    print('=' * 40);

    await loadText();
    await loadExisting();
    showStats();
    await mainLoop();
  }

  Future<void> loadText() async {
    try {
      final file = File(cleanedTextPath);
      final content = await file.readAsString();
      
      // Разбиваем на параграфы
      final parts = content.split(RegExp(r'\[pos:\d+\]'));
      paragraphs = parts
          .where((p) => p.trim().isNotEmpty)
          .map((p) => p.trim())
          .toList();
      
      print('✅ Загружено ${paragraphs.length} параграфов');
    } catch (e) {
      print('❌ Ошибка загрузки: $e');
      exit(1);
    }
  }

  Future<void> loadExisting() async {
    try {
      final file = File(outputPath);
      if (await file.exists()) {
        final content = await file.readAsString();
        final List<dynamic> jsonData = json.decode(content);
        processedQuotes = jsonData.map((j) => Quote.fromJson(j)).toList();
        print('✅ Загружено ${processedQuotes.length} обработанных цитат');
      }
    } catch (e) {
      print('📝 Начинаем с нуля');
    }
  }

  void showStats() {
    final approved = processedQuotes.where((q) => q.approved).length;
    final rejected = processedQuotes.where((q) => !q.approved).length;
    final remaining = paragraphs.length - processedQuotes.length;
    
    print('\n📊 СТАТИСТИКА:');
    print('Всего параграфов: ${paragraphs.length}');
    print('Обработано: ${processedQuotes.length}');
    print('Одобрено: $approved');
    print('Отклонено: $rejected');
    print('Осталось: $remaining');
    print('-' * 40);
  }

  Future<void> mainLoop() async {
    print('\nКоманды:');
    print('[n] Следующая цитата');
    print('[s] Статистика');
    print('[done] Экспорт и выход');
    print('[q] Выход без сохранения');
    print('');

    while (true) {
      stdout.write('> ');
      final command = stdin.readLineSync()?.trim().toLowerCase() ?? '';
      
      switch (command) {
        case 'n':
          await reviewNext();
          break;
        case 's':
          showStats();
          break;
        case 'done':
          await exportAndQuit();
          return;
        case 'q':
          return;
        default:
          print('❌ Неизвестная команда');
      }
    }
  }

  Future<void> reviewNext() async {
    // Находим следующий необработанный параграф
    final processedIndices = processedQuotes.map((q) => q.position).toSet();
    
    int? nextIndex;
    for (int i = 0; i < paragraphs.length; i++) {
      if (!processedIndices.contains(i)) {
        nextIndex = i;
        break;
      }
    }
    
    if (nextIndex == null) {
      print('✅ Все параграфы обработаны!');
      await exportAndQuit();
      return;
    }
    
    await reviewParagraph(nextIndex);
  }

  Future<void> reviewParagraph(int index) async {
    final paragraph = paragraphs[index];
    
    // Показываем параграф
    print('\n' + '=' * 60);
    print('ПАРАГРАФ #$index');
    print('=' * 60);
    print('');
    
    // Красиво форматируем текст
    _printFormatted(paragraph);
    
    print('\n' + '-' * 60);
    print('[y] ДА, хорошая цитата   [n] НЕТ, плохая   [s] Пропустить');
    
    stdout.write('Ваше решение: ');
    final decision = stdin.readLineSync()?.trim().toLowerCase() ?? 's';
    
    bool? approved;
    
    switch (decision) {
      case 'y':
      case 'yes':
      case 'да':
        approved = true;
        print('✅ ОДОБРЕНО');
        break;
      case 'n':
      case 'no':
      case 'нет':
        approved = false;
        print('❌ ОТКЛОНЕНО');
        break;
      case 's':
      case 'skip':
        print('⏭️ Пропущено');
        return;
      default:
        print('❓ Неясное решение, пропускаем');
        return;
    }
    
    // Создаем запись
    final quote = Quote(
      id: '${category}_${author}_$index',
      text: paragraph,
      author: author,
      source: source,
      category: category,
      position: index,
      approved: approved,
      reviewedAt: DateTime.now(),
    );
    
    // Удаляем старую версию если есть
    processedQuotes.removeWhere((q) => q.position == index);
    processedQuotes.add(quote);
    
    // Сохраняем
    await save();
    
    final remaining = paragraphs.length - processedQuotes.length;
    print('Прогресс: ${processedQuotes.length}/${paragraphs.length} (осталось: $remaining)');
  }

  void _printFormatted(String text) {
    // Красиво форматируем текст с переносами
    final words = text.split(' ');
    var currentLine = '';
    
    for (final word in words) {
      if (currentLine.length + word.length > 70) {
        print(currentLine);
        currentLine = word;
      } else {
        currentLine += (currentLine.isEmpty ? '' : ' ') + word;
      }
    }
    if (currentLine.isNotEmpty) print(currentLine);
  }

  Future<void> save() async {
    try {
      final file = File(outputPath);
      await file.writeAsString(
        JsonEncoder.withIndent('  ').convert(
          processedQuotes.map((q) => q.toJson()).toList()
        )
      );
    } catch (e) {
      print('❌ Ошибка сохранения: $e');
    }
  }

  Future<void> exportAndQuit() async {
    await save();
    
    // Экспортируем только одобренные
    final approved = processedQuotes.where((q) => q.approved).toList();
    final approvedPath = outputPath.replaceAll('.json', '_approved.json');
    
    try {
      final file = File(approvedPath);
      await file.writeAsString(
        JsonEncoder.withIndent('  ').convert(
          approved.map((q) => q.toJson()).toList()
        )
      );
      
      print('\n✅ Обработано: ${processedQuotes.length} цитат');
      print('✅ Одобрено: ${approved.length} цитат');
      print('✅ Экспорт: $approvedPath');
      print('\n🔥 Теперь добавь файл в pubspec.yaml:');
      print('   - $approvedPath');
      print('\nГотово! 👋');
    } catch (e) {
      print('❌ Ошибка экспорта: $e');
    }
  }
}

void main(List<String> args) async {
  if (args.length < 5) {
    print('Использование:');
    print('dart quote_curator.dart <текст> <выход> <категория> <автор> <название>');
    print('');
    print('Пример:');
    print('dart quote_curator.dart assets/texts/greece/aristotle_cleaned.txt assets/curated/aristotle.json greece Aristotle "Этика"');
    exit(1);
  }

  final curator = SimpleCurator(
    cleanedTextPath: args[0],
    outputPath: args[1],
    category: args[2],
    author: args[3],
    source: args[4],
  );

  await curator.run();
}


