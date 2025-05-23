import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:just_audio/just_audio.dart';
import 'package:lottie/lottie.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/quote.dart';

class ContextPage extends StatefulWidget {
  final Quote quote;
  final Color textColor;
  final String imageUrl;

  const ContextPage({
    super.key,
    required this.quote,
    required this.textColor,
    required this.imageUrl,
  });

  @override
  State<ContextPage> createState() => _ContextPageState();
}

class _ContextPageState extends State<ContextPage>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final AudioPlayer _pageSound;
  late final AudioPlayer _ambiencePlayer;
  late final AnimationController _animCtrl;
  late final Animation<double> _fadeAnim;
  bool _showHint = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeIn);

    _initAudio();
    _checkHint();
    _animCtrl.forward();
  }

  Future<void> _checkHint() async {
    final prefs = await SharedPreferences.getInstance();
    final shown = prefs.getBool('context_hint_shown') ?? false;
    if (!shown) {
      setState(() => _showHint = true);
      await prefs.setBool('context_hint_shown', true);
    }
  }

  Future<void> _initAudio() async {
    _pageSound = AudioPlayer();
    _ambiencePlayer = AudioPlayer();

    await _pageSound.setAsset('assets/sounds/page_turn.mp3');
    await _ambiencePlayer.setAsset('assets/sounds/candle.mp3');
    _ambiencePlayer.setLoopMode(LoopMode.one);

    _pageSound.play();
    _ambiencePlayer.play();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _ambiencePlayer.pause();
    } else if (state == AppLifecycleState.resumed) {
      _ambiencePlayer.play();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pageSound.dispose();
    _ambiencePlayer.dispose();
    _animCtrl.dispose();
    super.dispose();
  }

  List<InlineSpan> _buildContextText() {
    final context = widget.quote.context;
    final quoteText = widget.quote.text.trim();
    final parts = context.split(quoteText);
    return [
      TextSpan(
        text: parts[0],
        style: const TextStyle(fontStyle: FontStyle.italic),
      ),
      TextSpan(
        text: quoteText,
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
      TextSpan(
        text: parts.length > 1 ? parts[1] : '',
        style: const TextStyle(fontStyle: FontStyle.italic),
      ),
    ];
  }

  String? _getThemeIdFromQuoteId() {
    final id = widget.quote.id;
    if (id.contains("_")) {
      return id.split("_")[0];
    }
    return null;
  }

  Widget _buildLottieAnimation() {
    final theme = _getThemeIdFromQuoteId();
    if (theme == null) return const SizedBox.shrink();
    final path = 'assets/animations/$theme.json';

    return FutureBuilder(
      future: rootBundle.load(path).catchError((_) => null),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox.shrink();
        return IgnorePointer(
          child: Lottie.asset(
            path,
            fit: BoxFit.cover,
            repeat: true,
            animate: true,
          ),
        );
      },
    );
  }

  void _handleSwipeDown() {
    Navigator.of(context).pop();
  }

 
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onVerticalDragEnd: (details) {
          if (details.primaryVelocity != null && details.primaryVelocity! > 300) {
            Navigator.of(context).pop();
          }
        },
        child: FadeTransition(
          opacity: _fadeAnim,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.asset(
                'assets/images/book_background.jpg',
                fit: BoxFit.cover,
              ),
              Container(color: Colors.black.withOpacity(0.5)),
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.brown.withOpacity(0.35),
                      Colors.transparent,
                      Colors.brown.withOpacity(0.35),
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ),
              _buildLottieAnimation(),
              SafeArea(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: RichText(
                      textAlign: TextAlign.justify,
                      text: TextSpan(
                        style: GoogleFonts.merriweather(
                          fontSize: 18,
                          height: 1.5,
                          color: widget.textColor,
                        ),
                        children: _buildContextText(),
                      ),
                    ),
                  ),
                ),
              ),
              if (_showHint)
                Positioned(
                  bottom: 24,
                  left: 0,
                  right: 0,
                  child: Icon(Icons.keyboard_arrow_down, color: widget.textColor, size: 32),
                ),
            ],
          ),
        ),
      ),
    );
  }
 }