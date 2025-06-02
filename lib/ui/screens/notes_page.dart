
// lib/ui/screens/notes_page.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../utils/custom_cache.dart';
import '../widgets/note_modal.dart';
import '../../models/quote.dart';

class NotesPage extends StatefulWidget {
  const NotesPage({super.key});

  @override
  State<NotesPage> createState() => _NotesPageState();
}

class _NotesPageState extends State<NotesPage> with TickerProviderStateMixin {
  final CustomCachePrefs _cache = CustomCache.prefs;
  List<Map<String, dynamic>> _notes = [];
  List<Map<String, dynamic>> _filteredNotes = [];
  bool _isLoading = true;
  String _searchQuery = '';
  String _sortBy = 'date_desc';
  
  late AnimationController _animController;
  late Animation<double> _fadeAnimation;

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
    _loadNotes();
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);
    
    if (difference.inDays == 0) {
      if (difference.inHours == 0) {
        if (difference.inMinutes == 0) {
          return 'Только что';
        }
        return '${difference.inMinutes} мин. назад';
      }
      return '${difference.inHours} ч. назад';
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

  Future<void> _loadNotes() async {
    setState(() => _isLoading = true);
    
    try {
      final allNotes = _cache.getSetting<List<dynamic>>('all_notes') ?? [];
      _notes = allNotes.cast<Map<String, dynamic>>();
      _filterAndSortNotes();
      setState(() => _isLoading = false);
      _animController.forward();
    } catch (e) {
      print('Error loading notes: $e');
      setState(() => _isLoading = false);
    }
  }

  void _filterAndSortNotes() {
    // Фильтрация
    _filteredNotes = _notes.where((note) {
      if (_searchQuery.isEmpty) return true;
      
      final query = _searchQuery.toLowerCase();
      final noteText = (note['note'] as String).toLowerCase();
      final quoteText = (note['quoteText'] as String).toLowerCase();
      final author = (note['quoteAuthor'] as String).toLowerCase();
      
      return noteText.contains(query) || 
             quoteText.contains(query) || 
             author.contains(query);
    }).toList();
    
    // Сортировка
    switch (_sortBy) {
      case 'date_desc':
        _filteredNotes.sort((a, b) => 
          DateTime.parse(b['createdAt']).compareTo(DateTime.parse(a['createdAt'])));
        break;
      case 'date_asc':
        _filteredNotes.sort((a, b) => 
          DateTime.parse(a['createdAt']).compareTo(DateTime.parse(b['createdAt'])));
        break;
      case 'author':
        _filteredNotes.sort((a, b) => 
          (a['quoteAuthor'] as String).compareTo(b['quoteAuthor'] as String));
        break;
    }
  }

  Future<void> _deleteNote(String quoteId) async {
    final notes = _cache.getSetting<List<dynamic>>('all_notes') ?? [];
    notes.removeWhere((n) => n['quoteId'] == quoteId);
    await _cache.setSetting('all_notes', notes);
    await _cache.setSetting('note_$quoteId', null);
    _loadNotes();
  }

  void _editNote(Map<String, dynamic> noteData) {
    final quote = Quote(
      id: noteData['quoteId'],
      text: noteData['quoteText'],
      author: noteData['quoteAuthor'],
      source: '', // Не сохраняем в заметках
      category: '',
      position: 0,
      theme: '',
    );
    
    showNoteModal(
      context,
      quote,
      onSaved: () {
        _loadNotes();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(


content: Text('Заметка обновлена'),
            duration: Duration(seconds: 2),
          ),
        );
      },
    );
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
          'Мои заметки',
          style: GoogleFonts.merriweather(color: Colors.white),
        ),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.sort, color: Colors.white),
            onSelected: (value) {
              setState(() {
                _sortBy = value;
                _filterAndSortNotes();
              });
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'date_desc',
                child: Text('Сначала новые'),
              ),
              const PopupMenuItem(
                value: 'date_asc',
                child: Text('Сначала старые'),
              ),
              const PopupMenuItem(
                value: 'author',
                child: Text('По автору'),
              ),
            ],
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.white))
          : Column(
              children: [
                // Поиск
                if (_notes.isNotEmpty)
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
                        hintText: 'Поиск по заметкам...',
                        hintStyle: TextStyle(color: Colors.white38),
                        prefixIcon: const Icon(Icons.search, color: Colors.white38),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      ),
                      onChanged: (value) {
                        setState(() {
                          _searchQuery = value;
                          _filterAndSortNotes();
                        });
                      },
                    ),
                  ),
                
                // Список заметок
                Expanded(
                  child: _notes.isEmpty
                      ? _buildEmptyState()
                      : _filteredNotes.isEmpty
                          ? _buildNoResultsState()
                          : FadeTransition(
                              opacity: _fadeAnimation,
                              child: ListView.builder(
                                padding: const EdgeInsets.only(bottom: 16),
                                itemCount: _filteredNotes.length,
                                itemBuilder: (context, index) => 
                                  _buildNoteCard(_filteredNotes[index]),
                              ),
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
            Icons.note_alt_outlined,
            size: 64,
            color: Colors.white.withOpacity(0.3),
          ),
          const SizedBox(height: 16),
          Text(
            'Нет сохраненных заметок',
            style: GoogleFonts.merriweather(
              fontSize: 20,
              color: Colors.white.withOpacity(0.5),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Долгое нажатие на цитату создаст заметку',


style: TextStyle(
              fontSize: 16,
              color: Colors.white.withOpacity(0.3),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoResultsState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search_off,
            size: 64,
            color: Colors.white.withOpacity(0.3),
          ),
          const SizedBox(height: 16),
          Text(
            'Ничего не найдено',
            style: GoogleFonts.merriweather(
              fontSize: 20,
              color: Colors.white.withOpacity(0.5),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Попробуйте изменить поисковый запрос',
            style: TextStyle(
              fontSize: 16,
              color: Colors.white.withOpacity(0.3),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoteCard(Map<String, dynamic> noteData) {
    final createdAt = DateTime.parse(noteData['createdAt']);
    final formattedDate = _formatDate(createdAt);
    
    return Dismissible(
      key: Key(noteData['quoteId']),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        child: const Icon(
          Icons.delete,
          color: Colors.redAccent,
          size: 28,
        ),
      ),
      confirmDismiss: (direction) async {
        return await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: Colors.grey[900],
            title: const Text(
              'Удалить заметку?',
              style: TextStyle(color: Colors.white),
            ),
            content: const Text(
              'Это действие нельзя отменить',
              style: TextStyle(color: Colors.white70),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Отмена'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text(
                  'Удалить',
                  style: TextStyle(color: Colors.redAccent),
                ),
              ),
            ],
          ),
        );
      },
      onDismissed: (_) => _deleteNote(noteData['quoteId']),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.grey[900],
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white12),
        ),
        child: InkWell(
          onTap: () => _editNote(noteData),
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Заголовок с датой
                Row(
                  children: [
                    Icon(
                      Icons.edit_note,
                      size: 16,
                      color: Colors.white54,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      formattedDate,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white54,
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 12),
                
                // Заметка
                Text(
                  noteData['note'],
                  style: const TextStyle(
                    fontSize: 16,
                    color: Colors.white,
                    height: 1.5,
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,


),
                
                const SizedBox(height: 16),
                
                // Цитата
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.1),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '"${noteData['quoteText']}"',
                        style: TextStyle(
                          fontSize: 14,
                          fontStyle: FontStyle.italic,
                          color: Colors.white70,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '— ${noteData['quoteAuthor']}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white54,
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
  }
}
