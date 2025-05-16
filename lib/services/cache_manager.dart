import 'package:flutter_cache_manager/flutter_cache_manager.dart';

class CustomCache {
  static final CacheManager instance = CacheManager(
    Config(
      'quoteImagesCache', // имя кэша
      stalePeriod: const Duration(days: 30), // храним 30 дней
      maxNrOfCacheObjects: 200, // до 200 изображений
    ),
  );
}