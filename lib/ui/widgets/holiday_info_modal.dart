
import 'package:flutter/material.dart';
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
            // Тёмный фон
            GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              child: Container(
                color: Colors.black.withAlpha((0.8 * 255).round()),
              ),
            ),
            
            // Сворачивающееся окно
            DraggableScrollableSheet(
              initialChildSize: 0.8,
              minChildSize: 0.05,
              maxChildSize: 0.95,
              snap: true,
              snapSizes: const [0.05, 0.8, 0.95],
              builder: (context, scrollController) {
                return NotificationListener<DraggableScrollableNotification>(
                  onNotification: (notification) {
                    // Не закрываем автоматически - пусть пользователь сам решает
                    return false;
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(20),
                        topRight: Radius.circular(20),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withAlpha((0.4 * 255).round()),
                          blurRadius: 25,
                          spreadRadius: 0,
                          offset: const Offset(0, -8),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(20),
                        topRight: Radius.circular(20),
                      ),
                      child: BackdropFilter(
                        filter: ui.ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.black.withAlpha((0.97 * 255).round()),
                                Colors.black.withAlpha((0.98 * 255).round()),
                                Colors.black.withAlpha((0.99 * 255).round()),
                              ],
                              stops: const [0.0, 0.5, 1.0],
                            ),
                            border: Border.all(
                              color: Colors.white.withAlpha((0.08 * 255).round()),
                              width: 1,
                            ),
                          ),
                          child: Column(
                            children: [
                              _buildMinimalHeader(traditionColor),
                              Expanded(
                                child: _buildScrollableContent(scrollController, traditionColor),
                              ),
                            ],
                          ),
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

  Widget _buildMinimalHeader(Color traditionColor) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            traditionColor.withAlpha((0.15 * 255).round()),
            traditionColor.withAlpha((0.08 * 255).round()),
            Colors.black.withAlpha((0.05 * 255).round()),
          ],
          stops: const [0.0, 0.5, 1.0],
        ),
        border: Border(
          bottom: BorderSide(
            color: traditionColor.withAlpha((0.25 * 255).round()),
            width: 0.5, // Тонкая линия как в Apple
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Название с системным шрифтом Apple
                Text(
                  widget.holiday.name,
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                    letterSpacing: -0.5, // Типичный spacing Apple
                    height: 1.1,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                
                // Оригинальное название, если отличается
                if (widget.holiday.nameOriginal != widget.holiday.name) ...[
                  const SizedBox(height: 6),
                  Text(
                    widget.holiday.nameOriginal,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w400,
                      color: Colors.white.withAlpha((0.7 * 255).round()),
                      fontStyle: FontStyle.italic,
                      letterSpacing: -0.2,
                    ),
                  ),
                ],
                
                const SizedBox(height: 12),
                
                // Минимальный бейдж традиции
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        traditionColor.withAlpha((0.18 * 255).round()),
                        traditionColor.withAlpha((0.12 * 255).round()),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(16), // Rounded как в iOS
                    border: Border.all(
                      color: traditionColor.withAlpha((0.3 * 255).round()),
                      width: 0.5,
                    ),
                  ),
                  child: Text(
                    _getTraditionDisplayName(widget.holiday.tradition),
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: Colors.white,
                      letterSpacing: -0.1,
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // Кнопка закрытия в стиле iOS
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: Colors.white.withAlpha((0.08 * 255).round()),
              shape: BoxShape.circle,
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(15),
                onTap: () => Navigator.of(context).pop(),
                child: const Icon(
                  Icons.close,
                  color: Colors.white,
                  size: 16,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScrollableContent(ScrollController scrollController, Color traditionColor) {
    return SingleChildScrollView(
      controller: scrollController,
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 32), // Apple spacing
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSimpleCard(
            'Дата празднования',
            '${widget.holiday.date.day} ${_getMonthName(widget.holiday.date.month)}',
            traditionColor,
          ),
          
          const SizedBox(height: 20),
          
          _buildSimpleCard(
            'Описание',
            widget.holiday.description,
            traditionColor,
          ),
          
          if (widget.holiday.longDescription != null) ...[
            const SizedBox(height: 20),
            _buildLongDescriptionCard(widget.holiday.longDescription!, traditionColor),
          ],
          
          const SizedBox(height: 20),
          
          _buildSimpleCard(
            'Происхождение',
            _getSimpleDescription(widget.holiday.authenticity),
            Colors.grey[600]!,
          ),
          
          const SizedBox(height: 20),
          
          if (widget.holiday.traditions.isNotEmpty)
            _buildListCard(
              'Традиции празднования',
              widget.holiday.traditions,
              traditionColor,
            ),
          
          const SizedBox(height: 20),
          
          if (widget.holiday.symbols.isNotEmpty)
            _buildListCard(
              'Символы',
              widget.holiday.symbols,
              traditionColor,
            ),
          
          const SizedBox(height: 20),
          
          _buildSimpleCard(
            'Тип праздника',
            _getHolidayTypeDisplayName(widget.holiday.type),
            traditionColor,
          ),
          
          if (widget.holiday.sources.isNotEmpty) ...[
            const SizedBox(height: 20),
            _buildSourcesCard(widget.holiday.sources),
          ],
          
          const SizedBox(height: 32),
          
          _buildShareButton(traditionColor),
          
          const SizedBox(height: 40), // Больше места внизу
        ],
      ),
    );
  }

  Widget _buildSimpleCard(String title, String content, Color color) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20), // Apple стандарт
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            color.withAlpha((0.06 * 255).round()),
            Colors.black.withAlpha((0.1 * 255).round()),
          ],
        ),
        borderRadius: BorderRadius.circular(16), // iOS стандарт
        border: Border.all(
          color: color.withAlpha((0.2 * 255).round()),
          width: 0.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha((0.1 * 255).round()),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: color.withAlpha((0.8 * 255).round()),
              letterSpacing: -0.1,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            content,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w400,
              color: Colors.white,
              height: 1.4,
              letterSpacing: -0.2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLongDescriptionCard(String content, Color traditionColor) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24), // Больше места для длинного текста
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            traditionColor.withAlpha((0.08 * 255).round()),
            Colors.black.withAlpha((0.15 * 255).round()),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: traditionColor.withAlpha((0.2 * 255).round()),
          width: 0.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha((0.1 * 255).round()),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Text(
        content,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w400,
          color: Colors.white,
          height: 1.5,
          letterSpacing: -0.2,
        ),
      ),
    );
  }

  Widget _buildListCard(String title, List<String> items, Color color) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            color.withAlpha((0.06 * 255).round()),
            Colors.black.withAlpha((0.1 * 255).round()),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: color.withAlpha((0.2 * 255).round()),
          width: 0.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha((0.1 * 255).round()),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: color.withAlpha((0.8 * 255).round()),
              letterSpacing: -0.1,
            ),
          ),
          const SizedBox(height: 16),
          ...items.asMap().entries.map((entry) {
            final isLast = entry.key == items.length - 1;
            return Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 4,
                    height: 4,
                    margin: const EdgeInsets.only(top: 8, right: 16),
                    decoration: BoxDecoration(
                      color: color.withAlpha((0.6 * 255).round()),
                      shape: BoxShape.circle,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      entry.value,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w400,
                        color: Colors.white,
                        height: 1.4,
                        letterSpacing: -0.2,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildSourcesCard(List<String> sources) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black.withAlpha((0.6 * 255).round()),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withAlpha((0.05 * 255).round()),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Источники',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.white.withAlpha((0.6 * 255).round()),
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 12),
          ...sources.map((source) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 3,
                  height: 3,
                  margin: const EdgeInsets.only(top: 8, right: 12),
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha((0.3 * 255).round()),
                    shape: BoxShape.circle,
                  ),
                ),
                Expanded(
                  child: Text(
                    source,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.white.withAlpha((0.7 * 255).round()),
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
            padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  traditionColor.withAlpha((0.08 * 255).round()),
                  Colors.black.withAlpha((0.1 * 255).round()),
                ],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: traditionColor.withAlpha((0.25 * 255).round()),
                width: 0.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha((0.1 * 255).round()),
                  blurRadius: 20,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.share,
                  color: Colors.white,
                  size: 18,
                ),
                SizedBox(width: 12),
                Text(
                  'Поделиться',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.2,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

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

Future<void> showHolidayInfoModal(BuildContext context, PaganHoliday holiday) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => HolidayInfoModal(holiday: holiday),
  );
}