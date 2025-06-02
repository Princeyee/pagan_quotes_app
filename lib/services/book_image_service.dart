// lib/services/book_image_service.dart
import 'dart:math';
import '../utils/custom_cache.dart';

class BookImageService {
  static final Map<String, List<String>> themeImages = {
    "greece": [
      "https://ik.imagekit.io/3w7tqjsrr/images/greece/katie-moum-9jNcTRncjgM-unsplash.jpg?updatedAt=1747664991681",
      "https://ik.imagekit.io/3w7tqjsrr/images/greece/madeline-pere-r37QcATSbD4-unsplash.jpg?updatedAt=1747664991633",
      "https://ik.imagekit.io/3w7tqjsrr/images/greece/brice-cooper-ia-OTo1PglI-unsplash.jpg?updatedAt=1747664990089",
      "https://ik.imagekit.io/3w7tqjsrr/images/greece/the-new-york-public-library-XUlyS4W0JG4-unsplash.jpg?updatedAt=1747664496333",
      "https://ik.imagekit.io/3w7tqjsrr/images/greece/reiseuhu-jav87KjO2sc-unsplash.jpg?updatedAt=1747664496051",
      "https://ik.imagekit.io/3w7tqjsrr/images/greece/pexels-josiah-lewis-253232-772690.jpg?updatedAt=1747664495427",
      "https://ik.imagekit.io/3w7tqjsrr/images/greece/pexels-miraclekilly-199436491-11775861.jpg?updatedAt=1747664492245",
      "https://ik.imagekit.io/3w7tqjsrr/images/greece/pexels-jean-marc-bonnel-387362531-29128073.jpg?updatedAt=1747664488124",
      "https://ik.imagekit.io/3w7tqjsrr/images/greece/natalia-marcelewicz-qYzir1weLjI-unsplash.jpg?updatedAt=1747664488133",
      "https://ik.imagekit.io/3w7tqjsrr/images/greece/karol-chomka-K-k6-9i027U-unsplash.jpg?updatedAt=1747664488011",
      "https://ik.imagekit.io/3w7tqjsrr/images/greece/mike-chrisemer-Ed3rSGBYMuw-unsplash.jpg?updatedAt=1747664487813",
      "https://ik.imagekit.io/3w7tqjsrr/images/greece/pexels-hert-3224232.jpg?updatedAt=1747664487344",
      "https://ik.imagekit.io/3w7tqjsrr/images/greece/embla-munk-rynkebjerg-xs0PH19z5LM-unsplash.jpg?updatedAt=1747664485203",
      "https://ik.imagekit.io/3w7tqjsrr/images/greece/content-pixie-T9atF7iWhxw-unsplash.jpg?updatedAt=1747664483979",
      "https://ik.imagekit.io/3w7tqjsrr/images/greece/artists-eyes-v_5F8_1ROSg-unsplash.jpg?updatedAt=1747664484092",
      "https://ik.imagekit.io/3w7tqjsrr/images/greece/john-koliogiannis--sI6im4tj9o-unsplash.jpg?updatedAt=1747664483744",
      "https://ik.imagekit.io/3w7tqjsrr/images/greece/goutham-krishna-h5wvMCdOV3w-unsplash.jpg?updatedAt=1747664482300",
      "https://ik.imagekit.io/3w7tqjsrr/images/greece/david-cano-soriano-GByqbsuYI8M-unsplash.jpg?updatedAt=1747664480797",
      "https://ik.imagekit.io/3w7tqjsrr/images/greece/IMG_0605.JPG?updatedAt=1747664480375",
      "https://ik.imagekit.io/3w7tqjsrr/images/greece/bugra-karacam-hPwlvbaNE7E-unsplash.jpg?updatedAt=1747664477009",
    ],
    "nordic": [
      "https://ik.imagekit.io/3w7tqjsrr/images/nordic/muhammad-abdullah-4QUS_JW48KY-unsplash.jpg?updatedAt=1747665209978",
      "https://ik.imagekit.io/3w7tqjsrr/images/nordic/taras-truba-KWRFLdCqmpI-unsplash.jpg?updatedAt=1747664477378",
      "https://ik.imagekit.io/3w7tqjsrr/images/nordic/poppy-waddington-CiXY-6-NAlY-unsplash.jpg?updatedAt=1747664474878",
      "https://ik.imagekit.io/3w7tqjsrr/images/nordic/pexels-introspectivedsgn-5023742.jpg?updatedAt=1747664474492",
      "https://ik.imagekit.io/3w7tqjsrr/images/nordic/pexels-introspectivedsgn-5023686.jpg?updatedAt=1747664474478",
      "https://ik.imagekit.io/3w7tqjsrr/images/nordic/pexels-barnabas-davoti-31615494-8976091.jpg?updatedAt=1747664474075",
      "https://ik.imagekit.io/3w7tqjsrr/images/nordic/pexels-introspectivedsgn-5023692.jpg?updatedAt=1747664473625",
      "https://ik.imagekit.io/3w7tqjsrr/images/nordic/pexels-introspectivedsgn-5023699.jpg?updatedAt=1747664472739",
      "https://ik.imagekit.io/3w7tqjsrr/images/nordic/nicolas-lafargue-JnZ0iPdXTzg-unsplash.jpg?updatedAt=1747664469804",
      "https://ik.imagekit.io/3w7tqjsrr/images/nordic/matt-hanns-schroeter-fU707Rci5Xw-unsplash.jpg?updatedAt=1747664469597",
      "https://ik.imagekit.io/3w7tqjsrr/images/nordic/michael-fortsch-jvs9EcQMX2I-unsplash.jpg?updatedAt=1747664469586",
      "https://ik.imagekit.io/3w7tqjsrr/images/nordic/nika-benedictova-N06Fv3SpCUA-unsplash.jpg?updatedAt=1747664469453",
      "https://ik.imagekit.io/3w7tqjsrr/images/nordic/johannes-andersson-UCd78vfC8vU-unsplash.jpg?updatedAt=1747664467865",
      "https://ik.imagekit.io/3w7tqjsrr/images/nordic/kristijan-arsov-tcw3nwoAgvs-unsplash.jpg?updatedAt=1747664466113",
      "https://ik.imagekit.io/3w7tqjsrr/images/nordic/katie-moum-kKtD7ZsgE0U-unsplash.jpg?updatedAt=1747664463064",
      "https://ik.imagekit.io/3w7tqjsrr/images/nordic/IMG_0599.JPG?updatedAt=1747664462320",
      "https://ik.imagekit.io/3w7tqjsrr/images/nordic/alfred-kenneally-0hNbWbzwPB4-unsplash.jpg?updatedAt=1747664461601",
      "https://ik.imagekit.io/3w7tqjsrr/images/nordic/IMG_0601.JPG?updatedAt=1747664460688",
      "https://ik.imagekit.io/3w7tqjsrr/images/nordic/ashutosh-gupta-gPE2TpJlTJE-unsplash.jpg?updatedAt=1747664459096",
      "https://ik.imagekit.io/3w7tqjsrr/images/nordic/adel-z-rmOmNSE5UBs-unsplash.jpg?updatedAt=1747664457964",
    ],
    "pagan": [
      "https://ik.imagekit.io/3w7tqjsrr/images/pagan/laura-vinck-Hyu76loQLdk-unsplash.jpg?updatedAt=1747665375775",
      "https://ik.imagekit.io/3w7tqjsrr/images/pagan/silvan-schuppisser-YaV5xGq96gc-unsplash.jpg?updatedAt=1747664457287",
      "https://ik.imagekit.io/3w7tqjsrr/images/pagan/rolf-neumann-FYO4qGQDstk-unsplash.jpg?updatedAt=1747664456192",
      "https://ik.imagekit.io/3w7tqjsrr/images/pagan/pexels-maria-loznevaya-249159277-17670248.jpg?updatedAt=1747664455311",
      "https://ik.imagekit.io/3w7tqjsrr/images/pagan/pexels-leefinvrede-31147796.jpg?updatedAt=1747664455277",
      "https://ik.imagekit.io/3w7tqjsrr/images/pagan/pexels-valerie-13727324.jpg?updatedAt=1747664454076",
      "https://ik.imagekit.io/3w7tqjsrr/images/pagan/pexels-valeria-klys-343615194-14544393.jpg?updatedAt=1747664453237",
      "https://ik.imagekit.io/3w7tqjsrr/images/pagan/pexels-valeria-klys-343615194-14544394.jpg?updatedAt=1747664453017",
      "https://ik.imagekit.io/3w7tqjsrr/images/pagan/pexels-vladbagacian-1061623.jpg?updatedAt=1747664452194",
      "https://ik.imagekit.io/3w7tqjsrr/images/pagan/lora-ninova-U86FnrpRR0k-unsplash.jpg?updatedAt=1747664450708",
      "https://ik.imagekit.io/3w7tqjsrr/images/pagan/pexels-anatolii-hrytsenko-2045332-30919014.jpg?updatedAt=1747664449864",
      "https://ik.imagekit.io/3w7tqjsrr/images/pagan/iza-gawrych-3VEuFt2Duug-unsplash.jpg?updatedAt=1747664448101",
      "https://ik.imagekit.io/3w7tqjsrr/images/pagan/lasse-moller-4y0N8xUBsQs-unsplash.jpg?updatedAt=1747664445420",
      "https://ik.imagekit.io/3w7tqjsrr/images/pagan/IMG_0604.JPG?updatedAt=1747664444085",
      "https://ik.imagekit.io/3w7tqjsrr/images/pagan/casey-horner-1sim8ojvCbE-unsplash.jpg?updatedAt=1747664443759",
      "https://ik.imagekit.io/3w7tqjsrr/images/pagan/chris-curry-Eq4BNCL0jx4-unsplash.jpg?updatedAt=1747664443365",
      "https://ik.imagekit.io/3w7tqjsrr/images/pagan/IMG_0602.JPG?updatedAt=1747664441557",
      "https://ik.imagekit.io/3w7tqjsrr/images/pagan/IMG_0603.JPG?updatedAt=1747664441343",
      "https://ik.imagekit.io/3w7tqjsrr/images/pagan/alexis-antonio-TFth26tEjss-unsplash.jpg?updatedAt=1747664440061",
      "https://ik.imagekit.io/3w7tqjsrr/images/pagan/altinay-dinc-LluELtL5mK4-unsplash.jpg?updatedAt=1747664439890",
    ],
    "philosophy": [
      "https://ik.imagekit.io/3w7tqjsrr/images/philosophy/jei-lee-pr0I-DUB5eA-unsplash.jpg?updatedAt=1747666260630",
      "https://ik.imagekit.io/3w7tqjsrr/images/philosophy/andres-perez-AUrK7wuV8fE-unsplash.jpg?updatedAt=1747666260147",
      "https://ik.imagekit.io/3w7tqjsrr/images/philosophy/nathan-dumlao-OHzkfrv9Ycw-unsplash.jpg?updatedAt=1747666259844",
      "https://ik.imagekit.io/3w7tqjsrr/images/philosophy/wren-meinberg-xqV9QdGOSas-unsplash.jpg?updatedAt=1747664442237",
      "https://ik.imagekit.io/3w7tqjsrr/images/philosophy/pexels-n-voitkevich-5201598.jpg?updatedAt=1747664441207",
      "https://ik.imagekit.io/3w7tqjsrr/images/philosophy/vince-gx-lUYkDFU3FKQ-unsplash.jpg?updatedAt=1747664440866",
      "https://ik.imagekit.io/3w7tqjsrr/images/philosophy/pexels-eberhardgross-2310641.jpg?updatedAt=1747664436672",
      "https://ik.imagekit.io/3w7tqjsrr/images/philosophy/sara-kurfess-ltE8bDLjX9E-unsplash.jpg?updatedAt=1747664436227",
      "https://ik.imagekit.io/3w7tqjsrr/images/philosophy/rinck-content-studio-dovoV_nkJFE-unsplash.jpg?updatedAt=1747664434499",
      "https://ik.imagekit.io/3w7tqjsrr/images/philosophy/ben-moreland-KtZOt9X7jiw-unsplash.jpg?updatedAt=1747664434366",
      "https://ik.imagekit.io/3w7tqjsrr/images/philosophy/raphael-renter-raphi_rawr-VO_c55zvyrk-unsplash.jpg?updatedAt=1747664432656",
      "https://ik.imagekit.io/3w7tqjsrr/images/philosophy/pexels-vladbagacian-1061623.jpg?updatedAt=1747664432537",
      "https://ik.imagekit.io/3w7tqjsrr/images/philosophy/pexels-azamat-hatypov-97167739-18148158.jpg?updatedAt=1747664432441",
      "https://ik.imagekit.io/3w7tqjsrr/images/philosophy/pexels-eberhardgross-2098427.jpg?updatedAt=1747664428254",
      "https://ik.imagekit.io/3w7tqjsrr/images/philosophy/pexels-eberhardgross-1624438.jpg?updatedAt=1747664427001",
      "https://ik.imagekit.io/3w7tqjsrr/images/philosophy/pexels-aronvisuals-1743165.jpg?updatedAt=1747664425879",
      "https://ik.imagekit.io/3w7tqjsrr/images/philosophy/anna-keibalo-s0tqhVq-3hI-unsplash.jpg?updatedAt=1747664425089",
      "https://ik.imagekit.io/3w7tqjsrr/images/philosophy/art-institute-of-chicago-o8shn_qY1Vg-unsplash.jpg?updatedAt=1747664424944",
      "https://ik.imagekit.io/3w7tqjsrr/images/philosophy/gleb-lukomets-xXj3ctfRmvw-unsplash.jpg?updatedAt=1747664424015",
      "https://ik.imagekit.io/3w7tqjsrr/images/philosophy/IMG_0600.JPG?updatedAt=1747664422044",
    ],
  };

