import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class SplashScreen extends StatefulWidget {
  final Widget nextScreen;
  const SplashScreen({super.key, required this.nextScreen});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final String appName = "AEGIS";

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );

    _controller.forward();

    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        Future.delayed(const Duration(milliseconds: 700), () {
          if (mounted) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (_) => widget.nextScreen),
            );
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A3A5C),
      body: Center(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: _buildLetters(),
            );
          },
        ),
      ),
    );
  }

  List<Widget> _buildLetters() {
    final letters = appName.split('');
    final letterCount = letters.length;

    return List.generate(letterCount, (i) {
      // Each letter gets its own slice of the timeline, one after another
      final start = i / letterCount;
      final end = (i + 1) / letterCount;

      final letterProgress = CurvedAnimation(
        parent: _controller,
        curve: Interval(start, end, curve: Curves.easeIn),
      ).value;

      final opacity = letterProgress.clamp(0.0, 1.0);

      return Opacity(
        opacity: opacity,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: Text(
            letters[i],
            style: GoogleFonts.poppins(
              fontSize: 42,
              fontWeight: FontWeight.w600,
              color: Colors.white,
              letterSpacing: 4,
            ),
          ),
        ),
      );
    });
  }
}