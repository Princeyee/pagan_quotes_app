// lib/models/pagan_holiday.dart - ОБНОВЛЕННАЯ ВЕРСИЯ С ДОПОЛНИТЕЛЬНЫМИ ПРАЗДНИКАМИ
class PaganHoliday {
  final String id;
  final String name;
  final String nameOriginal; // Название на оригинальном языке
  final DateTime date;
  final String tradition; // nordic, slavic, celtic, germanic, etc.
  final String description;
  final String? longDescription;
  final List<String> traditions; // Традиции празднования
  final List<String> symbols; // Символы праздника
  final String? imageUrl;
  final bool isRecurring; // Повторяется ли каждый год
  final PaganHolidayType type;

  const PaganHoliday({
    required this.id,
    required this.name,
    required this.nameOriginal,
    required this.date,
    required this.tradition,
    required this.description,
    this.longDescription,
    required this.traditions,
    required this.symbols,
    this.imageUrl,
    this.isRecurring = true,
    required this.type,
  });

  factory PaganHoliday.fromJson(Map<String, dynamic> json) {
    return PaganHoliday(
      id: json['id'] as String,
      name: json['name'] as String,
      nameOriginal: json['nameOriginal'] as String,
      date: DateTime.parse(json['date'] as String),
      tradition: json['tradition'] as String,
      description: json['description'] as String,
      longDescription: json['longDescription'] as String?,
      traditions: List<String>.from(json['traditions'] as List),
      symbols: List<String>.from(json['symbols'] as List),
      imageUrl: json['imageUrl'] as String?,
      isRecurring: json['isRecurring'] as bool? ?? true,
      type: PaganHolidayType.values.firstWhere(
        (e) => e.toString() == 'PaganHolidayType.${json['type']}',
        orElse: () => PaganHolidayType.seasonal,
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'nameOriginal': nameOriginal,
      'date': date.toIso8601String(),
      'tradition': tradition,
      'description': description,
      'longDescription': longDescription,
      'traditions': traditions,
      'symbols': symbols,
      'imageUrl': imageUrl,
      'isRecurring': isRecurring,
      'type': type.toString().split('.').last,
    };
  }

  /// Получает дату для конкретного года
  DateTime getDateForYear(int year) {
    return DateTime(year, date.month, date.day);
  }

  /// Проверяет, выпадает ли праздник на указанную дату
  bool isOnDate(DateTime checkDate) {
    return date.month == checkDate.month && date.day == checkDate.day;
  }

  /// Получает цвет традиции
 String get traditionColor {
  switch (tradition.toLowerCase()) {
    case 'nordic':
    case 'scandinavian':
      return '#4A90E2'; // Синий
    case 'slavic':
      return '#E24A4A'; // Красный
    case 'celtic':
      return '#4AE24A'; // Зеленый
    case 'germanic':
      return '#E2A94A'; // Золотой
    case 'roman':
      return '#A94AE2'; // Фиолетовый (уже есть!)
    case 'greek':
      return '#4AE2E2'; // Бирюзовый (уже есть!)
    // НУЖНО ДОБАВИТЬ:
    case 'baltic':
      return '#E2E24A'; // Желтый
    case 'finnish':
    case 'finno-ugric':
      return '#E2A9A9'; // Розовый
    default:
      return '#E2E2E2'; // Серый
  }
}

  @override
  String toString() {
    return 'PaganHoliday(id: $id, name: $name, tradition: $tradition)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is PaganHoliday && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}

enum PaganHolidayType {
  seasonal, // Сезонные праздники (солнцестояния, равноденствия)
  lunar, // Лунные праздники
  harvest, // Праздники урожая
  ancestor, // Почитание предков
  deity, // Посвященные божествам
  fire, // Огненные праздники
  water, // Водные праздники
  nature, // Природные праздники
  protection, // Защитные ритуалы
  fertility, // Праздники плодородия
}

/// Сервис для работы с языческими праздниками
class PaganHolidayService {
  static final List<PaganHoliday> _holidays = [
    // =============== ЗИМНЕЕ СОЛНЦЕСТОЯНИЕ (21 декабря) ===============
    PaganHoliday(
      id: 'yule_nordic',
      name: 'Йоль',
      nameOriginal: 'Jól',
      date: DateTime(2024, 12, 21),
      tradition: 'nordic',
      description: 'Зимнее солнцестояние, праздник возрождения света',
      longDescription: 'Йоль — один из важнейших праздников северной традиции, отмечающий самую длинную ночь в году и возрождение солнца. В эти дни жгли костры, чтобы помочь солнцу вернуться, и проводили ритуалы защиты дома.',
      traditions: ['Сжигание йольского полена', 'Украшение елки', 'Пиры с родственниками', 'Ритуалы защиты'],
      symbols: ['Йольское полено', 'Вечнозеленые ветви', 'Руны', 'Свечи'],
      type: PaganHolidayType.seasonal,
    ),
    
    PaganHoliday(
      id: 'winter_solstice_celtic',
      name: 'Альбан Артан',
      nameOriginal: 'Alban Arthan',
      date: DateTime(2024, 12, 21),
      tradition: 'celtic',
      description: 'Кельтское зимнее солнцестояние, время обновления',
      longDescription: 'Альбан Артан — древний кельтский праздник зимнего солнцестояния, когда друиды проводили ритуалы возрождения света и жизни.',
      traditions: ['Ритуалы в священных рощах', 'Зажигание костров', 'Сбор омелы', 'Пророчества на новый год'],
      symbols: ['Омела', 'Дуб', 'Белые камни', 'Золотой серп'],
      type: PaganHolidayType.seasonal,
    ),

    PaganHoliday(
      id: 'winter_solstice_slavic',
      name: 'Коляда',
      nameOriginal: 'Коляда',
      date: DateTime(2024, 12, 21),
      tradition: 'slavic',
      description: 'Славянское зимнее солнцестояние, праздник поворота к свету',
      longDescription: 'Коляда — древнеславянский праздник, посвященный возрождению солнца и началу его победы над тьмой.',
      traditions: ['Колядование', 'Ряжение', 'Ритуальные песни', 'Жжение костров'],
      symbols: ['Коляда-солнце', 'Снежинки', 'Звезда', 'Колесо'],
      type: PaganHolidayType.seasonal,
    ),

    // =============== ВЕСЕННЕЕ РАВНОДЕНСТВИЕ (20 марта) ===============
    PaganHoliday(
      id: 'ostara',
      name: 'Остара',
      nameOriginal: 'Ostara',
      date: DateTime(2024, 3, 20),
      tradition: 'germanic',
      description: 'Весеннее равноденствие, праздник плодородия и возрождения',
      longDescription: 'Остара — время равновесия дня и ночи, когда природа пробуждается после зимнего сна. Посвящен германской богине рассвета Эостре.',
      traditions: ['Украшение яиц', 'Посадка семян', 'Сбор весенних цветов', 'Ритуалы плодородия'],
      symbols: ['Яйца', 'Зайцы', 'Весенние цветы', 'Молодые побеги'],
      type: PaganHolidayType.seasonal,
    ),

    PaganHoliday(
      id: 'spring_equinox_slavic',
      name: 'Жаворонки',
      nameOriginal: 'Жаворонки',
      date: DateTime(2024, 3, 20),
      tradition: 'slavic',
      description: 'Славянское весеннее равноденствие, встреча весны',
      longDescription: 'Праздник прилета птиц и пробуждения природы, когда пекли птичек из теста и призывали весну.',
      traditions: ['Выпечка жаворонков', 'Призывание птиц', 'Встреча рассвета', 'Заклинания весны'],
      symbols: ['Птицы', 'Первые цветы', 'Хлебные птички', 'Солнечные лучи'],
      type: PaganHolidayType.seasonal,
    ),

    // =============== ЛЕТНЕЕ СОЛНЦЕСТОЯНИЕ (21 июня) ===============
    PaganHoliday(
      id: 'midsummer_nordic',
      name: 'Мидсоммар',
      nameOriginal: 'Midsommar',
      date: DateTime(2024, 6, 21),
      tradition: 'nordic',
      description: 'Летнее солнцестояние, пик силы солнца',
      longDescription: 'Мидсоммар — празднование самого длинного дня в году, когда солнце достигает своей максимальной силы.',
      traditions: ['Танцы вокруг майского столба', 'Плетение венков', 'Сбор трав', 'Костры на холмах'],
      symbols: ['Майский столб', 'Полевые цветы', 'Солнечное колесо', 'Березовые ветви'],
      type: PaganHolidayType.seasonal,
    ),

    PaganHoliday(
      id: 'kupala_slavic',
      name: 'Купала',
      nameOriginal: 'Иван Купала',
      date: DateTime(2024, 7, 7), // По старому стилю
      tradition: 'slavic',
      description: 'Праздник летнего солнцестояния, воды и огня',
      longDescription: 'Купала — древний славянский праздник, сочетающий в себе культ огня и воды. Время поиска цветка папоротника, очистительных ритуалов и гаданий.',
      traditions: ['Прыжки через костры', 'Купание в реках', 'Плетение венков', 'Поиск цветка папоротника'],
      symbols: ['Костры', 'Венки', 'Папоротник', 'Вода'],
      type: PaganHolidayType.fire,
    ),

    PaganHoliday(
      id: 'litha_celtic',
      name: 'Лита',
      nameOriginal: 'Litha',
      date: DateTime(2024, 6, 21),
      tradition: 'celtic',
      description: 'Кельтское летнее солнцестояние, праздник света',
      longDescription: 'Лита — кельтский праздник летнего солнцестояния, время максимальной силы природы и магии.',
      traditions: ['Сбор лечебных трав', 'Костры на рассвете', 'Ритуалы плодородия', 'Танцы под звездами'],
      symbols: ['Дубовые листья', 'Лечебные травы', 'Солнечные диски', 'Золотые цветы'],
      type: PaganHolidayType.seasonal,
    ),

    // =============== ОСЕННЕЕ РАВНОДЕНСТВИЕ (22 сентября) ===============
    PaganHoliday(
      id: 'mabon',
      name: 'Мабон',
      nameOriginal: 'Mabon',
      date: DateTime(2024, 9, 22),
      tradition: 'celtic',
      description: 'Осеннее равноденствие, второй праздник урожая',
      longDescription: 'Мабон — время благодарности за урожай и подготовки к зиме. Равновесие света и тьмы перед наступлением темной половины года.',
      traditions: ['Сбор урожая', 'Консервирование', 'Украшение дома плодами', 'Ритуалы благодарности'],
      symbols: ['Осенние листья', 'Яблоки', 'Тыквы', 'Рог изобилия'],
      type: PaganHolidayType.harvest,
    ),

    PaganHoliday(
      id: 'autumn_equinox_slavic',
      name: 'Радогощь',
      nameOriginal: 'Радогощь',
      date: DateTime(2024, 9, 22),
      tradition: 'slavic',
      description: 'Славянское осеннее равноденствие, праздник урожая',
      longDescription: 'Радогощь — славянский праздник осеннего равноденствия, время благодарения богов за собранный урожай.',
      traditions: ['Освящение плодов', 'Пиры в честь урожая', 'Поминание предков', 'Заготовки на зиму'],
      symbols: ['Спелые плоды', 'Хлебные снопы', 'Красные листья', 'Рог изобилия'],
      type: PaganHolidayType.harvest,
    ),

    // =============== ДРУГИЕ ВАЖНЫЕ ПРАЗДНИКИ ===============
    PaganHoliday(
      id: 'imbolc',
      name: 'Имболк',
      nameOriginal: 'Imbolc',
      date: DateTime(2024, 2, 1),
      tradition: 'celtic',
      description: 'Праздник пробуждения земли и первых признаков весны',
      longDescription: 'Имболк отмечает середину пути между зимним солнцестоянием и весенним равноденствием. Это время очищения, новых начинаний и почитания богини Бригид.',
      traditions: ['Зажигание свечей', 'Очищение дома', 'Плетение соломенных кукол', 'Ритуалы с водой'],
      symbols: ['Свечи', 'Подснежники', 'Солома', 'Колодцы'],
      type: PaganHolidayType.seasonal,
    ),

    PaganHoliday(
      id: 'beltane',
      name: 'Белтайн',
      nameOriginal: 'Beltane',
      date: DateTime(2024, 5, 1),
      tradition: 'celtic',
      description: 'Праздник плодородия, страсти и расцвета жизни',
      longDescription: 'Белтайн — один из четырех главных кельтских праздников, отмечающий пик весны и начало лета. Время союза Бога и Богини, расцвета природы.',
      traditions: ['Майские танцы', 'Прыжки через костры', 'Украшение майскими цветами', 'Ритуалы любви'],
      symbols: ['Майское дерево', 'Боярышник', 'Зеленые ленты', 'Костры'],
      type: PaganHolidayType.fertility,
    ),

    PaganHoliday(
      id: 'lammas',
      name: 'Ламмас',
      nameOriginal: 'Lughnasadh',
      date: DateTime(2024, 8, 1),
      tradition: 'celtic',
      description: 'Первый праздник урожая, посвященный богу Лугу',
      longDescription: 'Ламмас отмечает начало сезона урожая и посвящен кельтскому богу мастерства Лугу. Время благодарности за первые плоды земли.',
      traditions: ['Выпечка хлеба', 'Сбор первого урожая', 'Ярмарки и состязания', 'Жертвоприношения богам'],
      symbols: ['Колосья пшеницы', 'Хлеб', 'Серп', 'Первые плоды'],
      type: PaganHolidayType.harvest,
    ),

    PaganHoliday(
      id: 'samhain',
      name: 'Самайн',
      nameOriginal: 'Samhain',
      date: DateTime(2024, 10, 31),
      tradition: 'celtic',
      description: 'Новый год, время почитания предков и духов',
      longDescription: 'Самайн — самый важный кельтский праздник, начало нового года и времени, когда граница между мирами истончается. Время почитания предков.',
      traditions: ['Зажигание костров', 'Почитание предков', 'Гадания', 'Маскировка от духов'],
      symbols: ['Тыквы', 'Черепа', 'Свечи', 'Яблоки'],
      type: PaganHolidayType.ancestor,
    ),

    // Дополнительные скандинавские праздники
    PaganHoliday(
      id: 'disablot',
      name: 'Дисаблот',
      nameOriginal: 'Dísablót',
      date: DateTime(2024, 2, 14),
      tradition: 'nordic',
      description: 'Праздник почитания дис — женских духов-покровительниц',
      longDescription: 'Дисаблот — скандинавский праздник, посвященный дис, женским духам, которые защищают род и семью. Время почитания женских предков.',
      traditions: ['Жертвоприношения дис', 'Почитание женщин рода', 'Ритуалы защиты семьи'],
      symbols: ['Женские украшения', 'Белые свечи', 'Семейные реликвии'],
      type: PaganHolidayType.ancestor,
    ),

    PaganHoliday(
      id: 'sumarmál',
      name: 'Сумармал',
      nameOriginal: 'Sumarmál',
      date: DateTime(2024, 4, 14),
      tradition: 'nordic',
      description: 'Первый день лета в исландском календаре',
      longDescription: 'Сумармал отмечает начало летней половины года в древнем исландском календаре. Время радости и ожидания теплых дней.',
      traditions: ['Весенние ритуалы', 'Очищение домов', 'Празднования на природе'],
      symbols: ['Первые цветы', 'Солнечные символы', 'Зеленые ветви'],
      type: PaganHolidayType.seasonal,
    ),

    PaganHoliday(
      id: 'vetrablot',
      name: 'Ветраблот',
      nameOriginal: 'Vetrablót',
      date: DateTime(2024, 10, 14),
      tradition: 'nordic',
      description: 'Зимний блот, жертвоприношение богам перед зимой',
      longDescription: 'Ветраблот — скандинавское жертвоприношение, проводимое перед наступлением зимы для обеспечения защиты и процветания в темные месяцы.',
      traditions: ['Жертвоприношения богам', 'Ритуалы защиты', 'Заготовка на зиму'],
      symbols: ['Рога для питья', 'Жертвенные алтари', 'Зимние символы'],
      type: PaganHolidayType.protection,
    ),

    // Дополнительные римские праздники
    PaganHoliday(
      id: 'saturnalia',
      name: 'Сатурналии',
      nameOriginal: 'Saturnalia',
      date: DateTime(2024, 12, 17),
      tradition: 'roman',
      description: 'Римский праздник бога Сатурна, время веселья и равенства',
      longDescription: 'Сатурналии — один из самых популярных римских праздников, время, когда социальные роли менялись местами.',
      traditions: ['Обмен ролями господ и рабов', 'Пиры и веселье', 'Обмен подарками', 'Азартные игры'],
      symbols: ['Свечи', 'Венки', 'Маски', 'Игральные кости'],
      type: PaganHolidayType.deity,
    ),

    // Дополнительные греческие праздники
    PaganHoliday(
      id: 'anthesteria',
      name: 'Анфестерии',
      nameOriginal: 'Ἀνθεστήρια',
      date: DateTime(2024, 2, 11),
      tradition: 'greek',
      description: 'Афинский праздник цветов и нового вина',
      longDescription: 'Анфестерии — древнегреческий праздник в честь Диониса, отмечавший приход весны и открытие молодого вина.',
      traditions: ['Дегустация нового вина', 'Украшение цветами', 'Ритуалы Диониса', 'Поминание усопших'],
      symbols: ['Цветы', 'Виноградные лозы', 'Амфоры с вином', 'Маски'],
      type: PaganHolidayType.deity,
    ),
     
// Дополнительные праздники для добавления в _holidays список в PaganHolidayService

// =============== ДОПОЛНИТЕЛЬНЫЕ СЛАВЯНСКИЕ ПРАЗДНИКИ ===============

// Зимние
PaganHoliday(
  id: 'karachun_slavic',
  name: 'Карачун',
  nameOriginal: 'Карачун',
  date: DateTime(2024, 12, 21),
  tradition: 'slavic',
  description: 'Древнеславянское зимнее солнцестояние, самый короткий день',
  longDescription: 'Карачун — древнейший славянский праздник зимнего солнцестояния, когда злой дух Карачун побеждает солнце, но после этого дня солнце начинает прибывать.',
  traditions: ['Защитные ритуалы', 'Жжение костров', 'Изгнание злых духов', 'Гадания'],
  symbols: ['Солнечные знаки', 'Защитные амулеты', 'Огонь', 'Колесо'],
  type: PaganHolidayType.seasonal,
),

PaganHoliday(
  id: 'ovsen_slavic',
  name: 'Овсень',
  nameOriginal: 'Овсень',
  date: DateTime(2024, 12, 31),
  tradition: 'slavic',
  description: 'Славянский новогодний праздник, брат Коляды',
  longDescription: 'Овсень — славянский бог нового года, который приносит изменения и обновление. Празднуется в последний день старого года.',
  traditions: ['Овсеневские песни', 'Колядование', 'Гадания на новый год', 'Обрядовые пляски'],
  symbols: ['Коляда-солнце', 'Мешок с подарками', 'Серп луны', 'Новогодние знаки'],
  type: PaganHolidayType.seasonal,
),

PaganHoliday(
  id: 'sochelnik_velesa',
  name: 'Сочельник Велеса',
  nameOriginal: 'Велесов день',
  date: DateTime(2024, 12, 24),
  tradition: 'slavic',
  description: 'Ночь почитания скотьего бога Велеса',
  longDescription: 'В эту ночь Велес обходит стада и защищает скот от волков и болезней. Время особых молитв скотоводов.',
  traditions: ['Кормление скота особым кормом', 'Защитные обряды', 'Почитание Велеса'],
  symbols: ['Медведь', 'Скот', 'Пастушеская палка', 'Мед'],
  type: PaganHolidayType.deity,
),

// Весенние
PaganHoliday(
  id: 'maslenitsa_slavic',
  name: 'Масленица',
  nameOriginal: 'Комоедица',
  date: DateTime(2024, 3, 11), // за неделю до равноденствия
  tradition: 'slavic',
  description: 'Проводы зимы и встреча весны, неделя блинов',
  longDescription: 'Масленица — древний славянский праздник проводов зимы, когда сжигают чучело зимы и пекут блины как символы солнца.',
  traditions: ['Печение блинов', 'Сжигание чучела', 'Масленичные гулянья', 'Катание на санях'],
  symbols: ['Блины', 'Чучело зимы', 'Солнце', 'Колесо'],
  type: PaganHolidayType.seasonal,
),

PaganHoliday(
  id: 'krasnaya_gorka',
  name: 'Красная Горка',
  nameOriginal: 'Красная Горка',
  date: DateTime(2024, 4, 28), // первое воскресенье после Пасхи
  tradition: 'slavic',
  description: 'Весенний праздник молодежи и любви',
  longDescription: 'Красная Горка — время свадеб, хороводов и весенних игр молодежи. Праздник любви и плодородия.',
  traditions: ['Хороводы на горах', 'Весенние игры', 'Сватовство', 'Украшение березок'],
  symbols: ['Красные яйца', 'Венки', 'Березки', 'Цветы'],
  type: PaganHolidayType.fertility,
),

PaganHoliday(
  id: 'vodopol_slavic',
  name: 'Водопол',
  nameOriginal: 'Переплут',
  date: DateTime(2024, 4, 3),
  tradition: 'slavic',
  description: 'Пробуждение водяного и водной стихии',
  longDescription: 'Водопол — день пробуждения водяного от зимней спячки. Время очищения и освящения воды.',
  traditions: ['Освящение колодцев', 'Очистительные обряды', 'Подношения водяному'],
  symbols: ['Вода', 'Рыбы', 'Кувшины', 'Речные камни'],
  type: PaganHolidayType.water,
),

PaganHoliday(
  id: 'lelnik_slavic',
  name: 'Лельник',
  nameOriginal: 'Лельник',
  date: DateTime(2024, 4, 22),
  tradition: 'slavic',
  description: 'Праздник богини девической любви Лели',
  longDescription: 'Лельник — славянский женский день, посвященный богине весны и девической любви Леле.',
  traditions: ['Девичьи хороводы', 'Плетение венков', 'Гадания на любовь'],
  symbols: ['Венки', 'Первые цветы', 'Березка', 'Красные ленты'],
  type: PaganHolidayType.fertility,
),

PaganHoliday(
  id: 'zhivin_den',
  name: 'Живин день',
  nameOriginal: 'Живин день',
  date: DateTime(2024, 5, 1),
  tradition: 'slavic',
  description: 'Праздник жизненной силы и плодородия',
  longDescription: 'Живин день — празднование жизненной силы природы, время союза мужского и женского начал.',
  traditions: ['Обрядовые браки', 'Майские игры', 'Украшение майского дерева'],
  symbols: ['Майское дерево', 'Зеленые ветви', 'Цветы', 'Венки'],
  type: PaganHolidayType.fertility,
),

// Летние
PaganHoliday(
  id: 'rusalii_slavic',
  name: 'Русалии',
  nameOriginal: 'Русальная неделя',
  date: DateTime(2024, 6, 10), // неделя перед Троицей
  tradition: 'slavic',
  description: 'Время выхода русалок из воды',
  longDescription: 'Русалии — неделя, когда русалки выходят из воды и водят хороводы в лесах. Время особой осторожности.',
  traditions: ['Защитные обряды', 'Проводы русалок', 'Очистительные ритуалы'],
  symbols: ['Полотенца', 'Венки', 'Березовые ветви', 'Вода'],
  type: PaganHolidayType.water,
),

PaganHoliday(
  id: 'perunov_den',
  name: 'Перунов день',
  nameOriginal: 'Перунов день',
  date: DateTime(2024, 7, 20),
  tradition: 'slavic',
  description: 'Главный праздник бога-громовержца Перуна',
  longDescription: 'Перунов день — праздник славянского бога грома и молнии, покровителя воинов и справедливости.',
  traditions: ['Воинские состязания', 'Освящение оружия', 'Молебны о дожде'],
  symbols: ['Молния', 'Дуб', 'Топор', 'Огонь'],
  type: PaganHolidayType.deity,
),

PaganHoliday(
  id: 'spozhinki_slavic',
  name: 'Спожинки',
  nameOriginal: 'Дожинки',
  date: DateTime(2024, 8, 7),
  tradition: 'slavic',
  description: 'Окончание жатвы, праздник урожая',
  longDescription: 'Спожинки — завершение жатвы, когда последний сноп убирают с особыми обрядами.',
  traditions: ['Дожинальные песни', 'Украшение последнего снопа', 'Обрядовые пиры'],
  symbols: ['Серп', 'Снопы', 'Зерно', 'Хлеб'],
  type: PaganHolidayType.harvest,
),

PaganHoliday(
  id: 'horoyar_slavic',
  name: 'Хорояр',
  nameOriginal: 'Хорояр',
  date: DateTime(2024, 8, 18),
  tradition: 'slavic',
  description: 'Праздник коней и братьев Хорса и Ярилы',
  longDescription: 'Хорояр — день почитания солнечных божеств Хорса и Ярилы, покровителей коней.',
  traditions: ['Конские состязания', 'Освящение лошадей', 'Солнечные обряды'],
  symbols: ['Лошади', 'Солнечные диски', 'Колесницы', 'Золото'],
  type: PaganHolidayType.deity,
),

// Осенние
PaganHoliday(
  id: 'rod_rozhanitsy',
  name: 'Род и Рожаницы',
  nameOriginal: 'Род и Рожаницы',
  date: DateTime(2024, 9, 21),
  tradition: 'slavic',
  description: 'Праздник семейного благополучия и рода',
  longDescription: 'День почитания Рода — верховного божества славян и Рожаниц — богинь судьбы и плодородия.',
  traditions: ['Семейные обеды', 'Поминание предков', 'Благословение детей'],
  symbols: ['Семейный очаг', 'Хлеб', 'Мед', 'Красные нити'],
  type: PaganHolidayType.ancestor,
),

PaganHoliday(
  id: 'mokosh_slavic',
  name: 'Мокошь',
  nameOriginal: 'Мокошь',
  date: DateTime(2024, 10, 28),
  tradition: 'slavic',
  description: 'Праздник богини судьбы и рукоделия',
  longDescription: 'Мокошь — единственная богиня в мужском пантеоне славян, покровительница женщин, судьбы и рукоделия.',
  traditions: ['Женские рукоделия', 'Прядение', 'Гадания на судьбу'],
  symbols: ['Веретено', 'Нити судьбы', 'Лен', 'Вода'],
  type: PaganHolidayType.deity,
),

PaganHoliday(
  id: 'velesova_noch',
  name: 'Велесова ночь',
  nameOriginal: 'Велесова ночь',
  date: DateTime(2024, 10, 31),
  tradition: 'slavic',
  description: 'Славянский день почитания предков и Велеса',
  longDescription: 'Велесова ночь — время, когда границы между мирами истончаются, и можно общаться с предками.',
  traditions: ['Поминание предков', 'Гадания', 'Защитные обряды', 'Угощение духов'],
  symbols: ['Медведь', 'Мед', 'Свечи', 'Могильные камни'],
  type: PaganHolidayType.ancestor,
),

// =============== ДОПОЛНИТЕЛЬНЫЕ СКАНДИНАВСКИЕ ПРАЗДНИКИ ===============

PaganHoliday(
  id: 'disting_nordic',
  name: 'Дистинг',
  nameOriginal: 'Dísablót',
  date: DateTime(2024, 2, 1),
  tradition: 'nordic',
  description: 'Праздник дис - женских духов-покровительниц',
  longDescription: 'Дистинг — шведский праздник, посвященный дис, женским духам, которые защищают род и семью.',
  traditions: ['Жертвоприношения дис', 'Ярмарки', 'Женские ритуалы'],
  symbols: ['Женские украшения', 'Белые свечи', 'Семейные реликвии'],
  type: PaganHolidayType.ancestor,
),

PaganHoliday(
  id: 'sumarsdaag_nordic',
  name: 'Сумарсдаг',
  nameOriginal: 'Sumarsdag',
  date: DateTime(2024, 4, 18),
  tradition: 'nordic',
  description: 'Первый день лета в исландском календаре',
  longDescription: 'Сумарсдаг — древний исландский праздник, отмечающий начало летней половины года.',
  traditions: ['Весенние ритуалы', 'Очищение домов', 'Празднования на природе'],
  symbols: ['Первые цветы', 'Солнечные символы', 'Зеленые ветви'],
  type: PaganHolidayType.seasonal,
),

PaganHoliday(
  id: 'freysfaxi_nordic',
  name: 'Фрейсфакси',
  nameOriginal: 'Freyfaxi',
  date: DateTime(2024, 8, 3),
  tradition: 'nordic',
  description: 'Праздник лошадей бога Фрейра',
  longDescription: 'Фрейсфакси — праздник в честь Фрейра и его коня, время освящения лошадей и первого урожая.',
  traditions: ['Конские состязания', 'Освящение лошадей', 'Первые плоды урожая'],
  symbols: ['Лошади', 'Колосья', 'Золотые украшения', 'Кабан'],
  type: PaganHolidayType.harvest,
),

PaganHoliday(
  id: 'vetrablot_nordic',
  name: 'Ветраблот',
  nameOriginal: 'Vetrablót',
  date: DateTime(2024, 10, 14),
  tradition: 'nordic',
  description: 'Зимний блот, подготовка к зиме',
  longDescription: 'Ветраблот — скандинавский праздник подготовки к зиме, время жертвоприношений для защиты в темные месяцы.',
  traditions: ['Жертвоприношения богам', 'Ритуалы защиты', 'Заготовка на зиму'],
  symbols: ['Рога для питья', 'Жертвенные алтари', 'Зимние символы'],
  type: PaganHolidayType.protection,
),

PaganHoliday(
  id: 'mothers_night',
  name: 'Ночь Матерей',
  nameOriginal: 'Mōdraniht',
  date: DateTime(2024, 12, 20),
  tradition: 'nordic',
  description: 'Канун Йоля, почитание женских предков',
  longDescription: 'Ночь Матерей — англосаксонский праздник, посвященный женским божествам и предкам.',
  traditions: ['Почитание предков', 'Женские ритуалы', 'Подготовка к Йолю'],
  symbols: ['Свечи', 'Семейные реликвии', 'Алтари предков'],
  type: PaganHolidayType.ancestor,
),

// =============== РИМСКИЕ ПРАЗДНИКИ ===============

PaganHoliday(
  id: 'sol_invictus',
  name: 'Соль Инвиктус',
  nameOriginal: 'Dies Natalis Solis Invicti',
  date: DateTime(2024, 12, 25),
  tradition: 'roman',
  description: 'День Непобедимого Солнца',
  longDescription: 'Соль Инвиктус — римский праздник солнечного божества, установленный императором Аврелианом в 274 году.',
  traditions: ['Солнечные ритуалы', 'Гонки колесниц', 'Пиры в честь солнца'],
  symbols: ['Солнечные диски', 'Колесницы', 'Золотые венки', 'Лучи света'],
  type: PaganHolidayType.deity,
),

PaganHoliday(
  id: 'lupercalia_roman',
  name: 'Луперкалии',
  nameOriginal: 'Lupercalia',
  date: DateTime(2024, 2, 15),
  tradition: 'roman',
  description: 'Праздник очищения и плодородия',
  longDescription: 'Луперкалии — древнеримский праздник плодородия, когда луперки бегали по городу и стегали женщин козьими шкурами.',
  traditions: ['Ритуальный бег', 'Стегание шкурами', 'Любовные гадания'],
  symbols: ['Козьи шкуры', 'Волчица', 'Пещера Луперкаль', 'Факелы'],
  type: PaganHolidayType.fertility,
),

PaganHoliday(
  id: 'floralia_roman',
  name: 'Флоралии',
  nameOriginal: 'Floralia',
  date: DateTime(2024, 4, 28),
  tradition: 'roman',
  description: 'Праздник богини цветов Флоры',
  longDescription: 'Флоралии — римский праздник весны и цветения, посвященный богине Флоре.',
  traditions: ['Украшение цветами', 'Театральные представления', 'Весенние игры'],
  symbols: ['Цветы', 'Венки', 'Козы', 'Разноцветные одежды'],
  type: PaganHolidayType.nature,
),

PaganHoliday(
  id: 'vestalia_roman',
  name: 'Весталии',
  nameOriginal: 'Vestalia',
  date: DateTime(2024, 6, 9),
  tradition: 'roman',
  description: 'Праздник богини очага Весты',
  longDescription: 'Весталии — римский праздник богини домашнего очага Весты, когда храм открывался для всех матрон.',
  traditions: ['Посещение храма Весты', 'Обновление священного огня', 'Домашние ритуалы'],
  symbols: ['Вечный огонь', 'Хлеб', 'Домашний очаг', 'Белые одежды'],
  type: PaganHolidayType.deity,
),

PaganHoliday(
  id: 'lemuria_roman',
  name: 'Лемурии',
  nameOriginal: 'Lemuria',
  date: DateTime(2024, 5, 9),
  tradition: 'roman',
  description: 'Дни поминовения мертвых',
  longDescription: 'Лемурии — римские дни изгнания злых духов умерших и почитания предков.',
  traditions: ['Изгнание духов', 'Ритуалы с бобами', 'Поминание предков'],
  symbols: ['Черные бобы', 'Маски', 'Свечи', 'Соль'],
  type: PaganHolidayType.ancestor,
),

// =============== ГРЕЧЕСКИЕ ПРАЗДНИКИ ===============

PaganHoliday(
  id: 'anthesteria_greek',
  name: 'Анфестерии',
  nameOriginal: 'Ἀνθεστήρια',
  date: DateTime(2024, 2, 11),
  tradition: 'greek',
  description: 'Афинский праздник цветов и нового вина',
  longDescription: 'Анфестерии — древнегреческий праздник в честь Диониса, отмечавший приход весны и открытие молодого вина.',
  traditions: ['Дегустация нового вина', 'Украшение цветами', 'Ритуалы Диониса'],
  symbols: ['Цветы', 'Виноградные лозы', 'Амфоры с вином', 'Маски'],
  type: PaganHolidayType.deity,
),

PaganHoliday(
  id: 'thesmophoria_greek',
  name: 'Фесмофории',
  nameOriginal: 'Θεσμοφόρια',
  date: DateTime(2024, 10, 15),
  tradition: 'greek',
  description: 'Женский праздник Деметры',
  longDescription: 'Фесмофории — древнегреческий женский праздник в честь Деметры, богини плодородия и земледелия.',
  traditions: ['Женские мистерии', 'Посевные ритуалы', 'Поминание Персефоны'],
  symbols: ['Колосья пшеницы', 'Поросята', 'Корзины', 'Семена'],
  type: PaganHolidayType.fertility,
),

PaganHoliday(
  id: 'dionysiac_greek',
  name: 'Великие Дионисии',
  nameOriginal: 'Διονύσια',
  date: DateTime(2024, 3, 25),
  tradition: 'greek',
  description: 'Главный праздник театра и Диониса',
  longDescription: 'Великие Дионисии — афинский праздник бога вина и театра, время драматических состязаний.',
  traditions: ['Театральные представления', 'Процессии с фаллосами', 'Винные ритуалы'],
  symbols: ['Театральные маски', 'Виноград', 'Тирс', 'Козлы'],
  type: PaganHolidayType.deity,
),

PaganHoliday(
  id: 'panathenaia_greek',
  name: 'Панафинеи',
  nameOriginal: 'Παναθήναια',
  date: DateTime(2024, 7, 28),
  tradition: 'greek',
  description: 'Главный праздник Афины в Афинах',
  longDescription: 'Панафинеи — величайший афинский праздник в честь богини Афины, покровительницы города.',
  traditions: ['Торжественная процессия', 'Спортивные состязания', 'Поднесение пеплоса'],
  symbols: ['Сова', 'Оливковые ветви', 'Копье', 'Пеплос'],
  type: PaganHolidayType.deity,
),

// =============== БАЛТИЙСКИЕ ПРАЗДНИКИ ===============

PaganHoliday(
  id: 'jonines_baltic',
  name: 'Йонинес',
  nameOriginal: 'Joninės',
  date: DateTime(2024, 6, 24),
  tradition: 'baltic',
  description: 'Литовский праздник летнего солнцестояния',
  longDescription: 'Йонинес — литовский праздник летнего солнцестояния, день росы и магических трав.',
  traditions: ['Сбор трав', 'Костры на холмах', 'Поиск цветка папоротника', 'Венки на воде'],
  symbols: ['Травы', 'Роса', 'Костры', 'Венки'],
  type: PaganHolidayType.nature,
),

PaganHoliday(
  id: 'ligo_baltic',
  name: 'Лиго',
  nameOriginal: 'Līgo',
  date: DateTime(2024, 6, 23),
  tradition: 'baltic',
  description: 'Латвийский праздник летнего солнцестояния',
  longDescription: 'Лиго — латвийский праздник летнего солнцестояния, время магии и плодородия.',
  traditions: ['Плетение венков', 'Прыжки через костры', 'Сбор лечебных трав'],
  symbols: ['Дубовые листья', 'Костры', 'Венки', 'Пиво'],
  type: PaganHolidayType.seasonal,
),

PaganHoliday(
  id: 'uzgavenes_baltic',
  name: 'Ужгавенес',
  nameOriginal: 'Užgavėnės',
  date: DateTime(2024, 3, 5),
  tradition: 'baltic',
  description: 'Литовские проводы зимы',
  longDescription: 'Ужгавенес — литовский карнавал проводов зимы, время масок и блинов.',
  traditions: ['Ряжение в маски', 'Сжигание чучела зимы', 'Блины', 'Шумные игры'],
  symbols: ['Маски', 'Блины', 'Чучело Море', 'Колокольчики'],
  type: PaganHolidayType.seasonal,
),

// =============== ФИННО-УГОРСКИЕ ПРАЗДНИКИ ===============

PaganHoliday(
  id: 'kekri_finnish',
  name: 'Кекри',
  nameOriginal: 'Kekri',
  date: DateTime(2024, 11, 1),
  tradition: 'finnish',
  description: 'Финский день мертвых и окончания урожая',
  longDescription: 'Кекри — древний финский праздник окончания сельскохозяйственного года и поминания предков.',
  traditions: ['Поминание умерших', 'Гадания', 'Заготовка на зиму', 'Банные ритуалы'],
  symbols: ['Свечи', 'Могильные камни', 'Репа', 'Баня'],
  type: PaganHolidayType.ancestor,
),

PaganHoliday(
  id: 'vappu_finnish',
  name: 'Ваппу',
  nameOriginal: 'Vappu',
  date: DateTime(2024, 5, 1),
  tradition: 'finnish',
  description: 'Финский праздник весны и плодородия',
  longDescription: 'Ваппу — финский майский праздник, время молодости, любви и пробуждения природы.',
  traditions: ['Студенческие карнавалы', 'Пикники на природе', 'Симо и мед'],
  symbols: ['Белые шапки', 'Березовые ветви', 'Мед', 'Весенние цветы'],
  type: PaganHolidayType.fertility,
),

PaganHoliday(
  id: 'juhannus_finnish',
  name: 'Юханнус',
  nameOriginal: 'Juhannus',
  date: DateTime(2024, 6, 24),
  tradition: 'finnish',
  description: 'Финское летнее солнцестояние',
  longDescription: 'Юханнус — финский праздник летнего солнцестояния, белых ночей и магии.',
  traditions: ['Костры у озер', 'Банные ритуалы', 'Полночное солнце', 'Гадания'],
  symbols: ['Костры', 'Березовые ветви', 'Озера', 'Белые ночи'],
  type: PaganHolidayType.seasonal,
),

// =============== ДОПОЛНИТЕЛЬНЫЕ КЕЛЬТСКИЕ ПРАЗДНИКИ ===============

PaganHoliday(
  id: 'alban_eilir_celtic',
  name: 'Альбан Эйлир',
  nameOriginal: 'Alban Eilir',
  date: DateTime(2024, 3, 20),
  tradition: 'celtic',
  description: 'Кельтское название весеннего равноденствия',
  longDescription: 'Альбан Эйлир — друидическое название весеннего равноденствия, время равновесия света и тьмы.',
  traditions: ['Друидические ритуалы', 'Посадка семян', 'Очищение священных мест'],
  symbols: ['Семена', 'Молодые побеги', 'Яйца', 'Заяц'],
  type: PaganHolidayType.seasonal,
),

PaganHoliday(
  id: 'alban_hefin_celtic',
  name: 'Альбан Хефин',
  nameOriginal: 'Alban Hefin',
  date: DateTime(2024, 6, 21),
  tradition: 'celtic',
  description: 'Кельтское название летнего солнцестояния',
  longDescription: 'Альбан Хефин — друидическое название летнего солнцестояния, пик силы солнца.',
  traditions: ['Друидические церемонии', 'Сбор омелы', 'Солнечные ритуалы'],
  symbols: ['Омела', 'Дубовые листья', 'Солнечные круги', 'Золотой серп'],
  type: PaganHolidayType.seasonal,
),

PaganHoliday(
  id: 'alban_elved_celtic',
  name: 'Альбан Эльвед',
  nameOriginal: 'Alban Elved',
  date: DateTime(2024, 9, 22),
  tradition: 'celtic',
  description: 'Кельтское название осеннего равноденствия',
  longDescription: 'Альбан Эльвед — друидическое название осеннего равноденствия, время сбора урожая мудрости.',
  traditions: ['Ритуалы благодарности', 'Сбор желудей', 'Подготовка к зиме'],
  symbols: ['Желуди', 'Осенние листья', 'Корзины урожая', 'Рог изобилия'],
  type: PaganHolidayType.harvest,
),

PaganHoliday(
  id: 'brigantia_celtic',
  name: 'Бригантия',
  nameOriginal: 'Brigantia',
  date: DateTime(2024, 2, 1),
  tradition: 'celtic',
  description: 'Континентальная версия Имболка',
  longDescription: 'Бригантия — континентальный кельтский праздник богини Бригантии, покровительницы ремесел и поэзии.',
  traditions: ['Кузнечные ритуалы', 'Поэтические состязания', 'Освящение инструментов'],
  symbols: ['Молот и наковальня', 'Поэтическая арфа', 'Священные источники', 'Огонь кузницы'],
  type: PaganHolidayType.deity,
),

PaganHoliday(
  id: 'lughnasa_celtic',
  name: 'Лугнаса',
  nameOriginal: 'Lughnasa',
  date: DateTime(2024, 8, 1),
  tradition: 'celtic',
  description: 'Ирландская версия Ламмаса',
  longDescription: 'Лугнаса — ирландский праздник бога Луга, время первого урожая и ремесленных ярмарок.',
  traditions: ['Ярмарки ремесел', 'Состязания в мастерстве', 'Ритуальные браки'],
  symbols: ['Колосья', 'Инструменты ремесел', 'Солнечные колеса', 'Золотые украшения'],
  type: PaganHolidayType.harvest,
),

// =============== ДОПОЛНИТЕЛЬНЫЕ ГЕРМАНСКИЕ ПРАЗДНИКИ ===============

PaganHoliday(
  id: 'charming_plough_germanic',
  name: 'Освящение плуга',
  nameOriginal: 'Pflugweihe',
  date: DateTime(2024, 1, 7),
  tradition: 'germanic',
  description: 'Германский праздник освящения сельскохозяйственных орудий',
  longDescription: 'День освящения плугов и других сельскохозяйственных инструментов перед началом полевых работ.',
  traditions: ['Освящение орудий труда', 'Благословение полей', 'Ритуальная борозда'],
  symbols: ['Плуг', 'Семена', 'Борозды', 'Рабочие инструменты'],
  type: PaganHolidayType.protection,
),

PaganHoliday(
  id: 'walpurgisnacht_germanic',
  name: 'Вальпургиева ночь',
  nameOriginal: 'Walpurgisnacht',
  date: DateTime(2024, 4, 30),
  tradition: 'germanic',
  description: 'Германская ночь ведьм и духов',
  longDescription: 'Вальпургиева ночь — германский праздник изгнания зимних духов и защиты от злых сил.',
  traditions: ['Костры на холмах', 'Шумные процессии', 'Защитные ритуалы', 'Изгнание ведьм'],
  symbols: ['Костры', 'Метлы', 'Колокола', 'Защитные травы'],
  type: PaganHolidayType.protection,
),

PaganHoliday(
  id: 'erntefest_germanic',
  name: 'Эрнтефест',
  nameOriginal: 'Erntefest',
  date: DateTime(2024, 9, 15),
  tradition: 'germanic',
  description: 'Германский праздник урожая',
  longDescription: 'Эрнтефест — германский праздник благодарения за собранный урожай и подготовки к зиме.',
  traditions: ['Праздничные пиры', 'Украшение снопами', 'Танцы урожая'],
  symbols: ['Снопы зерна', 'Серпы', 'Праздничные венки', 'Рог изобилия'],
  type: PaganHolidayType.harvest,
),

// =============== ДОПОЛНИТЕЛЬНЫЕ РИМСКИЕ ПРАЗДНИКИ ===============

PaganHoliday(
  id: 'carmentalia_roman',
  name: 'Карменталии',
  nameOriginal: 'Carmentalia',
  date: DateTime(2024, 1, 11),
  tradition: 'roman',
  description: 'Римский праздник богини Карменты',
  longDescription: 'Карменталии — римский праздник богини пророчеств Карменты, покровительницы рожениц.',
  traditions: ['Пророчества на новый год', 'Защита рожениц', 'Ритуалы плодородия'],
  symbols: ['Пророческие свитки', 'Младенцы', 'Лавровые венки', 'Священные источники'],
  type: PaganHolidayType.deity,
),

PaganHoliday(
  id: 'terminalia_roman',
  name: 'Терминалии',
  nameOriginal: 'Terminalia',
  date: DateTime(2024, 2, 23),
  tradition: 'roman',
  description: 'Римский праздник границ и межевых камней',
  longDescription: 'Терминалии — римский праздник бога Термина, защитника границ и межевых знаков.',
  traditions: ['Освящение границ', 'Жертвы на межах', 'Соседские пиры'],
  symbols: ['Межевые камни', 'Границы полей', 'Двуликий Янус', 'Ключи'],
  type: PaganHolidayType.protection,
),

PaganHoliday(
  id: 'matronalia_roman',
  name: 'Матроналии',
  nameOriginal: 'Matronalia',
  date: DateTime(2024, 3, 1),
  tradition: 'roman',
  description: 'Римский женский день',
  longDescription: 'Матроналии — римский праздник замужних женщин в честь богини Юноны.',
  traditions: ['Подарки женщинам', 'Молитвы о семейном благополучии', 'Женские пиры'],
  symbols: ['Цветы', 'Украшения', 'Семейный очаг', 'Павлин Юноны'],
  type: PaganHolidayType.fertility,
),

PaganHoliday(
  id: 'robigalia_roman',
  name: 'Робигалии',
  nameOriginal: 'Robigalia',
  date: DateTime(2024, 4, 25),
  tradition: 'roman',
  description: 'Римский праздник защиты урожая от болезней',
  longDescription: 'Робигалии — римский праздник моления о защите посевов от ржавчины и болезней.',
  traditions: ['Жертвы рыжих животных', 'Процессии по полям', 'Защитные заклинания'],
  symbols: ['Рыжие жертвы', 'Колосья', 'Серп', 'Защитные амулеты'],
  type: PaganHolidayType.protection,
),

PaganHoliday(
  id: 'neptunalia_roman',
  name: 'Нептуналии',
  nameOriginal: 'Neptunalia',
  date: DateTime(2024, 7, 23),
  tradition: 'roman',
  description: 'Римский праздник морского бога Нептуна',
  longDescription: 'Нептуналии — римский праздник бога морей Нептуна, время молений о дожде и защите мореплавателей.',
  traditions: ['Морские жертвоприношения', 'Молитвы о дожде', 'Водные игры'],
  symbols: ['Трезубец', 'Дельфины', 'Морские раковины', 'Корабли'],
  type: PaganHolidayType.water,
),

PaganHoliday(
  id: 'vulcanalia_roman',
  name: 'Вулканалии',
  nameOriginal: 'Vulcanalia',
  date: DateTime(2024, 8, 23),
  tradition: 'roman',
  description: 'Римский праздник бога огня Вулкана',
  longDescription: 'Вулканалии — римский праздник бога огня и кузнечного дела Вулкана.',
  traditions: ['Костры и жертвы', 'Кузнечные ритуалы', 'Защита от пожаров'],
  symbols: ['Молот и наковальня', 'Огонь', 'Металлические изделия', 'Вулканы'],
  type: PaganHolidayType.fire,
),

PaganHoliday(
  id: 'brumalia_roman',
  name: 'Брумалии',
  nameOriginal: 'Brumalia',
  date: DateTime(2024, 11, 25),
  tradition: 'roman',
  description: 'Римские празднества зимнего солнца',
  longDescription: 'Брумалии — поздние римские празднества, посвященные солнцу в преддверии зимнего солнцестояния.',
  traditions: ['Многодневные пиры', 'Солнечные ритуалы', 'Зимние игры'],
  symbols: ['Солнечные диски', 'Зимние венки', 'Свечи', 'Золотые украшения'],
  type: PaganHolidayType.seasonal,
),

// =============== ДОПОЛНИТЕЛЬНЫЕ ГРЕЧЕСКИЕ ПРАЗДНИКИ ===============

PaganHoliday(
  id: 'lenaia_greek',
  name: 'Ленеи',
  nameOriginal: 'Λήναια',
  date: DateTime(2024, 1, 25),
  tradition: 'greek',
  description: 'Греческий винодельческий праздник Диониса',
  longDescription: 'Ленеи — афинский зимний праздник Диониса, связанный с виноделием и театром.',
  traditions: ['Винные ритуалы', 'Драматические состязания', 'Процессии'],
  symbols: ['Виноград', 'Театральные маски', 'Винные чаши', 'Плющ'],
  type: PaganHolidayType.deity,
),

PaganHoliday(
  id: 'plynteria_greek',
  name: 'Плинтерии',
  nameOriginal: 'Πλυντήρια',
  date: DateTime(2024, 5, 25),
  tradition: 'greek',
  description: 'Омовение статуи Афины',
  longDescription: 'Плинтерии — афинский праздник очищения и омовения священной статуи Афины.',
  traditions: ['Омовение статуи', 'Очистительные ритуалы', 'Обновление одежд богини'],
  symbols: ['Чистая вода', 'Пеплос', 'Оливковое масло', 'Белые ткани'],
  type: PaganHolidayType.deity,
),

PaganHoliday(
  id: 'kronia_greek',
  name: 'Кронии',
  nameOriginal: 'Κρόνια',
  date: DateTime(2024, 7, 15),
  tradition: 'greek',
  description: 'Греческий праздник золотого века Кроноса',
  longDescription: 'Кронии — афинский праздник титана Кроноса, время временного равенства всех людей.',
  traditions: ['Смена социальных ролей', 'Общие пиры', 'Воспоминания о золотом веке'],
  symbols: ['Серп Кроноса', 'Общие столы', 'Золотые символы', 'Равенство'],
  type: PaganHolidayType.deity,
),

PaganHoliday(
  id: 'apaturia_greek',
  name: 'Апатурии',
  nameOriginal: 'Ἀπατούρια',
  date: DateTime(2024, 10, 20),
  tradition: 'greek',
  description: 'Греческий праздник братств и отцовства',
  longDescription: 'Апатурии — ионийский праздник, когда отцы представляли своих детей в фратрии.',
  traditions: ['Регистрация детей', 'Братские пиры', 'Семейные ритуалы'],
  symbols: ['Семейные гербы', 'Детские игрушки', 'Жертвенные животные', 'Родословные'],
  type: PaganHolidayType.ancestor,
),

PaganHoliday(
  id: 'pyanopsia_greek',
  name: 'Пианопсии',
  nameOriginal: 'Πυανόψια',
  date: DateTime(2024, 10, 7),
  tradition: 'greek',
  description: 'Греческий праздник бобов Аполлона',
  longDescription: 'Пианопсии — афинский праздник Аполлона, связанный с возвращением Тесея с Крита.',
  traditions: ['Варка священных бобов', 'Украшение ветвей', 'Благодарственные ритуалы'],
  symbols: ['Бобы', 'Украшенные ветви', 'Лавр', 'Корабль Тесея'],
  type: PaganHolidayType.deity,
),

// =============== СОВРЕМЕННЫЕ ПАМЯТНЫЕ ДНИ ===============

PaganHoliday(
  id: 'raud_strong_day',
  name: 'День Рауда Сильного',
  nameOriginal: 'Raud the Strong Day',
  date: DateTime(2024, 1, 9),
  tradition: 'nordic',
  description: 'День памяти норвежского язычника-мученика',
  longDescription: 'День памяти Рауда Сильного, норвежского вождя, который отказался принять христианство и был казнен королем Олафом Трюгвасоном.',
  traditions: ['Поминание павших за веру', 'Рассказы о героях', 'Клятвы верности традициям'],
  symbols: ['Мечи', 'Драккары', 'Рунические камни', 'Вороны'],
  type: PaganHolidayType.ancestor,
),

PaganHoliday(
  id: 'ragnar_lodbrok_day',
  name: 'День Рагнара Лодброка',
  nameOriginal: 'Ragnar Lodbrok Day',
  date: DateTime(2024, 3, 28),
  tradition: 'nordic',
  description: 'День памяти легендарного викинга',
  longDescription: 'День памяти Рагнара Лодброка, легендарного короля викингов, героя саг и завоевателя.',
  traditions: ['Чтение саг', 'Воинские игры', 'Поминание героев'],
  symbols: ['Вороны', 'Драккары', 'Секиры', 'Кольчуги'],
  type: PaganHolidayType.ancestor,
),

PaganHoliday(
  id: 'einherjar_day',
  name: 'День Эйнхериев',
  nameOriginal: 'Einherjar Day',
  date: DateTime(2024, 11, 11),
  tradition: 'nordic',
  description: 'День павших воинов Одина',
  longDescription: 'День памяти эйнхериев — умерших героев, заслуживших место в Вальхалле у Одина.',
  traditions: ['Поминание павших воинов', 'Воинские ритуалы', 'Питье из рога'],
  symbols: ['Валькирии', 'Мечи', 'Вальхалла', 'Вороны Одина'],
  type: PaganHolidayType.ancestor,
),
  ];

  /// Получает все праздники
  static List<PaganHoliday> getAllHolidays() {
    return List.unmodifiable(_holidays);
  }

  /// Получает праздники для конкретного месяца
  static List<PaganHoliday> getHolidaysForMonth(int month) {
    return _holidays.where((holiday) => holiday.date.month == month).toList();
  }

  /// Получает праздники для конкретной даты
  static List<PaganHoliday> getHolidaysForDate(DateTime date) {
    return _holidays.where((holiday) => holiday.isOnDate(date)).toList();
  }

  /// Получает праздники по традиции
  static List<PaganHoliday> getHolidaysByTradition(String tradition) {
    return _holidays.where((holiday) => holiday.tradition.toLowerCase() == tradition.toLowerCase()).toList();
  }

  /// Получает ближайший праздник
  static PaganHoliday? getNextHoliday() {
    final now = DateTime.now();
    final currentYear = now.year;
    
    // Ищем праздники в этом году после текущей даты
    var upcomingThisYear = _holidays
        .map((h) => h.getDateForYear(currentYear))
        .where((date) => date.isAfter(now))
        .toList();
    
    if (upcomingThisYear.isNotEmpty) {
      upcomingThisYear.sort();
      final nextDate = upcomingThisYear.first;
      return _holidays.firstWhere((h) => h.isOnDate(nextDate));
    }
    
    // Если в этом году праздников больше нет, берем первый в следующем году
    var nextYearHolidays = _holidays
        .map((h) => h.getDateForYear(currentYear + 1))
        .toList();
    
    nextYearHolidays.sort();
    final nextDate = nextYearHolidays.first;
    return _holidays.firstWhere((h) => h.isOnDate(nextDate));
  }

  /// Получает все традиции
  static List<String> getAllTraditions() {
    return _holidays.map((h) => h.tradition).toSet().toList();
  }
}


