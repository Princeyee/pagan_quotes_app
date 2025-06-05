
// bin/random_curator.dart - СЛУЧАЙНЫЙ ОТБОР ИЗ ВСЕХ КНИГ
import 'dart:io';
import 'dart:convert';
import 'dart:math';

class BookInfo {
  final String path;
  final String category;
  final String author;
  final String source;
  
  BookInfo({
    required this.path,
    required this.category,
    required this.author,
    required this.source,
  });
}

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

class Paragraph {
  final String text;
  final BookInfo book;
  final int position;
  final String id;
  
  Paragraph({
    required this.text,
    required this.book,
    required this.position,
    required this.id,
  });
}

class RandomCurator {
  final String outputPath;
  final Random random = Random();
  
  List<BookInfo> books = [];
  List<Paragraph> allParagraphs = [];
  List<Quote> processedQuotes = [];
  Set<String> processedIds = {};
  
  // Для циклического отбора
  Map<String, List<Paragraph>> paragraphsByBook = {};
  int currentBookIndex = 0;
  
  RandomCurator({required this.outputPath});

  Future<void> run() async {
    print('\n🎲 СЛУЧАЙНЫЙ ОТБОР ЦИТАТ ИЗ ВСЕХ КНИГ');
    print('=' * 50);

    setupBooks();
    await loadAllTexts();
    await loadExisting();
    showStats();
    await mainLoop();
  }

  void setupBooks() {
    books = [
      // Греция - античная философия
      BookInfo(path: 'assets/full_texts/greece/aristotle/metaphysics_cleaned.txt', category: 'greece', author: 'Аристотель', source: 'Метафизика'),
      BookInfo(path: 'assets/full_texts/greece/aristotle/ethics_cleaned.txt', category: 'greece', author: 'Аристотель', source: 'Этика'),
      BookInfo(path: 'assets/full_texts/greece/aristotle/politics_cleaned.txt', category: 'greece', author: 'Аристотель', source: 'Политика'),
      BookInfo(path: 'assets/full_texts/greece/aristotle/rhetoric_cleaned.txt', category: 'greece', author: 'Аристотель', source: 'Риторика'),
      BookInfo(path: 'assets/full_texts/greece/plato/sophist_cleaned.txt', category: 'greece', author: 'Платон', source: 'Софист'),
      BookInfo(path: 'assets/full_texts/greece/plato/parmenides_cleaned.txt', category: 'greece', author: 'Платон', source: 'Парменид'),
      BookInfo(path: 'assets/full_texts/greece/homer/iliad_cleaned.txt', category: 'greece', author: 'Гомер', source: 'Илиада'),
      BookInfo(path: 'assets/full_texts/greece/homer/odyssey_cleaned.txt', category: 'greece', author: 'Гомер', source: 'Одиссея'),
      BookInfo(path: 'assets/full_texts/greece/hesiod/labour_and_days_cleaned.txt', category: 'greece', author: 'Гесиод', source: 'Труды и дни'),
      
      // Север - эпос и мифология
      BookInfo(path: 'assets/full_texts/nordic/folk/beowulf_cleaned.txt', category: 'nordic', author: 'Аноним', source: 'Беовульф'),
      BookInfo(path: 'assets/full_texts/nordic/folk/elder_edda_cleaned.txt', category: 'nordic', author: 'Аноним', source: 'Старшая Эдда'),
      
      // Философия - современная мысль
      BookInfo(path: 'assets/full_texts/philosophy/heidegger/being_and_time_cleaned.txt', category: 'philosophy', author: 'Хайдеггер', source: 'Бытие и время'),
      BookInfo(path: 'assets/full_texts/philosophy/heidegger/what_means_to_think_cleaned.txt', category: 'philosophy', author: 'Хайдеггер', source: 'Что значит мыслить'),
      BookInfo(path: 'assets/full_texts/philosophy/nietzsche/antichrist_cleaned.txt', category: 'philosophy', author: 'Ницше', source: 'Антихрист'),
      BookInfo(path: 'assets/full_texts/philosophy/nietzsche/gay_science_cleaned.txt', category: 'philosophy', author: 'Ницше', source: 'Веселая наука'),
      BookInfo(path: 'assets/full_texts/philosophy/nietzsche/thus_spoke_zarathustra_cleaned.txt', category: 'philosophy', author: 'Ницше', source: 'Заратустра'),
      BookInfo(path: 'assets/full_texts/philosophy/nietzsche/birth_of_tragedy_cleaned.txt', category: 'philosophy', author: 'Ницше', source: 'Рождение трагедии'),
      BookInfo(path: 'assets/full_texts/philosophy/nietzsche/beyond_good_and_evil_cleaned.txt', category: 'philosophy', author: 'Ницше', source: 'По ту сторону добра и зла'),
      BookInfo(path: 'assets/full_texts/philosophy/schopenhauer/world_as_will_and_representation_cleaned.txt', category: 'philosophy', author: 'Шопенгауэр', source: 'Мир как воля'),
      BookInfo(path: 'assets/full_texts/philosophy/schopenhauer/aphorisms_on_wisdom_of_life_cleaned.txt', category: 'philosophy', author: 'Шопенгауэр', source: 'Афоризмы'),
      
      // Язычество - традиция и символизм
      BookInfo(path: 'assets/full_texts/pagan/julius_evola/pagan_imperialism_cleaned.txt', category: 'pagan', author: 'Эвола', source: 'Языческий империализм'),
      BookInfo(path: 'assets/full_texts/pagan/julius_evola/metaphysics_of_sex_cleaned.txt', category: 'pagan', author: 'Эвола', source: 'Метафизика пола'),
      BookInfo(path: 'assets/full_texts/pagan/julius_evola/men_among_ruins_cleaned.txt', category: 'pagan', author: 'Эвола', source: 'Люди и руины'),
      BookInfo(path: 'assets/full_texts/pagan/mercea_eliade/sacred_and_profane_cleaned.txt', category: 'pagan', author: 'Элиаде', source: 'Священное и мирское'),
      BookInfo(path: 'assets/full_texts/pagan/mercea_eliade/myth_of_eternal_return_cleaned.txt', category: 'pagan', author: 'Элиаде', source: 'Миф о вечном возвращении'),
      BookInfo(path: 'assets/full_texts/pagan/mercea_eliade/history_of_religious_ideas_vol1_cleaned.txt', category: 'pagan', author: 'Элиаде', source: 'История веры том 1'),
      BookInfo(path: 'assets/full_texts/pagan/mercea_eliade/history_of_religious_ideas_vol2_cleaned.txt', category: 'pagan', author: 'Элиаде', source: 'История веры том 2'),
      BookInfo(path: 'assets/full_texts/pagan/mercea_eliade/history_of_religious_ideas_vol3_cleaned.txt', category: 'pagan', author: 'Элиаде', source: 'История веры том 3'),
      BookInfo(path: 'assets/full_texts/pagan/askr_svarte/pagan_identity_xxi_cleaned.txt', category: 'pagan', author: 'Askr Svarte', source: 'Идентичность язычника в 21 веке'),
      BookInfo(path: 'assets/full_texts/pagan/askr_svarte/priblizheniye_i_okruzheniye_cleaned.txt', category: 'pagan', author: 'Askr Svarte', source: 'Приближение и окружение'),
      BookInfo(path: 'assets/full_texts/pagan/askr_svarte/polemos_cleaned.txt', category: 'pagan', author: 'Askr Svarte', source: 'Polemos'),
    ];
  }

