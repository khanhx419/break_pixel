import 'package:flutter/material.dart';
import 'screens/prologue_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const BreakPixelApp());
}

class BreakPixelApp extends StatelessWidget {
  const BreakPixelApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Break Pixel',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0F172A),
        colorScheme: const ColorScheme.dark(
          primary: Colors.amberAccent,
          secondary: Colors.cyanAccent,
          surface: Color(0xFF1E293B),
        ),
        fontFamily: 'Roboto',
        useMaterial3: true,
      ),
      home: const PrologueScreen(),
    );
  }
}
