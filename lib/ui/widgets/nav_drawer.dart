import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../screens/about_page.dart';
import '../screens/favorites_page.dart';
import '../screens/quote_page.dart';
import '../screens/theme_selector_page.dart';
import '../../services/session_data.dart';

class NavDrawer extends StatelessWidget {
  const NavDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: Colors.black.withOpacity(0.94),
      elevation: 12,
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Colors.black87, Colors.black54],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              border: const Border(
                bottom: BorderSide(color: Colors.white10),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.6),
                  offset: const Offset(0, 2),
                  blurRadius: 6,
                )
              ],
            ),
            child: Center(
              child: Text(
                'SACRAL',
                style: GoogleFonts.merriweather(
                  fontSize: 26,
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 3,
                ),
              ),
            ),
          ),
          _buildItem(
            context,
            icon: Icons.format_quote_rounded,
            label: 'Цитата дня',
            onTap: () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (_) => QuotePage(
                    quote: SessionData.quote,
                    imageUrl: SessionData.imageUrl,
                    textColor: SessionData.textColor,
                  ),
                ),
              );
            },
          ),
          _buildItem(
            context,
            icon: Icons.favorite_rounded,
            label: 'Избранное',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const FavoritesPage()),
              );
            },
          ),
          _buildItem(
            context,
            icon: Icons.style_rounded,
            label: 'Темы',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ThemeSelectorPage()),
              );
            },
          ),
          const Divider(color: Colors.white24, indent: 16, endIndent: 16),
          _buildItem(
            context,
            icon: Icons.info_outline_rounded,
            label: 'О приложении',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AboutPage()),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildItem(BuildContext context,
      {required IconData icon, required String label, required VoidCallback onTap}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Material(
        color: Colors.white.withOpacity(0.02),
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          splashColor: Colors.deepOrange.withOpacity(0.2),
          highlightColor: Colors.white10,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
            child: Row(
              children: [
                Icon(icon, color: Colors.white70),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    label,
                    style: GoogleFonts.merriweather(
                      fontSize: 16,
                      color: Colors.white,
                      letterSpacing: 0.7,
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
}