  Future<void> loadAllTexts() async {
    print('📚 Загружаем все книги...');
    
    for (final book in books) {
      try {
        final file = File(book.path);
        if (!await file.exists()) {
          print('⚠️  Файл не найден: ${book.path}');
          continue;
        }
        
        final content = await file.readAsString();
        final parts = content.split(RegExp(r'\[pos:\d+\]'));
        
        final bookParagraphs = <Paragraph>[];
        
        for (int i = 0; i < parts.length; i++) {
          final text = parts[i].trim();
          if (text.isNotEmpty && text.length > 20) { // Минимальная длина
            final id = '${book.category}_${book.author}_${book.source}_$i';
            final paragraph = Paragraph(
              text: text,
              book: book,
              position: i,
              id: id,
            );
            allParagraphs.add(paragraph);
            bookParagraphs.add(paragraph);
          }
        }
        
        // Группируем по книгам для циклического отбора
        final bookKey = '${book.author}_${book.source}';
        paragraphsByBook[bookKey] = bookParagraphs;
        
        print('✅ ${book.author} - ${book.source}: ${bookParagraphs.length} параграфов');
      } catch (e) {
        print('❌ Ошибка загрузки ${book.path}: $e');
      }
    }
    
    // Перемешиваем порядок книг для разнообразия
    final bookKeys = paragraphsByBook.keys.toList();
    bookKeys.shuffle(random);
    
    // Пересоздаем paragraphsByBook в новом порядке
    final shuffledMap = <String, List<Paragraph>>{};
    for (final key in bookKeys) {
      shuffledMap[key] = paragraphsByBook[key]!;
    }
    paragraphsByBook = shuffledMap;
    
    print('\n📊 Всего загружено: ${allParagraphs.length} параграфов из ${paragraphsByBook.length} книг');
    print('🔄 Установлен циклический режим отбора: по 1 цитате из каждой книги');
  }

