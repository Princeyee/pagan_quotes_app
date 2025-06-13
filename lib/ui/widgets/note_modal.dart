// lib/ui/widgets/note_modal.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:ui';
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
  final ScrollController _scrollController = ScrollController();
  
  bool _isSaving = false;
  String? _existingNote;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      duration: const Duration(milliseconds: 350),
      vsync: this,
    );
    
    _scaleAnimation = Tween<double>(
      begin: 0.95,
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
      if (mounted) {
        _focusNode.requestFocus();
      }
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
      await cache.setSetting('note_${widget.quote.id}', null);
    } else {
      await cache.setSetting('note_${widget.quote.id}', noteText);
      
      final allNotes = cache.getSetting<List<dynamic>>('all_notes') ?? [];
      allNotes.removeWhere((n) => n['quoteId'] == widget.quote.id);
      
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
    
    // Добавляем вибрацию при сохранении
    HapticFeedback.mediumImpact();
    
    await _animController.reverse();
    if (mounted) Navigator.of(context).pop();
  }

  @override
  void dispose() {
    _animController.dispose();
    _noteController.dispose();
    _focusNode.dispose();
    _scrollController.dispose();
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
            color: Colors.black.withAlpha((0.5 * 255).round()),
            child: SafeArea(
              child: Align(
                alignment: Alignment.bottomCenter,
                child: GestureDetector(
                  onTap: () {}, // Предотвращаем закрытие при тапе на контент
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0, 1),
                      end: Offset.zero,
                    ).animate(CurvedAnimation(
                      parent: _animController,
                      curve: Curves.easeOutQuart,
                    )),
                    child: Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(top: 20),
                      constraints: BoxConstraints(
                        maxHeight: MediaQuery.of(context).size.height * 0.85,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withAlpha((0.7 * 255).round()),
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(20),
                          topRight: Radius.circular(20),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withAlpha((0.3 * 255).round()),
                            blurRadius: 20,
                            spreadRadius: 5,
                          ),
                        ],
                        border: Border.all(
                          color: Colors.white.withAlpha((0.1 * 255).round()),
                          width: 0.5,
                        ),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Индикатор для свайпа вниз
                          Container(
                            margin: const EdgeInsets.only(top: 12),
                            width: 40,
                            height: 4,
                            decoration: BoxDecoration(
                              color: Colors.white.withAlpha((0.3 * 255).round()),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          // Заголовок
                          Container(
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              border: Border(
                                bottom: BorderSide(
                                  color: Colors.white.withAlpha((0.1 * 255).round()),
                                ),
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
                                    Icons.edit_note,
                                    color: Colors.white70,
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    _existingNote != null ? 'Редактировать заметку' : 'Новая заметка',
                                    style: GoogleFonts.merriweather(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                                Container(
                                  decoration: BoxDecoration(
                                    color: Colors.white.withAlpha((0.1 * 255).round()),
                                    shape: BoxShape.circle,
                                  ),
                                  child: IconButton(
                                    onPressed: () => Navigator.of(context).pop(),
                                    icon: const Icon(Icons.close, color: Colors.white),
                                    iconSize: 20,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          
                          // Контент с возможностью скролла
                          Expanded(
                            child: SingleChildScrollView(
                              controller: _scrollController,
                              padding: const EdgeInsets.all(24),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Цитата
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withAlpha((0.3 * 255).round()),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: Colors.white.withAlpha((0.1 * 255).round()),
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
                                  
                                  // Динамически расширяющееся текстовое поле
                                  Container(
                                    width: double.infinity,
                                    constraints: const BoxConstraints(
                                      minHeight: 120,
                                      maxHeight: 300,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withAlpha((0.2 * 255).round()),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: Colors.white.withAlpha((0.2 * 255).round()),
                                      ),
                                    ),
                                    child: TextField(
                                      controller: _noteController,
                                      focusNode: _focusNode,
                                      maxLines: null,
                                      minLines: 6,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 16,
                                        height: 1.5,
                                      ),
                                      decoration: InputDecoration(
                                        hintText: 'Запишите свои размышления о этой цитате...',
                                        hintStyle: TextStyle(
                                          color: Colors.white.withAlpha((0.3 * 255).round()),
                                        ),
                                        border: InputBorder.none,
                                        contentPadding: const EdgeInsets.all(16),
                                      ),
                                      onChanged: (text) {
                                        // Автоматически скроллим вниз при добавлении текста
                                        Future.delayed(const Duration(milliseconds: 100), () {
                                          if (_scrollController.hasClients) {
                                            _scrollController.animateTo(
                                              _scrollController.position.maxScrollExtent,
                                              duration: const Duration(milliseconds: 300),
                                              curve: Curves.easeOut,
                                            );
                                          }
                                        });
                                      },
                                    ),
                                  ),
                                  
                                  // Дополнительное пространство для клавиатуры
                                  SizedBox(height: MediaQuery.of(context).viewInsets.bottom + 20),
                                ],
                              ),
                            ),
                          ),
                          
                          // Кнопки внизу
                          Container(
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              border: Border(
                                top: BorderSide(
                                  color: Colors.white.withAlpha((0.1 * 255).round()),
                                ),
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                TextButton(
                                  onPressed: () => Navigator.of(context).pop(),
                                  style: TextButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 20,
                                      vertical: 12,
                                    ),
                                  ),
                                  child: Text(
                                    'Отмена',
                                    style: TextStyle(
                                      color: Colors.white54,
                                      fontSize: 16,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                ElevatedButton(
                                  onPressed: _isSaving ? null : _saveNote,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.white,
                                    foregroundColor: Colors.black,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 32,
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
                                      : Text(
                                          'Сохранить',
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600,
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
              ),
            ),
          ),
        ),
      ),
      )
    );
  }
}

// Вспомогательная функция для показа модалки
Future<void> showNoteModal(BuildContext context, Quote quote, {VoidCallback? onSaved}) {
  return showDialog(
    context: context,
    barrierDismissible: true,
    barrierColor: Colors.transparent,
    useSafeArea: false,
    builder: (context) => NoteModal(
      quote: quote,
      onSaved: onSaved,
    ),
  );
}