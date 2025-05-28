// lib/ui/screens/favorites_page.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:share_plus/share_plus.dart';

import '../../services/favorites_service.dart';
import '../../services/image_picker_service.dart';
import '../../utils/custom_cache.dart';
import '../ui/widgets/quote_card.dart';

class FavoritesPage extends StatefulWidget {
  const FavoritesPage({super.key});

  @override
  State<FavoritesPage> createState() => _FavoritesPageState();
}

class _FavoritesPageState extends State<FavoritesPage> with TickerProviderStateMixin {
  List<FavoriteQuoteWithImage> _favorites = [];
  bool _loading = true;
  late AnimationController _listAnimationController;
  late Animation<double> _listAnimation;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _loadFavorites();
  }

  void _initializeAnimations() {
    _listAnimationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    
    _listAnimation = CurvedAnimation(
      parent: _listAnimationController,
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _loadFavorites() async {
    try {
      final favSvc = await FavoritesService.init();
      
      // Выполняем миграцию старых избранных, если нужно
      await favSvc.migrateOldFavorites();
      
      final favs = await favSvc.getFavoriteQuotesWithImages();
      setState(() {
        _favorites = favs;
        _loading = false;
      });
      
      _listAnimationController.forward();
    } catch (e) {
      setState(() {
        _loading = false;
      });
      
      if (mounted) {
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
    final favSvc = await FavoritesService.init();
    
    await favSvc.removeFromFavorites(favoriteItem.quote.id);
    
    setState(() {
      _favorites.removeAt(index);
    });

    // Показываем снэкбар с возможностью отмены
    if (mounted) {
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
  }

  Future<void> _shareQuote(FavoriteQuoteWithImage favorite) async {
    final quote = favorite.quote;
    await Share.share(
      '"${quote.text}"\n— ${quote.author}\n\nИз приложения Sacral',
      subject: 'Цитата от ${quote.author}',
    );
  }

  Future<void> _exportAllFavorites() async {
    try {
      final favSvc = await FavoritesService.init();
      final exportText = await favSvc.exportFavorites();
      
      await Share.share(
        exportText,
        subject: 'Мои избранные цитаты - Sacral',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка экспорта: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  String _getImageUrl(FavoriteQuoteWithImage favorite) {
    if (favorite.imageUrl != null) {
      return favorite.imageUrl!;
    }
    
    // Fallback: используем случайное изображение для категории
    return ImagePickerService.getRandomImage(favorite.quote.category);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: Text(
          'Избранное', 
          style: GoogleFonts.merriweather(color: Colors.white)
        ),
        actions: [
          if (_favorites.isNotEmpty)
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, color: Colors.white),
              color: Colors.grey[900],
              onSelected: (value) {
                switch (value) {
                  case 'export':
                    _exportAllFavorites();
                    break;
                  case 'clear':
                    _showClearConfirmDialog();
                    break;
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'export',
                  child: Text(
                    'Экспортировать все',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
                const PopupMenuItem(
                  value: 'clear',
                  child: Text(
                    'Очистить все',
                    style: TextStyle(color: Colors.red),
                  ),
                ),
              ],
            ),
        ],
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: Colors.white)
            )
          : _favorites.isEmpty
              ? _buildEmptyState()
              : _buildFavoritesList(),
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
            color: Colors.white.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          Text(
            'Нет избранных цитат',
            style: GoogleFonts.merriweather(
              fontSize: 20,
              color: Colors.white.withOpacity(0.7),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Добавьте цитаты в избранное, чтобы\nони появились здесь',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              color: Colors.white.withOpacity(0.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFavoritesList() {
    return FadeTransition(
      opacity: _listAnimation,
      child: ListView.builder(
        itemCount: _favorites.length,
        padding: const EdgeInsets.symmetric(vertical: 12),
        itemBuilder: (context, index) {
          final favorite = _favorites[index];
          final imageUrl = _getImageUrl(favorite);
          
          return AnimatedBuilder(
            animation: _listAnimation,
            builder: (context, child) {
              final slideAnimation = Tween<Offset>(
                begin: const Offset(1.0, 0.0),
                end: Offset.zero,
              ).animate(CurvedAnimation(
                parent: _listAnimation,
                curve: Interval(
                  (index / _favorites.length) * 0.5,
                  ((index + 1) / _favorites.length) * 0.5 + 0.5,
                  curve: Curves.easeOutCubic,
                ),
              ));
              
              return SlideTransition(
                position: slideAnimation,
                child: child,
              );
            },
            child: Dismissible(
              key: Key(favorite.quote.id),
              direction: DismissDirection.endToStart,
              background: Container(
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.symmetric(horizontal: 24),
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.redAccent.withOpacity(0.8),
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
                height: 240,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.6),
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
                            child: CircularProgressIndicator(),
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
                              Colors.black.withOpacity(0.3),
                              Colors.black.withOpacity(0.7),
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
                            // Дата добавления
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withOpacity(0.5),
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
                                      color: Colors.black.withOpacity(0.5),
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
                                      maxLines: 6,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      favorite.quote.author,
                                      style: GoogleFonts.merriweather(
                                        fontSize: 14,
                                        color: Colors.white.withOpacity(0.9),
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    if (favorite.quote.source != favorite.quote.author)
                                      Text(
                                        favorite.quote.source,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.white.withOpacity(0.7),
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
            ),
          );
        },
      ),
    );
  }

  double _getFontSize(String text) {
    if (text.length > 200) return 14;
    if (text.length > 150) return 15;
    if (text.length > 100) return 16;
    return 18;
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

  void _showClearConfirmDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text(
          'Очистить избранное?',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'Это действие нельзя отменить. Все избранные цитаты будут удалены.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(context).pop();
              final favSvc = await FavoritesService.init();
              await favSvc.clearAllFavorites();
              _loadFavorites();
            },
            child: const Text(
              'Очистить',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _listAnimationController.dispose();
    super.dispose();
  }
}