  Future<void> loadExisting() async {
    try {
      final file = File(outputPath);
      if (await file.exists()) {
        final content = await file.readAsString();
        final List<dynamic> jsonData = json.decode(content);
        processedQuotes = jsonData.map((j) => Quote.fromJson(j)).toList();
        processedIds = processedQuotes.map((q) => q.id).toSet();
        print('✅ Загружено ${processedQuotes.length} обработанных цитат');
      }
    } catch (e) {
      print('📝 Начинаем с нуля');
    }
  }

  void showStats() {
    final approved = processedQuotes.where((q) => q.approved).length;
    final rejected = processedQuotes.where((q) => !q.approved).length;
    final totalRemaining = allParagraphs.where((p) => !processedIds.contains(p.id)).length;
    
    print('\n📊 ОБЩАЯ СТАТИСТИКА:');
    print('Всего параграфов: ${allParagraphs.length}');
    print('Обработано: ${processedQuotes.length}');
    print('Одобрено: $approved');
    print('Отклонено: $rejected');
    print('Осталось: $totalRemaining');
    
    print('\n📚 СТАТИСТИКА ПО КНИГАМ:');
    for (final bookKey in paragraphsByBook.keys) {
      final bookParagraphs = paragraphsByBook[bookKey]!;
      final processed = bookParagraphs.where((p) => processedIds.contains(p.id)).length;
      final remaining = bookParagraphs.length - processed;
      final approved = processedQuotes
          .where((q) => '${q.author}_${q.source}' == bookKey && q.approved)
          .length;
      
      print('  📖 $bookKey:');
      print('     Всего: ${bookParagraphs.length}, Обработано: $processed, Одобрено: $approved, Осталось: $remaining');
    }
    print('-' * 50);
  }

  Future<void> mainLoop() async {
    print('\nАвтоматический режим отбора цитат:');
    print('Для каждой цитаты: [y] - хорошая, [n] - плохая, [s] - пропустить');
    print('');
    print('КОМАНДЫ УПРАВЛЕНИЯ:');
    print('[s] - показать статистику');
    print('[done] - завершить и экспорт approved файла');
    print('[q] - выход без сохранения');
    print('');
    print('Начинаем циклический отбор...\n');

    // Автоматически показываем первую цитату
    await reviewRandom();

    while (true) {
      stdout.write('Команда: ');
      final command = stdin.readLineSync()?.trim().toLowerCase() ?? '';
      
      switch (command) {
        case 's':
          showStats();
          break;
        case 'done':
          await exportAndQuit();
          return;
        case 'q':
          print('Выход без сохранения...');
          return;
        default:
          print('❌ Неизвестная команда. Используйте [s], [done] или [q]');
          print('Для цитат используйте [y], [n] или [s]');
      }
    }
  }

  Future<void> reviewRandom() async {
    // Циклический отбор: берем случайную цитату из каждой книги по очереди
    final bookKeys = paragraphsByBook.keys.toList();
    
    if (bookKeys.isEmpty) {
      print('✅ Все книги обработаны!');
      print('Используйте команду [done] для экспорта результатов.');
      return;
    }
    
    Paragraph? selectedParagraph;
    
    // Ищем следующую книгу с необработанными параграфами
    int attempts = 0;
    while (attempts < bookKeys.length) {
      final bookKey = bookKeys[currentBookIndex];
      final bookParagraphs = paragraphsByBook[bookKey]!;
      
      // Находим все необработанные параграфы в этой книге
      final unprocessedInBook = bookParagraphs
          .where((p) => !processedIds.contains(p.id))
          .toList();
      
      if (unprocessedInBook.isNotEmpty) {
        // Выбираем СЛУЧАЙНЫЙ параграф из необработанных в этой книге
        selectedParagraph = unprocessedInBook[random.nextInt(unprocessedInBook.length)];
        break;
      }
      
      // Если в текущей книге больше нет необработанных - переходим к следующей
      currentBookIndex = (currentBookIndex + 1) % bookKeys.length;
      attempts++;
      
      // Если прошли полный круг по всем книгам
      if (currentBookIndex == 0) {
        final hasUnprocessed = bookKeys.any((key) {
          final bookParagraphs = paragraphsByBook[key]!;
          return bookParagraphs.any((p) => !processedIds.contains(p.id));
        });
        
        if (!hasUnprocessed) {
          print('✅ Все параграфы обработаны!');
          print('Используйте команду [done] для экспорта результатов.');
          return;
        }
        
        print('🔄 Новый цикл! Возвращаемся к книгам с оставшимися цитатами...');
      }
    }
    
    if (selectedParagraph == null) {
      print('✅ Все параграфы обработаны!');
      print('Используйте команду [done] для экспорта результатов.');
      return;
    }
    
    // Переходим к следующей книге для следующего вызова
    currentBookIndex = (currentBookIndex + 1) % bookKeys.length;
    
    await reviewParagraph(selectedParagraph);
  }

