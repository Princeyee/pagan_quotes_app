// lib/ui/screens/favorites_page.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter/rendering.dart';
import 'dart:ui';

import '../../services/favorites_service.dart';
import '../../services/image_picker_service.dart';
import '../../utils/custom_cache.dart';
import '../widgets/glass_background.dart';

class FavoritesPage extends StatefulWidget {
  const FavoritesPage({super.key});

  @override
  State<FavoritesPage> createState() => _FavoritesPageState();
}

class _FavoritesPageState extends State<FavoritesPage> {
  List<FavoriteQuoteWithImage> _favorites = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadFavorites();
  }

  Future<void> _loadFavorites() async {
    try {
      final favSvc = await FavoritesService.init();
      
      // Выполняем миграцию старых избранных, если нужно
      await favSvc.migrateOldFavorites();
      
      final favs = await favSvc.getFavoriteQuotesWithImages();
      if (mounted) {
        setState(() {
          _favorites = favs;
          _loading = false;
        });
      }
    } catch (e) {
      print('Error loading favorites: $e');
      if (mounted) {
        setState(() {
          _loading = false;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка загрузки избранного: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _removeQuote(int index) async {
    final favoriteItem = _favorites[index];
    
    try {
      final favSvc = await FavoritesService.init();
      await favSvc.removeFromFavorites(favoriteItem.quote.id);
      
      if (mounted) {
        setState(() {
          _favorites.removeAt(index);
        });

        // Показываем снэкбар с возможностью отмены
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Цитата удалена из избранного'),
            action: SnackBarAction(
              label: 'Отменить',
              onPressed: () async {
                await favSvc.addToFavorites(
                  favoriteItem.quote,
                  imageUrl: favoriteItem.imageUrl,
                );
                _loadFavorites();
              },
            ),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      print('Error removing favorite: $e');
    }
  }

  Future<void> _shareQuote(FavoriteQuoteWithImage favorite) async {
    final quote = favorite.quote;
    await Share.share(
      '"${quote.text}"\n— ${quote.author}\n\nИз приложения Sacral',
      subject: 'Цитата от ${quote.author}',
    );
  }

  String _getImageUrl(FavoriteQuoteWithImage favorite) {
    if (favorite.imageUrl != null && favorite.imageUrl!.isNotEmpty) {
      return favorite.imageUrl!;
    }
    
    // Fallback: используем случайное изображение для категории
    return ImagePickerService.getRandomImage(favorite.quote.category);
  }

  @override
  Widget build(BuildContext context) {
    final canPop = Navigator.of(context).canPop();
    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
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
                      child: _loading
                        ? const Center(child: CircularProgressIndicator(color: Colors.white))
                        : _favorites.isEmpty
                            ? _buildEmptyState()
                            : _buildFavoritesList(),
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

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.favorite_border,
            size: 64,
            color: Colors.white.withAlpha((0.5 * 255).round()),
          ),
          const SizedBox(height: 16),
          Text(
            'Нет избранных цитат',
            style: GoogleFonts.merriweather(
              fontSize: 20,
              color: Colors.white.withAlpha((0.7 * 255).round()),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Добавьте цитаты в избранное, чтобы\nони появились здесь',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              color: Colors.white.withAlpha((0.5 * 255).round()),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFavoritesList() {
    return ListView.builder(
      itemCount: _favorites.length,
      padding: const EdgeInsets.symmetric(vertical: 12),
      itemBuilder: (context, index) {
        final favorite = _favorites[index];
        final imageUrl = _getImageUrl(favorite);
        
        return Dismissible(
          key: Key(favorite.quote.id),
          direction: DismissDirection.endToStart,
          background: Container(
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.symmetric(horizontal: 24),
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.redAccent.withAlpha((0.8 * 255).round()),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.delete,
              color: Colors.white,
              size: 28,
            ),
          ),
          onDismissed: (_) => _removeQuote(index),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            height: 220,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha((0.6 * 255).round()),
                  blurRadius: 12,
                  offset: const Offset(0, 6),
                )
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Фоновое изображение
                  CachedNetworkImage(
                    imageUrl: imageUrl,
                    cacheManager: CustomCache.instance,
                    fit: BoxFit.cover,
                    placeholder: (_, __) => Container(
                      color: Colors.grey[900],
                      child: const Center(
                        child: CircularProgressIndicator(color: Colors.white),
                      ),
                    ),
                    errorWidget: (_, __, ___) => Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.grey[900]!,
                            Colors.grey[800]!,
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      child: const Icon(
                        Icons.image_not_supported,
                        color: Colors.white38,
                        size: 48,
                      ),
                    ),
                  ),
                  
                  // Градиент для читаемости
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.black.withAlpha((0.3 * 255).round()),
                          Colors.black.withAlpha((0.7 * 255).round()),
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                  
                  // Контент
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Дата добавления и кнопка поделиться
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.black.withAlpha((0.5 * 255).round()),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                _formatDate(favorite.addedAt),
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                            
                            // Кнопка поделиться
                            GestureDetector(
                              onTap: () => _shareQuote(favorite),
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.black.withAlpha((0.5 * 255).round()),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.share,
                                  color: Colors.white,
                                  size: 16,
                                ),
                              ),
                            ),
                          ],
                        ),
                        
                        // Цитата
                        Expanded(
                          child: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  '"${favorite.quote.text}"',
                                  style: GoogleFonts.merriweather(
                                    fontSize: _getFontSize(favorite.quote.text),
                                    color: Colors.white,
                                    height: 1.4,
                                    fontStyle: FontStyle.italic,
                                  ),
                                  textAlign: TextAlign.center,
                                  maxLines: 5,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  favorite.quote.author,
                                  style: GoogleFonts.merriweather(
                                    fontSize: 14,
                                    color: Colors.white.withAlpha((0.9 * 255).round()),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                if (favorite.quote.source != favorite.quote.author)
                                  Text(
                                    favorite.quote.source,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.white.withAlpha((0.7 * 255).round()),
                                      fontStyle: FontStyle.italic,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  double _getFontSize(String text) {
    if (text.length > 200) return 13;
    if (text.length > 150) return 14;
    if (text.length > 100) return 15;
    return 16;
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);
    
    if (difference.inDays == 0) {
      return 'Сегодня';
    } else if (difference.inDays == 1) {
      return 'Вчера';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} дн. назад';
    } else {
      final months = [
        'янв', 'фев', 'мар', 'апр', 'май', 'июн',
        'июл', 'авг', 'сен', 'окт', 'ноя', 'дек'
      ];
      return '${date.day} ${months[date.month - 1]}';
    }
  }
}