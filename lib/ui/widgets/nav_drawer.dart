
// lib/ui/widgets/nav_drawer.dart
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
  const NavDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
        child: Container(
          width: MediaQuery.of(context).size.width * 0.85,
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.7),
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
                // Заголовок
                Container(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    children: [
                      // Логотип/иконка
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white.withOpacity(0.3),
                            width: 2,
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
                            style: GoogleFonts.merriweather(
                              fontSize: 36,
                              color: Colors.white,
                              fontWeight: FontWeight.w300,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'SACRAL',
                        style: GoogleFonts.merriweather(
                          fontSize: 24,
                          color: Colors.white,
                          fontWeight: FontWeight.w400,
                          letterSpacing: 3,
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
                              Colors.white.withOpacity(0.5),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Пункты меню
                Expanded(
                  child: ListView(
                    padding: EdgeInsets.zero,
                    children: [
                      _buildMenuItem(
                        context,
                        icon: Icons.format_quote_rounded,
                        label: 'Цитата дня',
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.


pushReplacement(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const QuotePage(),
                            ),
                          );
                        },
                      ),
                      _buildMenuItem(
                        context,
                        icon: Icons.favorite_rounded,
                        label: 'Избранное',
                        gradient: LinearGradient(
                          colors: [
                            Colors.red.withOpacity(0.3),
                            Colors.red.withOpacity(0.1),
                          ],
                        ),
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const FavoritesPage()),
                          );
                        },
                      ),
                      _buildMenuItem(
                        context,
                        icon: Icons.note_alt_rounded,
                        label: 'Заметки',
                        gradient: LinearGradient(
                          colors: [
                            Colors.amber.withOpacity(0.3),
                            Colors.amber.withOpacity(0.1),
                          ],
                        ),
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const NotesPage()),
                          );
                        },
                      ),
                      _buildMenuItem(
                        context,
                        icon: Icons.library_books_rounded,
                        label: 'Библиотека',
                        gradient: LinearGradient(
                          colors: [
                            Colors.blue.withOpacity(0.3),
                            Colors.blue.withOpacity(0.1),
                          ],
                        ),
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const LibraryPage()),
                          );
                        },
                      ),
                      _buildMenuItem(
                        context,
                        icon: Icons.headphones_rounded,
                        label: 'Аудио',
                        gradient: LinearGradient(
                          colors: [
                            Colors.purple.withOpacity(0.3),
                            Colors.purple.withOpacity(0.1),
                          ],
                        ),
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const AudioLibraryPage()),
                          );
                        },
                      ),
                      _buildMenuItem(
                        context,
                        icon: Icons.style_rounded,
                        label: 'Темы',
                        gradient: LinearGradient(
                          colors: [
                            Colors.green.withOpacity(0.3),
                            Colors.green.withOpacity(0.1),
                          ],
                        ),
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const ThemeSelectorPage()),
                          );
                        },
                      ),


// Разделитель
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                        child: Container(
                          height: 1,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.transparent,
                                Colors.white.withOpacity(0.2),
                                Colors.transparent,
                              ],
                            ),
                          ),
                        ),
                      ),
                      
                      _buildMenuItem(
                        context,
                        icon: Icons.info_outline_rounded,
                        label: 'О приложении',
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const AboutPage()),
                          );
                        },
                      ),
                    ],
                  ),
                ),
                
                // Футер
                Container(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    'Возрождение близко',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white.withOpacity(0.4),
                      fontStyle: FontStyle.italic,
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

  Widget _buildMenuItem(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Gradient? gradient,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          splashColor: Colors.white.withOpacity(0.1),
          highlightColor: Colors.white.withOpacity(0.05),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
            decoration: BoxDecoration(
              gradient: gradient,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Colors.white.withOpacity(0.05),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                // Иконка в контейнере
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    icon,
                    color: Colors.white.withOpacity(0.9),
                    size: 22,
                  ),
                ),
                const SizedBox(width: 16),
                
                // Текст
                Expanded(
                  child: Text(
                    label,
                    style: GoogleFonts.merriweather(
                      fontSize: 16,
                      color: Colors.white,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ),
                
                // Стрелка
                Icon(
                  Icons.chevron_right,
                  color: Colors.white.withOpacity(0.3),
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
