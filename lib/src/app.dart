import 'package:flutter/material.dart';

import 'home_page.dart';
import 'theme.dart';

class GhaIndieWorkerApp extends StatelessWidget {
  const GhaIndieWorkerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'GHA Indie Worker',
      debugShowCheckedModeBanner: false,
      theme: appTheme(),
      home: const HomePage(),
    );
  }
}

