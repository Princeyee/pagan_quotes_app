import 'dart:convert';
import 'dart:io';
import 'dart:math';

/// Скрипт для исправления позиций цитат в JSON файлах
/// Находит правильные позиции цитат в текстовых файлах и обновляет JSON
void main() async {
  print('🔧 Начинаем исправление позиций цитат...');
  
  // Загружаем все JSON файлы с цитатами
  final jsonFiles = [
    'assets/curated/my_quotes_approved.json',
    'assets/curated/my_quotes_approved_4.json',
    'assets/curated/my_quotes_approved_5.json',
    'assets/curated/my_quotes_approved10.json',
  ];
  
  // Маппинг источников к файлам
  final sourceMapping = {
    'Так говорил Заратустра': 'assets/full_texts/philosophy/nietzsche/thus_spoke_zarathustra_cleaned.txt',
    'Антихрист': 'assets/full_texts/philosophy/nietzsche/antichrist_cleaned.txt',
    'Веселая наука': 'assets/full_texts/philosophy/nietzsche/gay_science_cleaned.txt',
    'По ту сторону добра и зла': 'assets/full_texts/philosophy/nietzsche/beyond_good_and_evil_cleaned.txt',
    'Рождение трагедии из духа музыки': 'assets/full_texts/philosophy/nietzsche/birth_of_tragedy_cleaned.txt',
    'Что значит мыслить': 'assets/full_texts/philosophy/heidegger/what_means_to_think_cleaned.txt',
    'Бытие и время': 'assets/full_texts/philosophy/heidegger/being_and_time_cleaned.txt',
    'Метафизика': 'assets/full_texts/greece/aristotle/metaphysics_cleaned.txt',
    'Никомахова этика': 'assets/full_texts/greece/aristotle/ethics_cleaned.txt',
    'Политика': 'assets/full_texts/greece/aristotle/politics_cleaned.txt',
    'Риторика': 'assets/full_texts/greece/aristotle/rhetoric_cleaned.txt',
    'Софист': 'assets/full_texts/greece/plato/sophist_cleaned.txt',
    'Парменид': 'assets/full_texts/greece/plato/parmenides_cleaned.txt',
    'Илиада': 'assets/full_texts/greece/homer/iliad_cleaned.txt',
    'Одиссея': 'assets/full_texts/greece/homer/odyssey_cleaned.txt',
    'Труды и дни': 'assets/full_texts/greece/hesiod/labour_and_days_cleaned.txt',
    'Беовульф': 'assets/full_texts/nordic/folk/beowulf_cleaned.txt',
    'Старшая Эдда': 'assets/full_texts/nordic/folk/elder_edda_cleaned.txt',
    'Приближение и окружение': 'assets/full_texts/pagan/askr_svarte/priblizheniye_i_okruzheniye_cleaned.txt',
    'Идентичность язычника в 21 веке': 'assets/full_texts/pagan/askr_svarte/pagan_identity_xxi_cleaned.txt',
    'Polemos': 'assets/full_texts/pagan/askr_svarte/polemos_cleaned.txt',
  };
  
  // Кэш для текстовых файлов
  final textCache = <String, String>{};
  
  for (final jsonFile in jsonFiles) {
    print('\n📄 Обрабатываем файл: $jsonFile');
    
    try {
      // Загружаем JSON
      final jsonString = await File(jsonFile).readAsString();
      final quotes = jsonDecode(jsonString) as List<dynamic>;
      
      int fixedCount = 0;
      
      for (int i = 0; i < quotes.length; i++) {
        final quote = quotes[i] as Map<String, dynamic>;
        final source = quote['source'] as String;
        final text = quote['text'] as String;
        final currentPosition = quote['position'] as int;
        
        // Проверяем, есть ли маппинг для этого источника
        if (sourceMapping.containsKey(source)) {
          final textFilePath = sourceMapping[source]!;
          
          // Загружаем текстовый файл (кэшируем)
          String fullText;
          if (textCache.containsKey(textFilePath)) {
            fullText = textCache[textFilePath]!;
          } else {
            fullText = await File(textFilePath).readAsString();
            textCache[textFilePath] = fullText;
          }
          
          // Ищем правильную позицию
          final correctPosition = findQuotePosition(fullText, text);
          
          if (correctPosition != null && correctPosition != currentPosition) {
            print('✅ Исправляем позицию для цитаты "${text.substring(0, min(50, text.length))}..."');
            print('   Старая позиция: $currentPosition -> Новая позиция: $correctPosition');
            quotes[i]['position'] = correctPosition;
            fixedCount++;
          }
        }
      }
      
      // Сохраняем исправленный JSON
      if (fixedCount > 0) {
        final updatedJson = jsonEncode(quotes);
        await File(jsonFile).writeAsString(updatedJson);
        print('💾 Сохранено $fixedCount исправлений в $jsonFile');
      } else {
        print('ℹ️ Исправления не требуются для $jsonFile');
      }
      
    } catch (e) {
      print('❌ Ошибка обработки $jsonFile: $e');
    }
  }
  
  print('\n🎉 Исправление позиций завершено!');
}

/// Находит позицию цитаты в тексте
int? findQuotePosition(String fullText, String quoteText) {
  // Извлекаем все параграфы с позициями
  final regex = RegExp(r'\[pos:(\d+)\]\s*((?:(?!\[pos:\d+\])[\s\S])*)', multiLine: true);
  final matches = regex.allMatches(fullText);
  
  for (final match in matches) {
    final position = int.parse(match.group(1)!);
    final content = match.group(2)!.trim();
    
    // Нормализуем текст для сравнения
    final normalizedContent = content.replaceAll(RegExp(r'\s+'), ' ').trim();
    final normalizedQuote = quoteText.replaceAll(RegExp(r'\s+'), ' ').trim();
    
    // Проверяем точное совпадение
    if (normalizedContent.toLowerCase() == normalizedQuote.toLowerCase()) {
      return position;
    }
    
    // Проверяем частичное совпадение (если цитата длинная)
    if (normalizedQuote.length > 30) {
      final searchText = normalizedQuote.substring(0, min(50, normalizedQuote.length));
      if (normalizedContent.toLowerCase().contains(searchText.toLowerCase())) {
        return position;
      }
    }
  }
  
  return null;
} 