  Future<void> reviewParagraph(Paragraph paragraph) async {
    // Показываем параграф
    print('\n' + '=' * 70);
    print('🎲 СЛУЧАЙНАЯ ЦИТАТА');
    print('=' * 70);
    print('📚 Книга: ${paragraph.book.source}');
    print('✍️  Автор: ${paragraph.book.author}');
    print('🏷️  Категория: ${paragraph.book.category}');
    print('📍 Позиция: ${paragraph.position}');
    print('=' * 70);
    print('');
    
    // Красиво форматируем текст
    _printFormatted(paragraph.text);
    
    print('\n' + '-' * 70);
    final remaining = allParagraphs.where((p) => !processedIds.contains(p.id)).length;
    print('Осталось необработанных: $remaining');
    print('\n[y] ДА, отличная цитата!   [n] НЕТ, плохая   [s] Пропустить   [done] Завершить');
    
    while (true) {
      stdout.write('Ваше решение: ');
      final decision = stdin.readLineSync()?.trim().toLowerCase() ?? 's';
      
      bool? approved;
      bool shouldContinue = false;
      
      switch (decision) {
        case 'y':
        case 'yes':
        case 'да':
          approved = true;
          print('✅ ОДОБРЕНО! 🔥');
          shouldContinue = true;
          break;
        case 'n':
        case 'no':
        case 'нет':
          approved = false;
          print('❌ ОТКЛОНЕНО');
          shouldContinue = true;
          break;
        case 's':
        case 'skip':
          print('⏭️ Пропущено');
          shouldContinue = true;
          break;
        case 'done':
          print('🏁 Завершаем работу...');
          await exportAndQuit();
          return;
        case 'q':
          print('❌ Выход без сохранения...');
          return;
        default:
          print('❓ Введите y, n, s, done или q');
          continue; // Повторяем ввод
      }
      
      if (approved != null) {
        // Создаем запись
        final quote = Quote(
          id: paragraph.id,
          text: paragraph.text,
          author: paragraph.book.author,
          source: paragraph.book.source,
          category: paragraph.book.category,
          position: paragraph.position,
          approved: approved,
          reviewedAt: DateTime.now(),
        );
        
        processedQuotes.add(quote);
        processedIds.add(paragraph.id);
        
        // Сохраняем
        await save();
        
        final approvedCount = processedQuotes.where((q) => q.approved).length;
        print('💎 Одобренных цитат: $approvedCount');
      }
      
      if (shouldContinue) {
        // Автоматически показываем следующую цитату
        print('\n⏳ Загружаем следующую цитату...');
        await Future.delayed(Duration(milliseconds: 500)); // Небольшая пауза
        await reviewRandom();
        break;
      }
    }
  }

  void _printFormatted(String text) {
    // Красиво форматируем текст с переносами
    final words = text.split(' ');
    var currentLine = '';
    
    for (final word in words) {
      if (currentLine.length + word.length > 65) {
        print('   $currentLine');
        currentLine = word;
      } else {
        currentLine += (currentLine.isEmpty ? '' : ' ') + word;
      }
    }
    if (currentLine.isNotEmpty) print('   $currentLine');
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
      
      print('\n' + '=' * 50);
      print('🎉 ФИНАЛЬНАЯ СТАТИСТИКА');
      print('=' * 50);
      print('✅ Обработано: ${processedQuotes.length} цитат');
      print('💎 Одобрено: ${approved.length} цитат');
      print('📂 Экспорт: $approvedPath');
      print('\n🔥 Теперь добавь файл в pubspec.yaml:');
      print('   - $approvedPath');
      print('\n🚀 Готово! Твоя коллекция цитат создана! 👋');
    } catch (e) {
      print('❌ Ошибка экспорта: $e');
    }
  }
}

void main(List<String> args) async {
  final outputPath = args.isNotEmpty ? args[0] : 'assets/curated/all_quotes.json';
  
  print('📝 Сохранение результатов в: $outputPath');
  
  final curator = RandomCurator(outputPath: outputPath);
  await curator.run();
}