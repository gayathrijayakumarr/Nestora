import 'package:flutter/material.dart';
import 'screens/landing_screen.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'screens/vitals_screen.dart';
import 'screens/symptoms_screen.dart';
import 'screens/reminders_screen.dart';
import 'screens/nutrition_screen.dart';
import 'screens/profile_screen.dart';

void main() {
  runApp(const NestoraApp());
}

class NestoraApp extends StatelessWidget {
  const NestoraApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'NESTORA',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFE91E63),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        fontFamily: 'Roboto',
      ),
      home: const LandingScreen(),
      routes: {
        '/landing': (context) => const LandingScreen(),
        '/login': (context) => const LoginScreen(),
        '/home': (context) => const HomeScreen(),
        '/vitals': (context) => const VitalsScreen(),
        '/symptoms': (context) => const SymptomsScreen(),
        '/reminders': (context) => const RemindersScreen(),
        '/nutrition': (context) => const NutritionScreen(),
        '/profile': (context) => const ProfileScreen(),
      },
    );
  }
}
