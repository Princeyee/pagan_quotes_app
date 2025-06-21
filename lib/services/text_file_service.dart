// lib/services/text_file_service.dart - ИСПРАВЛЕННАЯ ВЕРСИЯ

import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../models/book_source.dart';
import 'public_google_drive_service.dart'; // Добавляем импорт для проверки аудиокниг

class TextFileService {
  static final TextFileService _instance = TextFileService._internal();
  factory TextFileService() => _instance;
  TextFileService._internal();

  final Map<String, String> _cachedTexts = {};
  final Map<String, List<BookSource>> _cachedSources = {};
  final PublicGoogleDriveService _driveService = PublicGoogleDriveService();

  /// Загружает все доступные источники книг (ХАРДКОД из curator)
  Future<List<BookSource>> loadBookSources() async {
    // Если уже загружены, возвращаем кэш
    if (_cachedSources.isNotEmpty) {
      return _cachedSources.values.expand((list) => list).toList();
    }
    
    // ХАРДКОД - точно такие же книги как в book_sources.json
    final sources = <BookSource>[
      // Греция - античная философия
      BookSource(
        id: 'aristotle_metaphysics',
        title: 'Метафизика',
        author: 'Аристотель',
        category: 'greece',
        language: 'ru',
        translator: 'А.В. Кубицкий',
        cleanedFilePath: 'assets/full_texts/greece/aristotle/metaphysics_cleaned.txt',
        rawFilePath: 'assets/full_texts/greece/aristotle/metaphysics_raw.txt',
      ),
      BookSource(
        id: 'aristotle_ethics',
        title: 'Никомахова этика',
        author: 'Аристотель',
        category: 'greece',
        language: 'ru',
        translator: 'Н.В. Брагинская',
        cleanedFilePath: 'assets/full_texts/greece/aristotle/ethics_cleaned.txt',
        rawFilePath: 'assets/full_texts/greece/aristotle/ethics_raw.txt',
      ),
      BookSource(
        id: 'aristotle_politics',
        title: 'Политика',
        author: 'Аристотель',
        category: 'greece',
        language: 'ru',
        translator: 'С.А. Жебелев',
        cleanedFilePath: 'assets/full_texts/greece/aristotle/politics_cleaned.txt',
        rawFilePath: 'assets/full_texts/greece/aristotle/politics_raw.txt',
      ),
      BookSource(
        id: 'aristotle_rhetoric',
        title: 'Риторика',
        author: 'Аристотель',
        category: 'greece',
        language: 'ru',
        translator: 'Н. Платонова',
        cleanedFilePath: 'assets/full_texts/greece/aristotle/rhetoric_cleaned.txt',
        rawFilePath: 'assets/full_texts/greece/aristotle/rhetoric_raw.txt',
      ),
      BookSource(
        id: 'plato_sophist',
        title: 'Софист',
        author: 'Платон',
        category: 'greece',
        language: 'ru',
        translator: 'С.А. Ананьин',
        cleanedFilePath: 'assets/full_texts/greece/plato/sophist_cleaned.txt',
        rawFilePath: 'assets/full_texts/greece/plato/sophist_raw.txt',
      ),
      BookSource(
        id: 'plato_parmenides',
        title: 'Парменид',
        author: 'Платон',
        category: 'greece',
        language: 'ru',
        translator: 'Н.Н. Томасов',
        cleanedFilePath: 'assets/full_texts/greece/plato/parmenides_cleaned.txt',
        rawFilePath: 'assets/full_texts/greece/plato/parmenides_raw.txt',
      ),
      BookSource(
        id: 'homer_iliad',
        title: 'Илиада',
        author: 'Гомер',
        category: 'greece',
        language: 'ru',
        translator: 'Н.И. Гнедич',
        cleanedFilePath: 'assets/full_texts/greece/homer/iliad_cleaned.txt',
        rawFilePath: 'assets/full_texts/greece/homer/iliad_raw.txt',
      ),
      BookSource(
        id: 'homer_odyssey',
        title: 'Одиссея',
        author: 'Гомер',
        category: 'greece',
        language: 'ru',
        translator: 'В.А. Жуковский',
        cleanedFilePath: 'assets/full_texts/greece/homer/odyssey_cleaned.txt',
        rawFilePath: 'assets/full_texts/greece/homer/odyssey_raw.txt',
      ),
      BookSource(
        id: 'hesiod_labour_and_days',
        title: 'Труды и дни',
        author: 'Гесиод',
        category: 'greece',
        language: 'ru',
        translator: 'В.В. Вересаев',
        cleanedFilePath: 'assets/full_texts/greece/hesiod/labour_and_days_cleaned.txt',
        rawFilePath: 'assets/full_texts/greece/hesiod/labour_and_days_raw.txt',
      ),
      
      // Север - эпос и мифология
      BookSource(
        id: 'beowulf',
        title: 'Беовульф',
        author: 'Мифопоэтика',
        category: 'nordic',
        language: 'ru',
        translator: 'В.Г. Тихомиров',
        cleanedFilePath: 'assets/full_texts/nordic/folk/beowulf_cleaned.txt',
        rawFilePath: 'assets/full_texts/nordic/folk/beowulf_raw.txt',
      ),
      BookSource(
        id: 'elder_edda',
        title: 'Старшая Эдда',
        author: 'Аноним',
        category: 'nordic',
        language: 'ru',
        translator: 'А.И. Корсун',
        cleanedFilePath: 'assets/full_texts/nordic/folk/elder_edda_cleaned.txt',
        rawFilePath: 'assets/full_texts/nordic/folk/elder_edda_raw.txt',
      ),
      
      // Философия - современная мысль
      BookSource(
        id: 'heidegger_being_and_time',
        title: 'Бытие и время',
        author: 'Мартин Хайдеггер',
        category: 'philosophy',
        language: 'ru',
        translator: 'В.В. Бибихин',
        cleanedFilePath: 'assets/full_texts/philosophy/heidegger/being_and_time_cleaned.txt',
        rawFilePath: 'assets/full_texts/philosophy/heidegger/being_and_time_raw.txt',
      ),
      BookSource(
        id: 'heidegger_what_means_to_think',
        title: 'Что значит мыслить?',
        author: 'Мартин Хайдеггер',
        category: 'philosophy',
        language: 'ru',
        translator: 'Э. Сагетдинов',
        cleanedFilePath: 'assets/full_texts/philosophy/heidegger/what_means_to_think_cleaned.txt',
        rawFilePath: 'assets/full_texts/philosophy/heidegger/what_means_to_think_raw.txt',
      ),
      BookSource(
        id: 'nietzsche_antichrist',
        title: 'Антихрист',
        author: 'Фридрих Ницше',
        category: 'philosophy',
        language: 'ru',
        translator: 'Ю.М. Антоновский',
        cleanedFilePath: 'assets/full_texts/philosophy/nietzsche/antichrist_cleaned.txt',
        rawFilePath: 'assets/full_texts/philosophy/nietzsche/antichrist_raw.txt',
      ),
      BookSource(
        id: 'nietzsche_gay_science',
        title: 'Веселая наука',
        author: 'Фридрих Ницше',
        category: 'philosophy',
        language: 'ru',
        translator: 'К.А. Свасьян',
        cleanedFilePath: 'assets/full_texts/philosophy/nietzsche/gay_science_cleaned.txt',
        rawFilePath: 'assets/full_texts/philosophy/nietzsche/gay_science_raw.txt',
      ),
      BookSource(
        id: 'nietzsche_thus_spoke_zarathustra',
        title: 'Так говорил Заратустра',
        author: 'Фридрих Ницше',
        category: 'philosophy',
        language: 'ru',
        translator: 'Ю.М. Антоновский',
        cleanedFilePath: 'assets/full_texts/philosophy/nietzsche/thus_spoke_zarathustra_cleaned.txt',
        rawFilePath: 'assets/full_texts/philosophy/nietzsche/thus_spoke_zarathustra_raw.txt',
      ),
      BookSource(
        id: 'nietzsche_birth_of_tragedy',
        title: 'Рождение трагедии из духа музыки',
        author: 'Фридрих Ницше',
        category: 'philosophy',
        language: 'ru',
        translator: 'Г.А. Рачинский',
        cleanedFilePath: 'assets/full_texts/philosophy/nietzsche/birth_of_tragedy_cleaned.txt',
        rawFilePath: 'assets/full_texts/philosophy/nietzsche/birth_of_tragedy_raw.txt',
      ),
      BookSource(
        id: 'nietzsche_beyond_good_and_evil',
        title: 'По ту сторону добра и зла',
        author: 'Фридрих Ницше',
        category: 'philosophy',
        language: 'ru',
        translator: 'Н.А. Полторацкий',
        cleanedFilePath: 'assets/full_texts/philosophy/nietzsche/beyond_good_and_evil_cleaned.txt',
        rawFilePath: 'assets/full_texts/philosophy/nietzsche/beyond_good_and_evil_raw.txt',
      ),
      BookSource(
        id: 'schopenhauer_world_as_will',
        title: 'Мир как воля и представление',
        author: 'Артур Шопенгауэр',
        category: 'philosophy',
        language: 'ru',
        translator: 'Ю.И. Айхенвальд',
        cleanedFilePath: 'assets/full_texts/philosophy/schopenhauer/world_as_will_and_representation_cleaned.txt',
        rawFilePath: 'assets/full_texts/philosophy/schopenhauer/world_as_will_and_representation_raw.txt',
      ),
      BookSource(
        id: 'schopenhauer_aphorisms',
        title: 'Афоризмы житейской мудрости',
        author: 'Артур Шопенгауэр',
        category: 'philosophy',
        language: 'ru',
        translator: 'Ф.В. Черниговец',
        cleanedFilePath: 'assets/full_texts/philosophy/schopenhauer/aphorisms_on_wisdom_of_life_cleaned.txt',
        rawFilePath: 'assets/full_texts/philosophy/schopenhauer/aphorisms_on_wisdom_of_life_raw.txt',
      ),
      
      // Язычество и традиционализм
      BookSource(
        id: 'on_being_a_pagan',
        title: 'Как можно быть язычником',
        author: 'Ален де Бенуа',
        category: 'pagan',
        language: 'ru',
        translator: 'А.В. Кубицкий',
        cleanedFilePath: 'assets/full_texts/pagan/de_benua/on_being_a_pagan_cleaned.txt',
        rawFilePath: 'assets/full_texts/pagan/de_benua/on_being_a_pagan_raw.txt',
      ),
      BookSource(
        id: 'de_benua_faith_and_ideas_vol1',
        title: 'История веры и религиозных идей. Том 1',
        author: 'Мирча Элиаде',
        category: 'pagan',
        language: 'ru',
        translator: 'Н.Б. Абалакин',
        cleanedFilePath: 'assets/full_texts/pagan/mercea_eliade/history_of_religious_ideas_vol1_cleaned.txt',
        rawFilePath: 'assets/full_texts/pagan/mercea_eliade/history_of_religious_ideas_vol1_raw.txt',
      ),
      BookSource(
        id: 'de_benua_faith_and_ideas_vol2',
        title: 'История веры и религиозных идей. Том 2',
        author: 'Мирча Элиаде',
        category: 'pagan',
        language: 'ru',
        translator: 'Н.Б. Абалакин',
        cleanedFilePath: 'assets/full_texts/pagan/mercea_eliade/history_of_religious_ideas_vol2_cleaned.txt',
        rawFilePath: 'assets/full_texts/pagan/mercea_eliade/history_of_religious_ideas_vol2_raw.txt',
      ),
      BookSource(
        id: 'askr_svarte_pagan_identity',
        title: 'Идентичность язычника в 21 веке',
        author: 'Askr Svarte (Евгений Ничкасов)',
        category: 'pagan',
        language: 'ru',
        translator: 'Askr Svarte (Евгений Ничкасов)',
        cleanedFilePath: 'assets/full_texts/pagan/askr_svarte/pagan_identity_xxi_cleaned.txt',
        rawFilePath: 'assets/full_texts/pagan/askr_svarte/pagan_identity_xxi_raw.txt',
      ),
      BookSource(
        id: 'askr_svarte_priblizhenie',
        title: 'Приближение и окружение',
        author: 'Askr Svarte (Евгений Ничкасов)',
        category: 'pagan',
        language: 'ru',
        translator: 'Askr Svarte (Евгений Ничкасов)',
        cleanedFilePath: 'assets/full_texts/pagan/askr_svarte/priblizheniye_i_okruzheniye_cleaned.txt',
        rawFilePath: 'assets/full_texts/pagan/askr_svarte/priblizheniye_i_okruzheniye_raw.txt',
      ),
      BookSource(
        id: 'askr_svarte_polemos',
        title: 'Polemos',
        author: 'Askr Svarte (Евгений Ничкасов)',
        category: 'pagan',
        language: 'ru',
        translator: 'Askr Svarte (Евгений Ничкасов)',
        cleanedFilePath: 'assets/full_texts/pagan/askr_svarte/polemos_cleaned.txt',
        rawFilePath: 'assets/full_texts/pagan/askr_svarte/polemos_raw.txt',
      ),
      BookSource(
        id: 'de_benua_faith_and_ideas_vol3',
        title: 'История веры и религиозных идей. Том 3',
        author: 'Мирча Элиаде',
        category: 'pagan',
        language: 'ru',
        translator: 'Н.Б. Абалакин',
        cleanedFilePath: 'assets/full_texts/pagan/mercea_eliade/history_of_religious_ideas_vol3_cleaned.txt',
        rawFilePath: 'assets/full_texts/pagan/mercea_eliade/history_of_religious_ideas_vol3_raw.txt',
      ),
      BookSource(
        id: 'evola_pagan_imperialism',
        title: 'Языческий империализм',
        author: 'Юлиус Эвола',
        category: 'pagan',
        language: 'ru',
        translator: 'В.В. Ванюшкина',
        cleanedFilePath: 'assets/full_texts/pagan/julius_evola/pagan_imperialism_cleaned.txt',
        rawFilePath: 'assets/full_texts/pagan/julius_evola/pagan_imperialism_raw.txt',
      ),
      BookSource(
        id: 'evola_metaphysics_of_sex',
        title: 'Метафизика пола',
        author: 'Юлиус Эвола',
        category: 'pagan',
        language: 'ru',
        translator: 'Л.В. Семенова',
        cleanedFilePath: 'assets/full_texts/pagan/julius_evola/metaphysics_of_sex_cleaned.txt',
        rawFilePath: 'assets/full_texts/pagan/julius_evola/metaphysics_of_sex_raw.txt',
      ),
      BookSource(
        id: 'evola_men_among_ruins',
        title: 'Люди и руины',
        author: 'Юлиус Эвола',
        category: 'pagan',
        language: 'ru',
        translator: 'А.М. Кабанчик',
        cleanedFilePath: 'assets/full_texts/pagan/julius_evola/men_among_ruins_cleaned.txt',
        rawFilePath: 'assets/full_texts/pagan/julius_evola/men_among_ruins_raw.txt',
      ),
      BookSource(
        id: 'eliade_sacred_and_profane',
        title: 'Священное и мирское',
        author: 'Мирча Элиаде',
        category: 'pagan',
        language: 'ru',
        translator: 'Н.К. Гарбовский',
        cleanedFilePath: 'assets/full_texts/pagan/mercea_eliade/sacred_and_profane_cleaned.txt',
        rawFilePath: 'assets/full_texts/pagan/mercea_eliade/sacred_and_profane_raw.txt',
      ),
      BookSource(
        id: 'eliade_myth_eternal_return',
        title: 'Миф о вечном возвращении',
        author: 'Мирча Элиаде',
        category: 'pagan',
        language: 'ru',
        translator: 'А.А. Старостин',
        cleanedFilePath: 'assets/full_texts/pagan/mercea_eliade/myth_of_eternal_return_cleaned.txt',
        rawFilePath: 'assets/full_texts/pagan/mercea_eliade/myth_of_eternal_return_raw.txt',
      ),
    ];

    // Проверяем наличие аудиоверсий для книг
    await _checkAudioVersions(sources);
    
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

  /// Проверяет наличие аудиоверсий для книг
  Future<void> _checkAudioVersions(List<BookSource> sources) async {
    try {
      // Инициализируем Google Drive сервис
      final isInitialized = await _driveService.initialize();
      if (!isInitialized) {
        print('⚠️ Не удалось инициализировать Google Drive сервис для проверки аудиоверсий');
        return;
      }
      
      // Получаем структуру папок с аудиофайлами
      final folderStructure = await _driveService.getAudiobooksByFolders();
      if (folderStructure.isEmpty) {
        print('⚠️ Не найдено папок с аудиокнигами в Google Drive');
        return;
      }
      
      print('🎧 Найдено ${folderStructure.length} папок с аудиокнигами в Google Drive');
      
      // Маппинг ID текстовых книг к названиям папок аудиокниг
      final Map<String, List<String>> bookToAudioFolders = {
        'aristotle_metaphysics': ['аристотель метафизика', 'метафизика'],
        'aristotle_ethics': ['аристотель этика', 'этика'],
        'aristotle_politics': ['аристотель политика', 'политика'],
        'aristotle_rhetoric': ['аристотель риторика', 'риторика'],
        'plato_sophist': ['платон софист', 'софист'],
        'plato_parmenides': ['платон парменид', 'парменид'],
        'homer_iliad': ['гомер илиада', 'илиада'],
        'homer_odyssey': ['гомер одиссея', 'одиссея'],
        'hesiod_labour_and_days': ['гесиод труды', 'труды и дни'],
        'beowulf': ['беовульф'],
        'elder_edda': ['старшая эдда', 'эдда'],
        'heidegger_being_and_time': ['хайдеггер бытие', 'бытие и время'],
        'heidegger_what_means_to_think': ['хайдеггер мыслить', 'что значит мыслить'],
        'nietzsche_antichrist': ['ницше антихрист', 'антихрист'],
        'nietzsche_gay_science': ['ницше веселая', 'веселая наука'],
        'nietzsche_thus_spoke_zarathustra': ['ницше заратустра', 'заратустра'],
        'nietzsche_birth_of_tragedy': ['ницше трагедия', 'рождение трагедии'],
        'nietzsche_beyond_good_and_evil': ['ницше добро зло', 'по ту сторону'],
        'schopenhauer_world_as_will': ['шопенгауэр мир', 'мир как воля'],
        'schopenhauer_aphorisms': ['шопенгауэр афоризмы', 'афоризмы'],
        'on_being_a_pagan': ['де бенуа язычник', 'как можно быть язычником'],
        'eliade_sacred_and_profane': ['элиаде священное', 'священное и мирское'],
        'eliade_myth_eternal_return': ['элиаде миф', 'миф о вечном возвращении'],
        'evola_pagan_imperialism': ['эвола империализм', 'языческий империализм'],
        'evola_metaphysics_of_sex': ['эвола пол', 'метафизика пола'],
        'evola_men_among_ruins': ['эвола руины', 'люди и руины'],
        'askr_svarte_pagan_identity': ['аскр идентичность', 'идентичность язычника'],
        'askr_svarte_priblizhenie': ['аскр приближение', 'приближение и окружение'],
        'askr_svarte_polemos': ['аскр полемос', 'polemos'],
      };
      
      // Проверяем каждую книгу
      for (int i = 0; i < sources.length; i++) {
        final book = sources[i];
        final possibleAudioFolders = bookToAudioFolders[book.id];
        
        if (possibleAudioFolders != null) {
          // Проверяем, есть ли соответствующая папка в Google Drive
          bool hasAudio = false;
          for (final folderName in folderStructure.keys) {
            for (final possibleFolder in possibleAudioFolders) {
              if (folderName.toLowerCase().contains(possibleFolder.toLowerCase()) ||
                  possibleFolder.toLowerCase().contains(folderName.toLowerCase())) {
                hasAudio = true;
                break;
              }
            }
            if (hasAudio) break;
          }
          
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
            print('🎧 Текстовая книга "${book.title}" имеет аудиоверсию');
          }
        }
      }
    } catch (e) {
      print('❌ Ошибка при проверке аудиоверсий: $e');
    }
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
    debugPrint('!!! SACRAL_APP: START INDEX: $startIndex, END INDEX: $endIndex, CENTER INDEX: $centerIndex');
    
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