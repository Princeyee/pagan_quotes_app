
// lib/services/text_file_service.dart - ИСПРАВЛЕННАЯ ВЕРСИЯ

import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../models/book_source.dart';
import 'audiobook_service.dart';

class TextFileService {
  static final TextFileService _instance = TextFileService._internal();
  factory TextFileService() => _instance;
  TextFileService._internal();

  final Map<String, String> _cachedTexts = {};
  final Map<String, List<BookSource>> _cachedSources = {};

  /// Загружает все доступные источники книг (ХАРДКОД из curator)
  Future<List<BookSource>> loadBookSources() async {
    // Если уже загружены, возвращаем кэш
    if (_cachedSources.isNotEmpty) {
      return _cachedSources.values.expand((list) => list).toList();
    }
    
    // Загружаем список аудиокниг для проверки наличия аудиоверсий
    final audiobookService = AudiobookService();
    final audiobooks = await audiobookService.getAudiobooks();

    // ХАРДКОД - точно такие же книги как в random_curator.dart
    final sources = <BookSource>[
      // Греция - античная философия
      BookSource(
        id: 'aristotle_metaphysics',
        title: 'Метафизика',
        author: 'Аристотель',
        category: 'greece',
        language: 'ru',
        cleanedFilePath: 'assets/full_texts/greece/aristotle/metaphysics_cleaned.txt',
        rawFilePath: 'assets/full_texts/greece/aristotle/metaphysics_cleaned.txt',
      ),
      BookSource(
        id: 'aristotle_ethics',
        title: 'Этика',
        author: 'Аристотель',
        category: 'greece',
        language: 'ru',
        cleanedFilePath: 'assets/full_texts/greece/aristotle/ethics_cleaned.txt',
        rawFilePath: 'assets/full_texts/greece/aristotle/ethics_cleaned.txt',
      ),
      BookSource(
        id: 'aristotle_politics',
        title: 'Политика',
        author: 'Аристотель',
        category: 'greece',
        language: 'ru',
        cleanedFilePath: 'assets/full_texts/greece/aristotle/politics_cleaned.txt',
        rawFilePath: 'assets/full_texts/greece/aristotle/politics_cleaned.txt',
      ),
      BookSource(
        id: 'aristotle_rhetoric',
        title: 'Риторика',
        author: 'Аристотель',
        category: 'greece',
        language: 'ru',
        cleanedFilePath: 'assets/full_texts/greece/aristotle/rhetoric_cleaned.txt',
        rawFilePath: 'assets/full_texts/greece/aristotle/rhetoric_cleaned.txt',
      ),
      BookSource(
        id: 'plato_sophist',
        title: 'Софист',
        author: 'Платон',
        category: 'greece',
        language: 'ru',
        cleanedFilePath: 'assets/full_texts/greece/plato/sophist_cleaned.txt',
        rawFilePath: 'assets/full_texts/greece/plato/sophist_cleaned.txt',
      ),
      BookSource(
        id: 'plato_parmenides',
        title: 'Парменид',
        author: 'Платон',
        category: 'greece',
        language: 'ru',
        cleanedFilePath: 'assets/full_texts/greece/plato/parmenides_cleaned.txt',
        rawFilePath: 'assets/full_texts/greece/plato/parmenides_cleaned.txt',
      ),
      BookSource(
        id: 'homer_iliad',
        title: 'Илиада',
        author: 'Гомер',
        category: 'greece',
        language: 'ru',
        cleanedFilePath: 'assets/full_texts/greece/homer/iliad_cleaned.txt',
        rawFilePath: 'assets/full_texts/greece/homer/iliad_cleaned.txt',
      ),
      BookSource(
        id: 'homer_odyssey',
        title: 'Одиссея',
        author: 'Гомер',
        category: 'greece',
        language: 'ru',
        cleanedFilePath: 'assets/full_texts/greece/homer/odyssey_cleaned.txt',
        rawFilePath: 'assets/full_texts/greece/homer/odyssey_cleaned.txt',
      ),
      BookSource(
        id: 'hesiod_labour',
        title: 'Труды и дни',
        author: 'Гесиод',
        category: 'greece',
        language: 'ru',
        cleanedFilePath: 'assets/full_texts/greece/hesiod/labour_and_days_cleaned.txt',
        rawFilePath: 'assets/full_texts/greece/hesiod/labour_and_days_cleaned.txt',
      ),
      
      // Север - эпос и мифология
      BookSource(
        id: 'beowulf',
        title: 'Беовульф',
        author: 'Мифопоэтика',
        category: 'nordic',
        language: 'ru',
        cleanedFilePath: 'assets/full_texts/nordic/folk/beowulf_cleaned.txt',
        rawFilePath: 'assets/full_texts/nordic/folk/beowulf_cleaned.txt',
      ),
      BookSource(
        id: 'elder_edda',
        title: 'Старшая Эдда',
        author: 'Мифопоэтика',
        category: 'nordic',
        language: 'ru',
        cleanedFilePath: 'assets/full_texts/nordic/folk/elder_edda_cleaned.txt',
        rawFilePath: 'assets/full_texts/nordic/folk/elder_edda_cleaned.txt',
      ),
      
      // Философия - современная мысль
      BookSource(
        id: 'heidegger_being',
        title: 'Бытие и время',
        author: 'Хайдеггер',
        category: 'philosophy',
        language: 'ru',
        cleanedFilePath: 'assets/full_texts/philosophy/heidegger/being_and_time_cleaned.txt',
        rawFilePath: 'assets/full_texts/philosophy/heidegger/being_and_time_cleaned.txt',
      ),
      BookSource(
        id: 'heidegger_think',
        title: 'Что значит мыслить',
        author: 'Хайдеггер',
        category: 'philosophy',
        language: 'ru',
        cleanedFilePath: 'assets/full_texts/philosophy/heidegger/what_means_to_think_cleaned.txt',
        rawFilePath: 'assets/full_texts/philosophy/heidegger/what_means_to_think_cleaned.txt',
      ),
      BookSource(
        id: 'nietzsche_antichrist',
        title: 'Антихрист',
        author: 'Ницше',
        category: 'philosophy',
        language: 'ru',
        cleanedFilePath: 'assets/full_texts/philosophy/nietzsche/antichrist_cleaned.txt',
        rawFilePath: 'assets/full_texts/philosophy/nietzsche/antichrist_cleaned.txt',
      ),
      BookSource(
        id: 'nietzsche_gay_science',
        title: 'Веселая наука',
        author: 'Ницше',
        category: 'philosophy',
        language: 'ru',
        cleanedFilePath: 'assets/full_texts/philosophy/nietzsche/gay_science_cleaned.txt',
        rawFilePath: 'assets/full_texts/philosophy/nietzsche/gay_science_cleaned.txt',
      ),
      BookSource(
        id: 'nietzsche_zarathustra',
        title: 'Так говорил Заратустра',
        author: 'Ницше',
        category: 'philosophy',
        language: 'ru',
        cleanedFilePath: 'assets/full_texts/philosophy/nietzsche/thus_spoke_zarathustra_cleaned.txt',
        rawFilePath: 'assets/full_texts/philosophy/nietzsche/thus_spoke_zarathustra_cleaned.txt',
      ),
      BookSource(
        id: 'nietzsche_tragedy',
        title: 'Рождение трагедии из духа музкыки',
        author: 'Ницше',
        category: 'philosophy',
        language: 'ru',
        cleanedFilePath: 'assets/full_texts/philosophy/nietzsche/birth_of_tragedy_cleaned.txt',
        rawFilePath: 'assets/full_texts/philosophy/nietzsche/birth_of_tragedy_cleaned.txt',
      ),
      BookSource(
        id: 'nietzsche_beyond',
        title: 'По ту сторону добра и зла',
        author: 'Ницше',
        category: 'philosophy',
        language: 'ru',
        cleanedFilePath: 'assets/full_texts/philosophy/nietzsche/beyond_good_and_evil_cleaned.txt',
        rawFilePath: 'assets/full_texts/philosophy/nietzsche/beyond_good_and_evil_cleaned.txt',
      ),
      BookSource(
        id: 'schopenhauer_world',
        title: 'Мир как воля и представление',
        author: 'Шопенгауэр',
        category: 'philosophy',
        language: 'ru',
        cleanedFilePath: 'assets/full_texts/philosophy/schopenhauer/world_as_will_and_representation_cleaned.txt',
        rawFilePath: 'assets/full_texts/philosophy/schopenhauer/world_as_will_and_representation_cleaned.txt',
      ),
      BookSource(
        id: 'schopenhauer_aphorisms',
        title: 'Афоризмы житейской мудрости',
        author: 'Шопенгауэр',
        category: 'philosophy',
        language: 'ru',
        cleanedFilePath: 'assets/full_texts/philosophy/schopenhauer/aphorisms_on_wisdom_of_life_cleaned.txt',
        rawFilePath: 'assets/full_texts/philosophy/schopenhauer/aphorisms_on_wisdom_of_life_cleaned.txt',
      ),
      
      // Язычество - традиция и символизм
      // Добавьте эти BookSource объекты в список sources в методе loadBookSources()
// после существующих книг Элиаде:

      BookSource(
        id: 'askr_svarte_pagan_identity',
        title: 'Идентичность язычника в 21 веке',
        author: 'Askr Svarte',
        category: 'pagan',
        language: 'ru',
        cleanedFilePath: 'assets/full_texts/pagan/askr_svarte/pagan_identity_xxi_cleaned.txt',
        rawFilePath: 'assets/full_texts/pagan/askr_svarte/pagan_identity_xxi_raw.txt',
      ),
      BookSource(
        id: 'askr_svarte_priblizhenie',
        title: 'Приближение и окружение',
        author: 'Askr Svarte',
        category: 'pagan',
        language: 'ru', 
        cleanedFilePath: 'assets/full_texts/pagan/askr_svarte/priblizheniye_i_okruzheniye_cleaned.txt',
        rawFilePath: 'assets/full_texts/pagan/askr_svarte/priblizheniye_i_okruzheniye_raw.txt',
      ),
      BookSource(
        id: 'askr_svarte_polemos',
        title: 'Polemos',
        author: 'Askr Svarte',
        category: 'pagan',
        language: 'ru', 
        cleanedFilePath: 'assets/full_texts/pagan/askr_svarte/polemos_cleaned.txt',
        rawFilePath: 'assets/full_texts/pagan/askr_svarte/polemos_raw.txt',
      ),
      BookSource(
        id: 'evola_imperialism',
        title: 'Языческий империализм',
        author: 'Эвола',
        category: 'pagan',
        language: 'ru',
        cleanedFilePath: 'assets/full_texts/pagan/julius_evola/pagan_imperialism_cleaned.txt',
        rawFilePath: 'assets/full_texts/pagan/julius_evola/pagan_imperialism_cleaned.txt',
      ),
      BookSource(
        id: 'evola_sex',
        title: 'Метафизика пола',
        author: 'Эвола',
        category: 'pagan',
        language: 'ru',
        cleanedFilePath: 'assets/full_texts/pagan/julius_evola/metaphysics_of_sex_cleaned.txt',
        rawFilePath: 'assets/full_texts/pagan/julius_evola/metaphysics_of_sex_cleaned.txt',
      ),
      BookSource(
        id: 'evola_ruins',
        title: 'Люди и руины',
        author: 'Эвола',
        category: 'pagan',
        language: 'ru',
        cleanedFilePath: 'assets/full_texts/pagan/julius_evola/men_among_ruins_cleaned.txt',
        rawFilePath: 'assets/full_texts/pagan/julius_evola/men_among_ruins_cleaned.txt',
      ),
      BookSource(
        id: 'eliade_sacred',
        title: 'Священное и мирское',
        author: 'Элиаде',
        category: 'pagan',
        language: 'ru',
        cleanedFilePath: 'assets/full_texts/pagan/mercea_eliade/sacred_and_profane_cleaned.txt',
        rawFilePath: 'assets/full_texts/pagan/mercea_eliade/sacred_and_profane_cleaned.txt',
      ),
      BookSource(
        id: 'eliade_myth',
        title: 'Миф о вечном возвращении',
        author: 'Элиаде',
        category: 'pagan',
        language: 'ru',
        cleanedFilePath: 'assets/full_texts/pagan/mercea_eliade/myth_of_eternal_return_cleaned.txt',
        rawFilePath: 'assets/full_texts/pagan/mercea_eliade/myth_of_eternal_return_cleaned.txt',
      ),
      BookSource(
        id: 'eliade_history1',
        title: 'История веры и религиозных идей том 1',
        author: 'Элиаде',
        category: 'pagan',
        language: 'ru',
        cleanedFilePath: 'assets/full_texts/pagan/mercea_eliade/history_of_religious_ideas_vol1_cleaned.txt',
        rawFilePath: 'assets/full_texts/pagan/mercea_eliade/history_of_religious_ideas_vol1_cleaned.txt',
      ),
      BookSource(
        id: 'eliade_history2',
        title: 'История и религиозных идей веры том 2',
        author: 'Элиаде',
        category: 'pagan',
        language: 'ru',
        cleanedFilePath: 'assets/full_texts/pagan/mercea_eliade/history_of_religious_ideas_vol2_cleaned.txt',
        rawFilePath: 'assets/full_texts/pagan/mercea_eliade/history_of_religious_ideas_vol2_cleaned.txt',
      ),
      BookSource(
        id: 'eliade_history3',
        title: 'История и религиозных идей веры том 3',
        author: 'Элиаде',
        category: 'pagan',
        language: 'ru',
        cleanedFilePath: 'assets/full_texts/pagan/mercea_eliade/history_of_religious_ideas_vol3_cleaned.txt',
        rawFilePath: 'assets/full_texts/pagan/mercea_eliade/history_of_religious_ideas_vol3_cleaned.txt',
      ),
    ];

    // Проверяем наличие аудиоверсий для книг
    for (int i = 0; i < sources.length; i++) {
      final book = sources[i];
      // Проверяем, есть ли аудиокнига с таким же ID или названием
      final hasAudio = audiobooks.any((audiobook) => 
        audiobook.id == book.id || 
        audiobook.title.toLowerCase() == book.title.toLowerCase()
      );
      
      if (hasAudio) {
        sources[i] = BookSource(
          id: book.id,
          title: book.title,
          author: book.author,
          category: book.category,
          language: book.language,
          translator: book.translator,
          rawFilePath: book.rawFilePath,
          cleanedFilePath: book.cleanedFilePath,
          hasAudioVersion: true,
        );
      }
    }
    
    // Группируем по категориям для кэша
    final Map<String, List<BookSource>> categorizedSources = {};
    for (final source in sources) {
      categorizedSources.putIfAbsent(source.category, () => []).add(source);
    }
    
    _cachedSources.addAll(categorizedSources);
    
    print('📚 Загружено ${sources.length} книг в ${categorizedSources.length} категориях');
    for (final entry in categorizedSources.entries) {
      print('   ${entry.key}: ${entry.value.length} книг');
    }
    
    return sources;
  }

