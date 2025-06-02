// lib/ui/screens/library_page.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../models/book_source.dart';
import '../../services/text_file_service.dart';
import '../../services/image_picker_service.dart';
import '../../utils/custom_cache.dart';
import 'book_reader_page.dart';

class LibraryPage extends StatefulWidget {
  const LibraryPage({super.key});

  @override
  State<LibraryPage> createState() => _LibraryPageState();
}

class _LibraryPageState extends State<LibraryPage> with SingleTickerProviderStateMixin {
  final TextFileService _textService = TextFileService();
  late AnimationController _animController;
  late Animation<double> _fadeAnimation;
  
  List<BookSource> _books = [];
  List<BookSource> _filteredBooks = [];
  String _selectedCategory = 'all';
  bool _isLoading = true;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeIn,
    );
    _loadBooks();
  }

  Future<void> _loadBooks() async {
    try {
      final books = await _textService.loadBookSources();
      setState(() {
        _books = books;
        _filteredBooks = books;
        _isLoading = false;
      });
      _animController.forward();
    } catch (e) {
      print('Error loading books: $e');
      setState(() => _isLoading = false);
    }
  }

  void _filterBooks() {
    setState(() {
      _filteredBooks = _books.where((book) {
        final matchesCategory = _selectedCategory == 'all' || book.category == _selectedCategory;
        final matchesSearch = _searchQuery.isEmpty || 
            book.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
            book.author.toLowerCase().contains(_searchQuery.toLowerCase());
        return matchesCategory && matchesSearch;
      }).toList();
    });
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: Text(
          'Библиотека',
          style: GoogleFonts.merriweather(color: Colors.white),
        ),
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.white))
          : FadeTransition(
              opacity: _fadeAnimation,
              child: Column(
                children: [
                  // Поиск
                  Container(
                    margin: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey[900],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: TextField(
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'Поиск по названию или автору...',
                        hintStyle: TextStyle(color: Colors.white38),
                        prefixIcon: const Icon(Icons.search, color: Colors.white38),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      ),
                      onChanged: (value) {
                        _searchQuery = value;
                        _filterBooks();
                      },
                    ),
                  ),
                  
                  // Фильтр по категориям
                  SizedBox(
                    height: 50,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      children: [
                        _buildCategoryChip('all', 'Все'),
                        _buildCategoryChip('greece', 'Греция'),
                        _buildCategoryChip('nordic', 'Север'),
                        _buildCategoryChip('philosophy', 'Философия'),
                        _buildCategoryChip('pagan', 'Язычество'),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Список книг
                  Expanded(
                    child: _filteredBooks.isEmpty
                        ? Center(
                            child: Text(
                              'Книги не найдены',
                              style: TextStyle(color: Colors.white54),
                            ),
                          )
                        : GridView.builder(
                            padding: const EdgeInsets.all(16),
                            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              childAspectRatio: 0.65,
                              crossAxisSpacing: 16,
                              mainAxisSpacing: 16,
                            ),
                            itemCount: _filteredBooks.length,
                            itemBuilder: (context, index) => _buildBookCard(_filteredBooks[index]),
                          ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildCategoryChip(String category, String label) {
    final isSelected = _selectedCategory == category;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (selected) {
          setState(() {
            _selectedCategory = category;
            _filterBooks();
          });
        },
        backgroundColor: Colors.grey[900],
        selectedColor: Colors.white24,
        labelStyle: TextStyle(
          color: isSelected ? Colors.white : Colors.white70,
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
        ),
        side: BorderSide(
          color: isSelected ? Colors.white38 : Colors.white12,
        ),
      ),
    );
  }

  Widget _buildBookCard(BookSource book) {
    final imageUrl = ImagePickerService.getRandomImage(book.category);
    final readingProgress = _getReadingProgress(book.id);
    
    return GestureDetector(
      onTap: () => _openBook(book),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
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
                placeholder: (_, __) => Container(color: Colors.grey[900]),
                errorWidget: (_, __, ___) => Container(
                  color: Colors.grey[900],
                  child: const Icon(Icons.book, color: Colors.white24, size: 48),
                ),
              ),
              
              // Градиент
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.transparent,
                      Colors.black.withOpacity(0.8),
                    ],
                    begin: Alignment.center,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ),
              
              // Информация о книге
              Positioned(
                left: 12,
                right: 12,
                bottom: 12,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      book.title,
                      style: GoogleFonts.merriweather(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      book.author,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white70,
                      ),
                    ),
                    if (book.translator != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        'пер. ${book.translator}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white54,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                    if (readingProgress > 0) ...[
                      const SizedBox(height: 8),
                      LinearProgressIndicator(
                        value: readingProgress,
                        backgroundColor: Colors.white24,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white70),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${(readingProgress * 100).toInt()}% прочитано',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.white54,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              
              // Метка категории
              Positioned(
                top: 12,
                right: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _getCategoryColor(book.category),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _getCategoryLabel(book.category),
                    style: const TextStyle(
                      fontSize: 11,
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getCategoryColor(String category) {
    switch (category) {
      case 'greece':
        return Colors.blue[700]!;
      case 'nordic':
        return Colors.teal[700]!;
      case 'philosophy':
        return Colors.purple[700]!;
      case 'pagan':
        return Colors.deepOrange[700]!;
      default:
        return Colors.grey[700]!;
    }
  }

  String _getCategoryLabel(String category) {
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
        return 'Другое';
    }
  }

  double _getReadingProgress(String bookId) {
    // Получаем прогресс чтения из кэша
    final cache = CustomCache.prefs;
    return cache.getSetting<double>('reading_progress_$bookId') ?? 0.0;
  }

  void _openBook(BookSource book) {
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => 
            BookReaderPage(book: book),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(1, 0),
              end: Offset.zero,
            ).animate(CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
            )),
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 400),
      ),
    );
  }
}