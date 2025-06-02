
// lib/ui/widgets/nav_drawer.dart - ЭЛЕГАНТНАЯ ВЕРСИЯ
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:ui';

import '../screens/about_page.dart';
import '../screens/favorites_page.dart';
import '../screens/quote_page.dart';
import '../screens/theme_selector_page.dart';
import '../screens/library_page.dart';
import '../screens/notes_page.dart';
import '../screens/audio_library_page.dart';

class NavDrawer extends StatelessWidget {
  final Function(Widget)? onNavigate;
  
  const NavDrawer({super.key, this.onNavigate});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
        child: Container(
          width: MediaQuery.of(context).size.width * 0.85,
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.85),
            borderRadius: const BorderRadius.only(
              topRight: Radius.circular(30),
              bottomRight: Radius.circular(30),
            ),
            border: Border.all(
              color: Colors.white.withOpacity(0.1),
              width: 1,
            ),
          ),
          child: SafeArea(
            child: Column(
              children: [
                // Элегантный заголовок
                Container(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    children: [
                      // Логотип с классическим дизайном
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white.withOpacity(0.2),
                            width: 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.3),
                              blurRadius: 20,
                              spreadRadius: 5,
                            ),
                          ],
                        ),
                        child: Center(
                          child: Text(
                            'S',
                            style: TextStyle(
                              fontSize: 36,
                              color: Colors.white,
                              fontWeight: FontWeight.w300,
                              fontFamily: 'serif', // Классический шрифт с засечками
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'SACRAL',
                        style: TextStyle(
                          fontSize: 24,
                          color: Colors.white,
                          fontWeight: FontWeight.w300,
                          letterSpacing: 4,
                          fontFamily: 'serif',
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        width: 100,
                        height: 1,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.transparent,
                              Colors.white.withOpacity(0.3),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Пункты меню с единым стилем
                Expanded(
                  child: ListView(
                    padding: EdgeInsets.zero,
                    children: [
                      _buildElegantMenuItem(
                        context,
                        icon: Icons.auto_stories, // Классическая иконка для цитат
                        label: 'Цитата дня',
                        onTap: () {
                          Navigator.pop(context);
                          // Просто закрываем drawer - мы уже на QuotePage!
                          // Музыка продолжит играть без прерывания
                        },
                      ),
                      
                      _buildElegantMenuItem(
                        context,
                        icon: Icons.bookmark, // Элегантная закладка
                        label: 'Избранное',
                        onTap: () {
                          Navigator.pop(context);
                          if (onNavigate != null) {
                            onNavigate!(const FavoritesPage());
                          } else {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const FavoritesPage()),
                            );
                          }
                        },
                      ),
                      
                      _buildElegantMenuItem(
                        context,
                        icon: Icons.edit_note, // Классическая иконка заметок
                        label: 'Заметки',
                        onTap: () {
                          Navigator.pop(context);
                          if (onNavigate != null) {
                            onNavigate!(const NotesPage());
                          } else {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const NotesPage()),
                            );
                          }
                        },
                      ),
                      
                      _buildElegantMenuItem(
                        context,
                        icon: Icons.library_books, // Классическая библиотека
                        label: 'Библиотека',
                        onTap: () {
                          Navigator.pop(context);
                          if (onNavigate != null) {
                            onNavigate!(const LibraryPage());
                          } else {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const LibraryPage()),
                            );
                          }
                        },
                      ),
                      
                      _buildElegantMenuItem(
                        context,
                        icon: Icons.music_note, // Элегантная нота для аудио
                        label: 'Аудио',
                        onTap: () {
                          Navigator.pop(context);
                          if (onNavigate != null) {
                            onNavigate!(const AudioLibraryPage());
                          } else {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const AudioLibraryPage()),
                            );
                          }
                        },
                      ),
                      
                      _buildElegantMenuItem(
                        context,
                        icon: Icons.palette_outlined, // Элегантная палитра
                        label: 'Темы',
                        onTap: () {
                          Navigator.pop(context);
                          if (onNavigate != null) {
                            onNavigate!(const ThemeSelectorPage());
                          } else {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const ThemeSelectorPage()),
                            );
                          }
                        },
                      ),

                      // Элегантный разделитель
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                        child: Container(
                          height: 1,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.transparent,
                                Colors.white.withOpacity(0.1),
                                Colors.transparent,
                              ],
                            ),
                          ),
                        ),
                      ),
                      
                      _buildElegantMenuItem(
                        context,
                        icon: Icons.info_outline, // Минималистичная иконка информации
                        label: 'О приложении',
                        onTap: () {
                          Navigator.pop(context);
                          if (onNavigate != null) {
                            onNavigate!(const AboutPage());
                          } else {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const AboutPage()),
                            );
                          }
                        },
                      ),
                    ],
                  ),
                ),
                
                // Элегантный футер
                Container(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    'Возрождение близко',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white.withOpacity(0.3),
                      fontStyle: FontStyle.italic,
                      letterSpacing: 1,
                      fontFamily: 'serif',
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildElegantMenuItem(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(15),
        child: InkWell(
          borderRadius: BorderRadius.circular(15),
          onTap: onTap,
          splashColor: Colors.white.withOpacity(0.05),
          highlightColor: Colors.white.withOpacity(0.02),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(15),
              border: Border.all(
                color: Colors.white.withOpacity(0.03),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                // Элегантная иконка
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.08),
                      width: 1,
                    ),
                  ),
                  child: Icon(
                    icon,
                    color: Colors.white.withOpacity(0.85),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 16),
                
                // Элегантный текст
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.white.withOpacity(0.9),
                      fontWeight: FontWeight.w300,
                      letterSpacing: 0.5,
                      fontFamily: 'serif',
                    ),
                  ),
                ),
                
                // Минималистичная стрелка
                Icon(
                  Icons.chevron_right,
                  color: Colors.white.withOpacity(0.2),
                  size: 18,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}