  /// Загружает текст из файла (raw или cleaned)
  Future<String> loadTextFile(String path) async {
    debugPrint('!!! SACRAL_APP: START LOADING FILE: $path');

    if (_cachedTexts.containsKey(path)) {
      debugPrint('!!! SACRAL_APP: USING CACHE, LENGTH: ${_cachedTexts[path]!.length}');
      return _cachedTexts[path]!;
    }

    try {
      debugPrint('!!! SACRAL_APP: READING FROM ASSETS: $path');
      final content = await rootBundle.loadString(path);
      debugPrint('!!! SACRAL_APP: FILE LOADED, LENGTH: ${content.length}');
      
      if (content.isEmpty) {
        debugPrint('!!! SACRAL_APP: ERROR - FILE IS EMPTY: $path');
        throw Exception('File is empty: $path');
      }

      // Проверяем наличие позиционных маркеров
      final posMarkers = RegExp(r'\[pos:\d+\]').allMatches(content).length;
      debugPrint('!!! SACRAL_APP: FOUND $posMarkers POSITION MARKERS');
      
      if (posMarkers == 0) {
        debugPrint('!!! SACRAL_APP: WARNING - NO POSITION MARKERS IN FILE: $path');
      }

      _cachedTexts[path] = content;
      return content;
    } catch (e, stackTrace) {
      debugPrint('!!! SACRAL_APP: ERROR LOADING FILE: $path');
      debugPrint('!!! SACRAL_APP: ERROR DETAILS: $e');
      debugPrint('!!! SACRAL_APP: STACK TRACE START');
      debugPrint(stackTrace.toString());
      debugPrint('!!! SACRAL_APP: STACK TRACE END');
      throw Exception('Failed to load text file: $path - $e');
    }
  }

