// lib/models/pagan_holiday.dart - ИСПРАВЛЕННАЯ ВЕРСИЯ С ИСТОРИЧЕСКИМИ ДАННЫМИ
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
  final HistoricalAuthenticity authenticity; // НОВОЕ ПОЛЕ
  final List<String> sources; // НОВОЕ ПОЛЕ - источники

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
    required this.authenticity,
    required this.sources,
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
      authenticity: HistoricalAuthenticity.values.firstWhere(
        (e) => e.toString() == 'HistoricalAuthenticity.${json['authenticity']}',
        orElse: () => HistoricalAuthenticity.reconstructed,
      ),
      sources: List<String>.from(json['sources'] as List? ?? []),
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
      'authenticity': authenticity.toString().split('.').last,
      'sources': sources,
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
      case 'baltic':
        return '#E2E24A'; // Желтый
      case 'finnish':
      case 'finno-ugric':
        return '#E2A9A9'; // Розовый
      default:
        return '#E2E2E2'; // Серый
    }
  }

  /// Получает описание достоверности
  String get authenticityDescription {
    switch (authenticity) {
      case HistoricalAuthenticity.authentic:
        return 'Исторически подтверждённый';
      case HistoricalAuthenticity.likely:
        return 'Исторически вероятный';
      case HistoricalAuthenticity.reconstructed:
        return 'Современная реконструкция';
      case HistoricalAuthenticity.modern:
        return 'Современное изобретение';
    }
  }

  @override
  String toString() {
    return 'PaganHoliday(id: $id, name: $name, tradition: $tradition, authenticity: $authenticity)';
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

enum HistoricalAuthenticity {
  authentic,     // Исторически подтверждённые (древние источники)
  likely,        // Исторически вероятные (непрямые доказательства)
  reconstructed, // Современные реконструкции (на основе фольклора)
  modern,        // Полностью современные изобретения 20-21 века
}

/// Сервис для работы с языческими праздниками
class PaganHolidayService {
  static final List<PaganHoliday> _holidays = [
    
    // =============== КЕЛЬТСКИЕ ПРАЗДНИКИ (ИСТОРИЧЕСКИ ПОДТВЕРЖДЁННЫЕ) ===============
    
    // Четыре главных огненных праздника - единственные исторически достоверные кельтские праздники
    PaganHoliday(
      id: 'samhain_celtic',
      name: 'Самайн',
      nameOriginal: 'Samhain',
      date: DateTime(2024, 10, 31),
      tradition: 'celtic',
      description: 'Кельтский Новый год, время почитания предков',
      longDescription: 'Самайн — самый важный праздник в кельтском календаре, начало нового года и темной половины года. Время, когда граница между миром живых и мертвых становится тонкой.',
      traditions: ['Костры на холмах', 'Поминание предков', 'Гадания на будущее', 'Защитные ритуалы'],
      symbols: ['Костры', 'Яблоки', 'Орехи', 'Черепа'],
      type: PaganHolidayType.ancestor,
      authenticity: HistoricalAuthenticity.authentic,
      sources: ['Ирландские саги', 'Анналы четырех мастеров', 'Книга захватов Ирландии'],
    ),

    PaganHoliday(
      id: 'imbolc_celtic',
      name: 'Имболк',
      nameOriginal: 'Imbolc',
      date: DateTime(2024, 2, 1),
      tradition: 'celtic',
      description: 'Праздник богини Бригид и пробуждения земли',
      longDescription: 'Имболк отмечает середину пути между зимним солнцестоянием и весенним равноденствием. Время очищения и почитания богини Бригид.',
      traditions: ['Плетение крестов Бригид', 'Очищение домов', 'Зажигание свечей', 'Освящение семян'],
      symbols: ['Кресты из камыша', 'Свечи', 'Молоко', 'Первые цветы'],
      type: PaganHolidayType.seasonal,
      authenticity: HistoricalAuthenticity.authentic,
      sources: ['Житие святой Бригиды', 'Ирландские саги', 'Фольклор Ирландии и Шотландии'],
    ),

    PaganHoliday(
      id: 'beltane_celtic',
      name: 'Белтайн',
      nameOriginal: 'Bealtaine',
      date: DateTime(2024, 5, 1),
      tradition: 'celtic',
      description: 'Праздник плодородия и начала лета',
      longDescription: 'Белтайн — один из четырех главных кельтских праздников, отмечающий начало светлой половины года и союз божественного мужского и женского начал.',
      traditions: ['Костры Белтайна', 'Прогон скота через дым', 'Майские танцы', 'Сбор майских цветов'],
      symbols: ['Костры', 'Боярышник', 'Майские цветы', 'Зеленые ветви'],
      type: PaganHolidayType.fertility,
      authenticity: HistoricalAuthenticity.authentic,
      sources: ['Ирландские саги', 'Описания Диодора Сицилийского', 'Средневековые ирландские тексты'],
    ),

    PaganHoliday(
      id: 'lughnasadh_celtic',
      name: 'Лугнаса',
      nameOriginal: 'Lughnasadh',
      date: DateTime(2024, 8, 1),
      tradition: 'celtic',
      description: 'Праздник бога Луга и первого урожая',
      longDescription: 'Лугнаса — праздник в честь кельтского бога мастерства Луга, время первого урожая и ремесленных состязаний.',
      traditions: ['Ярмарки и состязания', 'Сбор первых плодов', 'Ремесленные турниры', 'Временные браки'],
      symbols: ['Колосья', 'Инструменты ремесел', 'Хлеб', 'Солнечные колеса'],
      type: PaganHolidayType.harvest,
      authenticity: HistoricalAuthenticity.authentic,
      sources: ['Ирландские саги о Луге', 'Записи о древних ярмарках', 'Валлийские мабиноги'],
    ),

    // =============== СКАНДИНАВСКИЕ/СЕВЕРНЫЕ ПРАЗДНИКИ ===============
    
    PaganHoliday(
      id: 'yule_nordic',
      name: 'Йоль',
      nameOriginal: 'Jól',
      date: DateTime(2024, 12, 25), // НЕ солнцестояние! Первое полнолуние после
      tradition: 'nordic',
<<<<<<< HEAD
      description: 'Главный северный праздник, трёхдневное пиршество',
      longDescription: 'Йоль — исторически подтверждённый скандинавский праздник, длившийся три дня. Время жертвоприношений Фрейру за хороший урожай.',
      traditions: ['Трёхдневные пиры', 'Жертвоприношения Фрейру', 'Запрет на ссоры', 'Клятвы и обеты'],
      symbols: ['Кабан Фрейра', 'Рога для питья', 'Йольское полено', 'Вечнозеленые ветви'],
=======
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
>>>>>>> 438e4cc (Assistant checkpoint: Добавлена поддержка Google Drive, фильтры праздников и улучшен календарь)
      type: PaganHolidayType.seasonal,
      authenticity: HistoricalAuthenticity.authentic,
      sources: ['Сага об Инглингах', 'Сага о Хаконе Добром', 'Сага о Харальде Прекрасноволосом'],
    ),

    PaganHoliday(
      id: 'sigrblot_nordic',
      name: 'Сигрблот',
      nameOriginal: 'Sigrblót',
      date: DateTime(2024, 4, 9), // Весна
      tradition: 'nordic',
      description: 'Жертвоприношение Одину за победу',
      longDescription: 'Сигрблот — скандинавский праздник жертвоприношений Одину для обеспечения победы в предстоящих битвах и предприятиях.',
      traditions: ['Жертвоприношения Одину', 'Воинские ритуалы', 'Освящение оружия', 'Клятвы верности'],
      symbols: ['Копьё Одина', 'Вороны', 'Воинское оружие', 'Руны победы'],
      type: PaganHolidayType.deity,
      authenticity: HistoricalAuthenticity.authentic,
      sources: ['Сага об Инглингах', 'Сага об Олаве Трюгвасоне'],
    ),

    PaganHoliday(
      id: 'disablot_nordic',
      name: 'Дисаблот',
      nameOriginal: 'Dísablót',
      date: DateTime(2024, 2, 14), // Конец зимы
      tradition: 'nordic',
      description: 'Праздник дис — женских духов-покровительниц',
      longDescription: 'Дисаблот — скандинавский праздник почитания дис, женских духов, которые защищают род и семью.',
      traditions: ['Жертвоприношения дис', 'Женские ритуалы', 'Почитание предков по женской линии'],
      symbols: ['Женские украшения', 'Семейные реликвии', 'Белые ткани', 'Домашний очаг'],
      type: PaganHolidayType.ancestor,
      authenticity: HistoricalAuthenticity.likely,
      sources: ['Сага об Эгиле', 'Исландские саги', 'Рунические надписи'],
    ),

    PaganHoliday(
      id: 'vetrnaetr_nordic',
      name: 'Зимние ночи',
      nameOriginal: 'Vetrnætr',
      date: DateTime(2024, 10, 14), // Полнолуние в октябре
      tradition: 'nordic',
      description: 'Начало зимы и нового года',
      longDescription: 'Ветрнэтр — древнескандинавский праздник начала зимней половины года, время почитания альвов и предков.',
      traditions: ['Альваблот', 'Поминание предков', 'Заготовки на зиму', 'Первые зимние костры'],
      symbols: ['Курганы предков', 'Зимние венки', 'Альвийские камни', 'Дары предкам'],
      type: PaganHolidayType.ancestor,
      authenticity: HistoricalAuthenticity.authentic,
      sources: ['Исландские саги', 'Рунические календари', 'Беда Достопочтенный'],
    ),

    // =============== ГЕРМАНСКИЕ ПРАЗДНИКИ ===============
    
    PaganHoliday(
      id: 'ostara_germanic',
      name: 'Остара',
      nameOriginal: 'Ēostre',
      date: DateTime(2024, 3, 20),
      tradition: 'germanic',
      description: 'Праздник богини рассвета Эостре',
      longDescription: 'Остара — единственный исторически подтверждённый германский праздник равноденствия, посвящённый богине Эостре.',
      traditions: ['Украшение яиц', 'Весенние ритуалы', 'Призывание плодородия', 'Встреча рассвета'],
      symbols: ['Яйца', 'Зайцы', 'Весенние цветы', 'Рассветное солнце'],
      type: PaganHolidayType.seasonal,
      authenticity: HistoricalAuthenticity.authentic,
      sources: ['Беда Достопочтенный "О счислении времён"', 'Англосаксонские хроники'],
    ),

    PaganHoliday(
      id: 'walpurgisnacht_germanic',
      name: 'Вальпургиева ночь',
      nameOriginal: 'Walpurgisnacht',
      date: DateTime(2024, 4, 30),
      tradition: 'germanic',
      description: 'Ночь изгнания зимних духов',
      longDescription: 'Вальпургиева ночь — германский праздник изгнания злых духов и встречи весны.',
      traditions: ['Костры на холмах', 'Шумные шествия', 'Изгнание злых духов', 'Защитные ритуалы'],
      symbols: ['Костры', 'Колокольчики', 'Метлы', 'Защитные травы'],
      type: PaganHolidayType.protection,
      authenticity: HistoricalAuthenticity.likely,
      sources: ['Германские хроники', 'Фольклорные записи', 'Братья Гримм'],
    ),

    // =============== СЛАВЯНСКИЕ ПРАЗДНИКИ (РЕКОНСТРУИРОВАННЫЕ) ===============
    
    PaganHoliday(
      id: 'koliada_slavic',
      name: 'Коляда',
      nameOriginal: 'Коляда',
      date: DateTime(2024, 12, 21),
      tradition: 'slavic',
      description: 'Зимнее солнцестояние, поворот к свету',
      longDescription: 'Коляда — реконструированный славянский праздник зимнего солнцестояния, основанный на фольклорных данных.',
      traditions: ['Колядование', 'Ряжение в маски', 'Катание на санях', 'Гадания'],
      symbols: ['Солнечные знаки', 'Маски', 'Колядные звёзды', 'Снопы'],
      type: PaganHolidayType.seasonal,
      authenticity: HistoricalAuthenticity.reconstructed,
      sources: ['Борис Рыбаков "Язычество древних славян"', 'Фольклорные записи 19-20 вв.'],
    ),

    PaganHoliday(
      id: 'kupala_slavic',
      name: 'Купала',
      nameOriginal: 'Иван Купала',
      date: DateTime(2024, 7, 7),
      tradition: 'slavic',
      description: 'Праздник воды, огня и плодородия',
      longDescription: 'Купала — славянский праздник летнего солнцестояния, сохранившийся в христианизированном виде как Иван Купала.',
      traditions: ['Прыжки через костры', 'Поиск цветка папоротника', 'Плетение венков', 'Купание в реках'],
      symbols: ['Костры', 'Папоротник', 'Венки на воде', 'Травы'],
      type: PaganHolidayType.fire,
      authenticity: HistoricalAuthenticity.reconstructed,
      sources: ['Этнографические записи', 'Русские народные песни', 'Обрядовый фольклор'],
    ),

    PaganHoliday(
      id: 'maslenitsa_slavic',
      name: 'Масленица',
      nameOriginal: 'Комоедица',
      date: DateTime(2024, 3, 11),
      tradition: 'slavic',
      description: 'Проводы зимы и встреча весны',
      longDescription: 'Масленица — славянский праздник проводов зимы, сохранившийся до наших дней в народной традиции.',
      traditions: ['Сжигание чучела зимы', 'Масленичные гулянья', 'Блины как символы солнца', 'Кулачные бои'],
      symbols: ['Чучело Масленицы', 'Блины', 'Солнечные знаки', 'Колесо'],
      type: PaganHolidayType.seasonal,
      authenticity: HistoricalAuthenticity.reconstructed,
      sources: ['Этнографические материалы', 'Записи обрядов 19-20 вв.', 'Славянская мифология'],
    ),

    PaganHoliday(
      id: 'perunov_den_slavic',
      name: 'Перунов день',
      nameOriginal: 'Перунов день',
      date: DateTime(2024, 7, 20),
      tradition: 'slavic',
      description: 'День бога-громовержца Перуна',
      longDescription: 'День почитания Перуна — главного бога славянского пантеона, повелителя грома и молний.',
      traditions: ['Воинские состязания', 'Освящение оружия', 'Молебны о дожде', 'Ритуалы у дубов'],
      symbols: ['Молния', 'Дуб', 'Секира', 'Огонь'],
      type: PaganHolidayType.deity,
      authenticity: HistoricalAuthenticity.reconstructed,
      sources: ['Повесть временных лет', 'Договоры с Византией', 'Поучение против язычества'],
    ),

    // =============== РИМСКИЕ ПРАЗДНИКИ ===============
    
    PaganHoliday(
      id: 'saturnalia_roman',
      name: 'Сатурналии',
      nameOriginal: 'Saturnalia',
      date: DateTime(2024, 12, 17),
      tradition: 'roman',
      description: 'Праздник бога Сатурна, время равенства',
      longDescription: 'Сатурналии — один из самых популярных римских праздников, когда на время отменялись социальные различия.',
      traditions: ['Смена ролей господ и рабов', 'Обмен подарками', 'Пиры и веселье', 'Игры и шутки'],
      symbols: ['Свечи', 'Глиняные куколки', 'Венки', 'Маски'],
      type: PaganHolidayType.deity,
      authenticity: HistoricalAuthenticity.authentic,
      sources: ['Плиний Младший', 'Тацит', 'Макробий "Сатурналии"'],
    ),

    PaganHoliday(
      id: 'lupercalia_roman',
      name: 'Луперкалии',
      nameOriginal: 'Lupercalia',
      date: DateTime(2024, 2, 15),
      tradition: 'roman',
      description: 'Праздник очищения и плодородия',
      longDescription: 'Луперкалии — древнеримский праздник плодородия, один из самых архаичных римских обрядов.',
      traditions: ['Бег луперков', 'Удары козьими шкурами', 'Очистительные ритуалы', 'Любовные гадания'],
      symbols: ['Козьи шкуры', 'Волчица', 'Фиговое дерево', 'Пещера Луперкаль'],
      type: PaganHolidayType.fertility,
      authenticity: HistoricalAuthenticity.authentic,
      sources: ['Плутарх', 'Овидий "Фасты"', 'Ливий'],
    ),

    // =============== ГРЕЧЕСКИЕ ПРАЗДНИКИ ===============
    
    PaganHoliday(
      id: 'dionysiac_greek',
      name: 'Великие Дионисии',
      nameOriginal: 'Διονύσια',
      date: DateTime(2024, 3, 25),
      tradition: 'greek',
      description: 'Главный праздник Диониса и театра',
      longDescription: 'Великие Дионисии — афинский праздник бога вина и театра, время великих драматических состязаний.',
      traditions: ['Театральные представления', 'Процессии с фаллосами', 'Винные ритуалы', 'Драматические агоны'],
      symbols: ['Театральные маски', 'Виноград', 'Тирс', 'Плющ'],
      type: PaganHolidayType.deity,
      authenticity: HistoricalAuthenticity.authentic,
      sources: ['Аристофан', 'Фукидид', 'Надписи о драматических состязаниях'],
    ),

    PaganHoliday(
      id: 'thesmophoria_greek',
      name: 'Фесмофории',
      nameOriginal: 'Θεσμοφόρια',
      date: DateTime(2024, 10, 15),
      tradition: 'greek',
      description: 'Женский праздник Деметры',
      longDescription: 'Фесмофории — древнегреческий женский праздник богини плодородия Деметры, один из самых важных мистериальных праздников.',
      traditions: ['Женские мистерии', 'Посевные ритуалы', 'Поминание Персефоны', 'Очистительные обряды'],
      symbols: ['Колосья пшеницы', 'Поросята', 'Корзины с плодами', 'Гранаты'],
      type: PaganHolidayType.fertility,
      authenticity: HistoricalAuthenticity.authentic,
      sources: ['Аристофан "Женщины на празднике Фесмофорий"', 'Геродот', 'Павсаний'],
    ),

    // =============== БАЛТИЙСКИЕ ПРАЗДНИКИ ===============
    
    PaganHoliday(
      id: 'jonines_baltic',
      name: 'Йонинес',
      nameOriginal: 'Joninės',
      date: DateTime(2024, 6, 24),
      tradition: 'baltic',
      description: 'Литовский праздник летнего солнцестояния',
      longDescription: 'Йонинес — сохранившийся литовский праздник летнего солнцестояния, один из важнейших балтийских праздников.',
      traditions: ['Поиск цветка папоротника', 'Костры на холмах', 'Венки на воде', 'Сбор лекарственных трав'],
      symbols: ['Папоротник', 'Дубовые венки', 'Костры', 'Роса'],
      type: PaganHolidayType.nature,
      authenticity: HistoricalAuthenticity.authentic,
      sources: ['Литовские хроники', 'Этнографические записи', 'Балтийский фольклор'],
    ),

    // =============== ФИННО-УГОРСКИЕ ПРАЗДНИКИ ===============
    
    PaganHoliday(
      id: 'kekri_finnish',
      name: 'Кекри',
      nameOriginal: 'Kekri',
      date: DateTime(2024, 11, 1),
      tradition: 'finnish',
      description: 'Финский день мертвых и завершения урожая',
      longDescription: 'Кекри — древний финский праздник окончания сельскохозяйственного года и поминания предков.',
      traditions: ['Поминание умерших', 'Банные ритуалы', 'Гадания', 'Заготовки на зиму'],
      symbols: ['Репа', 'Банные веники', 'Свечи', 'Могильные камни'],
      type: PaganHolidayType.ancestor,
      authenticity: HistoricalAuthenticity.authentic,
      sources: ['Финские народные песни', 'Калевала', 'Этнографические записи Карелии'],
    ),

    // =============== СОВРЕМЕННЫЕ ИЗОБРЕТЕНИЯ (ОТМЕЧЕННЫЕ КАК ТАКИЕ) ===============
    
    PaganHoliday(
      id: 'mabon_modern',
      name: 'Мабон (современное название)',
      nameOriginal: 'Autumn Equinox',
      date: DateTime(2024, 9, 22),
      tradition: 'celtic',
      description: 'ВНИМАНИЕ: Название "Мабон" создано в 1974 году американцем Эйданом Келли',
      longDescription: 'Название "Мабон" для осеннего равноденствия было придумано в 1974 году и не имеет исторических корней. Валлийские язычники не поддерживают это название. Исторические валлийские осенние праздники: Ffest y Wrach (пир ведьмы) и Caseg Fedi (кобыла осени).',
      traditions: ['Сбор урожая', 'Благодарственные ритуалы', 'Подготовка к зиме'],
      symbols: ['Осенние листья', 'Яблоки', 'Рог изобилия'],
      type: PaganHolidayType.harvest,
      authenticity: HistoricalAuthenticity.modern,
      sources: ['Эйдан Келли, 1974', 'Критика валлийских язычников', 'Patheos.com статья о происхождении названий'],
    ),

    PaganHoliday(
      id: 'litha_modern',
      name: 'Лита (современное название)',
      nameOriginal: 'Summer Solstice',
      date: DateTime(2024, 6, 21),
      tradition: 'germanic',
      description: 'ВНИМАНИЕ: Название "Лита" создано в 1974 году Эйданом Келли',
      longDescription: 'Название "Лита" для летнего солнцестояния — современное изобретение 1974 года. Исторические германские названия неизвестны.',
      traditions: ['Костры солнцестояния', 'Сбор трав', 'Солнечные ритуалы'],
      symbols: ['Солнечные колеса', 'Лекарственные травы', 'Костры'],
      type: PaganHolidayType.seasonal,
      authenticity: HistoricalAuthenticity.modern,
      sources: ['Эйдан Келли, 1974', 'Green Egg Magazine', 'Викканские источники'],
    ),

    // =============== ДОПОЛНИТЕЛЬНЫЕ ИСТОРИЧЕСКИ ПОДТВЕРЖДЁННЫЕ ПРАЗДНИКИ ===============

    PaganHoliday(
      id: 'floralia_roman',
      name: 'Флоралии',
      nameOriginal: 'Floralia',
      date: DateTime(2024, 4, 28),
      tradition: 'roman',
      description: 'Римский праздник богини цветов Флоры',
      longDescription: 'Флоралии — римский весенний праздник богини Флоры, покровительницы цветов и весеннего цветения.',
      traditions: ['Украшение цветами', 'Театральные представления', 'Весенние игры', 'Цветочные венки'],
      symbols: ['Цветы всех видов', 'Венки', 'Козы', 'Разноцветные одежды'],
      type: PaganHolidayType.nature,
      authenticity: HistoricalAuthenticity.authentic,
      sources: ['Овидий "Фасты"', 'Плиний Старший', 'Тацит'],
    ),

    PaganHoliday(
      id: 'anthesteria_greek',
      name: 'Анфестерии',
      nameOriginal: 'Ἀνθεστήρια',
      date: DateTime(2024, 2, 11),
      tradition: 'greek',
      description: 'Афинский праздник цветов и нового вина',
      longDescription: 'Анфестерии — трёхдневный афинский праздник в честь Диониса, отмечавший приход весны и открытие молодого вина.',
      traditions: ['Дегустация нового вина', 'Украшение цветами', 'Состязания в питье', 'Поминание усопших'],
      symbols: ['Цветы', 'Амфоры с вином', 'Виноградные лозы', 'Маски Диониса'],
      type: PaganHolidayType.deity,
      authenticity: HistoricalAuthenticity.authentic,
      sources: ['Фукидид', 'Афиней', 'Аристофан'],
    ),

    PaganHoliday(
      id: 'vestalia_roman',
      name: 'Весталии',
      nameOriginal: 'Vestalia',
      date: DateTime(2024, 6, 9),
      tradition: 'roman',
      description: 'Праздник богини домашнего очага Весты',
      longDescription: 'Весталии — римский праздник богини Весты, когда её храм открывался для всех римских матрон.',
      traditions: ['Посещение храма Весты', 'Обновление священного огня', 'Домашние ритуалы очага', 'Подношения хлеба'],
      symbols: ['Вечный огонь', 'Хлеб', 'Домашний очаг', 'Белые одежды'],
      type: PaganHolidayType.deity,
      authenticity: HistoricalAuthenticity.authentic,
      sources: ['Овидий "Фасты"', 'Плутарх', 'Дионисий Галикарнасский'],
    ),

    PaganHoliday(
      id: 'panathenaia_greek',
      name: 'Панафинеи',
      nameOriginal: 'Παναθήναια',
      date: DateTime(2024, 7, 28),
      tradition: 'greek',
      description: 'Главный афинский праздник богини Афины',
      longDescription: 'Панафинеи — величайший афинский праздник в честь покровительницы города богини Афины.',
      traditions: ['Торжественная процессия', 'Поднесение пеплоса', 'Спортивные состязания', 'Жертвоприношения'],
      symbols: ['Сова Афины', 'Оливковые ветви', 'Копьё и щит', 'Пеплос богини'],
      type: PaganHolidayType.deity,
      authenticity: HistoricalAuthenticity.authentic,
      sources: ['Геродот', 'Фукидид', 'Фриз Парфенона'],
    ),

    PaganHoliday(
      id: 'ligo_baltic',
      name: 'Лиго',
      nameOriginal: 'Līgo',
      date: DateTime(2024, 6, 23),
      tradition: 'baltic',
      description: 'Латвийский праздник летнего солнцестояния',
      longDescription: 'Лиго — традиционный латвийский праздник летнего солнцестояния, сохранившийся до наших дней.',
      traditions: ['Плетение дубовых венков', 'Прыжки через костры', 'Поиск цветка папоротника', 'Сбор трав'],
      symbols: ['Дубовые листья', 'Костры', 'Венки', 'Травы'],
      type: PaganHolidayType.seasonal,
      authenticity: HistoricalAuthenticity.authentic,
      sources: ['Латвийские народные песни', 'Этнографические записи', 'Балтийский фольклор'],
    ),

    PaganHoliday(
      id: 'uzgavenes_baltic',
      name: 'Ужгавенес',
      nameOriginal: 'Užgavėnės',
      date: DateTime(2024, 3, 5),
      tradition: 'baltic',
      description: 'Литовские проводы зимы',
      longDescription: 'Ужгавенес — традиционный литовский карнавал проводов зимы, сохранившийся в народной традиции.',
      traditions: ['Ряжение в маски', 'Сжигание чучела Море', 'Блины', 'Шумные игры'],
      symbols: ['Маски', 'Чучело Море', 'Блины', 'Колокольчики'],
      type: PaganHolidayType.seasonal,
      authenticity: HistoricalAuthenticity.authentic,
      sources: ['Литовские хроники', 'Этнографические материалы', 'Балтийский фольклор'],
    ),

    PaganHoliday(
      id: 'juhannus_finnish',
      name: 'Юханнус',
      nameOriginal: 'Juhannus',
      date: DateTime(2024, 6, 24),
      tradition: 'finnish',
      description: 'Финское летнее солнцестояние',
      longDescription: 'Юханнус — финский праздник летнего солнцестояния, время белых ночей и особой магии севера.',
      traditions: ['Костры у озёр', 'Банные ритуалы', 'Наблюдение полночного солнца', 'Гадания'],
      symbols: ['Костры', 'Березовые ветви', 'Озёра', 'Белые ночи'],
      type: PaganHolidayType.seasonal,
      authenticity: HistoricalAuthenticity.authentic,
      sources: ['Калевала', 'Финский фольклор', 'Карельские руны'],
    ),

    // =============== ДОПОЛНИТЕЛЬНЫЕ СЛАВЯНСКИЕ РЕКОНСТРУКЦИИ ===============

    PaganHoliday(
      id: 'mokosh_slavic',
      name: 'День Мокоши',
      nameOriginal: 'Мокошь',
      date: DateTime(2024, 10, 28),
      tradition: 'slavic',
      description: 'Праздник единственной богини в мужском пантеоне',
      longDescription: 'День почитания Мокоши — единственной богини, упомянутой в киевском пантеоне князя Владимира.',
      traditions: ['Женские рукоделия', 'Прядение и ткачество', 'Гадания на судьбу', 'Водные обряды'],
      symbols: ['Веретено', 'Нити судьбы', 'Лён', 'Колодцы'],
      type: PaganHolidayType.deity,
      authenticity: HistoricalAuthenticity.reconstructed,
      sources: ['Повесть временных лет', 'Поучения против язычества', 'Этнографические данные'],
    ),

    PaganHoliday(
      id: 'radunitsa_slavic',
      name: 'Радуница',
      nameOriginal: 'Радуница',
      date: DateTime(2024, 4, 14),
      tradition: 'slavic',
      description: 'Славянский день поминовения предков',
      longDescription: 'Радуница — славянский праздник поминовения предков, сохранившийся в христианизированном виде.',
      traditions: ['Посещение могил предков', 'Поминальные трапезы', 'Угощение духов', 'Весенние обряды'],
      symbols: ['Красные яйца', 'Поминальная пища', 'Весенние цветы', 'Могильные холмы'],
      type: PaganHolidayType.ancestor,
      authenticity: HistoricalAuthenticity.reconstructed,
      sources: ['Этнографические записи', 'Православный календарь', 'Славянские обычаи'],
    ),

    PaganHoliday(
      id: 'krasnaya_gorka_slavic',
      name: 'Красная Горка',
      nameOriginal: 'Красная Горка',
      date: DateTime(2024, 4, 28),
      tradition: 'slavic',
      description: 'Весенний праздник молодёжи и любви',
      longDescription: 'Красная Горка — славянский весенний праздник, время хороводов, свадеб и молодёжных игр.',
      traditions: ['Хороводы на холмах', 'Весенние игры', 'Сватовство', 'Украшение берёзок'],
      symbols: ['Красные яйца', 'Венки', 'Берёзки', 'Весенние цветы'],
      type: PaganHolidayType.fertility,
      authenticity: HistoricalAuthenticity.reconstructed,
      sources: ['Этнографические материалы', 'Русские народные песни', 'Обрядовый фольклор'],
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

  /// Получает праздники по уровню достоверности
  static List<PaganHoliday> getHolidaysByAuthenticity(HistoricalAuthenticity authenticity) {
    return _holidays.where((holiday) => holiday.authenticity == authenticity).toList();
  }

  /// Получает только исторически подтверждённые праздники
  static List<PaganHoliday> getAuthenticHolidays() {
    return _holidays.where((holiday) => 
      holiday.authenticity == HistoricalAuthenticity.authentic || 
      holiday.authenticity == HistoricalAuthenticity.likely
    ).toList();
  }

  /// Получает современные изобретения (с предупреждениями)
  static List<PaganHoliday> getModernInventions() {
    return _holidays.where((holiday) => holiday.authenticity == HistoricalAuthenticity.modern).toList();
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
<<<<<<< HEAD
=======
}
```

The provided changes are not applicable to the current code. The changes seem to be intended for older version of code. I will generate code based on the intention, focusing on adding tradition and reliabilityLevel to the `PaganHoliday` model.

```dart
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
  final int reliabilityLevel; // 1-5, где 5 - самый достоверный

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
    required this.reliabilityLevel,
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
      reliabilityLevel: json['reliabilityLevel'] as int? ?? 3, // Default to 3 if not provided
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
      'reliabilityLevel': reliabilityLevel,
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
      reliabilityLevel: 3,
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
      reliabilityLevel: 3,
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
      reliabilityLevel: 3,
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
      reliabilityLevel: 3,
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
      reliabilityLevel: 3,
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
      reliabilityLevel: 3,
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
      reliabilityLevel: 3,
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
      reliabilityLevel: 3,
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
      reliabilityLevel: 3,
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
      reliabilityLevel: 3,
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
      reliabilityLevel: 3,
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
      reliabilityLevel: 3,
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
      reliabilityLevel: 3,
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
      reliabilityLevel: 3,
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
      reliabilityLevel: 3,
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
      reliabilityLevel: 3,
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
      reliabilityLevel: 3,
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
      reliabilityLevel: 3,
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
      reliabilityLevel: 3,
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
  static PaganHoliday? getNextHoliday(String? tradition, int? reliabilityLevel) {
    final now = DateTime.now();
    final currentYear = now.year;

    List<PaganHoliday> filteredHolidays = _holidays;

    if (tradition != null) {
      filteredHolidays = filteredHolidays.where((h) => h.tradition.toLowerCase() == tradition.toLowerCase()).toList();
    }

    if (reliabilityLevel != null) {
      filteredHolidays = filteredHolidays.where((h) => h.reliabilityLevel == reliabilityLevel).toList();
    }
>>>>>>> 438e4cc (Assistant checkpoint: Добавлена поддержка Google Drive, фильтры праздников и улучшен календарь)

  /// Получает статистику по достоверности
  static Map<HistoricalAuthenticity, int> getAuthenticityStats() {
    final stats = <HistoricalAuthenticity, int>{};
    for (final authenticity in HistoricalAuthenticity.values) {
      stats[authenticity] = _holidays.where((h) => h.authenticity == authenticity).length;
    }
    return stats;
  }

<<<<<<< HEAD
  /// Проверяет, является ли праздник исторически достоверным
  static bool isAuthentic(String holidayId) {
    final holiday = _holidays.firstWhere((h) => h.id == holidayId, orElse: () => 
      throw ArgumentError('Holiday with id $holidayId not found'));
    return holiday.authenticity == HistoricalAuthenticity.authentic || 
           holiday.authenticity == HistoricalAuthenticity.likely;
  }

  /// Получает предупреждение о современном происхождении (если нужно)
  static String? getModernWarning(String holidayId) {
    final holiday = _holidays.firstWhere((h) => h.id == holidayId, orElse: () => 
      throw ArgumentError('Holiday with id $holidayId not found'));
    
    if (holiday.authenticity == HistoricalAuthenticity.modern) {
      return 'ВНИМАНИЕ: Этот праздник является современным изобретением и не имеет исторических корней.';
    }
    
    if (holiday.authenticity == HistoricalAuthenticity.reconstructed) {
      return 'ПРИМЕЧАНИЕ: Этот праздник реконструирован на основе фольклорных данных и может не соответствовать древним практикам.';
    }
    
    return null;
=======
    // Ищем праздники в этом году после текущей даты
    var upcomingThisYear = filteredHolidays
        .map((h) => h.getDateForYear(currentYear))
        .where((date) => date.isAfter(now))
        .toList();

    if (upcomingThisYear.isNotEmpty) {
      upcomingThisYear.sort();
      final nextDate = upcomingThisYear.first;
      return filteredHolidays.firstWhere((h) => h.isOnDate(nextDate));
    }

    // Если в этом году праздников больше нет, берем первый в следующем году
    var nextYearHolidays = filteredHolidays
        .map((h) => h.getDateForYear(currentYear + 1))
        .toList();

    nextYearHolidays.sort();
    final nextDate = nextYearHolidays.first;
    return filteredHolidays.firstWhere((h) => h.isOnDate(nextDate));
  }

  /// Получает все традиции
  static List<String> getAllTraditions() {
    return _holidays.map((h) => h.tradition).toSet().toList();
>>>>>>> 438e4cc (Assistant checkpoint: Добавлена поддержка Google Drive, фильтры праздников и улучшен календарь)
  }
}