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
        return '#A94AE2'; // Фиолетовый
      case 'greek':
        return '#4AE2E2'; // Бирюзовый
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