  /// Извлекает все абзацы с позициями из текста
  List<Map<String, dynamic>> extractParagraphsWithPositions(String text) {
    debugPrint('!!! SACRAL_APP: EXTRACTING PARAGRAPHS FROM TEXT LENGTH: ${text.length}');
    
    final paragraphs = <Map<String, dynamic>>[];
    
    // ТОЧНО ТАКОЙ ЖЕ regex как в curator
    final regex = RegExp(r'\[pos:(\d+)\]\s*((?:(?!\[pos:\d+\])[\s\S])*)', multiLine: true);
    final matches = regex.allMatches(text);
    
    debugPrint('!!! SACRAL_APP: FOUND ${matches.length} MATCHES');
    
    for (final match in matches) {
      final position = int.parse(match.group(1)!);
      final content = match.group(2)!.trim();
      
      if (content.isEmpty) {
        debugPrint('!!! SACRAL_APP: SKIPPING EMPTY CONTENT AT POSITION $position');
        continue;
      }
      
      // Нормализуем пробелы и переносы строк, сохраняя форматирование абзацев
      final normalizedContent = content
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();
      
      if (normalizedContent.isEmpty) {
        debugPrint('!!! SACRAL_APP: SKIPPING EMPTY NORMALIZED CONTENT AT POSITION $position');
        continue;
      }
      
      paragraphs.add({
        'position': position,
        'content': normalizedContent,
        'rawText': content,
      });
      
      // Логируем первые несколько для отладки
      if (paragraphs.length <= 3) {
        debugPrint('!!! SACRAL_APP: PARAGRAPH $position: "${normalizedContent.substring(0, min(50, normalizedContent.length))}..."');
      }
    }
    
    // Сортируем по позиции для гарантии правильного порядка
    paragraphs.sort((a, b) => (a['position'] as int).compareTo(b['position'] as int));
    
    debugPrint('!!! SACRAL_APP: EXTRACTED ${paragraphs.length} PARAGRAPHS');
    if (paragraphs.isNotEmpty) {
      debugPrint('!!! SACRAL_APP: FIRST POSITION: ${paragraphs.first['position']}');
      debugPrint('!!! SACRAL_APP: LAST POSITION: ${paragraphs.last['position']}');
    }
    
    return paragraphs;
  }

