import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../widgets/glass_background.dart';
import 'package:flutter/rendering.dart';
import 'dart:ui';

class AboutPage extends StatefulWidget {
  const AboutPage({super.key});

  @override
  State<AboutPage> createState() => _AboutPageState();
}

class _AboutPageState extends State<AboutPage> with SingleTickerProviderStateMixin {
  static const String _supportUrl = 'https://boosty.to/sacral/donate';

  late final AnimationController _animCtrl;
  late final Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeIn);
    _animCtrl.forward();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  Future<void> _launchSupport() async {
    final uri = Uri.parse(_supportUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      debugPrint('⚠️ Невозможно открыть ссылку: $_supportUrl');
    }
  }

  @override
  Widget build(BuildContext context) {
    final canPop = Navigator.of(context).canPop();
    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          // Фоновое изображение с блюром
          Positioned.fill(
            child: Image.asset(
              'assets/images/backgrounds/main_bg.jpg',
              fit: BoxFit.cover,
            ),
          ),
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: Container(
                color: Colors.black.withOpacity(0.7),
              ),
            ),
          ),
          SafeArea(
            child: Stack(
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 64),
                  child: GlassBackground(
                    child: Container(
                      margin: const EdgeInsets.all(12),
                      child: _buildAboutContent(),
                    ),
                  ),
                ),
                if (canPop)
                  Positioned(
                    top: 16,
                    left: 16,
                    child: ClipOval(
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                        child: Material(
                          color: Colors.black.withOpacity(0.25),
                          shape: const CircleBorder(),
                          child: IconButton(
                            icon: const Icon(Icons.chevron_left, color: Colors.white, size: 28),
                            onPressed: () => Navigator.of(context).maybePop(),
                            tooltip: 'Назад',
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAboutContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            ' Sacral',
            style: GoogleFonts.merriweather(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            'Цитаты, вдохновлённые духом, природой и мудростью времени.',
            style: GoogleFonts.merriweather(
              fontSize: 16,
              height: 1.6,
              color: Colors.white70,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 28),
          Text(
            'Этот проект создан со стремлением вернуть ощущение священного в повседневность.'
            'Для тех кто в силу обстоятель пока не может, или не хочет уезжать из городов, и отвергать технологии. Это приложение поможет если не начать с нуля, то постараться оседлать тигра',
            style: GoogleFonts.merriweather(
              fontSize: 15,
              height: 1.6,
              color: Colors.white60,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 36),
          // Временно скрыта кнопка поддержки проекта
          // ElevatedButton.icon(
          //   onPressed: _launchSupport,
          //   icon: const Icon(Icons.favorite_border),
          //   label: const Text('Поддержать проект'),
          //   style: ElevatedButton.styleFrom(
          //     foregroundColor: Colors.white,
          //     backgroundColor: Colors.deepOrangeAccent,
          //     padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
          //     textStyle: const TextStyle(fontSize: 16),
          //     shape: RoundedRectangleBorder(
          //       borderRadius: BorderRadius.circular(30),
          //     ),
          //   ),
          // ),
          // const SizedBox(height: 24),
          Text(
            'Спасибо за интерес к Sacral ✨',
            style: GoogleFonts.merriweather(
              fontSize: 14,
              fontStyle: FontStyle.italic,
              color: Colors.white38,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}