import 'package:flutter/material.dart';
import 'widgets/quote_page.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    print('📦 Приложение запускается...');
    return MaterialApp(
      title: 'Pagan Quotes',
      debugShowCheckedModeBanner: false,
      home: const QuotePage(),
    );
  }
}