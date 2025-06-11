 
// lib/ui/widgets/holiday_info_modal.dart - НОВАЯ СВОРАЧИВАЮЩАЯСЯ ВЕРСИЯ
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:ui' as ui;
import '../../models/pagan_holiday.dart';

class HolidayInfoModal extends StatefulWidget {
  final PaganHoliday holiday;

  const HolidayInfoModal({
    super.key,
    required this.holiday,
  });

  @override
  State<HolidayInfoModal> createState() => _HolidayInfoModalState();
}

class _HolidayInfoModalState extends State<HolidayInfoModal>
    with TickerProviderStateMixin {
  
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  
  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    );
    
    _fadeController.forward();
  }

  @override
  Widget build(BuildContext context) {
    final traditionColor = Color(int.parse(widget.holiday.traditionColor.replaceFirst('#', '0xFF')));
    
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Material(
        color: Colors.transparent,
        child: Stack(
          children: [
            // Темный фон
            GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              child: Container(
                color: Colors.black.withOpacity(0.7),
              ),
            ),
            
            // Сворачивающееся окно
            DraggableScrollableSheet(
              initialChildSize: 0.8, // Начальный размер (80% экрана)
              minChildSize: 0.1,     // Минимальный размер (10% экрана - только заголовок)
              maxChildSize: 0.95,    // Максимальный размер (95% экрана)
              builder: (context, scrollController) {
                return Container(
                  decoration: BoxDecoration(
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(25),
                      topRight: Radius.circular(25),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.3),
                        blurRadius: 30,
                        spreadRadius: 0,
                        offset: const Offset(0, -10),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(25),
                      topRight: Radius.circular(25),
                    ),
                    child: BackdropFilter(
                      filter: ui.ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              // Красивый градиент с цветом традиции
                              traditionColor.withOpacity(0.2),
                              traditionColor.withOpacity(0.1),
                              Colors.grey[900]!.withOpacity(0.95),
                              Colors.black.withOpacity(0.98),
                            ],
                            stops: const [0.0, 0.3, 0.7, 1.0],
                          ),
                          // Дополнительное стеклянное покрытие
                          border: Border.all(
                            color: Colors.white.withOpacity(0.1),
                            width: 1,
                          ),
                        ),
                        child: Column(
                          children: [
                            // Красивый заголовок с эффектами
                            _buildEnhancedHeader(traditionColor),
                            
                            // Содержимое
                            Expanded(
                              child: _buildScrollableContent(scrollController, traditionColor),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEnhancedHeader(Color traditionColor) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            traditionColor.withOpacity(0.3),
            traditionColor.withOpacity(0.15),
            traditionColor.withOpacity(0.05),
          ],
        ),
        // Добавляем красивую границу снизу
        border: Border(
          bottom: BorderSide(
            color: traditionColor.withOpacity(0.3),
            width: 1,
          ),
        ),
        // Дополнительное свечение
        boxShadow: [
          BoxShadow(
            color: traditionColor.withOpacity(0.2),
            blurRadius: 15,
            spreadRadius: 0,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          // Индикатор для свайпа
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.4),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          
          // Основной контент заголовка
          Row(
            children: [
              // Красивая иконка с эффектами
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    colors: [
                      traditionColor.withOpacity(0.4),
                      traditionColor.withOpacity(0.2),
                      traditionColor.withOpacity(0.1),
                    ],
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: traditionColor.withOpacity(0.3),
                      blurRadius: 10,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Center(
                  child: _getHolidayIcon(
                    widget.holiday.type, 
                    traditionColor.withOpacity(0.9)
                  ),
                ),
              ),
              
              const SizedBox(width: 16),
              
              // Текстовая информация
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Название с градиентным текстом
                    ShaderMask(
                      shaderCallback: (bounds) => LinearGradient(
                        colors: [
                          Colors.white,
                          traditionColor.withOpacity(0.8),
                        ],
                      ).createShader(bounds),
                      child: Text(
                        widget.holiday.name,
                        style: GoogleFonts.merriweather(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    
                    const SizedBox(height: 4),
                    
                    // Традиция с красивым фоном
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            traditionColor.withOpacity(0.3),
                            traditionColor.withOpacity(0.1),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: traditionColor.withOpacity(0.4),
                          width: 1,
                        ),
                      ),
                      child: Text(
                        _getTraditionDisplayName(widget.holiday.tradition),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Colors.white.withOpacity(0.9),
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              
              // Кнопка закрытия с эффектом
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withOpacity(0.2),
                    width: 1,
                  ),
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(18),
                    onTap: () => Navigator.of(context).pop(),
                    child: Icon(
                      Icons.close,
                      color: Colors.white.withOpacity(0.8),
                      size: 20,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildScrollableContent(ScrollController scrollController, Color traditionColor) {
    return SingleChildScrollView(
      controller: scrollController,
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Дата празднования
          _buildInfoCard(
            'Дата празднования',
            '${widget.holiday.date.day} ${_getMonthName(widget.holiday.date.month)}',
            traditionColor,
            Icons.calendar_today,
          ),
          
          const SizedBox(height: 16),
          
          // Описание
          _buildInfoCard(
            'Описание',
            widget.holiday.description,
            traditionColor,
            Icons.description,
          ),
          
          // Расширенное описание
          if (widget.holiday.longDescription != null) ...[
            const SizedBox(height: 16),
            _buildLongDescriptionCard(widget.holiday.longDescription!, traditionColor),
          ],
          
          const SizedBox(height: 16),
          
          // Происхождение
          _buildInfoCard(
            'Происхождение',
            _getSimpleDescription(widget.holiday.authenticity),
            Colors.grey,
            Icons.info_outline,
          ),
          
          const SizedBox(height: 16),
          
          // Традиции празднования
          if (widget.holiday.traditions.isNotEmpty)
            _buildListCard(
              'Традиции празднования',
              widget.holiday.traditions,
              traditionColor,
              Icons.celebration,
            ),
          
          const SizedBox(height: 16),
          
          // Символы
          if (widget.holiday.symbols.isNotEmpty)
            _buildListCard(
              'Символы',
              widget.holiday.symbols,
              traditionColor,
              Icons.auto_awesome,
            ),
          
          const SizedBox(height: 16),
          
          // Тип праздника
          _buildInfoCard(
            'Тип праздника',
            _getHolidayTypeDisplayName(widget.holiday.type),
            traditionColor,
            Icons.category,
          ),
          
          // Источники
          if (widget.holiday.sources.isNotEmpty) ...[
            const SizedBox(height: 16),
            _buildSourcesCard(widget.holiday.sources),
          ],
          
          const SizedBox(height: 16),
          
          // Кнопка поделиться
          _buildShareButton(traditionColor),
          
          const SizedBox(height: 32), // Дополнительный отступ снизу
        ],
      ),
    );
  }

  Widget _buildInfoCard(String title, String content, Color color, IconData icon) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            color.withOpacity(0.08),
            color.withOpacity(0.04),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: color.withOpacity(0.2),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                icon,
                size: 16,
                color: color.withOpacity(0.8),
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: color.withOpacity(0.9),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            content,
            style: TextStyle(
              fontSize: 15,
              color: Colors.white.withOpacity(0.9),
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLongDescriptionCard(String content, Color traditionColor) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            traditionColor.withOpacity(0.1),
            traditionColor.withOpacity(0.05),
            Colors.black.withOpacity(0.3),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: traditionColor.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Text(
        content,
        style: TextStyle(
          fontSize: 15,
          color: Colors.white.withOpacity(0.9),
          height: 1.6,
          fontStyle: FontStyle.italic,
        ),
      ),
    );
  }

  Widget _buildListCard(String title, List<String> items, Color color, IconData icon) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            color.withOpacity(0.08),
            color.withOpacity(0.04),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: color.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                icon,
                size: 16,
                color: color.withOpacity(0.8),
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: color.withOpacity(0.9),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...items.map((item) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 4,
                  height: 4,
                  margin: const EdgeInsets.only(top: 8, right: 12),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.7),
                    shape: BoxShape.circle,
                  ),
                ),
                Expanded(
                  child: Text(
                    item,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white.withOpacity(0.8),
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          )).toList(),
        ],
      ),
    );
  }

  Widget _buildSourcesCard(List<String> sources) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.3),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withOpacity(0.1),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.library_books,
                size: 16,
                color: Colors.white.withOpacity(0.7),
              ),
              const SizedBox(width: 8),
              Text(
                'Источники',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.white.withOpacity(0.9),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...sources.map((source) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 4,
                  height: 4,
                  margin: const EdgeInsets.only(top: 8, right: 12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.5),
                    shape: BoxShape.circle,
                  ),
                ),
                Expanded(
                  child: Text(
                    source,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.white.withOpacity(0.8),
                      height: 1.4,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              ],
            ),
          )).toList(),
        ],
      ),
    );
  }

  Widget _buildShareButton(Color traditionColor) {
    return Container(
      width: double.infinity,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _shareHoliday,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  traditionColor.withOpacity(0.2),
                  traditionColor.withOpacity(0.1),
                ],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: traditionColor.withOpacity(0.3),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.share,
                  color: Colors.white.withOpacity(0.9),
                  size: 20,
                ),
                const SizedBox(width: 12),
                Text(
                  'Поделиться',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ПРОСТЫЕ МЕТОДЫ БЕЗ ЯРКИХ ЦВЕТОВ
  String _getSimpleDescription(HistoricalAuthenticity authenticity) {
    switch (authenticity) {
      case HistoricalAuthenticity.authentic:
        return 'Подтверждён историческими источниками';
      case HistoricalAuthenticity.likely:
        return 'Основан на исторических данных';
      case HistoricalAuthenticity.reconstructed:
        return 'Восстановлен по фольклорным данным';
      case HistoricalAuthenticity.modern:
        return 'Создан в новое время';
    }
  }

  Widget _getHolidayIcon(PaganHolidayType type, Color color) {
    IconData iconData;
    switch (type) {
      case PaganHolidayType.seasonal:
        iconData = Icons.brightness_7;
        break;
      case PaganHolidayType.lunar:
        iconData = Icons.nightlight_round;
        break;
      case PaganHolidayType.harvest:
        iconData = Icons.grain;
        break;
      case PaganHolidayType.ancestor:
        iconData = Icons.family_restroom;
        break;
      case PaganHolidayType.deity:
        iconData = Icons.auto_awesome;
        break;
      case PaganHolidayType.fire:
        iconData = Icons.whatshot;
        break;
      case PaganHolidayType.water:
        iconData = Icons.waves;
        break;
      case PaganHolidayType.nature:
        iconData = Icons.park;
        break;
      case PaganHolidayType.protection:
        iconData = Icons.security;
        break;
      case PaganHolidayType.fertility:
        iconData = Icons.spa;
        break;
      default:
        iconData = Icons.auto_awesome;
    }

    return Icon(
      iconData,
      color: color,
      size: 24,
    );
  }

  void _shareHoliday() {
    final holiday = widget.holiday;
    final shareText = '''
${holiday.name} (${holiday.nameOriginal})
${_getTraditionDisplayName(holiday.tradition)}

${holiday.description}

Дата: ${holiday.date.day} ${_getMonthName(holiday.date.month)}
Происхождение: ${_getSimpleDescription(holiday.authenticity)}

Из приложения Sacral
''';

    Share.share(shareText, subject: holiday.name);
  }

  String _getTraditionDisplayName(String tradition) {
    switch (tradition.toLowerCase()) {
      case 'nordic':
      case 'scandinavian':
        return 'Северная традиция';
      case 'slavic':
        return 'Славянская традиция';
      case 'celtic':
        return 'Кельтская традиция';
      case 'germanic':
        return 'Германская традиция';
      case 'roman':
        return 'Римская традиция';
      case 'greek':
        return 'Греческая традиция';
      case 'baltic':
        return 'Балтийская традиция';
      case 'finnish':
      case 'finno-ugric':
        return 'Финно-угорская традиция';
      default:
        return tradition;
    }
  }

  String _getHolidayTypeDisplayName(PaganHolidayType type) {
    switch (type) {
      case PaganHolidayType.seasonal:
        return 'Сезонный праздник';
      case PaganHolidayType.lunar:
        return 'Лунный праздник';
      case PaganHolidayType.harvest:
        return 'Праздник урожая';
      case PaganHolidayType.ancestor:
        return 'Почитание предков';
      case PaganHolidayType.deity:
        return 'Божественный праздник';
      case PaganHolidayType.fire:
        return 'Огненный праздник';
      case PaganHolidayType.water:
        return 'Водный праздник';
      case PaganHolidayType.nature:
        return 'Природный праздник';
      case PaganHolidayType.protection:
        return 'Защитный ритуал';
      case PaganHolidayType.fertility:
        return 'Праздник плодородия';
    }
  }

  String _getMonthName(int month) {
    const months = [
      'января', 'февраля', 'марта', 'апреля', 'мая', 'июня',
      'июля', 'августа', 'сентября', 'октября', 'ноября', 'декабря'
    ];
    return months[month - 1];
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }
}

// Вспомогательная функция для показа модалки
Future<void> showHolidayInfoModal(BuildContext context, PaganHoliday holiday) {
  return showDialog(
    context: context,
    barrierDismissible: true,
    barrierColor: Colors.transparent,
    builder: (context) => HolidayInfoModal(holiday: holiday),
  );
}