
// lib/ui/widgets/nav_drawer.dart - ЭЛЕГАНТНАЯ ВЕРСИЯ С АНИМАЦИЯМИ
import 'package:flutter/material.dart';
import 'dart:ui';
import '../screens/about_page.dart';
import '../screens/favorites_page.dart';
import '../screens/theme_selector_page.dart';
import '../screens/library_page.dart';
import '../screens/notes_page.dart';
import '../screens/audio_library_page.dart';

class NavDrawer extends StatefulWidget {
  final Function(Widget)? onNavigate;
  
  const NavDrawer({super.key, this.onNavigate});

  @override
  State<NavDrawer> createState() => _NavDrawerState();
}

class _NavDrawerState extends State<NavDrawer> 
    with TickerProviderStateMixin {
  
  late AnimationController _slideController;
  late AnimationController _fadeController;
  late AnimationController _logoController;
  
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;
  late Animation<double> _logoScaleAnimation;
  late Animation<double> _logoRotateAnimation;

  @override
  void initState() {
    super.initState();
    
    // Контроллер для выезда drawer'а
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    
    // Контроллер для появления элементов
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    
    // Контроллер для анимации логотипа
    _logoController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    // Анимация выезда
    _slideAnimation = Tween<Offset>(
      begin: const Offset(-1.0, 0.0),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutCubic,
    ));

    // Анимация появления элементов
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    ));

    // Анимация масштабирования логотипа
    _logoScaleAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _logoController,
      curve: Curves.elasticOut,
    ));

    // Анимация поворота логотипа
    _logoRotateAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _logoController,
      curve: Curves.easeInOut,
    ));

    // Запуск анимаций последовательно
    _startAnimations();
  }

  void _startAnimations() async {
    _slideController.forward();
    await Future.delayed(const Duration(milliseconds: 200));
    _fadeController.forward();
    await Future.delayed(const Duration(milliseconds: 100));
    _logoController.forward();
  }

  @override
  void dispose() {
    _slideController.dispose();
    _fadeController.dispose();
    _logoController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SlideTransition(
      position: _slideAnimation,
      child: ClipRRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 15.0, sigmaY: 15.0),
          child: Container(
            width: MediaQuery.of(context).size.width * 0.85,
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.75),
              borderRadius: const BorderRadius.only(
                topRight: Radius.circular(30),
                bottomRight: Radius.circular(30),
              ),
              border: Border.all(
                color: Colors.white.withOpacity(0.15),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.5),
                  blurRadius: 30,
                  spreadRadius: 5,
                  offset: const Offset(5, 0),
                ),
              ],
            ),
            child: SafeArea(
              child: Column(
                children: [
                  // Элегантный заголовок с анимацией
                  FadeTransition(
                    opacity: _fadeAnimation,
                    child: Container(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        children: [
                          // Логотип с древом мира
                          AnimatedBuilder(
                            animation: _logoController,
                            builder: (context, child) {
                              return Transform.scale(
                                scale: _logoScaleAnimation.value,
                                child: Transform.rotate(
                                  angle: _logoRotateAnimation.value * 0.1,
                                  child: Container(
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
                                          color: Colors.black.withOpacity(0.4),
                                          blurRadius: 25,
                                          spreadRadius: 5,
                                        ),
                                      ],
                                    ),
                                    child: ClipOval(
                                      child: BackdropFilter(
                                        filter: ImageFilter.blur(sigmaX: 2.0, sigmaY: 2.0),
                                        child: Container(
                                          decoration: BoxDecoration(
                                            color: Colors.white.withOpacity(0.05),
                                            shape: BoxShape.circle,
                                          ),
                                          child: Center(
                                            child: _buildWorldTree(),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                          const SizedBox(height: 16),
                          SlideTransition(
                            position: Tween<Offset>(
                              begin: const Offset(0, 0.5),
                              end: Offset.zero,
                            ).animate(CurvedAnimation(
                              parent: _fadeController,
                              curve: Curves.easeOut,
                            )),
                            child: Text(
                              'SACRAL',
                              style: TextStyle(
                                fontSize: 24,
                                color: Colors.white,
                                fontWeight: FontWeight.w300,
                                letterSpacing: 4,
                                fontFamily: 'serif',
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 800),
                            width: _fadeAnimation.value * 100,
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
                  ),
                  
                  // Пункты меню с анимированным появлением
                  Expanded(
                    child: FadeTransition(
                      opacity: _fadeAnimation,
                      child: ListView(
                        padding: EdgeInsets.zero,
                        children: [
                          _buildAnimatedMenuItem(
                            context,
                            icon: Icons.auto_stories,
                            label: 'Цитата дня',
                            delay: 0,
                            onTap: () {
                              _closeDrawer(context);
                            },
                          ),
                          
                          _buildAnimatedMenuItem(
                            context,
                            icon: Icons.bookmark,
                            label: 'Избранное',
                            delay: 100,
                            onTap: () {
                              _closeDrawer(context);
                              _navigateToPage(const FavoritesPage());
                            },
                          ),
                          
                          _buildAnimatedMenuItem(
                            context,
                            icon: Icons.edit_note,
                            label: 'Заметки',
                            delay: 200,
                            onTap: () {
                              _closeDrawer(context);
                              _navigateToPage(const NotesPage());
                            },
                          ),
                          
                          _buildAnimatedMenuItem(
                            context,
                            icon: Icons.library_books,
                            label: 'Библиотека',
                            delay: 300,
                            onTap: () {
                              _closeDrawer(context);
                              _navigateToPage(const LibraryPage());
                            },
                          ),
                          
                          _buildAnimatedMenuItem(
                            context,
                            icon: Icons.music_note,
                            label: 'Аудио',
                            delay: 400,
                            onTap: () {
                              _closeDrawer(context);
                              _navigateToPage(const AudioLibraryPage());
                            },
                          ),
                          
                          _buildAnimatedMenuItem(
                            context,
                            icon: Icons.palette_outlined,
                            label: 'Темы',
                            delay: 500,
                            onTap: () {
                              _closeDrawer(context);
                              _navigateToPage(const ThemeSelectorPage());
                            },
                          ),

                          // Элегантный разделитель с анимацией
                          TweenAnimationBuilder<double>(
                            duration: Duration(milliseconds: 800 + 600),
                            tween: Tween(begin: 0.0, end: 1.0),
                            builder: (context, value, child) {
                              return Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                                child: Container(
                                  height: 1,
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        Colors.transparent,
                                        Colors.white.withOpacity(0.1 * value),
                                        Colors.transparent,
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                          
                          _buildAnimatedMenuItem(
                            context,
                            icon: Icons.info_outline,
                            label: 'О приложении',
                            delay: 700,
                            onTap: () {
                              _closeDrawer(context);
                              _navigateToPage(const AboutPage());
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                  // Элегантный футер с анимацией
                  SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0, 1.0),
                      end: Offset.zero,
                    ).animate(CurvedAnimation(
                      parent: _fadeController,
                      curve: Curves.easeOut,
                    )),
                    child: Container(
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
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Создаем SVG-подобное изображение древа мира
  Widget _buildWorldTree() {
    return CustomPaint(
      size: const Size(50, 50),
      painter: WorldTreePainter(),
    );
  }

  Widget _buildAnimatedMenuItem(
    BuildContext context, {
    required IconData icon,
    required String label,
    required int delay,
    required VoidCallback onTap,
  }) {
    return TweenAnimationBuilder<double>(
      duration: Duration(milliseconds: 600 + delay),
      tween: Tween(begin: 0.0, end: 1.0),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Transform.translate(
          offset: Offset(50 * (1 - value), 0),
          child: Opacity(
            opacity: value,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
              child: Material(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(15),
                child: InkWell(
                  borderRadius: BorderRadius.circular(15),
                  onTap: onTap,
                  splashColor: Colors.white.withOpacity(0.08),
                  highlightColor: Colors.white.withOpacity(0.03),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.05),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        // Элегантная иконка с анимацией
                        TweenAnimationBuilder<double>(
                          duration: Duration(milliseconds: 400 + delay),
                          tween: Tween(begin: 0.0, end: 1.0),
                          curve: Curves.elasticOut,
                          builder: (context, scaleValue, child) {
                            return Transform.scale(
                              scale: scaleValue,
                              child: Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.08),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: Colors.white.withOpacity(0.12),
                                    width: 1,
                                  ),
                                ),
                                child: Icon(
                                  icon,
                                  color: Colors.white.withOpacity(0.9),
                                  size: 20,
                                ),
                              ),
                            );
                          },
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
                        
                        // Минималистичная стрелка с анимацией
                        TweenAnimationBuilder<double>(
                          duration: Duration(milliseconds: 300 + delay),
                          tween: Tween(begin: 0.0, end: 1.0),
                          builder: (context, arrowValue, child) {
                            return Transform.translate(
                              offset: Offset(10 * (1 - arrowValue), 0),
                              child: Opacity(
                                opacity: arrowValue * 0.4,
                                child: Icon(
                                  Icons.chevron_right,
                                  color: Colors.white,
                                  size: 18,
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
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
        MaterialPageRoute(builder: (_) => page),
      );
    }
  }
}

// Кастомный painter для рисования древа мира
class WorldTreePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.7)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 5;

    // Ствол дерева
    canvas.drawLine(
      Offset(center.dx, center.dy + radius * 0.3),
      Offset(center.dx, center.dy + radius * 0.8),
      paint,
    );

    // Корни
    final rootPaint = Paint()
      ..color = Colors.white.withOpacity(0.5)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    // Левый корень
    final leftRootPath = Path()
      ..moveTo(center.dx, center.dy + radius * 0.8)
      ..quadraticBezierTo(
        center.dx - radius * 0.3, center.dy + radius * 0.6,
        center.dx - radius * 0.6, center.dy + radius * 0.9,
      );
    canvas.drawPath(leftRootPath, rootPaint);

    // Правый корень
    final rightRootPath = Path()
      ..moveTo(center.dx, center.dy + radius * 0.8)
      ..quadraticBezierTo(
        center.dx + radius * 0.3, center.dy + radius * 0.6,
        center.dx + radius * 0.6, center.dy + radius * 0.9,
      );
    canvas.drawPath(rightRootPath, rootPaint);

    // Крона - центральная ветвь
    canvas.drawLine(
      Offset(center.dx, center.dy + radius * 0.3),
      Offset(center.dx, center.dy - radius * 0.6),
      paint,
    );

    // Левые ветви
    final leftBranch1Path = Path()
      ..moveTo(center.dx, center.dy)
      ..quadraticBezierTo(
        center.dx - radius * 0.2, center.dy - radius * 0.3,
        center.dx - radius * 0.5, center.dy - radius * 0.4,
      );
    canvas.drawPath(leftBranch1Path, paint);

    final leftBranch2Path = Path()
      ..moveTo(center.dx, center.dy - radius * 0.2)
      ..quadraticBezierTo(
        center.dx - radius * 0.3, center.dy - radius * 0.4,
        center.dx - radius * 0.4, center.dy - radius * 0.7,
      );
    canvas.drawPath(leftBranch2Path, paint);

    // Правые ветви
    final rightBranch1Path = Path()
      ..moveTo(center.dx, center.dy)
      ..quadraticBezierTo(
        center.dx + radius * 0.2, center.dy - radius * 0.3,
        center.dx + radius * 0.5, center.dy - radius * 0.4,
      );
    canvas.drawPath(rightBranch1Path, paint);

    final rightBranch2Path = Path()
      ..moveTo(center.dx, center.dy - radius * 0.2)
      ..quadraticBezierTo(
        center.dx + radius * 0.3, center.dy - radius * 0.4,
        center.dx + radius * 0.4, center.dy - radius * 0.7,
      );
    canvas.drawPath(rightBranch2Path, paint);

    // Листья (маленькие окружности)
    final leafPaint = Paint()
      ..color = Colors.white.withOpacity(0.4)
      ..style = PaintingStyle.fill;

    final leafPositions = [
      Offset(center.dx, center.dy - radius * 0.6),
      Offset(center.dx - radius * 0.5, center.dy - radius * 0.4),
      Offset(center.dx + radius * 0.5, center.dy - radius * 0.4),
      Offset(center.dx - radius * 0.4, center.dy - radius * 0.7),
      Offset(center.dx + radius * 0.4, center.dy - radius * 0.7),
    ];

    for (final pos in leafPositions) {
      canvas.drawCircle(pos, 2, leafPaint);
    }
  }



  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}