import 'dart:convert';
import 'dart:io';

void main() async {
  try {
    final file = File('assets/curated/my_quotes_approved.json');
    final content = await file.readAsString();
    final jsonData = json.decode(content) as List;
    
    print('✅ JSON синтаксис корректен');
    print('📊 Всего цитат: ${jsonData.length}');
    
    // Проверяем уникальность ID
    final ids = <String>{};
    final duplicates = <String>[];
    
    for (final item in jsonData) {
      final id = item['id'] as String;
      if (ids.contains(id)) {
        duplicates.add(id);
      } else {
        ids.add(id);
      }
    }
    
    if (duplicates.isNotEmpty) {
      print('❌ Найдены дублирующиеся ID: $duplicates');
    } else {
      print('✅ Все ID уникальны');
    }
    
    // Проверяем соответствие ID и авторов
    final mismatches = <String>[];
    for (final item in jsonData) {
      final id = item['id'] as String;
      final author = item['author'] as String;
      final source = item['source'] as String;
      
      if (id.contains('Хайдеггер') && author != 'Мартин Хайдеггер') {
        mismatches.add('ID: $id, Author: $author, Source: $source');
      }
      if (id.contains('Шопенгауэр') && author != 'Артур Шопенгауэр') {
        mismatches.add('ID: $id, Author: $author, Source: $source');
      }
      if (id.contains('Ницше') && author != 'Фридрих Ницше') {
        mismatches.add('ID: $id, Author: $author, Source: $source');
      }
    }
    
    if (mismatches.isNotEmpty) {
      print('❌ Найдены несоответствия ID и авторов:');
      for (final mismatch in mismatches) {
        print('   $mismatch');
      }
    } else {
      print('✅ Все ID соответствуют авторам');
    }
    
  } catch (e) {
    print('❌ Ошибка при проверке JSON: $e');
  }
} 