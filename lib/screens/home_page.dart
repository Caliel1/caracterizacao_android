import 'package:flutter/material.dart';

import 'display_page.dart';
import 'touch_page.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text(
            'Caracterização do Android',
          ),
          bottom: const TabBar(
            tabs: [
              Tab(
                icon: Icon(Icons.phone_android),
                text: 'DISPLAY',
              ),
              Tab(
                icon: Icon(Icons.touch_app),
                text: 'TOUCHSCREEN',
              ),
            ],
          ),
        ),

        body: const TabBarView(
          // Impede que o usuário mude de aba
          // arrastando horizontalmente.
          physics: NeverScrollableScrollPhysics(),

          children: [
            DisplayPage(),
            TouchPage(),
          ],
        ),
      ),
    );
  }
}