  /// Находит абзац по позиции
  Map<String, dynamic>? findParagraphByPosition(String text, int position) {
    debugPrint('!!! SACRAL_APP: FINDING PARAGRAPH AT POSITION: $position');
    
    final paragraphs = extractParagraphsWithPositions(text);
    
    for (final para in paragraphs) {
      if (para['position'] == position) {
        debugPrint('!!! SACRAL_APP: FOUND PARAGRAPH AT POSITION $position');
        return para;
      }
    }
    
    debugPrint('!!! SACRAL_APP: PARAGRAPH NOT FOUND AT POSITION $position');
    return null;
  }

  /// Получает контекст вокруг указанной позиции с оптимизированным поиском
  List<Map<String, dynamic>> getContextAroundPosition(
    String text, 
    int centerPosition, 
    {int contextSize = 5}
  ) {
    debugPrint('!!! SACRAL_APP: GETTING CONTEXT AROUND POSITION: $centerPosition');
    
    final paragraphs = extractParagraphsWithPositions(text);
    if (paragraphs.isEmpty) {
      debugPrint('!!! SACRAL_APP: NO PARAGRAPHS FOUND');
      return [];
    }
    
    // Ищем индекс параграфа с нужной позицией
    int centerIndex = -1;
    for (int i = 0; i < paragraphs.length; i++) {
      if (paragraphs[i]['position'] == centerPosition) {
        centerIndex = i;
        break;
      }
    }
    
    // Если точное совпадение не найдено, используем ближайший абзац
    if (centerIndex == -1) {
      debugPrint('!!! SACRAL_APP: EXACT POSITION NOT FOUND, FINDING CLOSEST');
      
     // Находим ближайшую позицию
// Находим ближайшую позицию
int closestIndex = 0;
int minDiff = ((paragraphs[0]['position'] as int) - centerPosition).abs();

for (int i = 1; i < paragraphs.length; i++) {
  final diff = ((paragraphs[i]['position'] as int) - centerPosition).abs();
  if (diff < minDiff) {
    minDiff = diff;
    closestIndex = i;
  }
}
      
      centerIndex = closestIndex;
      debugPrint('!!! SACRAL_APP: USING CLOSEST POSITION: ${paragraphs[centerIndex]['position']}');
    }
    
    // Определяем границы контекста
    final startIndex = max(0, centerIndex - contextSize);
    final endIndex = min(paragraphs.length, centerIndex + contextSize + 1);
    
    final context = paragraphs.sublist(startIndex, endIndex);
    debugPrint('!!! SACRAL_APP: CONTEXT FOUND: ${context.length} PARAGRAPHS');
    
    return context;
  }

