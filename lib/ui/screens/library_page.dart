// lib/ui/screens/library_page.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../widgets/glass_background.dart';
import '../../models/book_source.dart';
import '../../services/text_file_service.dart';
import '../../services/book_image_service.dart';
import '../../utils/custom_cache.dart';
import '../../services/enhanced_audiobook_service.dart';
import '../../models/audiobook.dart';
import 'book_reader_page.dart';
import 'enhanced_audiobook_player.dart';
import 'package:flutter/rendering.dart';
import 'dart:ui';

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
  
  final Map<String, String> _bookImages = {};

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
      
      for (final book in books) {
        final imageUrl = await BookImageService.getStableBookImage(book.id, book.category);
        _bookImages[book.id] = imageUrl;
      }
      
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
                    child: _isLoading
                      ? const Center(child: CircularProgressIndicator(color: Colors.white))
                      : _buildLibraryContent(),
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

  Widget _buildLibraryContent() {
    return FadeTransition(
                    opacity: _fadeAnimation,
                    child: Column(
                      children: [
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
                              _buildCategoryChip('pagan', 'Язычество & традиционализм'),
                            ],
                          ),
                        ),
                        
                        const SizedBox(height: 16),
                        
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
    final imageUrl = _bookImages[book.id] ?? '';
    final readingProgress = _getReadingProgress(book.id);
    
    return GestureDetector(
      onTap: () => _openBook(book),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha((0.3 * 255).round()),
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
              if (imageUrl.isNotEmpty)
                CachedNetworkImage(
                  imageUrl: imageUrl,
                  cacheManager: CustomCache.instance,
                  fit: BoxFit.cover,
                  placeholder: (_, __) => Container(
                    color: Colors.grey[900],
                    child: Center(
                      child: CircularProgressIndicator(
                        color: _getCategoryColor(book.category),
                        strokeWidth: 2,
                      ),
                    ),
                  ),
                  errorWidget: (_, __, ___) => Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          _getCategoryColor(book.category).withAlpha((0.3 * 255).round()),
                          Colors.grey[900]!,
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: const Icon(Icons.book, color: Colors.white24, size: 48),
                  ),
                ),
              
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.transparent,
                      Colors.black.withAlpha((0.8 * 255).round()),
                    ],
                    begin: Alignment.center,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ),
              
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
              
              Positioned(
                top: 12,
                right: 12,
                child: Container(
                  constraints: BoxConstraints(
                    maxWidth: 90, // Ограничиваем ширину, чтобы текст переносился
                  ),
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
                      height: 1.2, // Немного уменьшаем межстрочный интервал
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 2, // Разрешаем две строки
                    overflow: TextOverflow.fade, // Плавное затухание если всё же не поместится
                  ),
                ),
              ),
              
              // Значок аудиоверсии
              if (book.hasAudioVersion)
                Positioned(
                  top: 12,
                  left: 12,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.black.withAlpha((0.7 * 255).round()),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: Colors.white.withAlpha((0.3 * 255).round()),
                        width: 1,
                      ),
                    ),
                    child: const Icon(
                      Icons.headphones,
                      color: Colors.white,
                      size: 16,
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
        return 'Язычество &\nТрадиционализм'; // Принудительный перенос строки
      default:
        return 'Другое';
    }
  }

  double _getReadingProgress(String bookId) {
    final cache = CustomCache.prefs;
    return cache.getSetting<double>('reading_progress_$bookId') ?? 0.0;
  }

  void _openBook(BookSource book) async {
    if (book.hasAudioVersion) {
      // Показываем диалог выбора между текстом и аудио
      final choice = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: Colors.grey[900],
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(
            'Выберите формат',
            style: GoogleFonts.merriweather(color: Colors.white),
          ),
          content: Text(
            'Эта книга доступна в текстовом и аудио формате',
            style: TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop('text'),
              child: Text('Читать текст', style: TextStyle(color: Colors.white70)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.black,
              ),
              onPressed: () => Navigator.of(context).pop('audio'),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.headphones, size: 16),
                  SizedBox(width: 6),
                  Text('Слушать аудио'),
                ],
              ),
            ),
          ],
        ),
      );
      
      if (choice == 'audio') {
        _openAudioVersion(book);
        return;
      } else if (choice == null) {
        // Пользователь отменил диалог
        return;
      }
      // Если выбран текст или диалог отменен, продолжаем с открытием текста
    }
    
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
  
  void _openAudioVersion(BookSource book) async {
    try {
      // Показываем индикатор загрузки
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => Center(
          child: Container(
            padding: EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.black87,
              borderRadius: BorderRadius.circular(10),
            ),
            child: CircularProgressIndicator(color: Colors.white),
          ),
        ),
      );

      final audiobookService = EnhancedAudiobookService();
      final audiobooks = await audiobookService.getAudiobooks();
      
      // Закрываем индикатор загрузки
      Navigator.of(context).pop();
      
      // Маппинг ID текстовых книг к названиям папок аудиокниг
      final Map<String, List<String>> bookToAudioFolders = {
        'aristotle_metaphysics': ['аристотель метафизика', 'метафизика'],
        'aristotle_ethics': ['аристотель этика', 'этика'],
        'aristotle_politics': ['аристотель политика', 'политика'],
        'aristotle_rhetoric': ['аристотель риторика', 'риторика'],
        'plato_sophist': ['платон софист', 'софист'],
        'plato_parmenides': ['платон парменид', 'парменид'],
        'homer_iliad': ['гомер илиада', 'илиада'],
        'homer_odyssey': ['гомер одиссея', 'одиссея'],
        'hesiod_labour': ['гесиод труды', 'труды и дни'],
        'beowulf': ['беовульф'],
        'elder_edda': ['старшая эдда', 'эдда'],
        'heidegger_being': ['хайдеггер бытие', 'бытие и время'],
        'heidegger_think': ['хайдеггер мыслить', 'что значит мыслить'],
        'nietzsche_antichrist': ['ницше антихрист', 'антихрист'],
        'nietzsche_gay_science': ['ницше веселая', 'веселая наука'],
        'nietzsche_zarathustra': ['ницше заратустра', 'заратустра'],
        'nietzsche_tragedy': ['ницше трагедия', 'рождение трагедии'],
        'nietzsche_beyond': ['ницше добро зло', 'по ту сторону'],
        'schopenhauer_world': ['шопенгауэр мир', 'мир как воля'],
        'schopenhauer_aphorisms': ['шопенгауэр афоризмы', 'афоризмы'],
        'on_being_a_pagan': ['де бенуа язычник', 'как можно быть язычником'],
        'eliade_sacred': ['элиаде священное', 'священное и мирское'],
        'eliade_myth': ['элиаде миф', 'миф о вечном возвращении'],
        'evola_imperialism': ['эвола империализм', 'языческий империализм'],
        'evola_sex': ['эвола пол', 'метафизика пола'],
        'evola_ruins': ['эвола руины', 'люди и руины'],
        'askr_svarte_pagan_identity': ['аскр идентичность', 'идентичность язычника'],
        'askr_svarte_priblizhenie': ['аскр приближение', 'приближение и окружение'],
        'askr_svarte_polemos': ['аскр полемос', 'polemos'],
      };
      
      // Ищем аудиокнигу по маппингу
      Audiobook? matchedAudiobook;
      final possibleAudioFolders = bookToAudioFolders[book.id];
      
      if (possibleAudioFolders != null) {
        for (final audiobook in audiobooks) {
          final audiobookTitle = audiobook.title.toLowerCase();
          
          // Проверяем совпадение с возможными названиями папок
          for (final folderName in possibleAudioFolders) {
            if (audiobookTitle.contains(folderName.toLowerCase()) ||
                folderName.toLowerCase().contains(audiobookTitle)) {
              matchedAudiobook = audiobook;
              break;
            }
          }
          
          if (matchedAudiobook != null) break;
        }
      }
      
      // Если не нашли по маппингу, пробуем общий поиск
      if (matchedAudiobook == null) {
        for (final audiobook in audiobooks) {
          // Проверяем точное совпадение названия
          if (audiobook.title.toLowerCase().trim() == book.title.toLowerCase().trim()) {
            matchedAudiobook = audiobook;
            break;
          }
          
          // Проверяем частичное совпадение названия
          if (audiobook.title.toLowerCase().contains(book.title.toLowerCase()) ||
              book.title.toLowerCase().contains(audiobook.title.toLowerCase())) {
            matchedAudiobook = audiobook;
            break;
          }
          
          // Проверяем совпадение по автору
          if (audiobook.title.toLowerCase().contains(book.author.toLowerCase()) ||
              book.author.toLowerCase().contains(audiobook.title.toLowerCase())) {
            matchedAudiobook = audiobook;
            break;
          }
        }
      }
      
      if (matchedAudiobook != null) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => EnhancedAudiobookPlayer(audiobook: matchedAudiobook!),
          ),
        );
      } else {
        // Если точного совпадения нет, показываем список доступных аудиокниг
        _showAudiobookSelectionDialog(audiobooks);
      }
    } catch (e) {
      // Закрываем индикатор загрузки если он еще открыт
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Ошибка при загрузке аудиокниг: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showAudiobookSelectionDialog(List<Audiobook> audiobooks) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Выберите аудиокнигу',
          style: GoogleFonts.merriweather(color: Colors.white),
        ),
        content: Container(
          width: double.maxFinite,
          height: 300,
          child: audiobooks.isEmpty
              ? Center(
                  child: Text(
                    'Аудиокниги не найдены',
                    style: TextStyle(color: Colors.white70),
                  ),
                )
              : ListView.builder(
                  itemCount: audiobooks.length,
                  itemBuilder: (context, index) {
                    final audiobook = audiobooks[index];
                    return ListTile(
                      leading: Icon(Icons.audiotrack, color: Colors.white),
                      title: Text(
                        audiobook.title,
                        style: TextStyle(color: Colors.white),
                      ),
                      subtitle: Text(
                        '${audiobook.chapters.length} ${_getChapterText(audiobook.chapters.length)}',
                        style: TextStyle(color: Colors.white70),
                      ),
                      onTap: () {
                        Navigator.of(context).pop();
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => EnhancedAudiobookPlayer(audiobook: audiobook),
                          ),
                        );
                      },
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Отмена', style: TextStyle(color: Colors.white70)),
          ),
        ],
      ),
    );
  }

  String _getChapterText(int count) {
    if (count % 10 == 1 && count % 100 != 11) {
      return 'глава';
    } else if (count % 10 >= 2 && count % 10 <= 4 && (count % 100 < 12 || count % 100 > 14)) {
      return 'главы';
    } else {
      return 'глав';
    }
  }
}