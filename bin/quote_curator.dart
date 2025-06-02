// bin/quote_curator.dart
// Запускать: dart bin/quote_curator.dart

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
  final String? translation;
  final bool approved;
  final int? rating; // 1-5
  final String? notes;
  final DateTime reviewedAt;

  Quote({
    required this.id,
    required this.text,
    required this.author,
    required this.source,
    required this.category,
    required this.position,
    this.translation,
    required this.approved,
    this.rating,
    this.notes,
    required this.reviewedAt,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'text': text,
    'author': author,
    'source': source,
    'category': category,
    'position': position,
    'translation': translation,
    'approved': approved,
    'rating': rating,
    'notes': notes,
    'reviewedAt': reviewedAt.toIso8601String(),
  };

  factory Quote.fromJson(Map<String, dynamic> json) => Quote(
    id: json['id'],
    text: json['text'],
    author: json['author'],
    source: json['source'],
    category: json['category'],
    position: json['position'],
    translation: json['translation'],
    approved: json['approved'],
    rating: json['rating'],
    notes: json['notes'],
    reviewedAt: DateTime.parse(json['reviewedAt']),
  );
}

class QuoteCurator {
  final String cleanedTextPath;
  final String curatedJsonPath;
  final String category;
  final String author;
  final String source;
  
  List<String> paragraphs = [];
  List<Quote> curatedQuotes = [];
  int currentIndex = 0;
  
  QuoteCurator({
    required this.cleanedTextPath,
    required this.curatedJsonPath,
    required this.category,
    required this.author,
    required this.source,
  });

  Future<void> run() async {
    print('\n📚 QUOTE CURATOR TOOL');
    print('=' * 50);
    print('Source: $source by $author');
    print('Category: $category');
    print('=' * 50);

    // Загружаем текст
    await loadText();
    
    // Загружаем существующие курированные цитаты
    await loadExistingCurated();
    
    // Показываем статистику
    showStats();
    
    // Основной цикл
    await mainLoop();
  }

  Future<void> loadText() async {
    try {
      final file = File(cleanedTextPath);
      final content = await file.readAsString();
      
      // Разбиваем на параграфы по позициям
      final parts = content.split(RegExp(r'\[pos:\d+\]'));
      paragraphs = parts
          .where((p) => p.trim().isNotEmpty)
          .map((p) => p.trim())
          .toList();
      
      print('\n✅ Loaded ${paragraphs.length} paragraphs');
    } catch (e) {
      print('❌ Error loading text: $e');
      exit(1);
    }
  }

  Future<void> loadExistingCurated() async {
    try {
      final file = File(curatedJsonPath);
      if (await file.exists()) {
        final content = await file.readAsString();
        final List<dynamic> jsonData = json.decode(content);
        curatedQuotes = jsonData.map((j) => Quote.fromJson(j)).toList();
        print('✅ Loaded ${curatedQuotes.length} existing curated quotes');
      } else {
        print('📝 Starting with empty curated list');
      }
    } catch (e) {
      print('⚠️ Could not load existing curated quotes: $e');
    }
  }

  void showStats() {
    final approved = curatedQuotes.where((q) => q.approved).length;
    final rejected = curatedQuotes.where((q) => !q.approved).length;
    final avgRating = curatedQuotes.where((q) => q.rating != null)
        .fold<double>(0, (sum, q) => sum + q.rating!) / 
        (curatedQuotes.where((q) => q.rating != null).length > 0 ? curatedQuotes.where((q) => q.rating != null).length : 1);
    
    print('\n📊 STATISTICS:');
    print('Total paragraphs: ${paragraphs.length}');
    print('Reviewed: ${curatedQuotes.length} (${(curatedQuotes.length / paragraphs.length * 100).toStringAsFixed(1)}%)');
    print('Approved: $approved');
    print('Rejected: $rejected');
    print('Average rating: ${avgRating.toStringAsFixed(1)}');
    print('-' * 50);
  }

  Future<void> mainLoop() async {
    print('\nCommands:');
    print('[n] Next random paragraph');
    print('[j] Jump to specific position');
    print('[s] Search by text');
    print('[f] Filter by length');
    print('[r] Show random approved quote');
    print('[stats] Show statistics');
    print('[export] Export approved quotes');
    print('[q] Quit');
    print('');

    while (true) {
      stdout.write('\n> ');
      final command = stdin.readLineSync()?.trim().toLowerCase() ?? '';
      
      switch (command) {
        case 'n':
          await reviewRandomParagraph();
          break;
        case 'j':
          await jumpToPosition();
          break;
        case 's':
          await searchByText();
          break;
        case 'f':
          await filterByLength();
          break;
        case 'r':
          showRandomApproved();
          break;
        case 'stats':
          showStats();
          break;
        case 'export':
          await exportApproved();
          break;
        case 'q':
          await saveAndQuit();
          return;
        default:
          print('Unknown command: $command');
      }
    }
  }