  static Future<String> getStableBookImage(String bookId, String category) async {
    final cache = CustomCache.prefs;
    final cacheKey = 'book_image_$bookId';
    
    String? cachedImageUrl = cache.getSetting<String>(cacheKey);
    if (cachedImageUrl != null) {
      return cachedImageUrl;
    }
    
    final imageUrl = _generateStableImage(bookId, category);
    
    await cache.setSetting(cacheKey, imageUrl);
    
    return imageUrl;
  }

  static String _generateStableImage(String bookId, String category) {
    final images = themeImages[category] ?? themeImages['philosophy']!;
    
    int hash = bookId.hashCode;
    if (hash < 0) hash = -hash;
    
    final index = hash % images.length;
    return images[index];
  }

  static String getRandomImage(String theme) {
    final list = themeImages[theme] ?? themeImages['philosophy']!;
    return list[Random().nextInt(list.length)];
  }

  static Future<void> clearBookImagesCache() async {
    final cache = CustomCache.prefs;
    final allSettings = cache.getSettings();
    
    for (final key in allSettings.keys.toList()) {
      if (key.startsWith('book_image_')) {
        await cache.setSetting(key, null);
      }
    }
  }

  static Future<void> preloadBookImages(List<String> bookIds, List<String> categories) async {
    for (int i = 0; i < bookIds.length; i++) {
      final bookId = bookIds[i];
      final category = i < categories.length ? categories[i] : 'philosophy';
      
      await getStableBookImage(bookId, category);
    }
  }
}