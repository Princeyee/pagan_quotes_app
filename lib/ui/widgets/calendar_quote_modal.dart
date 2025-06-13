// lib/ui/widgets/calendar_quote_modal.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:ui' as ui;
import '../../models/daily_quote.dart';
import '../../services/favorites_service.dart';
import '../../services/image_picker_service.dart';
import '../../utils/custom_cache.dart';
import '../screens/context_page.dart';
import 'note_modal.dart';

class CalendarQuoteModal extends StatefulWidget {
  final DailyQuote dailyQuote;

  const CalendarQuoteModal({
    super.key,
    required this.dailyQuote,
  });

  @override
  State<CalendarQuoteModal> createState() => _CalendarQuoteModalState();
}

class _CalendarQuoteModalState extends State<CalendarQuoteModal>
    with TickerProviderStateMixin {
  late AnimationController _animController;
  late AnimationController _imageController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;
  late Animation<double> _imageAnimation;

  String? _imageUrl;
  bool _isFavorite = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _loadData();
  }

  void _initializeAnimations() {
    _animController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    _imageController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutCubic,
    ));

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animController,
      curve: Curves.easeIn,
    ));

    _imageAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _imageController,
      curve: Curves.easeInOut,
    ));

    _animController.forward();
  }

  Future<void> _loadData() async {
    try {
      // Загружаем изображение
      final cache = CustomCache.prefs;
      final dateString = _dateToString(widget.dailyQuote.date);
      final cachedImageUrl = cache.getSetting<String>('daily_image_$dateString');
      
      if (cachedImageUrl != null) {
        _imageUrl = cachedImageUrl;
      } else {
        _imageUrl = ImagePickerService.getRandomImage(widget.dailyQuote.quote.category);
        await cache.setSetting('daily_image_$dateString', _imageUrl);
      }

      // Проверяем избранное
      final favService = await FavoritesService.init();
      _isFavorite = favService.isFavorite(widget.dailyQuote.quote.id);

      setState(() => _isLoading = false);
      _imageController.forward();
    } catch (e) {
      print('Error loading calendar quote data: $e');
      setState(() => _isLoading = false);
    }
  }

  String _dateToString(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.of(context).pop(),
      child: Material(
        color: Colors.transparent,
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              color: Colors.black.withAlpha((0.5 * 255).round()),
              child: SafeArea(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    SlideTransition(
                      position: _slideAnimation,
                      child: GestureDetector(
                        onTap: () {}, // Предотвращаем закрытие при тапе на контент
                        child: Container(
                          width: double.infinity,
                          margin: const EdgeInsets.only(top: 20),
                          constraints: BoxConstraints(
                            maxHeight: MediaQuery.of(context).size.height * 0.85,
                          ),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.black.withAlpha((0.8 * 255).round()),
                                Colors.black.withAlpha((0.9 * 255).round()),
                              ],
                            ),
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(30),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withAlpha((0.3 * 255).round()),
                                blurRadius: 20,
                                spreadRadius: 5,
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(30),
                            ),
                            child: BackdropFilter(
                              filter: ui.ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  _buildHeader(),
                                  _buildImageSection(),
                                  _buildQuoteSection(),
                                  _buildActionsSection(),
                                ],
                              ),
                            ),
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
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.white.withAlpha((0.1 * 255).round())),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withAlpha((0.1 * 255).round()),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.calendar_today,
              color: Colors.white70,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.dailyQuote.formattedDate,
                  style: GoogleFonts.merriweather(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                Text(
                  _getCategoryDisplayName(widget.dailyQuote.quote.category),
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white.withAlpha((0.7 * 255).round()),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close, color: Colors.white54),
          ),
        ],
      ),
    );
  }

  Widget _buildImageSection() {
    if (_isLoading || _imageUrl == null) {
      return Container(
        height: 160,
        decoration: BoxDecoration(
          color: Colors.black.withAlpha((0.3 * 255).round()),
        ),
        child: const Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
      );
    }

    return FadeTransition(
      opacity: _imageAnimation,
      child: Container(
        height: 160,
        width: double.infinity,
        child: CachedNetworkImage(
          imageUrl: _imageUrl!,
          cacheManager: CustomCache.instance,
          fit: BoxFit.cover,
          placeholder: (_, __) => Container(
            color: Colors.black.withAlpha((0.3 * 255).round()),
            child: const Center(
              child: CircularProgressIndicator(color: Colors.white),
            ),
          ),
          errorWidget: (_, __, ___) => Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.grey[800]!,
                  Colors.grey[900]!,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: const Center(
              child: Icon(
                Icons.image_not_supported,
                color: Colors.white38,
                size: 48,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildQuoteSection() {
    final quote = widget.dailyQuote.quote;
    
    return Expanded(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Цитата
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.black.withAlpha((0.2 * 255).round()),
                borderRadius: BorderRadius.circular(12),
                border: Border(
                  left: BorderSide(
                    color: Colors.white.withAlpha((0.8 * 255).round()),
                    width: 3,
                  ),
                ),
              ),
              child: Text(
                '"${quote.text}"',
                style: GoogleFonts.merriweather(
                  fontSize: 16,
                  fontStyle: FontStyle.italic,
                  color: Colors.white,
                  height: 1.5,
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Автор и источник
            Text(
              quote.author,
              style: GoogleFonts.merriweather(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              quote.source,
              style: TextStyle(
                fontSize: 14,
                fontStyle: FontStyle.italic,
                color: Colors.white.withAlpha((0.7 * 255).round()),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionsSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: Colors.white.withAlpha((0.1 * 255).round())),
        ),
      ),
      child: Column(
        children: [
          // Основные действия
          Row(
            children: [
              Expanded(
                child: _buildActionButton(
                  icon: _isFavorite ? Icons.favorite : Icons.favorite_border,
                  label: _isFavorite ? 'В избранном' : 'В избранное',
                  color: _isFavorite ? Colors.red : Colors.white,
                  onTap: _toggleFavorite,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildActionButton(
                  icon: Icons.share_outlined,
                  label: 'Поделиться',
                  color: Colors.white,
                  onTap: _shareQuote,
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 12),
          
          // Дополнительные действия
          Row(
            children: [
              Expanded(
                child: _buildActionButton(
                  icon: Icons.edit_note,
                  label: 'Заметка',
                  color: Colors.white,
                  onTap: _addNote,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildActionButton(
                  icon: Icons.library_books,
                  label: 'Контекст',
                  color: Colors.white,
                  onTap: _openContext,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.white.withAlpha((0.05 * 255).round()),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: color.withAlpha((0.3 * 255).round()),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 18),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _toggleFavorite() async {
    try {
      final favService = await FavoritesService.init();
      
      if (_isFavorite) {
        await favService.removeFromFavorites(widget.dailyQuote.quote.id);
      } else {
        await favService.addToFavorites(
          widget.dailyQuote.quote,
          imageUrl: _imageUrl,
        );
      }
      
      setState(() {
        _isFavorite = !_isFavorite;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isFavorite ? 'Добавлено в избранное' : 'Удалено из избранного'
          ),
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      print('Error toggling favorite: $e');
    }
  }

  void _shareQuote() {
    final quote = widget.dailyQuote.quote;
    Share.share(
      '"${quote.text}"\n— ${quote.author}\n\nИз приложения Sacral',
      subject: 'Цитата от ${quote.author}',
    );
  }

  void _addNote() {
    showNoteModal(
      context,
      widget.dailyQuote.quote,
      onSaved: () {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Заметка сохранена'),
            duration: Duration(seconds: 2),
          ),
        );
      },
    );
  }

  void _openContext() {
    Navigator.of(context).pop(); // Закрываем модалку
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            ContextPage(dailyQuote: widget.dailyQuote),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0.0, 1.0),
              end: Offset.zero,
            ).animate(CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
            )),
            child: FadeTransition(
              opacity: animation,
              child: child,
            ),
          );
        },
        transitionDuration: const Duration(milliseconds: 400),
      ),
    );
  }

  String _getCategoryDisplayName(String category) {
    switch (category) {
      case 'greece':
        return 'Греция';
      case 'nordic':
        return 'Север';
      case 'philosophy':
        return 'Философия';
      case 'pagan':
        return 'Язычество';
      default:
        return category;
    }
  }

  @override
  void dispose() {
    _animController.dispose();
    _imageController.dispose();
    super.dispose();
  }
}

// Вспомогательная функция для показа модалки
Future<void> showCalendarQuoteModal(BuildContext context, DailyQuote dailyQuote) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withAlpha((0.5 * 255).round()),
    builder: (context) => CalendarQuoteModal(dailyQuote: dailyQuote),
  );
}