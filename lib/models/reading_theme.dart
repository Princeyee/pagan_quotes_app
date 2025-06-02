// lib/models/reading_theme.dart
import 'package:flutter/material.dart';

enum ReadingThemeType { dark, light, sepia }

class ReadingTheme {
  final ReadingThemeType type;
  final Color backgroundColor;
  final Color textColor;
  final Color cardColor;
  final Color borderColor;
  final Color highlightColor;
  final Color quoteHighlightColor;
  final Color contextHighlightColor;
  final String displayName;
  final String letter;

  const ReadingTheme({
    required this.type,
    required this.backgroundColor,
    required this.textColor,
    required this.cardColor,
    required this.borderColor,
    required this.highlightColor,
    required this.quoteHighlightColor,
    required this.contextHighlightColor,
    required this.displayName,
    required this.letter,
  });

  static const ReadingTheme dark = ReadingTheme(
    type: ReadingThemeType.dark,
    backgroundColor: Colors.black,
    textColor: Colors.white,
    cardColor: Color(0xFF1A1A1A),
    borderColor: Color(0xFF333333),
    highlightColor: Color(0xFF444444),
    quoteHighlightColor: Color(0xFF4A90E2), // Более нейтральный синий
    contextHighlightColor: Color(0xFF2A2A2A),
    displayName: 'Темная',
    letter: 'α',
  );

  static const ReadingTheme light = ReadingTheme(
    type: ReadingThemeType.light,
    backgroundColor: Colors.white,
    textColor: Colors.black,
    cardColor: Color(0xFFF5F5F5),
    borderColor: Color(0xFFE0E0E0),
    highlightColor: Color(0xFFEEEEEE),
    quoteHighlightColor: Color(0xFF1565C0), // Более темный синий для светлой темы
    contextHighlightColor: Color(0xFFF0F0F0),
    displayName: 'Светлая',
    letter: 'α',
  );

  static const ReadingTheme sepia = ReadingTheme(
    type: ReadingThemeType.sepia,
    backgroundColor: Color(0xFFF4F1EA),
    textColor: Color(0xFF5D4E3A),
    cardColor: Color(0xFFEDE6D3),
    borderColor: Color(0xFFD4C4A8),
    highlightColor: Color(0xFFE8DCC0),
    quoteHighlightColor: Color(0xFF8B4513), // Коричневый для сепии
    contextHighlightColor: Color(0xFFE8DCC0),
    displayName: 'Сепия',
    letter: 'α',
  );

  static const List<ReadingTheme> allThemes = [dark, light, sepia];

  static ReadingTheme fromType(ReadingThemeType type) {
    switch (type) {
      case ReadingThemeType.dark:
        return dark;
      case ReadingThemeType.light:
        return light;
      case ReadingThemeType.sepia:
        return sepia;
    }
  }

  static ReadingThemeType fromString(String value) {
    switch (value) {
      case 'light':
        return ReadingThemeType.light;
      case 'sepia':
        return ReadingThemeType.sepia;
      case 'dark':
      default:
        return ReadingThemeType.dark;
    }
  }

  String get typeString {
    switch (type) {
      case ReadingThemeType.dark:
        return 'dark';
      case ReadingThemeType.light:
        return 'light';
      case ReadingThemeType.sepia:
        return 'sepia';
    }
  }
}