  Future<void> reviewRandomParagraph() async {
    // Находим непроверенные параграфы
    final unreviewed = <int>[];
    for (int i = 0; i < paragraphs.length; i++) {
      if (!curatedQuotes.any((q) => q.position == i)) {
        unreviewed.add(i);
      }
    }
    
    if (unreviewed.isEmpty) {
      print('✅ All paragraphs have been reviewed!');
      return;
    }
    
    // Выбираем случайный непроверенный
    final randomIndex = unreviewed[Random().nextInt(unreviewed.length)];
    await reviewParagraph(randomIndex);
  }

  Future<void> reviewParagraph(int index) async {
    if (index < 0 || index >= paragraphs.length) {
      print('❌ Invalid paragraph index');
      return;
    }
    
    final paragraph = paragraphs[index];
    
    // Очищаем экран
    print('\n' * 3);
    print('=' * 80);
    print('PARAGRAPH #$index (${paragraph.length} chars)');
    print('=' * 80);
    print('');
    
    // Показываем параграф с подсветкой
    _printHighlighted(paragraph);
    
    print('\n' + '-' * 80);
    print('[a] Approve  [r] Reject  [1-5] Rate  [n] Add note  [skip] Skip');
    
    stdout.write('Decision: ');
    final decision = stdin.readLineSync()?.trim().toLowerCase() ?? 'skip';
    
    if (decision == 'skip') {
      print('Skipped');
      return;
    }
    
    bool approved = false;
    int? rating;
    String? notes;
    
    if (decision == 'a') {
      approved = true;
      stdout.write('Rating (1-5, optional): ');
      final ratingStr = stdin.readLineSync()?.trim();
      if (ratingStr != null && ratingStr.isNotEmpty) {
        rating = int.tryParse(ratingStr);
        if (rating == null || rating < 1 || rating > 5) {
          print('Invalid rating, skipping');
          rating = null;
        }
      }
    } else if (decision == 'r') {
      approved = false;
    } else if (RegExp(r'^[1-5]$').hasMatch(decision)) {
      approved = true;
      rating = int.parse(decision);
    } else {
      print('Invalid decision, skipping');
      return;
    }
    
    stdout.write('Notes (optional): ');
    final notesInput = stdin.readLineSync()?.trim();
    if (notesInput != null && notesInput.isNotEmpty) {
      notes = notesInput;
    }
    
    // Создаем цитату
    final quote = Quote(
      id: '${category}_${author}_$index',
      text: paragraph,
      author: author,
      source: source,
      category: category,
      position: index,
      approved: approved,
      rating: rating,
      notes: notes,
      reviewedAt: DateTime.now(),
    );
    
    // Удаляем старую версию если есть
    curatedQuotes.removeWhere((q) => q.position == index);
    curatedQuotes.add(quote);
    
    // Сохраняем
    await saveCurated();
    
    print('\n✅ ${approved ? 'APPROVED' : 'REJECTED'} ${rating != null ? '(Rating: $rating)' : ''}');
    print('Progress: ${curatedQuotes.length}/${paragraphs.length}');
  }

  void _printHighlighted(String text) {
    // Подсвечиваем интересные элементы
    final highlighted = text
        .replaceAllMapped(RegExp(r'"([^"]+)"'), (m) => '\x1B[33m"${m.group(1)}"\x1B[0m') // Жёлтым цитаты
        .replaceAllMapped(RegExp(r'—|–'), (m) => '\x1B[36m${m.group(0)}\x1B[0m'); // Голубым тире
    
    // Переносим длинные строки
    final words = highlighted.split(' ');
    var currentLine = '';
    for (final word in words) {
      if (currentLine.length + word.length > 80) {
        print(currentLine);
        currentLine = word;
      } else {
        currentLine += (currentLine.isEmpty ? '' : ' ') + word;
      }
    }
    if (currentLine.isNotEmpty) print(currentLine);
  }

  Future<void> jumpToPosition() async {
    stdout.write('Enter position (0-${paragraphs.length - 1}): ');
    final posStr = stdin.readLineSync()?.trim();
    final pos = int.tryParse(posStr ?? '');
    
    if (pos != null && pos >= 0 && pos < paragraphs.length) {
      await reviewParagraph(pos);
    } else {
      print('❌ Invalid position');
    }
  }

