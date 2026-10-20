import 'package:flutter/material.dart';

import 'src/home_page.dart';

void main() => runApp(const BenchApp());

class BenchApp extends StatelessWidget {
  const BenchApp({super.key, this.home = const HomePage()});

  final Widget home;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Platform View Bench',
      theme: ThemeData(colorSchemeSeed: Colors.indigo),
      darkTheme: ThemeData(colorSchemeSeed: Colors.indigo, brightness: Brightness.dark),
      home: home,
    );
  }
}
