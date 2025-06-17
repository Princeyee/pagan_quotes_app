// lib/ui/widgets/nav_drawer.dart - ОБНОВЛЕННАЯ ВЕРСИЯ С КАЛЕНДАРЕМ
import 'package:flutter/material.dart';
import 'dart:ui';
import '../screens/about_page.dart';
import '../screens/favorites_page.dart';
import '../screens/theme_selector_page.dart';
import '../screens/library_page.dart';
import '../screens/notes_page.dart';
import '../screens/audio_library_page.dart';
import '../screens/calendar_page.dart'; // Новый импорт

class NavDrawer extends StatefulWidget {
  final Function(Widget)? onNavigate;
  
  const NavDrawer({super.key, this.onNavigate});

  @override
  State<NavDrawer> createState() => _NavDrawerState();
}

class _NavDrawerState extends State<NavDrawer> 
    with TickerProviderStateMixin {
  
  late AnimationController _slideController;
  
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    
    // Контроллер для выезда drawer'а
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 250),
      vsync: this,
    );

    // Анимация выезда
    _slideAnimation = Tween<Offset>(
      begin: const Offset(-1.0, 0.0),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOut,
    ));

    // Запуск анимации
    _slideController.forward();
  }

  @override
  void dispose() {
    _slideController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SlideTransition(
      position: _slideAnimation,
      child: ClipRRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20.0, sigmaY: 20.0),
          child: Container(
            width: MediaQuery.of(context).size.width * 0.85,
            decoration: BoxDecoration(
              // Очень прозрачное черное стекло
              color: Colors.black.withAlpha((0.15 * 255).round()),
              borderRadius: const BorderRadius.only(
                topRight: Radius.circular(25),
                bottomRight: Radius.circular(25),
              ),
              border: Border.all(
                color: Colors.white.withAlpha((0.08 * 255).round()),
                width: 0.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha((0.3 * 255).round()),
                  blurRadius: 40,
                  spreadRadius: 0,
                  offset: const Offset(5, 0),
                ),
              ],
            ),
            child: SafeArea(
              child: Column(
                children: [
                  // Заголовок с PNG иконкой
                  Container(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      children: [
                        // Логотип - PNG иконка в круге
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.white.withAlpha((0.15 * 255).round()),
                              width: 1,
                            ),
                            color: Colors.black.withAlpha((0.3 * 255).round()),
                          ),
                          child: ClipOval(
                            child: Image.asset(
                              'assets/images/rune_icon.png',
                              width: 60,
                              height: 60,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                // Fallback если первая иконка не найдена
                                return ClipOval(
                                  child: Image.asset(
                                    'assets/images/RuneIcon.small.png',
                                    width: 60,
                                    height: 60,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) {
                                      // Fallback на простую иконку если нет PNG
                                      return Container(
                                        width: 60,
                                        height: 60,
                                        decoration: const BoxDecoration(
                                          color: Colors.transparent,
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(
                                          Icons.account_tree,
                                          color: Colors.white.withAlpha((0.8 * 255).round()),
                                          size: 30,
                                        ),
                                      );
                                    },
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'SACRAL',
                          style: TextStyle(
                            fontSize: 24,
                            color: Colors.white.withAlpha((0.9 * 255).round()),
                            fontWeight: FontWeight.w200,
                            letterSpacing: 4,
                            fontFamily: 'serif',
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          width: 80,
                          height: 1,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.transparent,
                                Colors.white.withAlpha((0.2 * 255).round()),
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
                      physics: const BouncingScrollPhysics(),
                      padding: EdgeInsets.zero,
                      children: [
                        _buildMenuItem(
                          context,
                          icon: Icons.auto_stories,
                          label: 'Цитата дня',
                          onTap: () {
                            _closeDrawer(context);
                          },
                        ),

                        _buildMenuItem(
                          context,
                          icon: Icons.calendar_month,
                          label: 'Календарь',
                          onTap: () {
                            _closeDrawer(context);
                            _navigateToPage(const CalendarPage());
                          },
                        ),
                        
                        _buildMenuItem(
                          context,
                          icon: Icons.bookmark,
                          label: 'Избранное',
                          onTap: () {
                            _closeDrawer(context);
                            _navigateToPage(const FavoritesPage());
                          },
                        ),
                        
                        _buildMenuItem(
                          context,
                          icon: Icons.edit_note,
                          label: 'Заметки',
                          onTap: () {
                            _closeDrawer(context);
                            _navigateToPage(const NotesPage());
                          },
                        ),
                        
                        _buildMenuItem(
                          context,
                          icon: Icons.library_books,
                          label: 'Библиотека',
                          onTap: () {
                            _closeDrawer(context);
                            _navigateToPage(const LibraryPage());
                          },
                        ),
                        
                        _buildMenuItem(
                          context,
                          icon: Icons.music_note,
                          label: 'Аудио',
                          onTap: () {
                            _closeDrawer(context);
                            _navigateToPage( AudioLibraryPage());
                          },
                        ),
                        
                        _buildMenuItem(
                          context,
                          icon: Icons.palette_outlined,
                          label: 'Темы',
                          onTap: () {
                            _closeDrawer(context);
                            _navigateToPage(const ThemeSelectorPage());
                          },
                        ),

                        // Разделитель
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                          child: Container(
                            height: 1,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Colors.transparent,
                                  Colors.white.withAlpha((0.08 * 255).round()),
                                  Colors.transparent,
                                ],
                              ),
                            ),
                          ),
                        ),
                        
                        _buildMenuItem(
                          context,
                          icon: Icons.info_outline,
                          label: 'О приложении',
                          onTap: () {
                            _closeDrawer(context);
                            _navigateToPage(const AboutPage());
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
                        color: Colors.white.withAlpha((0.25 * 255).round()),
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
      ),
    );
  }

  Widget _buildMenuItem(
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
          splashColor: Colors.white.withAlpha((0.05 * 255).round()),
          highlightColor: Colors.white.withAlpha((0.02 * 255).round()),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(15),
              color: Colors.black.withAlpha((0.15 * 255).round()),
              border: Border.all(
                color: Colors.white.withAlpha((0.08 * 255).round()),
                width: 0.5,
              ),
            ),
            child: Row(
              children: [
                // Иконка
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha((0.05 * 255).round()),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: Colors.white.withAlpha((0.08 * 255).round()),
                      width: 0.5,
                    ),
                  ),
                  child: Icon(
                    icon,
                    color: Colors.white.withAlpha((0.8 * 255).round()),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 16),
                
                // Текст
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.white.withAlpha((0.8 * 255).round()),
                      fontWeight: FontWeight.w300,
                      letterSpacing: 0.5,
                      fontFamily: 'serif',
                    ),
                  ),
                ),
                
                // Стрелка
                Icon(
                  Icons.chevron_right,
                  color: Colors.white.withAlpha((0.3 * 255).round()),
                  size: 18,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _closeDrawer(BuildContext context) {
    Navigator.pop(context);
  }

  void _navigateToPage(Widget page) {
    if (widget.onNavigate != null) {
      widget.onNavigate!(page);
    } else {
      Navigator.push(
        context,
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) => page,
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            const begin = Offset(1.0, 0.0);
            const end = Offset.zero;
            const curve = Curves.easeOutCubic;
            
            var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
            var offsetAnimation = animation.drive(tween);
            
            return SlideTransition(
              position: offsetAnimation,
              child: FadeTransition(
                opacity: animation,
                child: child,
              ),
            );
          },
          transitionDuration: const Duration(milliseconds: 300),
        ),
      );
    }
  }
}