  Future<void> searchByText() async {
    stdout.write('Enter search text: ');
    final searchText = stdin.readLineSync()?.trim().toLowerCase() ?? '';
    
    if (searchText.isEmpty) return;
    
    final results = <int>[];
    for (int i = 0; i < paragraphs.length; i++) {
      if (paragraphs[i].toLowerCase().contains(searchText)) {
        results.add(i);
      }
    }
    
    if (results.isEmpty) {
      print('No results found');
      return;
    }
    
    print('\nFound ${results.length} results:');
    for (int i = 0; i < min(10, results.length); i++) {
      final idx = results[i];
      final preview = paragraphs[idx].substring(0, min(100, paragraphs[idx].length));
      print('[$idx] $preview...');
    }
    
    if (results.length > 10) {
      print('... and ${results.length - 10} more');
    }
    
    stdout.write('\nReview which one? (index or "cancel"): ');
    final choice = stdin.readLineSync()?.trim();
    final choiceIdx = int.tryParse(choice ?? '');
    
    if (choiceIdx != null && results.contains(choiceIdx)) {
      await reviewParagraph(choiceIdx);
    }
  }

  Future<void> filterByLength() async {
    stdout.write('Min length (default 50): ');
    final minStr = stdin.readLineSync()?.trim();
    final minLen = int.tryParse(minStr ?? '') ?? 50;
    
    stdout.write('Max length (default 300): ');
    final maxStr = stdin.readLineSync()?.trim();
    final maxLen = int.tryParse(maxStr ?? '') ?? 300;
    
    final filtered = <int>[];
    for (int i = 0; i < paragraphs.length; i++) {
      final len = paragraphs[i].length;
      if (len >= minLen && len <= maxLen) {
        filtered.add(i);
      }
    }
    
    print('\nFound ${filtered.length} paragraphs between $minLen-$maxLen chars');
    
    if (filtered.isNotEmpty) {
      stdout.write('Review random from filtered? (y/n): ');
      if (stdin.readLineSync()?.trim().toLowerCase() == 'y') {
        final randomIdx = filtered[Random().nextInt(filtered.length)];
        await reviewParagraph(randomIdx);
      }
    }
  }

  void showRandomApproved() {
    final approved = curatedQuotes.where((q) => q.approved).toList();
    if (approved.isEmpty) {
      print('No approved quotes yet');
      return;
    }
    
    final random = approved[Random().nextInt(approved.length)];
    print('\n' + '=' * 80);
    print('RANDOM APPROVED QUOTE');
    print('=' * 80);
    _printHighlighted(random.text);
    print('\nRating: ${random.rating ?? 'N/A'}');
    if (random.notes != null) print('Notes: ${random.notes}');
    print('Position: ${random.position}');
  }

  Future<void> exportApproved() async {
    final approved = curatedQuotes.where((q) => q.approved).toList();
    final exportPath = curatedJsonPath.replaceAll('.json', '_approved.json');
    
    try {
      final file = File(exportPath);
      await file.writeAsString(
        JsonEncoder.withIndent('  ').convert(
          approved.map((q) => q.toJson()).toList()
        )
      );
      print('✅ Exported ${approved.length} approved quotes to $exportPath');
    } catch (e) {
      print('❌ Export failed: $e');
    }
  }

  Future<void> saveCurated() async {
    try {
      final file = File(curatedJsonPath);
      await file.writeAsString(
        JsonEncoder.withIndent('  ').convert(
          curatedQuotes.map((q) => q.toJson()).toList()
        )
      );
    } catch (e) {
      print('❌ Failed to save: $e');
    }
  }

  Future<void> saveAndQuit() async {
    await saveCurated();
    print('\n✅ Saved ${curatedQuotes.length} curated quotes');
    print('Goodbye! 👋');
  }
}

void main(List<String> args) async {
  if (args.length < 5) {
    print('Usage: dart quote_curator.dart <cleaned_text_path> <output_json_path> <category> <author> <source>');
    print('Example: dart quote_curator.dart assets/texts/greece/homer_iliad_cleaned.txt curated/homer_iliad.json greece Homer "Илиада"');
    exit(1);
  }

  final curator = QuoteCurator(
    cleanedTextPath: args[0],
    curatedJsonPath: args[1],
    category: args[2],
    author: args[3],
    source: args[4],
  );

  await curator.run();
}
