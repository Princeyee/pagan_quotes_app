// Временный тест для проверки логики поиска источников
import 'lib/services/text_file_service.dart';

void main() async {
  final textService = TextFileService();
  await textService.loadBookSources();
  
  // Тестируем поиск для Ницше
  print('\n=== ТЕСТ НИЦШЕ ===');
  var source = textService.findBookSource('Ницше', 'Заратустра');
  print('Ницше + Заратустра -> ${source?.title}');
  
  source = textService.findBookSource('Ницше', 'Антихрист');
  print('Ницше + Антихрист -> ${source?.title}');
  
  source = textService.findBookSource('Фридрих Ницше', 'Так говорил Заратустра');
  print('Фридрих Ницше + Так говорил Заратустра -> ${source?.title}');
  
  // Тестируем поиск для Аристотеля
  print('\n=== ТЕСТ АРИСТОТЕЛЬ ===');
  source = textService.findBookSource('Аристотель', 'Метафизика');
  print('Аристотель + Метафизика -> ${source?.title}');
  
  source = textService.findBookSource('Аристотель', 'Этика');
  print('Аристотель + Этика -> ${source?.title}');
  
  // Тестируем поиск для других авторов
  print('\n=== ТЕСТ ДРУГИЕ АВТОРЫ ===');
  source = textService.findBookSource('Платон', 'Софист');
  print('Платон + Софист -> ${source?.title}');
  
  source = textService.findBookSource('Хайдеггер', 'Бытие и время');
  print('Хайдеггер + Бытие и время -> ${source?.title}');
  
  source = textService.findBookSource('Эвола', 'Метафизика пола');
  print('Эвола + Метафизика пола -> ${source?.title}');
} 