import 'package:flutter/material.dart';

import 'features/ludo/view/lobby_screen.dart';

class LudoApp extends StatelessWidget {
  const LudoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(child: LobbyScreen()),
      ),
    );
  }
}
