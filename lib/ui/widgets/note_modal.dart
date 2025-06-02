// lib/ui/widgets/note_modal.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/quote.dart';
import '../../utils/custom_cache.dart';

class NoteModal extends StatefulWidget {
  final Quote quote;
  final VoidCallback? onSaved;

  const NoteModal({
    super.key,
    required this.quote,
    this.onSaved,
  });

  @override
  State<NoteModal> createState() => _NoteModalState();
}

class _NoteModalState extends State<NoteModal> with SingleTickerProviderStateMixin {
  late final AnimationController _animController;
  late final Animation<double> _scaleAnimation;
  late final Animation<double> _fadeAnimation;
  
  final TextEditingController _noteController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  bool _isSaving = false;
  String? _existingNote;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    
    _scaleAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutBack,
    ));
    
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animController,
      curve: Curves.easeIn,
    ));
    
    _animController.forward();
    _loadExistingNote();
    
    // Автоматически показываем клавиатуру
    Future.delayed(const Duration(milliseconds: 400), () {
      _focusNode.requestFocus();
    });
  }

  Future<void> _loadExistingNote() async {
    final cache = CustomCache.prefs;
    final note = cache.getSetting<String>('note_${widget.quote.id}');
    if (note != null) {
      setState(() {
        _existingNote = note;
        _noteController.text = note;
      });
    }
  }

  Future<void> _saveNote() async {
    if (_isSaving) return;
    
    setState(() => _isSaving = true);
    
    final noteText = _noteController.text.trim();
    final cache = CustomCache.prefs;
    
    if (noteText.isEmpty) {
      // Удаляем заметку если пустая
      await cache.setSetting('note_${widget.quote.id}', null);
    } else {
      // Сохраняем заметку
      await cache.setSetting('note_${widget.quote.id}', noteText);
      
      // Сохраняем в список всех заметок для страницы заметок
      final allNotes = cache.getSetting<List<dynamic>>('all_notes') ?? [];
      
      // Удаляем старую версию если есть
      allNotes.removeWhere((n) => n['quoteId'] == widget.quote.id);
      
      // Добавляем новую
      allNotes.add({
        'quoteId': widget.quote.id,
        'quoteText': widget.quote.text,
        'quoteAuthor': widget.quote.author,
        'note': noteText,
        'createdAt': DateTime.now().toIso8601String(),
      });
      
      await cache.setSetting('all_notes', allNotes);
    }
    
    setState(() => _isSaving = false);
    
    widget.onSaved?.call();
    
    // Закрываем модалку с анимацией
    await _animController.reverse();
    if (mounted) Navigator.of(context).pop();
  }

  @override
  void dispose() {
    _animController.dispose();
    _noteController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.of(context).pop(),
      child: Material(
        color: Colors.transparent,
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Container(
            color: Colors.black.withOpacity(0.7),
            child: Center(
              child: GestureDetector(
                onTap: () {}, // Предотвращаем закрытие при тапе на контент
                child: ScaleTransition(
                  scale: _scaleAnimation,
                  child: Container(
                    margin: const EdgeInsets.all(24),
                    padding: const EdgeInsets.all(24),
                    constraints: const BoxConstraints(
                      maxWidth: 500,
                      maxHeight: 600,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.grey[900],
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.3),
                          blurRadius: 20,
                          spreadRadius: 5,
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Заголовок
                        Row(
                          children: [
                            Icon(
                              Icons.edit_note,
                              color: Colors.white70,
                              size: 28,
                            ),
                            const SizedBox(width: 12),
                            Text(
                              _existingNote != null ? 'Редактировать заметку' : 'Новая заметка',
                              style: GoogleFonts.merriweather(
                                fontSize: 20,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                            const Spacer(),
                            IconButton(
                              onPressed: () => Navigator.of(context).pop(),
                              icon: const Icon(Icons.close, color: Colors.white54),
                            ),
                          ],
                        ),
                        
                        const SizedBox(height: 20),
                        
                        // Цитата
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.3),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.1),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '"${widget.quote.text}"',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontStyle: FontStyle.italic,
                                  color: Colors.white70,
                                  height: 1.5,
                                ),
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '— ${widget.quote.author}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.white54,
                                ),
                              ),
                            ],
                          ),
                        ),
                        
                        const SizedBox(height: 24),
                        
                        // Поле ввода заметки
                        Text(
                          'Ваши мысли:',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.white70,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 12),
                        
                        Flexible(
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.2),
                              ),
                            ),
                            child: TextField(
                              controller: _noteController,
                              focusNode: _focusNode,
                              maxLines: null,
                              minLines: 5,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                height: 1.5,
                              ),
                              decoration: InputDecoration(
                                hintText: 'Запишите свои размышления о этой цитате...',
                                hintStyle: TextStyle(
                                  color: Colors.white.withOpacity(0.3),
                                ),
                                border: InputBorder.none,
                                contentPadding: const EdgeInsets.all(16),
                              ),
                            ),
                          ),
                        ),
                        
                        const SizedBox(height: 24),
                        
                        // Кнопки
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton(
                              onPressed: () => Navigator.of(context).pop(),
                              child: Text(
                                'Отмена',
                                style: TextStyle(color: Colors.white54),
                              ),
                            ),
                            const SizedBox(width: 16),
                            ElevatedButton(
                              onPressed: _isSaving ? null : _saveNote,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: Colors.black,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 24,
                                  vertical: 12,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(30),
                                ),
                              ),
                              child: _isSaving
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
                                      ),
                                    )
                                  : const Text('Сохранить'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// Вспомогательная функция для показа модалки
Future<void> showNoteModal(BuildContext context, Quote quote, {VoidCallback? onSaved}) {
  return showDialog(
    context: context,
    barrierDismissible: true,
    barrierColor: Colors.transparent,
    builder: (context) => NoteModal(
      quote: quote,
      onSaved: onSaved,
    ),
  );
}