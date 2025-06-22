class ThemeInfo {
  final String id;
  final String name;
  final String image;
  final List<String> authors;
  final String description;

  ThemeInfo({
    required this.id,
    required this.name,
    required this.image,
    required this.authors,
    required this.description,
  });
}

final List<ThemeInfo> allThemes = [
  ThemeInfo(
    id: "greece",
    name: "Греция",
    image: "assets/images/greece.jpg",
    authors: ["Гомер", "Платон", "Аристотель", "Гесиод"],
    description: "Философия, поэзия и мышление древних греков.",
  ),
  ThemeInfo(
    id: "nordic",
    name: "Север",
    image: "assets/images/nordic.jpg",
    authors: ["Старшая Эдда", "Беовульф"],
    description: "Скандинавская мудрость, мифы и эпос викингов.",
  ),
  ThemeInfo(
    id: "philosophy",
    name: "Философия",
    image: "assets/images/philosophy.jpg",
    authors: ["Ницше","Хайдеггер", "Шопенгауэр"],
    description: "Размышления о бытии, человеке и истине.",
  ),
  ThemeInfo(
    id: "pagan",
    name: "Язычество и традиционализм",
    image: "assets/images/pagan.jpg",
    authors: ["Эвола", "Элиаде", "Ален де Бенуа", "Askr Svarte"],
    description: "Архаические традиции, мифология и символизм.",
  ),
];
