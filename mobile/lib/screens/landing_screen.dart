import 'package:flutter/material.dart';
import 'dart:async';

class LandingScreen extends StatefulWidget {
  const LandingScreen({super.key});

  @override
  State<LandingScreen> createState() => _LandingScreenState();
}

class _LandingScreenState extends State<LandingScreen>
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late AnimationController _scaleController;
  late Animation<double> _fadeIn;
  late Animation<Offset> _slideUp;
  late Animation<double> _scaleIn;

  Timer? _navTimer;
  final String _brandName = 'NESTORA';
  late List<AnimationController> _letterControllers;
  late List<Animation<double>> _letterOpacities;
  late List<Animation<Offset>> _letterSlides;

  @override
  void initState() {
    super.initState();

    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _slideController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _fadeIn = CurvedAnimation(parent: _fadeController, curve: Curves.easeIn);
    _slideUp = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _slideController, curve: Curves.easeOut));
    _scaleIn = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.easeOutBack),
    );

    _letterControllers = List.generate(_brandName.length, (i) {
      return AnimationController(
        duration: const Duration(milliseconds: 600),
        vsync: this,
      );
    });

    _letterOpacities = _letterControllers.map((c) {
      return Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: c, curve: Curves.easeIn),
      );
    }).toList();

    _letterSlides = _letterControllers.map((c) {
      return Tween<Offset>(
        begin: const Offset(0, 0.5),
        end: Offset.zero,
      ).animate(CurvedAnimation(parent: c, curve: Curves.easeOutBack));
    }).toList();

    _startAnimations();

    // Held in a field so dispose() can cancel it. An orphaned timer fires
    // after the widget is gone and trips the "timer still pending"
    // assertion in tests.
    _navTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/login');
      }
    });
  }

  void _startAnimations() async {
    _fadeController.forward();
    _slideController.forward();

    for (int i = 0; i < _letterControllers.length; i++) {
      await Future.delayed(const Duration(milliseconds: 100));
      if (mounted) _letterControllers[i].forward();
    }

    await Future.delayed(const Duration(milliseconds: 300));
    if (mounted) _scaleController.forward();
  }

  @override
  void dispose() {
    _navTimer?.cancel();
    _navTimer = null;
    _fadeController.dispose();
    _slideController.dispose();
    _scaleController.dispose();
    for (final c in _letterControllers) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFFFF0F5),
              Color(0xFFFFF8FC),
              Color(0xFFFCE4EC),
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              const Spacer(flex: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(_brandName.length, (i) {
                  return SlideTransition(
                    position: _letterSlides[i],
                    child: FadeTransition(
                      opacity: _letterOpacities[i],
                      child: Text(
                        _brandName[i],
                        style: const TextStyle(
                          fontSize: 42,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFFEC4899),
                          letterSpacing: 4,
                        ),
                      ),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 14),
              ScaleTransition(
                scale: _scaleIn,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEC4899).withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'Smart Maternal Healthcare',
                    style: TextStyle(
                      fontSize: 13,
                      color: Color(0xFF7D6B82),
                      letterSpacing: 1.5,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
              const Spacer(flex: 4),
              FadeTransition(
                opacity: _fadeIn,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(3, (i) {
                    return AnimatedBuilder(
                      animation: _fadeController,
                      builder: (context, child) {
                        final delay = i * 0.3;
                        final value = (_fadeController.value + delay) % 1.0;
                        final opacity =
                            (0.3 + (value * 0.7)).clamp(0.3, 1.0);
                        return Container(
                          width: i == 1 ? 24 : 6,
                          height: 6,
                          margin: const EdgeInsets.symmetric(horizontal: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEC4899)
                                .withValues(alpha: opacity),
                            borderRadius: BorderRadius.circular(3),
                          ),
                        );
                      },
                    );
                  }),
                ),
              ),
              const SizedBox(height: 20),
              const Padding(
                padding: EdgeInsets.only(bottom: 40),
                child: Text(
                  'Made with care for every mother',
                  style: TextStyle(
                    fontSize: 11,
                    color: Color(0xFFB0A3B4),
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
