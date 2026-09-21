import 'package:flutter/material.dart';

import 'screens/home_page.dart';

void main() {
  runApp(const CharacterizationApp());
}

class CharacterizationApp extends StatelessWidget {
  const CharacterizationApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Caracterização Android',
      theme: ThemeData(
        useMaterial3: true,
      ),
      home: const HomePage(),
    );
  }
}