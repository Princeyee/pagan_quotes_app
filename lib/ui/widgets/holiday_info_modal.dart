
// lib/ui/widgets/holiday_info_modal.dart - ОБНОВЛЕННАЯ ВЕРСИЯ С ИНДИКАТОРАМИ ДОСТОВЕРНОСТИ
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_plus/share_plus.dart';
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
  late AnimationController _animController;
  late AnimationController _contentController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
  }

  void _initializeAnimations() {
    _animController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    _contentController = AnimationController(
      duration: const Duration(milliseconds: 600),
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

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _contentController,
      curve: Curves.easeOutCubic,
    ));

    _animController.forward();
    Future.delayed(const Duration(milliseconds: 200), () {
      _contentController.forward();
    });
  }

  @override
  Widget build(BuildContext context) {
    final traditionColor = Color(int.parse(widget.holiday.traditionColor.replaceFirst('#', '0xFF')));
    
    return GestureDetector(
      onTap: () => Navigator.of(context).pop(),
      child: Material(
        color: Colors.transparent,
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Container(
            color: Colors.black.withOpacity(0.8),
            child: SafeArea(
              child: Center(
                child: GestureDetector(
                  onTap: () {}, // Предотвращаем закрытие при тапе на контент
                  child: ScaleTransition(
                    scale: _scaleAnimation,
                    child: Container(
                      margin: const EdgeInsets.all(20),
                      constraints: BoxConstraints(
                        maxWidth: 500,
                        maxHeight: MediaQuery.of(context).size.height * 0.9,
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
                        children: [
                          _buildHeader(traditionColor),
                          Expanded(
                            child: SlideTransition(
                              position: _slideAnimation,
                              child: _buildContent(traditionColor),
                            ),
                          ),
                          _buildActions(traditionColor),
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
    );
  }

  Widget _buildHeader(Color traditionColor) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            traditionColor.withOpacity(0.08),
            traditionColor.withOpacity(0.04),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
        border: Border(
          bottom: BorderSide(color: traditionColor.withOpacity(0.15)),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              gradient: RadialGradient(
                colors: [
                  traditionColor.withOpacity(0.15),
                  traditionColor.withOpacity(0.05),
                  Colors.transparent,
                ],
              ),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: _getHolidayIcon(widget.holiday.type, traditionColor.withOpacity(0.7)),
            ),
          ),
          const SizedBox(width: 16),
          
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Название с индикатором достоверности
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        widget.holiday.name,
                        style: GoogleFonts.merriweather(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _buildAuthenticityBadge(widget.holiday.authenticity),
                  ],
                ),
                
                if (widget.holiday.nameOriginal != widget.holiday.name) ...[
                  const SizedBox(height: 4),
                  Text(
                    widget.holiday.nameOriginal,
                    style: TextStyle(
                      fontSize: 16,
                      fontStyle: FontStyle.italic,
                      color: traditionColor.withOpacity(0.8),
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: traditionColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: traditionColor.withOpacity(0.25),
                      width: 1,
                    ),
                  ),
                  child: Text(
                    _getTraditionDisplayName(widget.holiday.tradition),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: traditionColor.withOpacity(0.9),
                    ),
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

  Widget _buildAuthenticityBadge(HistoricalAuthenticity authenticity) {
    final authenticityData = _getAuthenticityData(authenticity);
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: authenticityData['color'].withOpacity(0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: authenticityData['color'].withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            authenticityData['icon'],
            size: 12,
            color: authenticityData['color'],
          ),
          const SizedBox(width: 4),
          Text(
            authenticityData['shortLabel'],
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: authenticityData['color'],
            ),
          ),
        ],
      ),
    );
  }

  Map<String, dynamic> _getAuthenticityData(HistoricalAuthenticity authenticity) {
    switch (authenticity) {
      case HistoricalAuthenticity.authentic:
        return {
          'icon': Icons.verified,
          'color': Colors.green,
          'shortLabel': 'Подлинный',
        };
      case HistoricalAuthenticity.likely:
        return {
          'icon': Icons.check_circle_outline,
          'color': Colors.blue,
          'shortLabel': 'Вероятный',
        };
      case HistoricalAuthenticity.reconstructed:
        return {
          'icon': Icons.construction,
          'color': Colors.orange,
          'shortLabel': 'Реконструкция',
        };
      case HistoricalAuthenticity.modern:
        return {
          'icon': Icons.new_releases,
          'color': Colors.red,
          'shortLabel': 'Современный',
        };
    }
  }

  Widget _buildContent(Color traditionColor) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Дата празднования
          _buildSimpleInfoSection(
            'Дата празднования',
            '${widget.holiday.date.day} ${_getMonthName(widget.holiday.date.month)}',
            traditionColor,
          ),
          
          const SizedBox(height: 20),
          
          // Описание
          _buildSimpleInfoSection(
            'Описание',
            widget.holiday.description,
            traditionColor,
          ),
          
          // Расширенное описание
          if (widget.holiday.longDescription != null) ...[
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.white.withOpacity(0.1),
                ),
              ),
              child: Text(
                widget.holiday.longDescription!,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.white.withOpacity(0.9),
                  height: 1.6,
                ),
              ),
            ),
          ],
          
          const SizedBox(height: 20),
          
          // Историческая достоверность
          _buildAuthenticityInfo(widget.holiday),
          
          const SizedBox(height: 20),
          
          // Традиции празднования
          if (widget.holiday.traditions.isNotEmpty)
            _buildSimpleListSection(
              'Традиции празднования',
              widget.holiday.traditions,
              traditionColor,
            ),
          
          const SizedBox(height: 20),
          
          // Символы
          if (widget.holiday.symbols.isNotEmpty)
            _buildSimpleListSection(
              'Символы',
              widget.holiday.symbols,
              traditionColor,
            ),
          
          const SizedBox(height: 20),
          
          // Тип праздника
          _buildSimpleInfoSection(
            'Тип праздника',
            _getHolidayTypeDisplayName(widget.holiday.type),
            traditionColor,
          ),
          
          // Источники
          if (widget.holiday.sources.isNotEmpty) ...[
            const SizedBox(height: 20),
            _buildSourcesSection(widget.holiday.sources),
          ],
        ],
      ),
    );
  }

  Widget _buildAuthenticityInfo(PaganHoliday holiday) {
    final authenticityData = _getAuthenticityData(holiday.authenticity);
    final authenticityColor = authenticityData['color'] as Color;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Уровень достоверности
        _buildSimpleInfoSection(
          'Историческая достоверность',
          holiday.authenticityDescription,
          authenticityColor,
        ),
        
        // Предупреждение для современных изобретений
        if (holiday.authenticity == HistoricalAuthenticity.modern) ...[
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.red.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.red.withOpacity(0.3)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.warning, color: Colors.red, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'ВНИМАНИЕ: Это современное изобретение, не имеющее исторических корней',
                    style: TextStyle(
                      color: Colors.red,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
        
        // Предупреждение для реконструкций
        if (holiday.authenticity == HistoricalAuthenticity.reconstructed) ...[
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.orange.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.orange.withOpacity(0.3)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info, color: Colors.orange, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'ПРИМЕЧАНИЕ: Праздник реконструирован на основе фольклорных данных и может не соответствовать древним практикам',
                    style: TextStyle(
                      color: Colors.orange,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildSourcesSection(List<String> sources) {
    return Column(
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
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.2),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Colors.white.withOpacity(0.1),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: sources.map((source) => Padding(
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
          ),
        ),
      ],
    );
  }

  Widget _buildSimpleInfoSection(String title, String content, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: color.withOpacity(0.9),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          content,
          style: TextStyle(
            fontSize: 16,
            color: Colors.white.withOpacity(0.9),
            height: 1.5,
          ),
        ),
      ],
    );
  }

  Widget _buildSimpleListSection(String title, List<String> items, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: color.withOpacity(0.9),
          ),
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
    );
  }

  Widget _buildActions(Color traditionColor) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: Colors.white.withOpacity(0.1)),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildActionButton(
              icon: Icons.share_outlined,
              label: 'Поделиться',
              color: Colors.white.withOpacity(0.8),
              onTap: _shareHoliday,
            ),
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
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
          decoration: BoxDecoration(
            color: color.withOpacity(0.06),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: color.withOpacity(0.15),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color, size: 18),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  label,
                  style: TextStyle(
                    color: color,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
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
Достоверность: ${holiday.authenticityDescription}

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
    _animController.dispose();
    _contentController.dispose();
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