  /// Очищает кэш текстов
  void clearCache() {
    _cachedTexts.clear();
  }

  /// Получает размер кэша в байтах (приблизительно)
  int get cacheSize {
    return _cachedTexts.values
        .map((text) => text.length * 2) // примерно 2 байта на символ
        .fold(0, (sum, size) => sum + size);
  }

  /// Универсальный фильтр глав и заголовков (используется везде)
  static bool isHeader(String text) {
    final List<RegExp> headerPatterns = [
      RegExp(r'^(Глава|Chapter|Часть|Part)\s+\d+', caseSensitive: false),
      RegExp(r'^(Книга|Book)\s+\d+', caseSensitive: false),
      RegExp(r'^[IVXLCDM]+\.\s* ?$', caseSensitive: true), // Римские цифры, только если вся строка
      RegExp(r'^\d+\.\s* ?$', caseSensitive: true), // Просто числа с точкой, только если вся строка
      RegExp(r'^(СОДЕРЖАНИЕ|ОГЛАВЛЕНИЕ|CONTENT|INDEX)', caseSensitive: false),
      RegExp(r'^(ПРЕДИСЛОВИЕ|ВВЕДЕНИЕ|ЗАКЛЮЧЕНИЕ|PREFACE|INTRODUCTION|CONCLUSION)', caseSensitive: false),
    ];
    for (final pattern in headerPatterns) {
      if (pattern.hasMatch(text.trim())) return true;
    }
    // Только если строка короткая и полностью заглавная
    if (text.length < 50 && text == text.toUpperCase() && text.contains(' ')) {
      return true;
    }
    return false;
  }
}